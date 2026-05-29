// LZLandingViewModel.m

#import "LZLandingViewModel.h"
#import "LZPreferencesService.h"

NSNotificationName const LZLandingViewModelDaemonReadyNotification = @"LZLandingViewModelDaemonReady";

// Returns 0 if usbmuxd is running, -1 otherwise.
static int _checkDaemon(void) {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/ps";
    task.arguments  = @[@"-A"];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    [task launch];
    [task waitUntilExit];
    NSData *data   = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [output containsString:@"(usbmuxd)"] ? 0 : -1;
}

@implementation LZLandingViewModel

- (BOOL)hasLanded {
    return [LZPreferencesService sharedService].hasLanded;
}

- (void)waitForDaemonIfNeeded {
    if (_checkDaemon() == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:LZLandingViewModelDaemonReadyNotification object:self];
        });
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        while (_checkDaemon() != 0) {
            sleep(1);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter]
                postNotificationName:LZLandingViewModelDaemonReadyNotification object:self];
        });
    });
}

- (void)completeLanding {
    [LZPreferencesService sharedService].hasLanded = YES;
}

@end
