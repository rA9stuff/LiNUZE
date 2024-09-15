//
//  USBUtils.mm
//  LiNUZE
//
//  Created by rA9stuff on 10.02.2023.
//

#include "USBUtils.h"
#include <IOKit/usb/IOUSBLib.h>
#include "LDD.h"
#include "LiNUZE_VC.h"
#include "NormalModeOperations.h"
#include "NSTask.h"
#include <libirecovery.h>
#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/lockdown.h>
#include <libimobiledevice-glue/utils.h>
#include <common.h>

bool deadDevice;
bool breaksignal;
LDD** masterDFUDevice;
idevice_t** masterNormalDevice;
lockdownd_client_t** masterLockdownDevice;
NSString** masterNormalDeviceName;
extern ViewController* ipad_vc;
extern ViewController* iphone_vc;

@implementation USBUtils : NSObject

- (NSString*) getNameOfUSBDevice: (io_object_t) usbDevice {
    kern_return_t kernResult;
    CFMutableDictionaryRef properties = NULL;
    kernResult = IORegistryEntryCreateCFProperties(usbDevice, &properties, kCFAllocatorDefault, kNilOptions);
    if (kernResult != KERN_SUCCESS) {
        NSLog(@"Unable to access USB device properties");
        return @"err";
    }
    CFTypeRef nameRef = CFDictionaryGetValue(properties, CFSTR(kUSBProductString));
    if (!nameRef) {
        NSLog(@"Name not found");
        return @"err";
    }
    CFStringRef nameStrRef = (CFStringRef)nameRef;
    char nameCStr[1024];
    if (!CFStringGetCString(nameStrRef, nameCStr, 1024, kCFStringEncodingUTF8)) {
        NSLog(@"Unable to get C string representation of name");
        return @"err";
    }

    NSString *name = [NSString stringWithCString:nameCStr encoding:NSUTF8StringEncoding];
    CFRelease(properties);
    return name;
}

- (void) displayFailure {
    
    UIActivityIndicatorView *activityView = [[ipad_vc statusContainer] viewWithTag:5];
    UILabel* statusLabel = [[ipad_vc statusContainer] viewWithTag:3];
    UIImageView* statusImage = [[ipad_vc statusContainer] viewWithTag:2];
    UIImageView* iphoneImage = [[ipad_vc statusContainer] viewWithTag:1];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        iphoneImage.image = [UIImage imageNamed:@"iphone_x_generic"];
        [activityView stopAnimating];
        NSString *err =  @"Failed to establish a connection, please re-plug your device to try again";
        // add basic ui handling here
        [statusImage setImage:[UIImage imageNamed:@"error.circle.fill"]];
        // Create attributed string for "Connected" with bold font
        UIFont* boldFont = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
        NSDictionary *boldAttrs = @{ NSForegroundColorAttributeName : [UIColor whiteColor], NSFontAttributeName : boldFont };
        NSAttributedString *boldStr = [[NSAttributedString alloc] initWithString:@"Error\n\n" attributes:boldAttrs];
        
        // Create attributed string for device name with regular font
        UIFont* regularFont = [UIFont systemFontOfSize:13];
        NSDictionary *regularAttrs = @{ NSForegroundColorAttributeName : [UIColor whiteColor], NSFontAttributeName : regularFont };
        NSAttributedString *regularStr = [[NSAttributedString alloc] initWithString:@"An error occured connecting to device, please re-plug the USB cable to try again." attributes:regularAttrs];
        
        // Combine the two attributed strings
        NSMutableAttributedString *combinedStr = [[NSMutableAttributedString alloc] init];
        [combinedStr appendAttributedString:boldStr];
        [combinedStr appendAttributedString:regularStr];
        
        statusLabel.attributedText = combinedStr;
        [ipad_vc updateStatus: err color: [UIColor redColor]];
        iphoneImage.alpha = 1.0;
    });
}

- (void) USBDeviceDetectedCallback:(void *)refcon iterator: (io_iterator_t) iterator {
    io_object_t usbDevice;
    while ((usbDevice = IOIteratorNext(iterator))) {
        
        NSString* name = [self getNameOfUSBDevice:usbDevice];
        __block int res = -10;
        UIActivityIndicatorView *activityView = [[ipad_vc statusContainer] viewWithTag:5];
        UILabel* statusLabel = [[ipad_vc statusContainer] viewWithTag:3];
        UIImageView* iphoneImage = [[ipad_vc statusContainer] viewWithTag:1];
        dispatch_async(dispatch_get_main_queue(), ^{
            [ipad_vc updateStatus:[NSString stringWithFormat:@"New USB device: %@", name] color:[UIColor whiteColor]];
        });
        if ([name isEqualToString:@"Apple Mobile Device (DFU Mode)"] || [name isEqualToString:@"Apple Mobile Device (Recovery Mode)"]) {
            deadDevice = false;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[iphone_vc statusStr] setText:name];
                [ipad_vc updateStatus: @"Attempting to establish a connection..." color: [UIColor whiteColor]];
                [activityView startAnimating];
                [statusLabel setText:[NSString stringWithFormat:@"Connecting to %@...", name]];
                [iphoneImage setHidden:YES];
            });
            
            dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INITIATED, -1);
            dispatch_queue_t lddqueue = dispatch_queue_create("com.linuze.lddqueue", attr);
            dispatch_async(lddqueue, ^{
                LDD *dev = NULL;
                dev = new LDD;
                res = dev -> openConnection(10);
                if (res == 0) {
                    *masterDFUDevice = dev;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [activityView stopAnimating];
                        [ipad_vc displayCorrectBasicInterface:[NSString stringWithUTF8String: __func__] devptr:(*masterDFUDevice) normaldevname:NULL VC:ipad_vc];
                        [[iphone_vc statusStr] setText:[NSString stringWithFormat:@"Connected: %s", (*masterDFUDevice)->getDisplayName()]];
                        [ipad_vc gentlyActivateButtons];
                        [iphone_vc gentlyActivateButtons];
                        [ipad_vc updateStatus: @"OK" color: [UIColor cyanColor]];
                        [ipad_vc updateStatus: [NSString stringWithFormat:@"Done, LDD created at %p", dev] color: [UIColor greenColor]];
                        [ipad_vc PrintDevInfo:dev];
                        if (masterDFUDevice == NULL) {
                            [ipad_vc updateStatus: @"masterDFUDevice is null!" color: [UIColor redColor]];
                        }
                        else
                            [ipad_vc updateStatus: [NSString stringWithFormat:@"masterDFUDevice: %p", *masterDFUDevice] color: [UIColor whiteColor]];
                    });
                    
                }
                else {
                    [self displayFailure];
                }
            });
        }
        else if ([name isEqualToString:@"iPhone"] || [name isEqualToString:@"iPad"] || [name isEqualToString:@"iPod"]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [activityView startAnimating];
                [[ipad_vc statusLabelPhone] setText:[NSString stringWithFormat:@"Connecting to %@...", name]];
                [[ipad_vc statusStr] setText:[NSString stringWithFormat:@"Connecting to %@...", name]];
                [ipad_vc updateStatus:@"iDevice in normal mode detected, things will fail if usbmuxd daemon is not running!" color: [UIColor whiteColor]];
            });
            
            **masterNormalDevice = NULL;
            res = openNormalModeConnection(*masterNormalDevice, 5);
            if (res == -1) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self displayFailure];
                    [[iphone_vc statusStr] setText:@"usbmuxd error"];
                    [ipad_vc updateStatus:@"Connection failed, is usbmuxd running?" color: [UIColor redColor]];
                });
                continue;
            }
            *masterNormalDeviceName = [[NSString alloc] initWithString:getDeviceName(*masterNormalDevice, *masterLockdownDevice)];
            if ([*masterNormalDeviceName isEqualToString:@"err"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self displayFailure];
                    [[ipad_vc statusStr] setText:@"Failed to get device name"];
                    [ipad_vc updateStatus:@"Failed to get device name" color: [UIColor redColor]];
                });
                continue;
            }
            if ([*masterNormalDeviceName isEqualToString:@"err_pair"])  {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[iphone_vc statusStr] setText:@"Waiting for approval..."];
                    [ipad_vc updateStatus:@"Please hit \"trust\" button on your device to continue" color: [UIColor whiteColor]];
                });
                sleep(2);
                lockdownd_error_t err = LOCKDOWN_E_PAIRING_DIALOG_RESPONSE_PENDING;
                while (err == LOCKDOWN_E_PAIRING_DIALOG_RESPONSE_PENDING) {
                    err = lockdownd_client_new_with_handshake(**masterNormalDevice, *masterLockdownDevice, "dingus");
                    sleep(1);
                }
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [activityView stopAnimating];
                    [ipad_vc displayCorrectBasicInterface:[NSString stringWithUTF8String: __func__] devptr:(*masterDFUDevice) normaldevname: *masterNormalDeviceName VC:ipad_vc];
                    [[iphone_vc statusStr] setText:[NSString stringWithFormat:@"Connected: %@", *masterNormalDeviceName]];
                    [ipad_vc updateStatus:[NSString stringWithFormat:@"Connected: %@", *masterNormalDeviceName] color: [UIColor cyanColor]];
                    [ipad_vc gentlyActivateButtons];
                    [iphone_vc gentlyActivateButtons];
                });
            }
        }
        IOObjectRelease(usbDevice);
    }
}


- (BOOL) detectTrapRemoval {
    @autoreleasepool {
        CFMutableDictionaryRef matchingDict = IOServiceMatching("IOUSBHostDevice");
        io_iterator_t iter;
        IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iter);
        io_service_t usbDevice;
        while ((usbDevice = IOIteratorNext(iter))) {
            // Get device name
            NSString* devname = [self getNameOfUSBDevice:usbDevice];
            if ([devname isEqualToString:@"iPhone"] || [devname isEqualToString:@"iPad"] || [devname isEqualToString:@"iPod"]) {
                printf("%s Device switched state!\n", __func__);
                return true;
            }
            IOObjectRelease(usbDevice);
        }
        IOObjectRelease(iter);
    }
    return false;
}


- (void) USBDeviceRemovedCallback:(void *)refcon iterator: (io_iterator_t) iterator {
    
    io_object_t usbDevice;
    while ((usbDevice = IOIteratorNext(iterator))) {
        
        if ([self detectTrapRemoval])
            continue;
        
        NSString* name = [self getNameOfUSBDevice:usbDevice];
        dispatch_async(dispatch_get_main_queue(), ^{
            [ipad_vc updateStatus:[NSString stringWithFormat:@"Lost USB device: %@", name] color:[UIColor whiteColor]];
        });
        if ([name isEqualToString:@"Apple Mobile Device (DFU Mode)"] || [name isEqualToString:@"Apple Mobile Device (Recovery Mode)"] || [name isEqualToString:@"iPhone"] || [name isEqualToString:@"iPad"] || [name isEqualToString:@"iPod"]) {
            deadDevice = true;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[iphone_vc statusStr] setText:@"waiting for a device"];
                    [ipad_vc displayCorrectBasicInterface:[NSString stringWithUTF8String: __func__] devptr:NULL normaldevname: NULL VC:ipad_vc];
                    [ipad_vc updateStatus:@"waiting for a device" color: [UIColor whiteColor]];
                    [ipad_vc gentlyDeactivateButtons];
                    [iphone_vc gentlyDeactivateButtons];
                });
                if (*masterDFUDevice == NULL) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [ipad_vc updateStatus: @"Not attempting to free lost LDD..." color: [UIColor whiteColor]];
                    });
                    continue;
                }
                else if ((*masterDFUDevice)->getDevice() == NULL) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [ipad_vc updateStatus: @"Not attempting to free lost device..." color: [UIColor whiteColor]];
                    });
                    continue;
                }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [ipad_vc updateStatus: [NSString stringWithFormat:@"Attempting to free lost device at %p with LDD pair at %p", (*masterDFUDevice)->getDevice(), (*masterDFUDevice)] color: [UIColor whiteColor]];
            });
            (*masterDFUDevice)->freeDevice();
        }
        IOObjectRelease(usbDevice);
    }
}

static void DeviceAdded(void *refCon, io_iterator_t iterator) {
    USBUtils *obj = (USBUtils *)refCon;
    [obj USBDeviceDetectedCallback:NULL iterator:iterator];
}

static void DeviceRemoved(void *refCon, io_iterator_t iterator) {
    USBUtils *obj = (USBUtils *)refCon;
    [obj USBDeviceRemovedCallback:NULL iterator:iterator];
}

io_iterator_t detectionIterator, removalIterator;

- (void) registerForUSBDeviceNotifications {
    CFMutableDictionaryRef matchingDict = IOServiceMatching("IOUSBHostDevice");
    if (!matchingDict) {
        NSLog(@"Unable to create matching dictionary for USB device detection");
        return;
    }
    
    IONotificationPortRef notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    CFRunLoopSourceRef runLoopSource = IONotificationPortGetRunLoopSource(notificationPort);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    kern_return_t kernResult = IOServiceAddMatchingNotification(notificationPort, kIOPublishNotification, matchingDict, DeviceAdded, (__bridge void*)self, &detectionIterator);

    if (kernResult != kIOReturnSuccess) {
        NSLog(@"Unable to register for USB device detection notifications");
        return;
    }
    [self USBDeviceDetectedCallback:NULL iterator: detectionIterator];
    
    CFMutableDictionaryRef removalMatchingDict = IOServiceMatching("IOUSBHostDevice");
    if (!removalMatchingDict) {
        NSLog(@"Unable to create matching dictionary for USB device detection");
        return;
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    kernResult = IOServiceAddMatchingNotification(notificationPort, kIOTerminatedNotification, removalMatchingDict, DeviceRemoved, (__bridge void*)self, &removalIterator);

    if (kernResult != kIOReturnSuccess) {
        NSLog(@"Unable to register for USB device detection notifications");
        return;
    }
    [self USBDeviceRemovedCallback:NULL iterator:removalIterator];
}

- (void) startMonitoringUSBDevices:(ViewController *)viewController maindevptr:(LDD**)maindevptr normaldevptr:(idevice_t**) normaldevptr lockdownptr:(lockdownd_client_t**)lockdownptr normaldevname:(NSString**)normaldevname {
    // here, we want maindevptr to keep track of masterDFUDevice
    // we will use a temporary LDD* to connect to a device in USBDeviceDetectedCallback method
    // if it goes well, we'll copy the address to masterDFUDevice,
    // which maindevptr will have access to since it will always point at masterDFUDevice
    //ipad_vc = viewController;
    [ipad_vc updateStatus:@"waiting for a device" color: [UIColor whiteColor]];
    
    masterDFUDevice        = (LDD**)(malloc(sizeof(LDD)));
    masterNormalDevice     = (idevice_t**)malloc(sizeof(idevice_t));
    masterLockdownDevice   = (lockdownd_client_t**)malloc(sizeof(lockdownd_client_t));
    masterDFUDevice        = maindevptr;
    masterNormalDevice     = normaldevptr;
    masterLockdownDevice   = lockdownptr;
    masterNormalDeviceName = normaldevname;
    
    [self registerForUSBDeviceNotifications];
    [[NSRunLoop currentRunLoop] run];
    
}

- (void) stopMonitoringUSBDevices {
    IOObjectRelease(detectionIterator);
    IOObjectRelease(removalIterator);
}

@end
