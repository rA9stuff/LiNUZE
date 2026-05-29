// LZMainViewController.mm
//
// This file only contains UIKit binding code. Zero device logic lives here.
// Pattern: observe NSNotifications from the ViewModel → call -_updateUI.

#import "LZMainViewController.h"
#import "LZLandingViewController.h"
#import "LZLandingViewModel.h"
#import "LZPreferencesService.h"

@interface LZMainViewController ()
@property (nonatomic, strong) LZLandingViewModel *landingViewModel;
@end

@implementation LZMainViewController

// ---------------------------------------------------------------------------
#pragma mark - View lifecycle
// ---------------------------------------------------------------------------

- (void)viewDidLoad {
    [super viewDidLoad];
    NSAssert(self.viewModel, @"viewModel must be set before presentation");

    [self _styleLogView];
    [self _applyVersionLabel];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(_onStateUpdate:)
               name:LZMainViewModelDidUpdateStateNotification
             object:self.viewModel];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(_onLogUpdate:)
               name:LZMainViewModelDidUpdateLogNotification
             object:self.viewModel];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self _styleButtonContainers];
    self.navigationItem.hidesBackButton = YES;
    self.ipadLogScrollView.showsVerticalScrollIndicator = NO;
    self.logScrollView.showsVerticalScrollIndicator     = NO;

    // Restore dev-console toggle state from the ViewModel.
    [self.devConsoleToggle setOn:self.viewModel.devConsoleEnabled animated:NO];
    [self _applyConsoleLayout:self.viewModel.devConsoleEnabled];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Activate the ViewModel once (guard is inside activate).
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        [self.viewModel activate];
        [self _updateUI];
        [self _showLandingIfNeeded];
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// ---------------------------------------------------------------------------
#pragma mark - ViewModel notification handlers
// ---------------------------------------------------------------------------

- (void)_onStateUpdate:(NSNotification *)note {
    [self _updateUI];
}

- (void)_onLogUpdate:(NSNotification *)note {
    [self _refreshLogViews];
}

// ---------------------------------------------------------------------------
#pragma mark - UI update
// ---------------------------------------------------------------------------

- (void)_updateUI {
    LZMainViewModel *vm = self.viewModel;

    // Status card
    [self _updateStatusCard];

    // CPU label
    self.cpuUsageLabel.text = vm.cpuUsageString;

    // Buttons
    BOOL enable = vm.buttonsEnabled;
    if (enable) [self _gentlyActivateButtons];
    else        [self _gentlyDeactivateButtons];

    // Console toggle
    [self.devConsoleToggle setOn:vm.devConsoleEnabled animated:YES];
    [self _applyConsoleLayout:vm.devConsoleEnabled];
}

- (void)_updateStatusCard {
    LZDeviceInfo *device = self.viewModel.connectedDevice;
    LZMainViewState state = self.viewModel.viewState;

    if (state == LZMainViewStateConnecting) {
        self.deviceImageView.hidden = YES;
        [self.connectingSpinner startAnimating];
        self.statusIconView.image = nil;
        self.statusDetailLabel.text = @"Connecting…";
        return;
    }

    [self.connectingSpinner stopAnimating];
    self.deviceImageView.hidden = NO;
    self.deviceImageView.alpha = 1.0;

    if (!device) {
        self.deviceImageView.alpha = 0;
        self.statusIconView.image = [UIImage imageNamed:@"iphone.slash"];
        self.statusDetailLabel.text = @"No device connected";
        return;
    }

    if (state == LZMainViewStateOperating) {
        self.statusIconView.image = [UIImage imageNamed:@"cloud.rain"];
        self.statusDetailLabel.text = @"Pwning device…";
        self.deviceImageView.alpha = 0;
        return;
    }

    // Device connected – build attributed status string
    BOOL isiPhone = [device.displayName containsString:@"iPhone"];
    self.deviceImageView.image = [UIImage imageNamed:isiPhone ? @"iphone_x_generic" : @"ipad_generic"];
    self.statusIconView.image  = [UIImage imageNamed:@"checkmark.seal.fill"];

    if (device.connectionMode == LZDeviceConnectionModeNormal) {
        self.statusDetailLabel.attributedText =
            [self _connectedString:device.displayName subtitle:@"Normal Mode"];
    } else {
        NSString *subtitle = [NSString stringWithFormat:@"%@ Mode",
                              [device connectionModeDisplayString]];
        if (device.isPwned)
            subtitle = [subtitle stringByAppendingFormat:@"\n\n\n\n\nPwned with %@", device.pwnTag];
        self.statusDetailLabel.attributedText =
            [self _connectedString:device.displayName subtitle:subtitle];
    }
}

- (NSAttributedString *)_connectedString:(NSString *)title subtitle:(NSString *)subtitle {
    UIFont *bold   = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    UIFont *regular = [UIFont systemFontOfSize:13];
    NSDictionary *boldAttrs    = @{ NSForegroundColorAttributeName: [UIColor whiteColor],
                                     NSFontAttributeName: bold };
    NSDictionary *regularAttrs = @{ NSForegroundColorAttributeName: [UIColor whiteColor],
                                     NSFontAttributeName: regular };
    NSMutableAttributedString *combined = [[NSMutableAttributedString alloc] init];
    [combined appendAttributedString:[[NSAttributedString alloc] initWithString:@"Connected\n\n"
                                                                     attributes:boldAttrs]];
    NSString *detail = [NSString stringWithFormat:@"%@\n%@", title, subtitle];
    [combined appendAttributedString:[[NSAttributedString alloc] initWithString:detail
                                                                     attributes:regularAttrs]];
    return combined;
}

- (void)_refreshLogViews {
    NSAttributedString *log = self.viewModel.logText;
    [self.ipadLogView.textStorage setAttributedString:log];
    [self.ipadLogView scrollRangeToVisible:NSMakeRange(self.ipadLogView.text.length, 0)];
}

// ---------------------------------------------------------------------------
#pragma mark - Button animations (UI-only, ViewModel-agnostic)
// ---------------------------------------------------------------------------

- (void)_gentlyDeactivateButtons {
    self.ipadUpperContainer.userInteractionEnabled  = NO;
    self.ipadBottomContainer.userInteractionEnabled = NO;
    [self _fadeContainers:0.30];
}

- (void)_gentlyActivateButtons {
    [self _fadeContainers:1.0];
    self.ipadUpperContainer.userInteractionEnabled  = YES;
    self.ipadBottomContainer.userInteractionEnabled = YES;
}

- (void)_fadeContainers:(CGFloat)alpha {
    [UIView animateWithDuration:0.3 animations:^{
        self.ipadUpperContainer.alpha  = alpha;
        self.ipadBottomContainer.alpha = alpha;
        self.iphoneUpperContainer.alpha  = alpha;
        self.iphoneBottomContainer.alpha = alpha;
    }];
}

- (void)_animateButtonTap:(UIView *)button {
    [UIView animateKeyframesWithDuration:0.2 delay:0 options:0 animations:^{
        [UIView addKeyframeWithRelativeStartTime:0   relativeDuration:0.5 animations:^{ button.alpha = 0.3; }];
        [UIView addKeyframeWithRelativeStartTime:0.5 relativeDuration:0.5 animations:^{ button.alpha = 1.0; }];
    } completion:^(BOOL f) {
        button.userInteractionEnabled = YES;
    }];
}

// ---------------------------------------------------------------------------
#pragma mark - IBActions
// ---------------------------------------------------------------------------

- (IBAction)enterRecoveryTapped:(id)sender {
    self.enterRecoveryButton.userInteractionEnabled = NO;
    [self _animateButtonTap:self.enterRecoveryButton];
    [self.viewModel enterRecovery];
}

- (IBAction)exitRecoveryTapped:(id)sender {
    self.exitRecoveryButton.userInteractionEnabled = NO;
    [self _animateButtonTap:self.exitRecoveryButton];
    [self.viewModel exitRecovery];
}

- (IBAction)setAPNonceTapped:(id)sender {
    [self _animateButtonTap:self.setAPNonceButton];
    [self _showUnsupported];
}

- (IBAction)leetDownTapped:(id)sender {
    [self _animateButtonTap:self.leetDownButton];
    [self _showUnsupported];
}

- (IBAction)pwnDeviceTapped:(id)sender {
    [self _animateButtonTap:self.pwnDeviceButton];
    [self.viewModel pwnDevice];
}

- (IBAction)devConsoleToggled:(UISwitch *)sender {
    [self.viewModel setDevConsoleEnabled:sender.isOn];
    [self _applyConsoleLayout:sender.isOn];
}

// ---------------------------------------------------------------------------
#pragma mark - Console / status card toggle
// ---------------------------------------------------------------------------

- (void)_applyConsoleLayout:(BOOL)consoleOn {
    [UIView animateWithDuration:0.2 animations:^{
        self.logScrollView.alpha   = consoleOn ? 1.0 : 0.0;
        self.devConsoleLabel.alpha = consoleOn ? 1.0 : 0.0;
        self.statusContainer.alpha = consoleOn ? 0.0 : 1.0;
    }];
}

// ---------------------------------------------------------------------------
#pragma mark - Onboarding
// ---------------------------------------------------------------------------

- (void)_showLandingIfNeeded {
    self.landingViewModel = [[LZLandingViewModel alloc] init];
    if (self.landingViewModel.hasLanded) {
        [self _waitForDaemonIfNeeded];
        return;
    }
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    LZLandingViewController *vc =
        [sb instantiateViewControllerWithIdentifier:@"LZLandingVC"];
    vc.viewModel = self.landingViewModel;
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)_waitForDaemonIfNeeded {
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(_daemonReady:)
               name:LZLandingViewModelDaemonReadyNotification
             object:self.landingViewModel];
    [self.landingViewModel waitForDaemonIfNeeded];
}

- (void)_daemonReady:(NSNotification *)note {
    [[NSNotificationCenter defaultCenter] removeObserver:self
        name:LZLandingViewModelDaemonReadyNotification object:nil];
}

// ---------------------------------------------------------------------------
#pragma mark - Styling helpers
// ---------------------------------------------------------------------------

- (void)_styleLogView {
    self.ipadLogView.layer.borderWidth = 1.0f;
    self.ipadLogView.layer.borderColor =
        [[UIColor colorWithRed:8/255.0 green:164/255.0 blue:167/255.0 alpha:1.0] CGColor];
}

- (void)_styleButtonContainers {
    NSArray *buttonViews = @[self.enterRecoveryButton ?: [NSNull null],
                             self.exitRecoveryButton  ?: [NSNull null],
                             self.setAPNonceButton    ?: [NSNull null],
                             self.leetDownButton      ?: [NSNull null],
                             self.pwnDeviceButton     ?: [NSNull null]];
    for (id v in buttonViews) {
        if ([v isEqual:[NSNull null]]) continue;
        UIView *view = (UIView *)v;
        for (CALayer *sub in view.layer.sublayers) {
            sub.cornerRadius  = 20;
            sub.masksToBounds = YES;
        }
    }
}

- (void)_applyVersionLabel {
    NSString *nightly = self.viewModel.nightlyHash;
    NSString *text = nightly.length
        ? [NSString stringWithFormat:@"LiNUZE nightly %@ © rA9 2023", nightly]
        : @"LiNUZE © rA9 2023";
    self.versionLabel.text     = text;
    self.versionLabelIPad.text = text;
}

- (void)_showUnsupported {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Not supported"
                                            message:@"This feature is not available yet."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
