// LZDeviceManager.h – Owns the full device lifecycle:
//   • IOKit USB monitoring (previously scattered across USBUtils + globals)
//   • DFU/Recovery connection via libirecovery (previously LDD + globals)
//   • Normal-mode connection via libimobiledevice (previously NormalModeOperations + globals)
//   • Device operations: enterRecovery, exitRecovery, pwnDevice
//
// No global variables. No ViewController references. No double pointers passed
// as parameters. All delegate callbacks arrive on the main thread.

#import <Foundation/Foundation.h>
#import "LZDeviceManagerDelegate.h"
#import "LZDeviceInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface LZDeviceManager : NSObject

// Assign before calling -startMonitoring.
@property (nonatomic, weak, nullable) id<LZDeviceManagerDelegate> delegate;

// Whether a device is currently connected and ready.
@property (nonatomic, readonly) BOOL isDeviceConnected;

// Snapshot of the last successfully connected device. Nil when disconnected.
@property (nonatomic, readonly, nullable) LZDeviceInfo *connectedDeviceInfo;

// Starts IOKit USB event monitoring on a private background thread.
// Safe to call more than once — subsequent calls are no-ops until -stopMonitoring.
- (void)startMonitoring;

// Tears down the IOKit run loop and releases device resources.
- (void)stopMonitoring;

// Re-registers IOKit notifications without destroying the run loop thread.
// Used before/after exploit runs that briefly own the USB interface.
- (void)pauseMonitoring;
- (void)resumeMonitoring;

// Device operations – must only be called when isDeviceConnected == YES.
// Each dispatches internally on a background queue and calls the delegate
// log method with progress; the caller does not need a completion handler.
- (void)enterRecovery;
- (void)exitRecovery;
- (void)pwnDevice;

@end

NS_ASSUME_NONNULL_END
