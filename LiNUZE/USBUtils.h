//
//  USBUtils.h
//  LiNUZE
//
//  Created by rA9stuff on 10.02.2023.
//

#ifndef USBUtils_h
#define USBUtils_h

#include <stdio.h>
#include <IOKit/usb/IOUSBLib.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/lockdown.h>
#import "LDD.h"

@interface USBUtils : NSObject

- (void)startMonitoringUSBDevices:(UIViewController *) vc maindevptr:(LDD**)maindevptr normaldevptr:(idevice_t**) normaldevptr lockdownptr:(lockdownd_client_t**) lockdownptr normaldevname:(NSString**)normaldevname;
- (NSString*) getNameOfUSBDevice:(io_object_t) usbDevice;
- (void) USBDeviceDetectedCallback:(void *)refcon iterator: (io_iterator_t) iterator;
- (void) registerForUSBDeviceNotifications;
- (void) stopMonitoringUSBDevices;
@property (nonatomic, strong) UIViewController* vc;
@property (nonatomic) LDD* devptr;

@end


#endif /* USBUtils_h */
