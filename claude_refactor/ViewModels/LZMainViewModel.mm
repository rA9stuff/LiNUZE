// LZMainViewModel.mm

#import "LZMainViewModel.h"
#import "LZDeviceManager.h"
#import "LZDeviceManagerDelegate.h"
#import "LZPreferencesService.h"

#include <sys/utsname.h>
#include <mach/mach.h>

NSNotificationName const LZMainViewModelDidUpdateStateNotification = @"LZMainViewModelDidUpdateState";
NSNotificationName const LZMainViewModelDidUpdateLogNotification   = @"LZMainViewModelDidUpdateLog";

// ---------------------------------------------------------------------------
// CPU usage – pure C, no UIKit dependency
// ---------------------------------------------------------------------------

static float _currentCPUUsage(void) {
    thread_array_t threads;
    mach_msg_type_number_t count;
    if (task_threads(mach_task_self(), &threads, &count) != KERN_SUCCESS) return -1;
    float total = 0;
    for (mach_msg_type_number_t i = 0; i < count; i++) {
        thread_info_data_t info;
        mach_msg_type_number_t infoCount = THREAD_INFO_MAX;
        if (thread_info(threads[i], THREAD_BASIC_INFO, (thread_info_t)info, &infoCount) != KERN_SUCCESS) continue;
        thread_basic_info_t basic = (thread_basic_info_t)info;
        if (!(basic->flags & TH_FLAGS_IDLE))
            total += basic->cpu_usage / (float)TH_USAGE_SCALE * 100.0f;
    }
    vm_deallocate(mach_task_self(), (vm_offset_t)threads, count * sizeof(thread_t));
    return total;
}

// ---------------------------------------------------------------------------

@interface LZMainViewModel () <LZDeviceManagerDelegate>
@property (nonatomic, strong) LZDeviceManager *deviceManager;
@property (nonatomic, strong) LZPreferencesService *prefs;
@property (nonatomic, strong) NSMutableAttributedString *mutableLog;
@property (nonatomic, strong) dispatch_source_t cpuTimer;

// Backing stores for readonly properties
@property (nonatomic, readwrite) LZMainViewState viewState;
@property (nonatomic, readwrite, nullable) LZDeviceInfo *connectedDevice;
@property (nonatomic, readwrite) NSString *statusText;
@property (nonatomic, readwrite) UIColor *statusColor;
@property (nonatomic, readwrite) BOOL buttonsEnabled;
@property (nonatomic, readwrite) BOOL devConsoleEnabled;
@property (nonatomic, readwrite) NSString *cpuUsageString;
@end

@implementation LZMainViewModel

- (instancetype)init {
    self = [super init];
    if (self) {
        _prefs          = [LZPreferencesService sharedService];
        _deviceManager  = [[LZDeviceManager alloc] init];
        _deviceManager.delegate = self;
        _mutableLog     = [[NSMutableAttributedString alloc] init];
        _viewState      = LZMainViewStateIdle;
        _statusText     = @"Waiting for a device…";
        _statusColor    = [UIColor greenColor];
        _buttonsEnabled = NO;
        _devConsoleEnabled = _prefs.devConsoleEnabled;
        _cpuUsageString = @"cpu usage: —";
        _nightlyHash    = _prefs.nightlyHash;
    }
    return self;
}

- (NSAttributedString *)logText { return [_mutableLog copy]; }

- (NSString *)environmentInfo {
    struct utsname u;
    uname(&u);
    return [NSString stringWithFormat:@"%s on %@ %@",
            u.machine,
            [UIDevice currentDevice].systemName,
            [UIDevice currentDevice].systemVersion];
}

// ---------------------------------------------------------------------------
#pragma mark - Lifecycle
// ---------------------------------------------------------------------------

- (void)activate {
    NSAssert([NSThread isMainThread], @"-activate must be called on the main thread");
    [self _appendLog:@"Ready, waiting for a device\n" color:[UIColor greenColor]];
    [self _startCPUMonitor];
    [self _startStdoutMonitor];
    [self.deviceManager startMonitoring];
}

// ---------------------------------------------------------------------------
#pragma mark - Actions
// ---------------------------------------------------------------------------

- (void)enterRecovery {
    [self.deviceManager enterRecovery];
}

- (void)exitRecovery {
    [self.deviceManager exitRecovery];
}

- (void)pwnDevice {
    self.viewState      = LZMainViewStateOperating;
    self.buttonsEnabled = NO;
    [self _postStateUpdate];
    [self.deviceManager pwnDevice];
}

- (void)setDevConsoleEnabled:(BOOL)enabled {
    _devConsoleEnabled = enabled;
    _prefs.devConsoleEnabled = enabled;
    [self _postStateUpdate];
}

// ---------------------------------------------------------------------------
#pragma mark - LZDeviceManagerDelegate
// ---------------------------------------------------------------------------

- (void)deviceManager:(LZDeviceManager *)manager
 deviceDidConnectWithInfo:(LZDeviceInfo *)info {
    self.connectedDevice = info;
    self.viewState       = LZMainViewStateConnected;
    self.buttonsEnabled  = YES;
    self.statusText      = [NSString stringWithFormat:@"Connected: %@", info.displayName];
    self.statusColor     = [UIColor cyanColor];
    [self _postStateUpdate];
}

- (void)deviceManagerDeviceDidDisconnect:(LZDeviceManager *)manager {
    self.connectedDevice = nil;
    self.viewState       = LZMainViewStateIdle;
    self.buttonsEnabled  = NO;
    self.statusText      = @"Waiting for a device…";
    self.statusColor     = [UIColor greenColor];
    [self _postStateUpdate];
}

- (void)deviceManager:(LZDeviceManager *)manager
 connectionDidFailWithError:(NSString *)errorMessage {
    self.viewState       = LZMainViewStateError;
    self.buttonsEnabled  = NO;
    self.statusText      = errorMessage;
    self.statusColor     = [UIColor redColor];
    [self _appendLog:[NSString stringWithFormat:@"[Error] %@\n", errorMessage]
               color:[UIColor redColor]];
    [self _postStateUpdate];
}

- (void)deviceManager:(LZDeviceManager *)manager
      didProduceLog:(NSString *)message
              color:(UIColor *)color {
    [self _appendLog:message color:color];
}

// ---------------------------------------------------------------------------
#pragma mark - Stdout monitor (captures ipwnder_lite / gaster printf output)
// ---------------------------------------------------------------------------

- (void)_startStdoutMonitor {
    setbuf(stdout, NULL);
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *read = [pipe fileHandleForReading];
    dup2([[pipe fileHandleForWriting] fileDescriptor], fileno(stdout));

    dispatch_source_t src = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_READ,
        (uintptr_t)[read fileDescriptor],
        0,
        dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));

    dispatch_source_set_event_handler(src, ^{
        void *buf = malloc(4096);
        ssize_t n;
        do { n = read(read.fileDescriptor, buf, 4096); } while (n == -1 && errno == EINTR);
        if (n > 0) {
            NSString *s = [[NSString alloc] initWithBytesNoCopy:buf length:n
                                                       encoding:NSUTF8StringEncoding
                                                   freeWhenDone:YES];
            UIColor *color = [UIColor whiteColor];
            if ([s containsString:@"[31m"]) color = [UIColor redColor];
            else if ([s containsString:@"[32m"]) color = [UIColor greenColor];
            s = [[s stringByReplacingOccurrencesOfString:@"[31m" withString:@""]
                     stringByReplacingOccurrencesOfString:@"[32m" withString:@""]
                     stringByReplacingOccurrencesOfString:@"[39m" withString:@""];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self _appendLog:s color:color];
            });
        } else {
            free(buf);
        }
    });
    dispatch_resume(src);
}

// ---------------------------------------------------------------------------
#pragma mark - CPU monitor
// ---------------------------------------------------------------------------

- (void)_startCPUMonitor {
    _cpuTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                       dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0));
    dispatch_source_set_timer(_cpuTimer,
                              dispatch_time(DISPATCH_TIME_NOW, 0),
                              NSEC_PER_SEC,
                              NSEC_PER_SEC / 2);
    __weak typeof(self) weak = self;
    dispatch_source_set_event_handler(_cpuTimer, ^{
        float usage = _currentCPUUsage();
        dispatch_async(dispatch_get_main_queue(), ^{
            weak.cpuUsageString = [NSString stringWithFormat:@"cpu usage: %.0f%%", usage];
            [[NSNotificationCenter defaultCenter]
                postNotificationName:LZMainViewModelDidUpdateStateNotification object:weak];
        });
    });
    dispatch_resume(_cpuTimer);
}

// ---------------------------------------------------------------------------
#pragma mark - Helpers
// ---------------------------------------------------------------------------

- (void)_appendLog:(NSString *)text color:(UIColor *)color {
    NSAssert([NSThread isMainThread], @"_appendLog must run on main thread");
    UIFont *font = [UIFont fontWithName:@"SFMono-Regular" size:13]
                ?: [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    NSDictionary *attrs = @{ NSForegroundColorAttributeName: color,
                              NSFontAttributeName: font };
    NSAttributedString *str = [[NSAttributedString alloc] initWithString:text attributes:attrs];
    [_mutableLog appendAttributedString:str];

    // Persist plain log to disk (best effort; errors are not fatal)
    NSString *logPath = @"/var/mobile/Media/LiNUZE/LiNUZE_Log.txt";
    [_mutableLog.string writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:LZMainViewModelDidUpdateLogNotification object:self];
}

- (void)_postStateUpdate {
    NSAssert([NSThread isMainThread], @"_postStateUpdate must run on main thread");
    [[NSNotificationCenter defaultCenter]
        postNotificationName:LZMainViewModelDidUpdateStateNotification object:self];
}

@end
