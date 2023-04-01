//
//  ViewController.h
//  LiNUZE
//
//  Created by rA9stuff on 15.08.2022.
//  Copyright © 2022 rA9stuff. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "LDD.h"
#define NSLog myNSLog
#undef NSLog

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *statusStr;
@property (weak, nonatomic) IBOutlet UITextView *devInfoBox;
@property (weak, nonatomic) IBOutlet UIImageView *exitRecImg;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (retain, nonatomic) IBOutlet UITextView *ipad_logview;
@property (retain, nonatomic) IBOutlet UIImageView *enter_rec_img;
@property (retain, nonatomic) IBOutlet UILabel *ipad_statusstr;
@property (retain, nonatomic) IBOutlet UIScrollView *ipad_logscrollview;
- (void)infoLog:(NSString*)text color:(UIColor*)color1;
- (void)updateStatus:(NSString*)text color:(UIColor*)color1;
- (int) PrintDevInfo:(LDD*)devptr;
- (void) gentlyActivateButtons;
- (void) gentlyDeactivateButtons;
- (void)displayCorrectBasicInterface:(id)sender devptr:(LDD* _Nullable)devptr normaldevname:(NSString* _Nullable)normalDeviceName VC:(UIViewController*)VC;
@property (nonatomic) LDD* maindevptr;
@property (retain, nonatomic) IBOutlet UIView *LiNUZE_VC;
@property (retain, nonatomic) IBOutlet UISwitch *devConsoleToggle;
@property (retain, nonatomic) IBOutlet UIImageView *statusImage;
@property (retain, nonatomic) IBOutlet UILabel *statusLabelPhone;
@property (retain, nonatomic) IBOutlet UILabel *devConsoleLabel;
@property (retain, nonatomic) IBOutlet UIImageView *iphoneImage;
@property (retain, nonatomic) IBOutlet UIView *statusContainer;
@property (retain, nonatomic) IBOutlet UIScrollView *logScrollView;
@property (retain, nonatomic) IBOutlet UIActivityIndicatorView *basicUIprogressView;
@property (retain, nonatomic) IBOutlet UIView *OnboardingView;
@property (retain, nonatomic) IBOutlet UIButton *OnboardingViewDoneButton;
@property (retain, nonatomic) IBOutlet UIStackView *leftVStack;
@property (retain, nonatomic) IBOutlet UILabel *alignment;
@property (retain, nonatomic) IBOutlet UIStackView *iphone_logview_hstack;
@property (retain, nonatomic) IBOutlet UIButton *iphone_logview_dismissButton;
@property (retain, nonatomic) IBOutlet UILabel *logwindow_label;
@property (retain, nonatomic) IBOutlet UIStackView *logview_hstack;
@property (retain, nonatomic) IBOutlet UILabel *versionLabeliPad;

@property (retain, nonatomic) IBOutlet UIView *enterRecoveryButtonOutlet;
@property (retain, nonatomic) IBOutlet UIView *exitRecoveryButtonOutlet;
@property (retain, nonatomic) IBOutlet UIView *setAPNonceButtonOutlet;
@property (retain, nonatomic) IBOutlet UIView *LeetDownButtonOutlet;
@property (retain, nonatomic) IBOutlet UIView *pwnDeviceButtonOutlet;
@property (retain, nonatomic) IBOutlet UIView *cv1;
@property (retain, nonatomic) IBOutlet UIView *cv2;
@property (retain, nonatomic) IBOutlet UIView *cv3;
@property (retain, nonatomic) IBOutlet UIView *cv4;
@property (retain, nonatomic) IBOutlet UIView *cv5;
@property (retain, nonatomic) IBOutlet UIView *ipad_upper_container;
@property (retain, nonatomic) IBOutlet UIView *ipad_bottom_container;
@property (retain, nonatomic) IBOutlet UIView *iphone_upper_container;
@property (retain, nonatomic) IBOutlet UIView *iphone_bottom_container;
@property (retain, nonatomic) IBOutlet UILabel *cpu_usage_label;

@property (retain, nonatomic) IBOutlet UIScrollView *firstScrollView;
@property (retain, nonatomic) IBOutlet UIScrollView *secondScrollView;



@end

int checkDaemon();
