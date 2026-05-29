// LZLandingViewController.h – Onboarding screen. Binds to LZLandingViewModel.

#import <UIKit/UIKit.h>
#import "LZLandingViewModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface LZLandingViewController : UIViewController

// Injected before presentation.
@property (nonatomic, strong) LZLandingViewModel *viewModel;

// -----------------------------------------------------------------------
// IBOutlets
// -----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UILabel      *greetLabel;
@property (weak, nonatomic) IBOutlet UIButton     *doneButton;
@property (weak, nonatomic) IBOutlet UIButton     *viewProjectButton;

@property (weak, nonatomic) IBOutlet UIStackView  *mostOuterVStack;
@property (weak, nonatomic) IBOutlet UIStackView  *hstack1;
@property (weak, nonatomic) IBOutlet UIStackView  *hstack2;
@property (weak, nonatomic) IBOutlet UIStackView  *hstack3;

@property (weak, nonatomic) IBOutlet UIImageView  *featureImage1;
@property (weak, nonatomic) IBOutlet UIImageView  *featureImage2;
@property (weak, nonatomic) IBOutlet UIImageView  *featureImage3;

@property (weak, nonatomic) IBOutlet UILabel      *detailLabel1;
@property (weak, nonatomic) IBOutlet UILabel      *detailLabel2;
@property (weak, nonatomic) IBOutlet UILabel      *detailLabel3;

@end

NS_ASSUME_NONNULL_END
