//
//  Landing.mm
//  LiNUZ
//
//  Created by rA9stuff on 6.03.2023.
//  Copyright © 2023 rA9stuff. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Landing.h"
#import "LiNUZE_VC.h"
#import "PlistModifier.h"

#define background_thread dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
#define main_thread dispatch_async(dispatch_get_main_queue(), ^()

@implementation Landing

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (false) {
   // if (checkDaemon() != 0) {
        printf("[*] waiting for launchd to start usbmuxd...\n");
        background_thread {
            __block UIAlertController *alertController = NULL;
            main_thread {
                alertController = [UIAlertController alertControllerWithTitle:@"Waiting for usbmuxd initialization" message:@"This could take up to 10 seconds. If it gets stuck here, please manually start it from a root shell." preferredStyle:UIAlertControllerStyleAlert];
                [self presentViewController:alertController animated:YES completion:nil];
            });
            
            while (checkDaemon() != 0) {
                sleep(1);
            }
            printf("[*] usbmuxd started, dismissing the VC\n");
            main_thread {
                [alertController dismissViewControllerAnimated:YES completion:nil];
            });
        });
    }
}

- (void)viewDidLoad {
    
    UILabel *label = _greetLabel;
    
    [_doneButton.titleLabel setFont:[UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold]];
    
    [_greetLabel setFont:[UIFont systemFontOfSize:18.0 weight:UIFontWeightHeavy]];
    _greetLabel.minimumScaleFactor = 0.5;
    _greetLabel.adjustsFontSizeToFitWidth = YES;
    
    [_viewProjectButton setTitle:@"View project on GitHub" forState:UIControlStateNormal];
    [_viewProjectButton setTitleColor:[UIColor colorWithRed:8/255.0 green:190/255.0 blue:190/255.0 alpha:1.0] forState:UIControlStateNormal];
    
    
    UIEdgeInsets safeAreaInsets = UIEdgeInsetsZero;
    safeAreaInsets = UIApplication.sharedApplication.keyWindow.safeAreaInsets;
    CGFloat safeAreaWidth = self.view.frame.size.width;
    CGFloat fontSize = safeAreaWidth * 0.1; // Set the font size as a fraction of the screen width
    
    if (fontSize > 30) {
        fontSize = 30;
    }
    
    label.font = [UIFont systemFontOfSize:fontSize weight:UIFontWeightSemibold];
    [label sizeToFit]; // Resize the label to fit its text
    
    UIButton *button = _doneButton;
    [button setBackgroundColor:[UIColor colorWithRed:8/255.0 green:190/255.0 blue:190/255.0 alpha:1.0]];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:button];
    
    [button.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [button.heightAnchor constraintEqualToConstant:60.0].active = YES;
    
    [button.layer setCornerRadius:16];
    
    CGFloat width = (self.view.frame.size.width);
    
    _hstack1.spacing = 20;
    _hstack2.spacing = 20;
    _hstack3.spacing = 20;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        _mostOuterVStack.spacing = 60;
        width = 450;
        [button.widthAnchor constraintEqualToConstant:350].active = YES;
    }
    else {
        _mostOuterVStack.spacing = 30;
        [button.widthAnchor constraintEqualToConstant:width-26].active = YES;
    }
    
    CGSize labelSize1 = CGSizeMake(width - 110, CGFLOAT_MAX);
    NSDictionary *attributes1 = @{NSFontAttributeName: _detailLabel1.font};
    CGRect expectedLabelRect1 = [_detailLabel1.text boundingRectWithSize:labelSize1 options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes1 context:nil];
    NSInteger numberOfLines1 = ceil(expectedLabelRect1.size.height / _detailLabel1.font.lineHeight);
    
    CGSize labelSize2 = CGSizeMake(width - 110, CGFLOAT_MAX);
    NSDictionary *attributes2 = @{NSFontAttributeName: _detailLabel2.font};
    CGRect expectedLabelRect2 = [_detailLabel2.text boundingRectWithSize:labelSize2 options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes2 context:nil];
    NSInteger numberOfLines2 = ceil(expectedLabelRect2.size.height / _detailLabel2.font.lineHeight);
    
    CGSize labelSize3 = CGSizeMake(width - 110, CGFLOAT_MAX);
    NSDictionary *attributes3 = @{NSFontAttributeName: _detailLabel3.font};
    CGRect expectedLabelRect3 = [_detailLabel3.text boundingRectWithSize:labelSize3 options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes3 context:nil];
    NSInteger numberOfLines3 = ceil(expectedLabelRect3.size.height / _detailLabel3.font.lineHeight);
    
    
    _detailLabel1.numberOfLines = numberOfLines1;
    _detailLabel2.numberOfLines = numberOfLines2;
    _detailLabel3.numberOfLines = numberOfLines3;
    
    //[_label1 setText:[NSString stringWithFormat:@"%ld", (long)numberOfLines1]];
    //[_label2 setText:[NSString stringWithFormat:@"%ld", (long)numberOfLines2]];
    //[_label3 setText:[NSString stringWithFormat:@"%ld", (long)numberOfLines3]];
    
    NSLayoutConstraint *c0 = [_hstack1.widthAnchor constraintEqualToConstant:width - 50];
    NSLayoutConstraint *c1 = [_hstack1.heightAnchor constraintEqualToConstant:numberOfLines1 * _detailLabel1.font.lineHeight + 20];
    NSLayoutConstraint *c2 = [_image1.widthAnchor constraintEqualToConstant:40];
    NSLayoutConstraint *c3 = [_image1.heightAnchor constraintEqualToConstant:40];
    NSLayoutConstraint *c4 = [_detailLabel1.widthAnchor constraintEqualToConstant:width - 50];
    
    NSLayoutConstraint *c5 = [_hstack2.widthAnchor constraintEqualToConstant:width - 50];
    NSLayoutConstraint *c6 = [_hstack2.heightAnchor constraintEqualToConstant:numberOfLines2 * _detailLabel2.font.lineHeight+ 20];
    NSLayoutConstraint *c7 = [_image2.widthAnchor constraintEqualToConstant:40];
    NSLayoutConstraint *c8 = [_image2.heightAnchor constraintEqualToConstant:40];
    NSLayoutConstraint *c9 = [_detailLabel2.widthAnchor constraintEqualToConstant:width - 50];
    
    NSLayoutConstraint *c10 = [_hstack3.widthAnchor constraintEqualToConstant:width - 50];
    NSLayoutConstraint *c11 = [_hstack3.heightAnchor constraintEqualToConstant:numberOfLines3 * _detailLabel3.font.lineHeight+ 20];
    NSLayoutConstraint *c12 = [_image3.widthAnchor constraintEqualToConstant:40];
    NSLayoutConstraint *c13 = [_image3.heightAnchor constraintEqualToConstant:40];
    NSLayoutConstraint *c14 = [_detailLabel3.widthAnchor constraintEqualToConstant:width - 50];
    
    NSLayoutConstraint *c15 = [_greetLabel.widthAnchor constraintEqualToConstant:width - 60];
    [NSLayoutConstraint activateConstraints:@[c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15]];
    
    [_image1.layer setMinificationFilter:kCAFilterTrilinear];
    [_image2.layer setMinificationFilter:kCAFilterTrilinear];
    [_image3.layer setMinificationFilter:kCAFilterTrilinear];
    
}

- (IBAction)viewProjectButtonClicked:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://github.com/ra9stuff/LiNUZE"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (IBAction)doneButtonAct:(id)sender {
    PlistModifier *landed = (PlistModifier*)malloc(sizeof(PlistModifier));
    landed -> modifyPref(@"Landed", @"1");
    free(landed);
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc {
    [_greetLabel release];
    [super dealloc];
}
@end
