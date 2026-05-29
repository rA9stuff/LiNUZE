// LZMainViewModel.h – Drives the main screen.
//
// The ViewController binds to this object's properties and calls its action
// methods. The ViewModel owns the service layer; the ViewController never
// touches LZDeviceManager or LZPreferencesService directly.
//
// Notification pattern: the ViewModel posts NSNotifications so the VC can
// react without tight coupling (no delegate back-reference from VM to VC).

#import <UIKit/UIKit.h>
#import "LZTypes.h"
#import "LZDeviceInfo.h"

NS_ASSUME_NONNULL_BEGIN

// Posted on the main thread whenever any observable property changes.
extern NSNotificationName const LZMainViewModelDidUpdateStateNotification;
// Posted on the main thread whenever the log text changes.
extern NSNotificationName const LZMainViewModelDidUpdateLogNotification;

@interface LZMainViewModel : NSObject

// -----------------------------------------------------------------------
// Observable state – always read on the main thread.
// -----------------------------------------------------------------------

// Current lifecycle state of the screen.
@property (nonatomic, readonly) LZMainViewState viewState;

// Nil when no device is connected.
@property (nonatomic, readonly, nullable) LZDeviceInfo *connectedDevice;

// Accumulated colored log output.
@property (nonatomic, readonly) NSAttributedString *logText;

// One-line status string for the status area.
@property (nonatomic, readonly) NSString *statusText;

// Color matching statusText.
@property (nonatomic, readonly) UIColor *statusColor;

// Whether the action buttons should accept input.
@property (nonatomic, readonly) BOOL buttonsEnabled;

// Whether the developer console tab is active.
@property (nonatomic, readonly) BOOL devConsoleEnabled;

// Label text for the environment footer (e.g. "iPhone15,2 on iOS 16.5").
@property (nonatomic, readonly) NSString *environmentInfo;

// CPU usage percentage string, e.g. "cpu usage: 12%"
@property (nonatomic, readonly) NSString *cpuUsageString;

// Nightly build hash, or nil if a stable release.
@property (nonatomic, readonly, nullable) NSString *nightlyHash;

// -----------------------------------------------------------------------
// Lifecycle
// -----------------------------------------------------------------------

// Call once when the main UI is ready.
- (void)activate;

// -----------------------------------------------------------------------
// Actions – called by the ViewController in response to user input.
// -----------------------------------------------------------------------

- (void)enterRecovery;
- (void)exitRecovery;
- (void)pwnDevice;

// Persists the preference and updates devConsoleEnabled.
- (void)setDevConsoleEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
