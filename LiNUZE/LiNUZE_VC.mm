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
#import "exploit_wrappers.h"
#import <mach/mach.h>


#define background_thread dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
#define main_thread dispatch_async(dispatch_get_main_queue(), ^()
// thanks for the tip matty :)

bool restoreStarted = false;
LDD* maindevptr = NULL;
idevice_t* normaldevptr = NULL;
lockdownd_client_t* lockdownptr = NULL;
NSMutableAttributedString* fulllogtext = [[NSMutableAttributedString alloc] init];
UITextView* iphone_logview_addr;
UITextView* ipad_logview_addr;
NSString* normaldevname = NULL;
ViewController* ipad_vc = NULL;
ViewController* iphone_vc = NULL;
extern NSPipe* lnpipe;


@interface ViewController ()

@end

@implementation ViewController

- (void)startMonitoringStdout {
    setbuf(stdout, NULL);
    NSPipe* pipe = [NSPipe pipe];
    NSFileHandle* pipeReadHandle = [pipe fileHandleForReading];
    dup2([[pipe fileHandleForWriting] fileDescriptor], fileno(stdout));
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, [pipeReadHandle fileDescriptor], 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    dispatch_source_set_event_handler(source, ^{
        void* data = malloc(4096);
        ssize_t readResult = 0;
        do {
            errno = 0;
            readResult = read([pipeReadHandle fileDescriptor], data, 4096);
        } while (readResult == -1 && errno == EINTR);
        
        if (readResult > 0) {
            dispatch_async(dispatch_get_main_queue(),^{
                NSString *stdOutString = [[NSString alloc] initWithBytesNoCopy:data length:readResult encoding:NSUTF8StringEncoding freeWhenDone:YES];
                
                // beautify ipwnder_lite output
                UIColor* outputcolor = [UIColor whiteColor];
                
                if ([stdOutString containsString:@"[31m"]) {
                    outputcolor = [UIColor redColor];
                }
                else if ([stdOutString containsString:@"[32m"]) {
                    outputcolor = [UIColor greenColor];
                }
                stdOutString = [[[stdOutString stringByReplacingOccurrencesOfString:@"[31m" withString:@""]
                                        stringByReplacingOccurrencesOfString:@"[32m" withString:@""]
                                        stringByReplacingOccurrencesOfString:@"[39m" withString:@""];

                [self infoLog:stdOutString color:outputcolor];
            });
        }
        else {
            free(data);
        }
    });
    dispatch_resume(source);
}

float cpu_usage()
{
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;

    task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }

    task_basic_info_t      basic_info;
    thread_array_t         thread_list;
    mach_msg_type_number_t thread_count;

    thread_info_data_t     thinfo;
    mach_msg_type_number_t thread_info_count;

    thread_basic_info_t basic_info_th;
    uint32_t stat_thread = 0; // Mach threads

    basic_info = (task_basic_info_t)tinfo;

    // get threads in the task
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    if (thread_count > 0)
        stat_thread += thread_count;

    long tot_sec = 0;
    long tot_usec = 0;
    float tot_cpu = 0;
    int j;

    for (j = 0; j < (int)thread_count; j++)
    {
        thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
                         (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }

        basic_info_th = (thread_basic_info_t)thinfo;

        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
            tot_usec = tot_usec + basic_info_th->user_time.microseconds + basic_info_th->system_time.microseconds;
            tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100.0;
        }

    } // for each thread

    kr = vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
    assert(kr == KERN_SUCCESS);

    return tot_cpu;
}

- (void)monitorCPUusage {
    background_thread {
        while (true) {
            float usage = cpu_usage();
            main_thread {
                [[ipad_vc cpu_usage_label] setText:[NSString stringWithFormat:@"cpu usage: %g%%", usage]];
            });
            sleep(1);
        }
    });
}


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
        NSString *logFilePath = @"/var/mobile/Media/LiNUZE/LiNUZE_Log.txt";
        NSError *error;
        if (![fulllogtext.string writeToFile:logFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
            [self updateStatus: [NSString stringWithFormat:@"Failed to write to file: %@", error.localizedDescription] color:[UIColor whiteColor]];
        }
        [[iphone_logview_addr textStorage] setAttributedString:fulllogtext];
        [[ipad_logview_addr textStorage] setAttributedString:fulllogtext];
        [iphone_logview_addr scrollRangeToVisible:NSMakeRange([[iphone_logview_addr text] length], 0)];
        [ipad_logview_addr scrollRangeToVisible:NSMakeRange([[ipad_logview_addr text] length], 0)];
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
        [[ipad_logview_addr textStorage] setAttributedString:fulllogtext];
        [[iphone_logview_addr textStorage] setAttributedString:fulllogtext];
        [iphone_logview_addr scrollRangeToVisible:NSMakeRange([[iphone_logview_addr text] length], 0)];
        [ipad_logview_addr scrollRangeToVisible:NSMakeRange([[ipad_logview_addr text] length], 0)];
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
    if ([nonce isEqualToString: @""])
        return @" N/A";
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
    _ipad_upper_container.userInteractionEnabled    = NO;
    _ipad_bottom_container.userInteractionEnabled   = NO;
    _iphone_upper_container.userInteractionEnabled  = NO;
    _iphone_bottom_container.userInteractionEnabled = NO;
    background_thread {
        for (double i = 1.0; i > 0.30; i-=0.01) {
            main_thread {
                _ipad_upper_container.alpha    = i;
                _ipad_bottom_container.alpha   = i;
                _iphone_upper_container.alpha  = i;
                _iphone_bottom_container.alpha = i;
            });
            usleep(2000);
        }
    });
}

- (void) gentlyActivateButtons {
    background_thread {
        for (double i = 0.30; i < 1.0; i+=0.01) {
            main_thread {
                _ipad_upper_container.alpha    = i;
                _ipad_bottom_container.alpha   = i;
                _iphone_upper_container.alpha  = i;
                _iphone_bottom_container.alpha = i;
            });
            usleep(2000);
        }
    });
    _ipad_upper_container.userInteractionEnabled    = YES;
    _ipad_bottom_container.userInteractionEnabled   = YES;
    _iphone_upper_container.userInteractionEnabled  = YES;
    _iphone_bottom_container.userInteractionEnabled = YES;
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
        
        [self infoLog: [NSString stringWithFormat:@"Yes (%s)\n\n", devptr -> getPWNDTag()] color:[UIColor whiteColor]];
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

- (void)displayCorrectBasicInterface:(id)sender devptr:(nullable LDD*)devptr normaldevname:(NSString* _Nullable)normalDeviceName VC:(UIViewController*)VC {
    
    UIImageView *iphoneImage = [ipad_vc.statusContainer viewWithTag:1];
    UIImageView *statusImage = [ipad_vc.statusContainer viewWithTag:2];
    UILabel* statusLabel = [ipad_vc.statusContainer viewWithTag:3];
    UIActivityIndicatorView* basicUIprogressView = ipad_vc.basicUIprogressView;
    
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
        basicUIprogressView.hidden = YES;
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
        basicUIprogressView.hidden = YES;
        iphoneImage.alpha = 1.0;
        iphoneImage.image = [UIImage imageNamed:@"iphone_x_generic"];
        statusImage.image = [UIImage imageNamed:@"checkmark.seal.fill"];
        
        
        NSAttributedString *regularStr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat: @"%@\n%s Mode", devname, devptr->getDeviceMode()] attributes:regularAttrs];
        if (devptr->checkPwn()) {
            regularStr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat: @"%@\n%s Mode\n\n\n\n\nPwned with %s", devname, devptr->getDeviceMode(), devptr->getPWNDTag()] attributes:regularAttrs];
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


bool firstRun = true;
bool didAlreadyStartMonitoring = false;
bool sanityCheckPassed = false;
USBUtils* usbVC;

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
    [self monitorCPUusage];
    background_thread {
        usbVC = [[USBUtils alloc] init];
        [usbVC startMonitoringUSBDevices:self maindevptr:&maindevptr normaldevptr:&normaldevptr lockdownptr:&lockdownptr normaldevname:&normaldevname];
    });
    
    PlistModifier *landingcheck = (PlistModifier*)malloc(sizeof(PlistModifier));
    NSString* res = landingcheck -> getPref(@"Landed");
    free(landingcheck);
    
    if ([res isEqualToString:@"1"]) {
        if (false) {
        //if (checkDaemon() != 0) {
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
    
    NSArray *layers = @[(self.cv1.layer ?: [NSNull null]),
                        (self.cv2.layer ?: [NSNull null]),
                        (self.cv3.layer ?: [NSNull null]),
                        (self.cv4.layer ?: [NSNull null]),
                        (self.cv5.layer ?: [NSNull null])];

    for (CALayer *layer in layers) {
        if ([layer isEqual:[NSNull null]])
            continue;
        for (CALayer *subLayer in layer.sublayers) {
            subLayer.cornerRadius = 20;
            subLayer.masksToBounds = YES;
        }
    }
    
    [_firstScrollView setShowsVerticalScrollIndicator:NO];
    [_secondScrollView setShowsVerticalScrollIndicator:NO];
    
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
    
    [self loadCorrectUI];
    
    UIStackView *stackView = self.leftVStack;
    UIView *spacerView = [[UIView alloc] initWithFrame:CGRectZero];
    spacerView.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *spacerHeightConstraint = [spacerView.heightAnchor constraintEqualToConstant:10.0];
    spacerHeightConstraint.active = YES;
    [stackView insertArrangedSubview:spacerView atIndex:2];
    
    UIView *spacerViewDup = [[UIView alloc] initWithFrame:CGRectZero];
    spacerViewDup.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *spacerHeightConstraintDup = [spacerViewDup.heightAnchor constraintEqualToConstant:30.0];
    spacerHeightConstraintDup.active = YES;

    
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
    
    if (!didSanityCheck) {
    // basically the first run and viewdidload will never reach here again

        [self startMonitoringStdout];
        
        if (sanityCheck() == 0)
            sanityCheckPassed = true;
    }
    didSanityCheck = true;
    
    if (([self.restorationIdentifier isEqualToString:@"iPhoneUI"]) || ([self.restorationIdentifier isEqualToString:@"iPadUI"])) {
        
        PlistModifier* nightlyCheck = (PlistModifier*)malloc(sizeof(PlistModifier));
        NSString* nightlyHashVal = nightlyCheck->getPref(@"nightlyHash");
        
        if (![nightlyHashVal isEqualToString:@""]) {
           [_versionLabel setText: [@"LiNUZE nightly " stringByAppendingString:nightlyHashVal]];
            _versionLabeliPad.text = [@"LiNUZE nightly " stringByAppendingString:nightlyHashVal];
            _versionLabel.text = [_versionLabel.text stringByAppendingString:@" © rA9 2023"];
            _versionLabeliPad.text = [_versionLabeliPad.text stringByAppendingString:@" © rA9 2023"];
        }
        [_iphoneImage.layer setMinificationFilter:kCAFilterTrilinear];
    }
    if ([self.restorationIdentifier isEqualToString:@"iPadUI"]) {
        ipad_logview_addr = self.ipad_logview;
        ipad_vc = self;
        iphone_vc = NULL;
    }
    else if ([self.restorationIdentifier isEqualToString:@"iPhoneUI"]) {
        iphone_vc = self;
    }
    
}

- (void)exitRecovery:(id)sender {
    [self updateStatus:[NSString stringWithFormat:@"exitRecovery got called from %@", sender] color:[UIColor whiteColor]];
    [[self exitRecoveryButtonOutlet] setUserInteractionEnabled:NO];

    [self animateButtonTap:self->_exitRecoveryButtonOutlet];
    
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
    [[self enterRecoveryButtonOutlet] setUserInteractionEnabled:NO];

    [self animateButtonTap:self->_enterRecoveryButtonOutlet];

    background_thread {
        lockdownd_enter_recovery(*lockdownptr);
        lockdownd_goodbye(*lockdownptr);
        idevice_free(*normaldevptr);
    });
}

- (void)exploitDFU {
    int cpid = NSCPID(&maindevptr -> getDevInfo() -> cpid).intValue;
    [self updateStatus:@"Pausing USB device monitoring for pwndfu functions" color:[UIColor whiteColor]];
    [usbVC stopMonitoringUSBDevices];
    maindevptr -> freeDevice();
    background_thread {
        sleep(1);
        // ipwnder_lite seems to be unreliable on A9, so use gaster instead
        if (cpid == 7000 || cpid == 7001 || cpid == 8000 || cpid == 8003)
            run_gaster();
        else
            run_ipwnder_lite();
        
        main_thread {
            [self updateStatus:@"Resuming USB device monitoring in 1s" color:[UIColor whiteColor]];
        });
        sleep(1);
        [usbVC startMonitoringUSBDevices:self maindevptr:&maindevptr normaldevptr:&normaldevptr lockdownptr:&lockdownptr normaldevname:&normaldevname];
    });
}

- (void)pushLogview {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UIViewController *onboardingVC = [storyboard instantiateViewControllerWithIdentifier:@"logview_iphone"];
    onboardingVC.modalPresentationStyle = UIModalPresentationFormSheet;
    [iphone_vc presentViewController:onboardingVC animated:YES completion:nil];
}

#pragma mark BUTTON ACTIONS

- (IBAction)dismissLogViewAct:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void) showUnsupported {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Not supported"
                                                                   message:@"This feature is not available yet."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* okButton = [UIAlertAction actionWithTitle:@"OK"
                                                         style:UIAlertActionStyleDefault
                                                       handler:nil];
    [alert addAction:okButton];
    [self presentViewController:alert animated:YES completion:nil];
}


- (IBAction)enterRecoveryButtonTapped:(id)sender {
    [ipad_vc animateButtonTap:_cv1];
    if (iphone_vc != NULL) {
        [self pushLogview];
    }
    [self enterRecovery:self];
}

- (IBAction)exitRecoveryButtonTapped:(id)sender {
    [ipad_vc animateButtonTap:_cv2];
    if (iphone_vc != NULL) {
        [self pushLogview];
    }
    [self exitRecovery:self];
}

- (IBAction)setAPNonceButtonTapped:(id)sender {
    [ipad_vc animateButtonTap:_cv3];
    [self showUnsupported];
}
- (IBAction)LeetDownButtonTapped:(id)sender {
    [ipad_vc animateButtonTap:_cv4];
    [self showUnsupported];
}

- (IBAction)pwnDeviceButtonTapped:(id)sender {
    
    if (iphone_vc != NULL) {
        [self pushLogview];
    }
    
    [ipad_vc animateButtonTap:_cv5];
    [ipad_vc gentlyDeactivateButtons];
    UIImageView *iphoneImage = [ipad_vc.statusContainer viewWithTag:1];
    UIImageView *statusImage = [ipad_vc.statusContainer viewWithTag:2];
    UILabel* statusLabel = [ipad_vc.statusContainer viewWithTag:3];
    UIActivityIndicatorView* basicUIprogressView = [ipad_vc.statusContainer viewWithTag:5];
    
    [statusLabel setText:@"Pwning device..."];
    [statusImage setImage:[UIImage imageNamed:@"cloud.rain"]];
    [iphoneImage setAlpha:0];
    [basicUIprogressView startAnimating];
    [self exploitDFU];
}




- (void)dealloc {
    [super dealloc];
}
@end

