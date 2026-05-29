// LZDeviceManagerDelegate.h – Protocol through which LZDeviceManager
// reports device lifecycle events to its owner (the ViewModel).
// All callbacks are guaranteed to arrive on the main thread.

#import <UIKit/UIKit.h>

@class LZDeviceManager;
@class LZDeviceInfo;

NS_ASSUME_NONNULL_BEGIN

@protocol LZDeviceManagerDelegate <NSObject>
@required

// A device became ready. |info| carries all device metadata.
- (void)deviceManager:(LZDeviceManager *)manager
  deviceDidConnectWithInfo:(LZDeviceInfo *)info;

// The previously connected device was removed from USB.
- (void)deviceManagerDeviceDidDisconnect:(LZDeviceManager *)manager;

// Handshake with a detected device failed.
- (void)deviceManager:(LZDeviceManager *)manager
connectionDidFailWithError:(NSString *)errorMessage;

// Log output from device operations; for display in the console view.
- (void)deviceManager:(LZDeviceManager *)manager
      didProduceLog:(NSString *)message
              color:(UIColor *)color;

@end

NS_ASSUME_NONNULL_END
