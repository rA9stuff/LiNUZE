// LZLandingViewController.m

#import "LZLandingViewController.h"

@interface LZLandingViewController ()
// Retained reference so the alert can be dismissed on the main thread.
@property (nonatomic, strong) UIAlertController *daemonWaitAlert;
@end

@implementation LZLandingViewController

// ---------------------------------------------------------------------------
#pragma mark - View lifecycle
// ---------------------------------------------------------------------------

- (void)viewDidLoad {
    [super viewDidLoad];
    NSAssert(self.viewModel, @"viewModel must be set before presentation");

    [self _styleView];
    [self _applyDynamicLayout];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(_daemonReady:)
               name:LZLandingViewModelDaemonReadyNotification
             object:self.viewModel];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self _showDaemonWaitAlertIfNeeded];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// ---------------------------------------------------------------------------
#pragma mark - IBActions
// ---------------------------------------------------------------------------

- (IBAction)doneButtonTapped:(id)sender {
    [self.viewModel completeLanding];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)viewProjectButtonTapped:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://github.com/ra9stuff/LiNUZE"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

// ---------------------------------------------------------------------------
#pragma mark - Daemon wait
// ---------------------------------------------------------------------------

- (void)_showDaemonWaitAlertIfNeeded {
    // The ViewModel will post a notification when the daemon is ready;
    // if it is already running, the notification fires immediately.
    [self.viewModel waitForDaemonIfNeeded];
}

- (void)_daemonReady:(NSNotification *)note {
    [self.daemonWaitAlert dismissViewControllerAnimated:YES completion:nil];
    self.daemonWaitAlert = nil;
}

// ---------------------------------------------------------------------------
#pragma mark - Layout & styling
// ---------------------------------------------------------------------------

- (void)_styleView {
    UIColor *teal = [UIColor colorWithRed:8/255.0 green:190/255.0 blue:190/255.0 alpha:1.0];

    [self.doneButton.titleLabel setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold]];
    [self.doneButton setBackgroundColor:teal];
    [self.doneButton.layer setCornerRadius:16];
    self.doneButton.clipsToBounds = YES;

    [self.viewProjectButton setTitle:@"View project on GitHub" forState:UIControlStateNormal];
    [self.viewProjectButton setTitleColor:teal forState:UIControlStateNormal];

    [self.greetLabel setFont:[UIFont systemFontOfSize:18 weight:UIFontWeightHeavy]];
    self.greetLabel.minimumScaleFactor     = 0.5;
    self.greetLabel.adjustsFontSizeToFitWidth = YES;

    for (UIImageView *iv in @[self.featureImage1, self.featureImage2, self.featureImage3]) {
        [iv.layer setMinificationFilter:kCAFilterTrilinear];
    }
}

- (void)_applyDynamicLayout {
    BOOL iPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat width = iPad ? 450.0 : self.view.frame.size.width;

    self.mostOuterVStack.spacing = iPad ? 60 : 30;
    self.hstack1.spacing = 20;
    self.hstack2.spacing = 20;
    self.hstack3.spacing = 20;

    // Scale greeting label font to screen width
    CGFloat fontSize = MIN(self.view.frame.size.width * 0.1, 30.0);
    self.greetLabel.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightSemibold];
    [self.greetLabel sizeToFit];

    // Done button width
    NSLayoutConstraint *btnWidth = iPad
        ? [self.doneButton.widthAnchor constraintEqualToConstant:350]
        : [self.doneButton.widthAnchor constraintEqualToConstant:width - 26];
    btnWidth.active = YES;
    [self.doneButton.heightAnchor constraintEqualToConstant:60].active = YES;
    [self.doneButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;

    // Feature row constraints
    [self _constrainRow:self.hstack1 image:self.featureImage1 label:self.detailLabel1 width:width];
    [self _constrainRow:self.hstack2 image:self.featureImage2 label:self.detailLabel2 width:width];
    [self _constrainRow:self.hstack3 image:self.featureImage3 label:self.detailLabel3 width:width];

    [self.greetLabel.widthAnchor constraintEqualToConstant:width - 60].active = YES;
}

- (void)_constrainRow:(UIStackView *)hstack
                image:(UIImageView *)imageView
                label:(UILabel *)label
                width:(CGFloat)width {
    // Measure how many lines the label needs
    CGSize labelSize = CGSizeMake(width - 110, CGFLOAT_MAX);
    NSDictionary *attrs = @{ NSFontAttributeName: label.font };
    CGRect rect = [label.text boundingRectWithSize:labelSize
                                           options:NSStringDrawingUsesLineFragmentOrigin
                                        attributes:attrs context:nil];
    NSInteger lines = (NSInteger)ceil(rect.size.height / label.font.lineHeight);
    label.numberOfLines = lines;

    [NSLayoutConstraint activateConstraints:@[
        [hstack.widthAnchor    constraintEqualToConstant:width - 50],
        [hstack.heightAnchor   constraintEqualToConstant:lines * label.font.lineHeight + 20],
        [imageView.widthAnchor constraintEqualToConstant:40],
        [imageView.heightAnchor constraintEqualToConstant:40],
        [label.widthAnchor     constraintEqualToConstant:width - 50],
    ]];
}

@end
