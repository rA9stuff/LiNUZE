//
//  ViewController.m
//  LiNUZE
//
//  Created by rA9stuff on 15.08.2022.
//  Copyright © 2022 rA9stuff. All rights reserved.
//

#import "LiNUZE_VC.h"
#import "LDD.h"
#import "NSTask.h"
#import <sys/utsname.h>
#import <IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>
#import "USBUtils.h"
#import "PlistModifier.h"
#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/lockdown.h>
#include <libimobiledevice-glue/utils.h>
#include <common.h>
#import <objc/runtime.h>

#define background_thread dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
#define main_thread dispatch_async(dispatch_get_main_queue(), ^()
// thanks for the tip matty :)

bool restoreStarted = false;
LDD* maindevptr = NULL;
idevice_t* normaldevptr = NULL;
lockdownd_client_t* lockdownptr = NULL;
NSMutableAttributedString* fulllogtext = [[NSMutableAttributedString alloc] init];
UITextView* iphone_logview_addr;
NSString* normaldevname = NULL;



@interface ViewController ()

@end

@implementation ViewController

int checkDaemon() {
    
    NSPipe* output = [NSPipe pipe];
    NSTask* greptask = [[NSTask alloc] init];
    [greptask setArguments: @[@"-A"]];
    [greptask setLaunchPath:@"/bin/ps"];
    [greptask setStandardOutput:output];
    [greptask launch];
    [greptask waitUntilExit];
    
    NSFileHandle *read = [output fileHandleForReading];
    NSData *dataRead = [read readDataToEndOfFile];
    NSString *stringRead = [[[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding] autorelease];
    
    if (![stringRead containsString:@"(usbmuxd)"])
        return -1;
    
    return 0;
}


int sanityCheck() {
    
    const char* filePaths[] = {
        "/var/mobile/Media/LiNUZE",
        "/var/mobile/Media/LiNUZE/LiNUZE_stdoutwrapper.txt",
        "/usr/lib/libimobiledevice-1.0.6.dylib",
        "/usr/lib/libcrypto.1.1.dylib",
        "/usr/lib/libirecovery.3.dylib",
        "/usr/lib/libplist.3.dylib",
        "/usr/lib/libusb-1.0.0.dylib",
        "/usr/lib/libusbmuxd.6.dylib",
    };
    size_t arrSize = sizeof(filePaths)/sizeof(filePaths[0]);

    for (int i = 0; i < arrSize; i++) {
        if (access(filePaths[i], F_OK) == 0) {
            printf("[%s]: %s exists\n", __func__, filePaths[i]);
            continue;
        }
        printf("[%s]: %s does not exist!\n", __func__, filePaths[i]);
        return -1;
    }
    printf("[%s]: all checks have passed\n", __func__);
    return 0;
}


NSFileHandle *fh;

- (void)updateStatus:(NSString*)text color:(UIColor*)color1 {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *logtext = NULL;

        logtext = @"[*] ";

        logtext = [logtext stringByAppendingString:text];
        logtext = [logtext stringByAppendingString:@"\n"];
        UIColor *color = color1;
        UIFont* font = [UIFont fontWithName:@"SFMono-Regular" size:13];
         
        NSDictionary *attrs = @{ NSForegroundColorAttributeName : color, NSFontAttributeName : font};
        NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:logtext attributes:attrs];
        [fulllogtext appendAttributedString:attrStr];
        //[[self -> _ipad_logview textStorage] setAttributedString: @"a"];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        //NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"LiNUZE_stdoutwrapper.txt"];
        NSString *logFilePath = @"/var/mobile/Media/LiNUZE/LiNUZE_Log.txt";
        NSError *error;
        if (![fulllogtext.string writeToFile:logFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
            [self updateStatus: [NSString stringWithFormat:@"Failed to write to file: %@", error.localizedDescription] color:[UIColor whiteColor]];
        }
        
        [[iphone_logview_addr textStorage] setAttributedString:fulllogtext];
        [[_ipad_logview textStorage] setAttributedString:fulllogtext];
        [iphone_logview_addr scrollRangeToVisible:NSMakeRange([[iphone_logview_addr text] length], 0)];
        [_ipad_logview scrollRangeToVisible:NSMakeRange([[_ipad_logview text] length], 0)];
    });
}

- (void)infoLog:(NSString*)text color:(UIColor*)color1 {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *logtext = @"";
        logtext = [logtext stringByAppendingString:text];
        UIColor *color = color1;
        UIFont* font = [UIFont fontWithName:@"SFMono-Regular" size:13];
        NSDictionary *attrs = @{ NSForegroundColorAttributeName : color, NSFontAttributeName : font};
        NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:logtext attributes:attrs];
        [fulllogtext appendAttributedString:attrStr];
        [[self -> _ipad_logview textStorage] setAttributedString:fulllogtext];
        [[self -> _devInfoBox textStorage] setAttributedString:fulllogtext];
        [self -> _devInfoBox scrollRangeToVisible:NSMakeRange([[self->_devInfoBox text] length], 0)];
        [self -> _ipad_logview scrollRangeToVisible:NSMakeRange([[self->_ipad_logview text] length], 0)];
    });
}


bool pwned = false;
bool alreadyAnimating = false;

NSString* getEnvDetails(void) {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString* sysname = [[UIDevice currentDevice] systemName];
    NSString* sysversion = [[UIDevice currentDevice] systemVersion];
    NSString* combined = [NSString stringWithFormat:@"%s on %@ %@", systemInfo.machine, sysname, sysversion];

    return combined;
}

NSString* NSCPID(const unsigned int *buf) {
    NSMutableString *ms=[[NSMutableString alloc] init];
    [ms appendFormat:@"%04x", buf[0]];
    return ms;
}

NSString* NSNonce(unsigned char *buf, size_t len) {
    NSMutableString *nonce=[[NSMutableString alloc] init];
    for (int i = 0; i < len; i++) {
        [nonce appendFormat:@"%02x", buf[i]];
    }
    return nonce;
}

- (void) animateButtonTap: (UIView*)buttonName {
    
    background_thread {
        for (double i = 1.0; i > 0.3; i-=0.1) {
            main_thread {
                buttonName.alpha = i;
            });
            usleep(10000);
        }
        for (double i = 0.3; i < 1.0; i+=0.1) {
            main_thread {
                buttonName.alpha = i;
            });
            usleep(10000);
        }
        main_thread {
            [buttonName setUserInteractionEnabled:YES];
        });
    });
}

- (void) gentlyDeactivateButtons {
    _buttonContainer.userInteractionEnabled = NO;
    _bc2.userInteractionEnabled = NO;
    _bc3.userInteractionEnabled = NO;
    _bc4.userInteractionEnabled = NO;
    _iPadBC1.userInteractionEnabled = NO;
    _iPadBC2.userInteractionEnabled = NO;
    _iPadBC3.userInteractionEnabled = NO;
    _iPadBC4.userInteractionEnabled = NO;
    background_thread {
        for (double i = 1.0; i > 0.30; i-=0.01) {
            main_thread {
                _buttonContainer.alpha = i;
                _bc2.alpha = i;
                _bc3.alpha = i;
                _bc4.alpha = i;
                _iPadBC1.alpha = i;
                _iPadBC2.alpha = i;
                _iPadBC3.alpha = i;
                _iPadBC4.alpha = i;
            });
            usleep(2000);
        }
    });
}

- (void) gentlyActivateButtons {
    background_thread {
        for (double i = 0.30; i < 1.0; i+=0.01) {
            main_thread {
                _buttonContainer.alpha = i;
                _bc2.alpha = i;
                _bc3.alpha = i;
                _bc4.alpha = i;
                _iPadBC1.alpha = i;
                _iPadBC2.alpha = i;
                _iPadBC3.alpha = i;
                _iPadBC4.alpha = i;
            });
            usleep(2000);
        }
    });
    _buttonContainer.userInteractionEnabled = YES;
    _bc2.userInteractionEnabled = YES;
    _bc3.userInteractionEnabled = YES;
    _bc4.userInteractionEnabled = YES;
    _iPadBC1.userInteractionEnabled = YES;
    _iPadBC2.userInteractionEnabled = YES;
    _iPadBC3.userInteractionEnabled = YES;
    _iPadBC4.userInteractionEnabled = YES;
}


- (int) PrintDevInfo:(LDD*)devptr {

    NSString *stag = [NSString stringWithFormat:@"%s", devptr -> getDevInfo() -> serial_string];
    if ([stag containsString:@"PWND:"]) {
        pwned = true;
    }
    [self infoLog: @"\nModel Name: " color:[UIColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%s\n", devptr -> getDisplayName()] color:[UIColor whiteColor]];
    [self infoLog: @"Hardware Model: " color:[UIColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%s\n", devptr -> getHardwareModel()] color:[UIColor whiteColor]];
    [self infoLog: @"ECID: " color:[UIColor cyanColor]];
    unsigned long long ecid = devptr -> getDevInfo() -> ecid;
    NSString* ecidstr = [NSString stringWithFormat:@"%llu\n", ecid];
    [self infoLog: ecidstr color:[UIColor whiteColor]];
    [self infoLog: @"Serial Tag: " color:[UIColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%s\n", devptr -> getDevInfo() -> srtg] color:[UIColor whiteColor]];
    [self infoLog: @"APNonce:" color:[UIColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%@\n", NSNonce(devptr -> getDevInfo() -> ap_nonce, devptr -> getDevInfo() -> ap_nonce_size)] color:[UIColor whiteColor]];
    [self infoLog: @"SEPNonce:" color:[UIColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%@\n", NSNonce(devptr -> getDevInfo() -> sep_nonce, devptr -> getDevInfo() -> sep_nonce_size)] color:[UIColor whiteColor]];
    [self infoLog:@"CPID: " color:[UIColor cyanColor]];
    [self infoLog: [NSString stringWithFormat:@"%@\n", NSCPID(&devptr -> getDevInfo() -> cpid)] color:[UIColor whiteColor]];
    [self infoLog:@"Pwned: " color:[UIColor cyanColor]];
    if (devptr -> checkPwn()) {
        [self infoLog: @"Yes\n\n" color:[UIColor whiteColor]];
    }
    else {
        [self infoLog: @"No\n\n" color:[UIColor whiteColor]];
    }
    return 0;
}


UIView* iPadView;
UIView* iPhoneView;
UIViewController* iPadVCGlobal;
UIViewController* iPhoneVCGlobal;
UIStoryboard *storyboard;


- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
/*
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (UIInterfaceOrientationIsPortrait(orientation)) {
        // Switch to iPhoneUI
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        UIViewController *iPhoneUI = [storyboard instantiateViewControllerWithIdentifier:@"iPhoneUI"];
        UINavigationController *navController = self.navigationController;
        [navController popToRootViewControllerAnimated:NO];
        [navController pushViewController:iPhoneUI animated:YES];
        [[self navigationItem] setHidesBackButton:YES];
    }
    else {
        // Switch to iPadUI
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        UIViewController *iPadUI = [storyboard instantiateViewControllerWithIdentifier:@"iPadUI"];
        UINavigationController *navController = self.navigationController;
        [navController popToRootViewControllerAnimated:NO];
        [navController pushViewController:iPadUI animated:YES];
        [[self navigationItem] setHidesBackButton:YES];
    }*/
}

- (void)displayCorrectBasicInterface:(id)sender devptr:(nullable LDD*)devptr normaldevname:(NSString* _Nullable)normalDeviceName VC:(UIViewController*)VC {
    
    UIImageView *iphoneImage = [self.statusContainer viewWithTag:1];
    UIImageView *statusImage = [self.statusContainer viewWithTag:2];
    UILabel* statusLabel = [self.statusContainer viewWithTag:3];
    
    iphoneImage.hidden = NO;
    statusImage.alpha = 1.0;
    //[self updateStatus:[NSString stringWithFormat:@"displayCorrectBasicInterface got called from %@", sender] color:[UIColor whiteColor]];
    if ((devptr == NULL || devptr->getClient() == NULL) && normalDeviceName == NULL) {
        iphoneImage.alpha = 0;
        statusImage.image = [UIImage imageNamed:@"iphone.slash"];
        statusLabel.text = @"No device connected";
        return;
    }
    
    UIFont* boldFont = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    NSDictionary *boldAttrs = @{ NSForegroundColorAttributeName : [UIColor whiteColor], NSFontAttributeName : boldFont };
    NSAttributedString *boldStr = [[NSAttributedString alloc] initWithString:@"Connected\n\n" attributes:boldAttrs];
    UIFont* regularFont = [UIFont systemFontOfSize:13];
    NSDictionary *regularAttrs = @{ NSForegroundColorAttributeName : [UIColor whiteColor], NSFontAttributeName : regularFont };
    
    if (normalDeviceName != NULL) {
        // we are displaying a normal mode device
        _basicUIprogressView.hidden = YES;
        iphoneImage.alpha = 1.0;
        iphoneImage.image = [UIImage imageNamed:@"iphone_x_generic"];
        statusImage.image = [UIImage imageNamed:@"checkmark.seal.fill"];
        NSAttributedString *regularStr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat: @"%@\nNormal Mode", normalDeviceName] attributes:regularAttrs];
        NSMutableAttributedString *combinedStr = [[NSMutableAttributedString alloc] init];
        [combinedStr appendAttributedString:boldStr];
        [combinedStr appendAttributedString:regularStr];
        
        statusLabel.attributedText = combinedStr;
        return;
    }
    else if (strstr(devptr -> getDisplayName(), "iPhone") != NULL) {
        NSString* devname = [NSString stringWithUTF8String: devptr -> getDisplayName()];
        _basicUIprogressView.hidden = YES;
        iphoneImage.alpha = 1.0;
        iphoneImage.image = [UIImage imageNamed:@"iphone_x_generic"];
        statusImage.image = [UIImage imageNamed:@"checkmark.seal.fill"];
        
        
        NSAttributedString *regularStr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat: @"%@\n%s Mode", devname, devptr->getDeviceMode()] attributes:regularAttrs];
        if (devptr->checkPwn()) {
            regularStr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat: @"%@\n%s Mode (pwned)", devname, devptr->getDeviceMode()] attributes:regularAttrs];
        }
        
        NSMutableAttributedString *combinedStr = [[NSMutableAttributedString alloc] init];
        [combinedStr appendAttributedString:boldStr];
        [combinedStr appendAttributedString:regularStr];
        
        statusLabel.attributedText = combinedStr;
        return;
    }
    else {
        NSString* devname = [NSString stringWithUTF8String: devptr -> getDisplayName()];
        iphoneImage.alpha = 1.0;
        iphoneImage.image = [UIImage imageNamed:@"ipad_generic"];
        statusImage.image = [UIImage imageNamed:@"checkmark.seal.fill"];
        statusLabel.text = [NSString stringWithFormat:@"%@", devname];
    }
}



- (void)loadCorrectUI {
    
    static BOOL didAlreadyLoadCorrectUI = NO;
    if (didAlreadyLoadCorrectUI)
        return;
    didAlreadyLoadCorrectUI = YES;
    NSString *deviceModel = [[UIDevice currentDevice] model];
    if ([deviceModel containsString:@"iPhone"]) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        UIViewController *iPhoneUI = [storyboard instantiateViewControllerWithIdentifier:@"iPhoneUI"];
        UINavigationController *navController = self.navigationController;
        [navController popToRootViewControllerAnimated:NO];
        [navController pushViewController:iPhoneUI animated:NO];
    }
}

- (IBAction)devConsoleToggleAct:(id)sender {
    
    UISwitch *devConsoleToggle = (UISwitch *)sender;
    PlistModifier* updatePref = (PlistModifier*)malloc(sizeof(PlistModifier));
    
    if ([devConsoleToggle isOn]) {
        
        //[self updateStatus: @"Switched to console view" color: [UIColor whiteColor]];
        @try {
            updatePref -> modifyPref(@"DevConsoleEnabled", @"1");
        }
        @catch (NSException* exception) {
            [self updateStatus:[NSString stringWithFormat:@"%@", exception] color: [UIColor redColor]];
        }
        self.devConsoleLabel.alpha = 1.0;
        self.logScrollView.alpha = 1.0;
        self.statusContainer.alpha = 0;
        
    }
    else {
        //[self updateStatus: @"Switched to basic view" color: [UIColor whiteColor]];
        
        @try {
            updatePref -> modifyPref(@"DevConsoleEnabled", @"0");
        } @catch (NSException *exception) {
            [self updateStatus:[NSString stringWithFormat:@"%@", exception] color: [UIColor redColor]];
        }
        
        self.logScrollView.alpha = 0;
        self.statusContainer.alpha = 1.0;
        self.devConsoleLabel.alpha = 0;
        self.statusImage.alpha = 1.0;
        try {
            [self displayCorrectBasicInterface:[NSString stringWithUTF8String: __func__] devptr:maindevptr normaldevname:normaldevname VC:self];
        } catch (NSException *a) {
            [self updateStatus:[NSString stringWithFormat:@"%@",a] color:[UIColor redColor]];
        }
       
    }
}


- (BOOL)monitorFileChanges {

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    //NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"LiNUZE_stdoutwrapper.txt"];
    NSString *filePath = @"/var/mobile/Media/LiNUZE/LiNUZE_stdoutwrapper.txt";
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    [fileHandle seekToEndOfFile];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleFileChangedNotification:)
                                                 name:NSFileHandleDataAvailableNotification
                                               object:fileHandle];
    [fileHandle waitForDataInBackgroundAndNotify];
    return true;
}

- (void)handleFileChangedNotification:(NSNotification *)notification {
    NSFileHandle *fileHandle = [notification object];
    NSData *data = [fileHandle availableData];
    NSString *newContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    [self infoLog:newContent color:[UIColor whiteColor]];
    [fileHandle waitForDataInBackgroundAndNotify];
}




bool aa = true;
bool firstRun = true;
bool didAlreadyStartMonitoring = false;
bool sanityCheckPassed = false;

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (!([self.restorationIdentifier isEqualToString:@"iPhoneUI"]) && !([self.restorationIdentifier isEqualToString:@"iPadUI"])) {
        if (self -> _ipad_logview != NULL) {
            [[self -> _ipad_logview textStorage] setAttributedString:fulllogtext];
            [self -> _ipad_logview scrollRangeToVisible:NSMakeRange([[self->_ipad_logview text] length], 0)];
        }
        else if (self -> _devInfoBox != NULL) {
            [[iphone_logview_addr textStorage] setAttributedString:fulllogtext];
            [iphone_logview_addr scrollRangeToVisible:NSMakeRange([[iphone_logview_addr text] length], 0)];
        }
        return;
    }
    
    [self updateStatus:@"view did reload" color: [UIColor whiteColor]];
    
    UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
    CGSize screenSize = UIScreen.mainScreen.bounds.size;
    CGSize windowSize = keyWindow.bounds.size;
    if (windowSize.width < screenSize.width || windowSize.height < screenSize.height) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        UIViewController *iPhoneUI = [storyboard instantiateViewControllerWithIdentifier:@"iPhoneUI"];
        UINavigationController *navController = self.navigationController;
        ViewController* top = (ViewController*)navController.topViewController;
        // Check if the current view controller is already the top view controller
        if (top.iPadBC1 != NULL) {
            [navController popToRootViewControllerAnimated:NO];
            [navController pushViewController:iPhoneUI animated:YES];
        }
        return;
    }
    
    [self displayCorrectBasicInterface:[NSString stringWithUTF8String: __func__] devptr:maindevptr normaldevname:NULL VC:self];
    [self gentlyDeactivateButtons];
    
    if (!sanityCheckPassed) {
        if ([self.restorationIdentifier isEqualToString:@"iPhoneUI"] || [self.restorationIdentifier isEqualToString:@"iPadUI"]) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sanity checks failed"
                                                                           message:@"One or more dependencies are missing from your system. Check /var/mobile/Media/LiNUZE/LiNUZE_Log.txt for more details."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* okButton = [UIAlertAction actionWithTitle:@"OK"
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * action) { exit(1); }];
            [alert addAction:okButton];
            [self presentViewController:alert animated:YES completion:nil];
        }
        return;
    }
    
    if (didAlreadyStartMonitoring)
        return;
    didAlreadyStartMonitoring = true;
    
    background_thread {
        USBUtils* usbVC = [[USBUtils alloc] init];
        [usbVC startMonitoringUSBDevices:self maindevptr:&maindevptr normaldevptr:&normaldevptr lockdownptr:&lockdownptr normaldevname:&normaldevname];
    });
    
    PlistModifier *landingcheck = (PlistModifier*)malloc(sizeof(PlistModifier));
    NSString* res = landingcheck -> getPref(@"Landed");
    free(landingcheck);
    
    if ([res isEqualToString:@"1"]) {
        if (checkDaemon() != 0) {
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
                printf("[*] usbmuxd started, dismissing the alert now\n");
                main_thread {
                    [alertController dismissViewControllerAnimated:YES completion:nil];
                });
            });
        }
        return;
    }
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UIViewController *onboardingVC = [storyboard instantiateViewControllerWithIdentifier:@"LandingVC"];
    onboardingVC.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:onboardingVC animated:YES completion:nil];
    
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:YES];
    if (!([self.restorationIdentifier isEqualToString:@"iPhoneUI"]) && !([self.restorationIdentifier isEqualToString:@"iPadUI"])) {
        if (self -> _devInfoBox != NULL) {
            
            UIStackView *stackView = self.iphone_logview_hstack;
            [stackView.heightAnchor constraintEqualToConstant:40].active = YES;
            
            iphone_logview_addr = self -> _devInfoBox;
            double sysversion = [[[UIDevice currentDevice] systemVersion] doubleValue];
            if (sysversion >= 13.0) {
                _iphone_logview_dismissButton.hidden = YES;
                return;
            }
            
            if (stackView.subviews.count == 2) {
                UIView *spacerView = [[UIView alloc] initWithFrame:CGRectZero];
                spacerView.translatesAutoresizingMaskIntoConstraints = NO;
                NSLayoutConstraint *spacerWidthConstraint = [spacerView.widthAnchor constraintEqualToConstant:self.view.frame.size.width - 250];
                spacerWidthConstraint.active = YES;
                [stackView insertArrangedSubview:spacerView atIndex:1];
            }
            
            // Set up the constraints for the label
            _logwindow_label.translatesAutoresizingMaskIntoConstraints = NO;
            
            _iphone_logview_dismissButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
            // Set up the constraints for the button
            _iphone_logview_dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
            [_iphone_logview_dismissButton.widthAnchor constraintEqualToConstant:30].active = YES;
            [_iphone_logview_dismissButton.heightAnchor constraintEqualToConstant:30].active = YES;

            
        }
        return;
    }
    
    NSArray *layers = @[(self.buttonContainer.layer ?: [NSNull null]),
                        (self.bc2.layer ?: [NSNull null]),
                        (self.bc3.layer ?: [NSNull null]),
                        (self.bc4.layer ?: [NSNull null]),
                        (self.iPadBC1.layer ?: [NSNull null]),
                        (self.iPadBC2.layer ?: [NSNull null]),
                        (self.iPadBC3.layer ?: [NSNull null]),
                        (self.iPadBC4.layer ?: [NSNull null])];

    for (CALayer *layer in layers) {
        if ([layer isEqual:[NSNull null]])
            continue;
        for (CALayer *subLayer in layer.sublayers) {
            subLayer.cornerRadius = 20;
            subLayer.masksToBounds = YES;
        }
    }
    [self loadCorrectUI];
    
    UIStackView *stackView = self.leftVStack; // replace with your actual UIStackView instance
    UIView *spacerView = [[UIView alloc] initWithFrame:CGRectZero];
    spacerView.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *spacerHeightConstraint = [spacerView.heightAnchor constraintEqualToConstant:20.0];
    spacerHeightConstraint.active = YES;
    [stackView insertArrangedSubview:spacerView atIndex:3];
    
    // Things UIKit makes me do...
    UILabel *alignmentLabel = _alignment;
    NSLayoutConstraint *widthConstraint = [alignmentLabel.widthAnchor constraintEqualToConstant:0.0];
    NSLayoutConstraint *centerXConstraint = [alignmentLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor];
    NSLayoutConstraint *centerYConstraint = [alignmentLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor];
    widthConstraint.active = YES;
    centerXConstraint.active = YES;
    centerYConstraint.active = YES;
    
    
    self.ipad_logview.layer.borderWidth = 1.0f;
    self.ipad_logview.layer.borderColor = [[UIColor colorWithRed:8/255.0 green:164/255.0 blue:167/255.0 alpha:1.0] CGColor];
    self.navigationItem.hidesBackButton = YES;
    
    PlistModifier *pm = (PlistModifier*)malloc(sizeof(PlistModifier));
    NSString* state = pm -> getPref(@"DevConsoleEnabled");
    UISwitch *sw = [[UISwitch alloc] init];
    
    if ([state isEqualToString:@"1"]) {
        [sw setOn:YES];
        [[self devConsoleToggle] setOn:YES];
    }
    else {
        [sw setOn:NO];
        [[self devConsoleToggle] setOn:NO];
    }
    [self devConsoleToggleAct:sw];

    CGSize scrollableSize = CGSizeMake(0, 10);
    [_ipad_logscrollview setContentSize:scrollableSize];
    _enter_rec_activity.hidden = true;
    
    _ipad_statusstr.text = [NSString stringWithFormat: @"Env: %@", getEnvDetails()];
    
    if (!sanityCheckPassed)
        return;
    
    if (!firstRun) {
        return;
    }
    firstRun = false;
    
    printf("Running on %s\n", getEnvDetails().UTF8String);
    
    [self updateStatus:@"Ready, waiting for a device" color:[UIColor greenColor]];
    [self gentlyDeactivateButtons];
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INITIATED, -1);
    dispatch_queue_t lthread = dispatch_queue_create("com.rA9stuff.LiNUZE-thread", attr);
    dispatch_async(lthread, ^{
        normaldevptr = new idevice_t;
        lockdownptr = new lockdownd_client_t;
        maindevptr = new LDD;
        [self updateStatus: [NSString stringWithFormat:@"[LiNUZE_VC.mm] maindevptr: %p", &maindevptr] color: [UIColor whiteColor]];
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];
    static bool didSanityCheck = false;
    
    if (!didSanityCheck && [self monitorFileChanges] && sanityCheck() == 0)
        sanityCheckPassed = true;
    
    didSanityCheck = true;
}

- (void)exitRecovery:(id)sender {
    [self updateStatus:[NSString stringWithFormat:@"exitRecovery got called from %@", sender] color:[UIColor whiteColor]];
    [[self bc2] setUserInteractionEnabled:NO];
    [[self iPadBC2] setUserInteractionEnabled:NO];

    [self animateButtonTap:self->_bc2];
    [self animateButtonTap:self->_iPadBC2];
    
    background_thread {
        if (maindevptr == NULL) {
            main_thread {
                [self infoLog:@"maindevptr is null!" color:[UIColor redColor]];
            });
            return;
        }
        main_thread {
            [self updateStatus:[NSString stringWithFormat:@"LDD object at %p", maindevptr] color:[UIColor whiteColor]];
        });
        int res = 0;
        maindevptr -> sendCommand("setenv auto-boot true", NO);
        main_thread {
            [self updateStatus:[NSString stringWithFormat: @"sendCommand() returned with %d", res]  color:[UIColor whiteColor]];
        });
        res = maindevptr -> sendCommand("saveenv", NO);
        main_thread {
            [self updateStatus:[NSString stringWithFormat: @"sendCommand() returned with %d", res]  color:[UIColor whiteColor]];
        });
        res = maindevptr -> sendCommand("reset", NO);
        main_thread {
            [self updateStatus:[NSString stringWithFormat: @"sendCommand() returned with %d", maindevptr -> sendCommand("reset", NO)]  color:[UIColor whiteColor]];
        });
    });
}

- (void)enterRecovery:(id)sender {
    [self updateStatus:[NSString stringWithFormat:@"enterRecovery got called from %@", sender] color:[UIColor whiteColor]];
    [[self buttonContainer] setUserInteractionEnabled:NO];
    [[self iPadBC1] setUserInteractionEnabled:NO];

    [self animateButtonTap:self->_buttonContainer];
    [self animateButtonTap:self->_iPadBC1];
    background_thread {
        lockdownd_enter_recovery(*lockdownptr);
        lockdownd_goodbye(*lockdownptr);
        idevice_free(*normaldevptr);
    });
}


#pragma mark BUTTON ACTIONS

- (IBAction)dismissLogViewAct:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}



- (IBAction)exitRecoveryAct:(id)sender {
    [self animateButtonTap:_bc2];
    [self exitRecovery:sender];
}

- (IBAction)enter_rec_ipad_act:(id)sender {
    [self animateButtonTap:_buttonContainer];
    [self enterRecovery:sender];
}

- (IBAction)exit_rec_ipad_act:(id)sender {
    [self animateButtonTap:_iPadBC2];
    [self exitRecovery:sender];
}

- (void) showUnsupported {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Not supported"
                                                                   message:@"This feature is not yet available."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* okButton = [UIAlertAction actionWithTitle:@"OK"
                                                         style:UIAlertActionStyleDefault
                                                       handler:nil];
    [alert addAction:okButton];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)set_apnonce_ipad_act:(id)sender {
    [self animateButtonTap:_iPadBC3];
    [self showUnsupported];
}

- (IBAction)leetdown_ipad_act:(id)sender {
    [self animateButtonTap:_iPadBC4];
    [self showUnsupported];
}
- (IBAction)enterRecoveryActiPhone:(id)sender {
    [self animateButtonTap:_buttonContainer];
    [self enterRecovery:sender];
}



- (IBAction)setNonceAct:(id)sender {
    [self animateButtonTap:_bc3];
    [self showUnsupported];
}

- (IBAction)leetdownAct:(id)sender {
    [self animateButtonTap:_bc4];
    [self showUnsupported];
}

- (IBAction)devInfoAct:(id)sender {
    
}




- (void)dealloc {
    [_iPadBC1 release];
    [super dealloc];
}
@end

