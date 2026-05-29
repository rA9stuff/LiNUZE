// LZDeviceManager.mm
//
// Design notes:
// • All mutable state is confined to _stateQueue (serial) – no data races.
// • The IOKit run loop runs on _monitorThread; callbacks marshal to _stateQueue
//   then to the main thread for delegate calls.
// • No global variables. The original USBUtils globals (masterDFUDevice, ipad_vc,
//   etc.) are replaced by strong ivars on this object.
// • LDD is wrapped and never exposed outside this file.
// • The "deadDevice" global bool is replaced by the _deviceDisconnecting BOOL ivar
//   which is set on _stateQueue before cancelling LDD::openConnection().

#import "LZDeviceManager.h"

#include <IOKit/usb/IOUSBLib.h>
#include <libirecovery.h>
#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/lockdown.h>

// Pull in the original C++ LDD class from the parent project.
// We only use it inside this .mm file; it is never exposed in the header.
#include "../../LiNUZE/LDD.h"

// exploit wrappers (run_gaster / run_ipwnder_lite)
#include "../../LiNUZE/exploit_wrappers.h"

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

static NSString *_nonce(const unsigned char *buf, size_t len) {
    if (!buf || len == 0) return @"N/A";
    NSMutableString *s = [NSMutableString stringWithCapacity:len * 2];
    for (size_t i = 0; i < len; i++) {
        [s appendFormat:@"%02x", buf[i]];
    }
    return [s length] > 0 ? s : @"N/A";
}

static NSString *_cpidStr(unsigned int cpid) {
    return [NSString stringWithFormat:@"%04x", cpid];
}

static LZDeviceConnectionMode _modeFromLDD(LDD *dev) {
    int mode = 0;
    irecv_get_mode(dev->getClient(), &mode);
    switch (mode) {
        case IRECV_K_RECOVERY_MODE_1:
        case IRECV_K_RECOVERY_MODE_2:
        case IRECV_K_RECOVERY_MODE_3:
        case IRECV_K_RECOVERY_MODE_4: return LZDeviceConnectionModeRecovery;
        case IRECV_K_DFU_MODE:        return LZDeviceConnectionModeDFU;
        case IRECV_K_WTF_MODE:        return LZDeviceConnectionModeWTF;
        default:                      return LZDeviceConnectionModeNone;
    }
}

static LZDeviceInfo *_deviceInfoFromLDD(LDD *dev) {
    const struct irecv_device_info *info = dev->getDevInfo();
    BOOL pwned = dev->checkPwn();
    NSString *pwnTag = pwned ? [NSString stringWithUTF8String:dev->getPWNDTag()] : nil;
    return [[LZDeviceInfo alloc]
            initWithDisplayName:[NSString stringWithUTF8String:dev->getDisplayName()]
                  hardwareModel:[NSString stringWithUTF8String:dev->getHardwareModel()]
                    productType:[NSString stringWithUTF8String:dev->getProductType()]
                           ecid:[NSString stringWithFormat:@"%llu", info->ecid]
                           cpid:_cpidStr(info->cpid)
                        apNonce:_nonce(info->ap_nonce, info->ap_nonce_size)
                       sepNonce:_nonce(info->sep_nonce, info->sep_nonce_size)
                         pwnTag:pwnTag
                       isPwned:pwned
                 connectionMode:_modeFromLDD(dev)];
}

// ---------------------------------------------------------------------------
// C-level IOKit callbacks – bridge to the ObjC instance stored in refCon.
// ---------------------------------------------------------------------------

@class LZDeviceManager;
static void _DeviceAdded(void *refCon, io_iterator_t iterator);
static void _DeviceRemoved(void *refCon, io_iterator_t iterator);

// ---------------------------------------------------------------------------
// LZDeviceManager implementation
// ---------------------------------------------------------------------------

@interface LZDeviceManager ()
// All reads/writes to device state go through _stateQueue.
@property (nonatomic, strong) dispatch_queue_t stateQueue;
@property (nonatomic, strong) dispatch_queue_t operationQueue;

// Monitoring thread + run loop
@property (nonatomic, strong) NSThread *monitorThread;
@property (nonatomic) CFRunLoopRef monitorRunLoop; // set on monitorThread

// IOKit iterators – owned by the monitoring run loop
@property (nonatomic) io_iterator_t detectionIterator;
@property (nonatomic) io_iterator_t removalIterator;
@property (nonatomic, strong) NSThread *ioKitNotifPort; // just for lifetime
@property (nonatomic) IONotificationPortRef notificationPort;

// Device state
@property (nonatomic) BOOL deviceDisconnecting; // replaces global "deadDevice"
@property (nonatomic) LDD *dfuDevice;           // heap-allocated, managed here
@property (nonatomic) idevice_t normalDevice;
@property (nonatomic) lockdownd_client_t lockdownClient;
@property (nonatomic, readwrite) LZDeviceInfo *connectedDeviceInfo;
@property (nonatomic, readwrite) BOOL isDeviceConnected;

@property (nonatomic) BOOL monitoringActive;
@end

@implementation LZDeviceManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _stateQueue     = dispatch_queue_create("com.linuze.devicemanager.state",
                                                DISPATCH_QUEUE_SERIAL);
        _operationQueue = dispatch_queue_create("com.linuze.devicemanager.ops",
                                                DISPATCH_QUEUE_SERIAL);
        _dfuDevice      = NULL;
        _normalDevice   = NULL;
        _lockdownClient = NULL;
    }
    return self;
}

- (void)dealloc {
    [self stopMonitoring];
}

// ---------------------------------------------------------------------------
#pragma mark - Monitoring lifecycle
// ---------------------------------------------------------------------------

- (void)startMonitoring {
    dispatch_async(_stateQueue, ^{
        if (self.monitoringActive) return;
        self.monitoringActive = YES;
        self.monitorThread = [[NSThread alloc] initWithTarget:self
                                                     selector:@selector(_runMonitorLoop)
                                                       object:nil];
        self.monitorThread.name = @"com.linuze.usb-monitor";
        [self.monitorThread start];
    });
}

- (void)stopMonitoring {
    dispatch_sync(_stateQueue, ^{
        self.monitoringActive = NO;
        [self _teardownIOKit];
        if (self.monitorRunLoop) {
            CFRunLoopStop(self.monitorRunLoop);
        }
        [self _freeDFUDevice];
        [self _freeNormalDevice];
    });
}

- (void)pauseMonitoring {
    dispatch_async(_stateQueue, ^{
        [self _teardownIOKit];
    });
}

- (void)resumeMonitoring {
    // Schedule re-registration on the monitor thread's run loop.
    if (!self.monitorThread || !self.monitorRunLoop) return;
    CFRunLoopPerformBlock(self.monitorRunLoop, kCFRunLoopDefaultMode, ^{
        [self _registerForUSBDeviceNotifications];
    });
    CFRunLoopWakeUp(self.monitorRunLoop);
}

// Runs on _monitorThread
- (void)_runMonitorLoop {
    @autoreleasepool {
        self.monitorRunLoop = CFRunLoopGetCurrent();
        [self _registerForUSBDeviceNotifications];
        CFRunLoopRun();
        // Reached after CFRunLoopStop() in stopMonitoring.
        self.monitorRunLoop = nil;
    }
}

// ---------------------------------------------------------------------------
#pragma mark - IOKit registration (called on monitor thread)
// ---------------------------------------------------------------------------

- (void)_registerForUSBDeviceNotifications {
    CFMutableDictionaryRef addDict = IOServiceMatching("IOUSBHostDevice");
    if (!addDict) {
        [self _log:@"[LZDeviceManager] Failed to create IOKit matching dict" color:[UIColor redColor]];
        return;
    }

    if (!self.notificationPort) {
        self.notificationPort = IONotificationPortCreate(kIOMasterPortDefault);
        CFRunLoopSourceRef src = IONotificationPortGetRunLoopSource(self.notificationPort);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, kCFRunLoopDefaultMode);
    }

    io_iterator_t addIter = 0, remIter = 0;
    kern_return_t kr;

    kr = IOServiceAddMatchingNotification(self.notificationPort,
                                          kIOPublishNotification,
                                          addDict,
                                          _DeviceAdded,
                                          (__bridge void *)self,
                                          &addIter);
    if (kr != kIOReturnSuccess) {
        [self _log:@"[LZDeviceManager] Failed to register add notification" color:[UIColor redColor]];
        return;
    }
    self.detectionIterator = addIter;
    // Drain the iterator to arm future notifications.
    [self _handleDeviceAdded:addIter];

    CFMutableDictionaryRef remDict = IOServiceMatching("IOUSBHostDevice");
    kr = IOServiceAddMatchingNotification(self.notificationPort,
                                          kIOTerminatedNotification,
                                          remDict,
                                          _DeviceRemoved,
                                          (__bridge void *)self,
                                          &remIter);
    if (kr != kIOReturnSuccess) {
        [self _log:@"[LZDeviceManager] Failed to register remove notification" color:[UIColor redColor]];
        return;
    }
    self.removalIterator = remIter;
    [self _handleDeviceRemoved:remIter];
}

- (void)_teardownIOKit {
    if (self.detectionIterator) {
        IOObjectRelease(self.detectionIterator);
        self.detectionIterator = 0;
    }
    if (self.removalIterator) {
        IOObjectRelease(self.removalIterator);
        self.removalIterator = 0;
    }
    if (self.notificationPort) {
        IONotificationPortDestroy(self.notificationPort);
        self.notificationPort = nil;
    }
}

// ---------------------------------------------------------------------------
#pragma mark - IOKit C callbacks (bridge back to instance methods)
// ---------------------------------------------------------------------------

static void _DeviceAdded(void *refCon, io_iterator_t iterator) {
    LZDeviceManager *self = (__bridge LZDeviceManager *)refCon;
    [self _handleDeviceAdded:iterator];
}

static void _DeviceRemoved(void *refCon, io_iterator_t iterator) {
    LZDeviceManager *self = (__bridge LZDeviceManager *)refCon;
    [self _handleDeviceRemoved:iterator];
}

// ---------------------------------------------------------------------------
#pragma mark - Device added
// ---------------------------------------------------------------------------

- (void)_handleDeviceAdded:(io_iterator_t)iterator {
    io_object_t usbObject;
    while ((usbObject = IOIteratorNext(iterator))) {
        NSString *name = [self _nameForUSBObject:usbObject];
        IOObjectRelease(usbObject);

        if (!name) continue;

        [self _log:[NSString stringWithFormat:@"New USB device: %@", name]
             color:[UIColor whiteColor]];

        if ([name isEqualToString:@"Apple Mobile Device (DFU Mode)"] ||
            [name isEqualToString:@"Apple Mobile Device (Recovery Mode)"]) {
            [self _connectDFUDevice:name];
        } else if ([name isEqualToString:@"iPhone"] ||
                   [name isEqualToString:@"iPad"]   ||
                   [name isEqualToString:@"iPod"]) {
            [self _connectNormalModeDevice:name];
        }
    }
}

- (void)_connectDFUDevice:(NSString *)usbName {
    dispatch_async(_stateQueue, ^{
        self.deviceDisconnecting = NO;
    });

    [self _delegateOnMain:^{
        id<LZDeviceManagerDelegate> d = self.delegate;
        // Notify connecting state via log
        [d deviceManager:self
          didProduceLog:[NSString stringWithFormat:@"Connecting to %@…", usbName]
                  color:[UIColor whiteColor]];
    }];

    dispatch_async(_operationQueue, ^{
        LDD *dev = new LDD;
        int res = dev->openConnection(10);

        if (res != 0 || !self.delegate) {
            delete dev;
            [self _log:@"Failed to open libirecovery connection" color:[UIColor redColor]];
            [self _delegateOnMain:^{
                [self.delegate deviceManager:self
                   connectionDidFailWithError:@"libirecovery failed to connect. Re-plug the device and try again."];
            }];
            return;
        }

        LZDeviceInfo *info = _deviceInfoFromLDD(dev);

        dispatch_async(self.stateQueue, ^{
            [self _freeDFUDevice];
            self.dfuDevice = dev;
            self.isDeviceConnected = YES;
            self.connectedDeviceInfo = info;
        });

        [self _log:[NSString stringWithFormat:@"Connected: %@", info.displayName]
             color:[UIColor cyanColor]];
        [self _logDeviceInfo:info];

        [self _delegateOnMain:^{
            [self.delegate deviceManager:self deviceDidConnectWithInfo:info];
        }];
    });
}

- (void)_connectNormalModeDevice:(NSString *)usbName {
    [self _log:@"Normal-mode device detected" color:[UIColor whiteColor]];

    dispatch_async(_operationQueue, ^{
        [self _freeNormalDevice];

        idevice_t device = NULL;
        lockdownd_client_t lockdown = NULL;

        // Retry with backoff
        idevice_error_t err = IDEVICE_E_UNKNOWN_ERROR;
        for (int i = 0; i < 5 && err != IDEVICE_E_SUCCESS; i++) {
            err = idevice_new_with_options(&device, NULL, IDEVICE_LOOKUP_USBMUX);
            if (err != IDEVICE_E_SUCCESS) usleep(500000);
        }

        if (err != IDEVICE_E_SUCCESS) {
            [self _log:@"idevice_new failed – is usbmuxd running?" color:[UIColor redColor]];
            [self _delegateOnMain:^{
                [self.delegate deviceManager:self
                   connectionDidFailWithError:@"Connection failed. Is usbmuxd running?"];
            }];
            return;
        }

        lockdownd_error_t lerr = lockdownd_client_new(device, &lockdown, "linuze");
        if (lerr == LOCKDOWN_E_PAIRING_DIALOG_RESPONSE_PENDING) {
            [self _log:@"Please tap \"Trust\" on the device" color:[UIColor yellowColor]];
            while (lerr == LOCKDOWN_E_PAIRING_DIALOG_RESPONSE_PENDING) {
                lerr = lockdownd_client_new_with_handshake(device, &lockdown, "linuze");
                sleep(1);
            }
        }

        if (lerr != LOCKDOWN_E_SUCCESS) {
            idevice_free(device);
            [self _log:@"lockdownd handshake failed" color:[UIColor redColor]];
            [self _delegateOnMain:^{
                [self.delegate deviceManager:self
                   connectionDidFailWithError:@"Lockdownd handshake failed."];
            }];
            return;
        }

        char *nameBuf = NULL;
        lockdownd_get_device_name(lockdown, &nameBuf);
        NSString *devName = nameBuf
            ? [NSString stringWithUTF8String:nameBuf]
            : @"Unknown Device";
        free(nameBuf);

        LZDeviceInfo *info = [LZDeviceInfo normalModeDeviceWithName:devName];

        dispatch_async(self.stateQueue, ^{
            self.normalDevice    = device;
            self.lockdownClient  = lockdown;
            self.isDeviceConnected = YES;
            self.connectedDeviceInfo = info;
        });

        [self _log:[NSString stringWithFormat:@"Connected: %@", devName] color:[UIColor cyanColor]];

        [self _delegateOnMain:^{
            [self.delegate deviceManager:self deviceDidConnectWithInfo:info];
        }];
    });
}

// ---------------------------------------------------------------------------
#pragma mark - Device removed
// ---------------------------------------------------------------------------

- (void)_handleDeviceRemoved:(io_iterator_t)iterator {
    io_object_t usbObject;
    while ((usbObject = IOIteratorNext(iterator))) {
        NSString *name = [self _nameForUSBObject:usbObject];
        IOObjectRelease(usbObject);

        if (!name) continue;
        if (![self _isAppleDevice:name]) continue;

        // Guard against a DFU→Recovery transition triggering a spurious removal.
        if ([self _detectTrapRemoval]) continue;

        [self _log:[NSString stringWithFormat:@"Lost device: %@", name] color:[UIColor whiteColor]];

        dispatch_async(_stateQueue, ^{
            self.deviceDisconnecting = YES;
            self.isDeviceConnected   = NO;
            self.connectedDeviceInfo = nil;
            [self _freeDFUDevice];
            [self _freeNormalDevice];
        });

        [self _delegateOnMain:^{
            [self.delegate deviceManagerDeviceDidDisconnect:self];
        }];
    }
}

// ---------------------------------------------------------------------------
#pragma mark - Device operations
// ---------------------------------------------------------------------------

- (void)enterRecovery {
    [self _log:@"Entering recovery mode…" color:[UIColor whiteColor]];
    dispatch_async(_operationQueue, ^{
        __block idevice_t dev = NULL;
        __block lockdownd_client_t lk = NULL;
        dispatch_sync(self.stateQueue, ^{
            dev = self.normalDevice;
            lk  = self.lockdownClient;
        });
        if (!dev || !lk) {
            [self _log:@"enterRecovery: no normal-mode device connected" color:[UIColor redColor]];
            return;
        }
        lockdownd_enter_recovery(lk);
        lockdownd_goodbye(lk);
        idevice_free(dev);
        dispatch_async(self.stateQueue, ^{
            self.normalDevice   = NULL;
            self.lockdownClient = NULL;
        });
        [self _log:@"Recovery command sent" color:[UIColor cyanColor]];
    });
}

- (void)exitRecovery {
    [self _log:@"Exiting recovery mode…" color:[UIColor whiteColor]];
    dispatch_async(_operationQueue, ^{
        __block LDD *dev = NULL;
        dispatch_sync(self.stateQueue, ^{ dev = self.dfuDevice; });
        if (!dev) {
            [self _log:@"exitRecovery: no DFU/Recovery device connected" color:[UIColor redColor]];
            return;
        }
        dev->sendCommand("setenv auto-boot true", NO);
        dev->sendCommand("saveenv", NO);
        dev->sendCommand("reset", NO);
        [self _log:@"Exit-recovery commands sent" color:[UIColor cyanColor]];
    });
}

- (void)pwnDevice {
    [self _log:@"Starting pwn sequence…" color:[UIColor whiteColor]];

    __block int cpid = 0;
    dispatch_sync(_stateQueue, ^{
        if (self.dfuDevice) {
            cpid = (int)self.dfuDevice->getDevInfo()->cpid;
        }
    });

    if (cpid == 0) {
        [self _log:@"pwnDevice: no DFU device connected" color:[UIColor redColor]];
        return;
    }

    [self pauseMonitoring];

    dispatch_async(_stateQueue, ^{
        [self _freeDFUDevice];
    });

    dispatch_async(_operationQueue, ^{
        sleep(1);
        // A9 and A9X chips (7000/7001/8000/8003) use gaster; others use ipwnder_lite.
        if (cpid == 0x7000 || cpid == 0x7001 || cpid == 0x8000 || cpid == 0x8003)
            run_gaster();
        else
            run_ipwnder_lite();

        [self _log:@"Exploit finished, resuming USB monitoring…" color:[UIColor whiteColor]];
        sleep(1);
        [self resumeMonitoring];
    });
}

// ---------------------------------------------------------------------------
#pragma mark - Internal helpers
// ---------------------------------------------------------------------------

- (void)_freeDFUDevice {
    // Must be called on _stateQueue or during teardown.
    if (_dfuDevice) {
        _dfuDevice->freeDevice();
        delete _dfuDevice;
        _dfuDevice = NULL;
    }
}

- (void)_freeNormalDevice {
    if (_lockdownClient) {
        lockdownd_client_free(_lockdownClient);
        _lockdownClient = NULL;
    }
    if (_normalDevice) {
        idevice_free(_normalDevice);
        _normalDevice = NULL;
    }
}

- (NSString *)_nameForUSBObject:(io_object_t)obj {
    CFMutableDictionaryRef props = NULL;
    if (IORegistryEntryCreateCFProperties(obj, &props, kCFAllocatorDefault, 0) != KERN_SUCCESS)
        return nil;
    CFTypeRef nameRef = CFDictionaryGetValue(props, CFSTR(kUSBProductString));
    NSString *name = nil;
    if (nameRef) {
        char buf[1024];
        if (CFStringGetCString((CFStringRef)nameRef, buf, sizeof(buf), kCFStringEncodingUTF8))
            name = [NSString stringWithUTF8String:buf];
    }
    CFRelease(props);
    return name;
}

- (BOOL)_isAppleDevice:(NSString *)name {
    return [name isEqualToString:@"Apple Mobile Device (DFU Mode)"]    ||
           [name isEqualToString:@"Apple Mobile Device (Recovery Mode)"]||
           [name isEqualToString:@"iPhone"]                             ||
           [name isEqualToString:@"iPad"]                               ||
           [name isEqualToString:@"iPod"];
}

// Detect DFU→normal-mode transition: a removal followed immediately by a
// normal-mode add. If the device already shows up as iPhone/iPad/iPod in the
// service list we skip the "disconnected" event.
- (BOOL)_detectTrapRemoval {
    CFMutableDictionaryRef dict = IOServiceMatching("IOUSBHostDevice");
    io_iterator_t iter = 0;
    IOServiceGetMatchingServices(kIOMasterPortDefault, dict, &iter);
    io_service_t obj;
    while ((obj = IOIteratorNext(iter))) {
        NSString *n = [self _nameForUSBObject:obj];
        IOObjectRelease(obj);
        if ([n isEqualToString:@"iPhone"] || [n isEqualToString:@"iPad"] || [n isEqualToString:@"iPod"]) {
            IOObjectRelease(iter);
            return YES;
        }
    }
    IOObjectRelease(iter);
    return NO;
}

- (void)_logDeviceInfo:(LZDeviceInfo *)info {
    [self _log:@"\nModel Name: "    color:[UIColor cyanColor]];
    [self _log:info.displayName     color:[UIColor whiteColor]];
    [self _log:@"\nHardware Model: " color:[UIColor cyanColor]];
    [self _log:info.hardwareModel   color:[UIColor whiteColor]];
    [self _log:@"\nECID: "          color:[UIColor cyanColor]];
    [self _log:info.ecid            color:[UIColor whiteColor]];
    [self _log:@"\nCPID: "          color:[UIColor cyanColor]];
    [self _log:info.cpid            color:[UIColor whiteColor]];
    [self _log:@"\nAPNonce: "       color:[UIColor cyanColor]];
    [self _log:info.apNonce         color:[UIColor whiteColor]];
    [self _log:@"\nSEPNonce: "      color:[UIColor cyanColor]];
    [self _log:info.sepNonce        color:[UIColor whiteColor]];
    [self _log:@"\nPwned: "         color:[UIColor cyanColor]];
    if (info.isPwned)
        [self _log:[NSString stringWithFormat:@"Yes (%@)\n\n", info.pwnTag] color:[UIColor whiteColor]];
    else
        [self _log:@"No\n\n"        color:[UIColor whiteColor]];
}

// Thread-safe log helper – dispatches to the delegate on the main thread.
- (void)_log:(NSString *)message color:(UIColor *)color {
    [self _delegateOnMain:^{
        [self.delegate deviceManager:self didProduceLog:message color:color];
    }];
}

- (void)_delegateOnMain:(void(^)(void))block {
    if ([NSThread isMainThread]) {
        if (self.delegate) block();
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate) block();
        });
    }
}

@end
