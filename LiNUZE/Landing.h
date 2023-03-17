//
//  Landing.h
//  LiNUZ
//
//  Created by rA9stuff on 6.03.2023.
//  Copyright © 2023 rA9stuff. All rights reserved.
//

#ifndef Landing_h
#define Landing_h

#import <UIKit/UIKit.h>
#import "LDD.h"

@interface Landing : UIViewController

@property (retain, nonatomic) IBOutlet UILabel *greetLabel;
@property (retain, nonatomic) IBOutlet UIStackView *mostOuterVStack;
@property (retain, nonatomic) IBOutlet UIStackView *hstack1;
@property (retain, nonatomic) IBOutlet UIStackView *hstack2;
@property (retain, nonatomic) IBOutlet UIStackView *hstack3;
@property (retain, nonatomic) IBOutlet UIStackView *vstack1;
@property (retain, nonatomic) IBOutlet UIStackView *vstack2;
@property (retain, nonatomic) IBOutlet UIStackView *vstack3;
@property (retain, nonatomic) IBOutlet UIButton *doneButton;
@property (retain, nonatomic) IBOutlet UILabel *detailLabel1;
@property (retain, nonatomic) IBOutlet UILabel *detailLabel2;
@property (retain, nonatomic) IBOutlet UILabel *detailLabel3;
@property (retain, nonatomic) IBOutlet UILabel *label1;
@property (retain, nonatomic) IBOutlet UILabel *label2;
@property (retain, nonatomic) IBOutlet UILabel *label3;
@property (retain, nonatomic) IBOutlet UIImageView *image1;
@property (retain, nonatomic) IBOutlet UIImageView *image2;
@property (retain, nonatomic) IBOutlet UIImageView *image3;
@property (retain, nonatomic) IBOutlet UIButton *viewProjectButton;

@end


#endif /* Landing_h */
