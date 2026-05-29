// LZMainViewController.h – Main screen. Binds to LZMainViewModel.
// No business logic here; the VC only translates ViewModel state into
// UIKit updates and user actions into ViewModel method calls.

#import <UIKit/UIKit.h>
#import "LZMainViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface LZMainViewController : UIViewController

// Injected by the coordinator/AppDelegate before presentation.
@property (nonatomic, strong) LZMainViewModel *viewModel;

// -----------------------------------------------------------------------
// IBOutlets – iPad layout
// -----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UIView       *ipadUpperContainer;
@property (weak, nonatomic) IBOutlet UIView       *ipadBottomContainer;
@property (weak, nonatomic) IBOutlet UITextView   *ipadLogView;
@property (weak, nonatomic) IBOutlet UIScrollView *ipadLogScrollView;
@property (weak, nonatomic) IBOutlet UILabel      *ipadStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel      *versionLabelIPad;

// -----------------------------------------------------------------------
// IBOutlets – iPhone layout
// -----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UIView       *iphoneUpperContainer;
@property (weak, nonatomic) IBOutlet UIView       *iphoneBottomContainer;
@property (weak, nonatomic) IBOutlet UILabel      *statusLabel;
@property (weak, nonatomic) IBOutlet UILabel      *versionLabel;

// -----------------------------------------------------------------------
// IBOutlets – shared / status card
// -----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UIView                  *statusContainer;
@property (weak, nonatomic) IBOutlet UIImageView             *deviceImageView;
@property (weak, nonatomic) IBOutlet UIImageView             *statusIconView;
@property (weak, nonatomic) IBOutlet UILabel                 *statusDetailLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *connectingSpinner;

// -----------------------------------------------------------------------
// IBOutlets – buttons (outer container views for tap animation)
// -----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UIView *enterRecoveryButton;
@property (weak, nonatomic) IBOutlet UIView *exitRecoveryButton;
@property (weak, nonatomic) IBOutlet UIView *setAPNonceButton;
@property (weak, nonatomic) IBOutlet UIView *leetDownButton;
@property (weak, nonatomic) IBOutlet UIView *pwnDeviceButton;

// -----------------------------------------------------------------------
// IBOutlets – misc
// -----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UISwitch     *devConsoleToggle;
@property (weak, nonatomic) IBOutlet UILabel      *devConsoleLabel;
@property (weak, nonatomic) IBOutlet UIScrollView *logScrollView;
@property (weak, nonatomic) IBOutlet UILabel      *cpuUsageLabel;

@end

NS_ASSUME_NONNULL_END
