// LZLandingViewModel.h – Drives the onboarding/landing screen.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Posted (on main thread) once the usbmuxd daemon becomes available.
extern NSNotificationName const LZLandingViewModelDaemonReadyNotification;

@interface LZLandingViewModel : NSObject

// YES if the user has already seen and dismissed the landing screen.
@property (nonatomic, readonly) BOOL hasLanded;

// Starts a background poll for usbmuxd if it is not yet running.
// Posts LZLandingViewModelDaemonReadyNotification when ready.
- (void)waitForDaemonIfNeeded;

// Records that the user tapped "Done" and dismisses the need to show
// the landing screen again.
- (void)completeLanding;

@end

NS_ASSUME_NONNULL_END
