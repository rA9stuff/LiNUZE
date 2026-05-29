# claude_refactor – Architecture Notes

Full MVVM + Service Layer refactor of the original LiNUZE codebase.

---

## Directory layout

```
claude_refactor/
├── Models/
│   ├── LZTypes.h               – Shared enums (LZDeviceConnectionMode, LZMainViewState)
│   ├── LZDeviceInfo.h/.m       – Immutable value object for a connected device
├── Protocols/
│   └── LZDeviceManagerDelegate.h – Event contract between LZDeviceManager and its owner
├── Services/
│   ├── LZPreferencesService.h/.m  – Singleton plist wrapper (replaces PlistModifier)
│   ├── LZDeviceManager.h/.mm      – USB monitoring + device operations (replaces USBUtils + globals)
├── ViewModels/
│   ├── LZMainViewModel.h/.mm      – State for the main screen
│   ├── LZLandingViewModel.h/.m    – State for the onboarding screen
└── ViewControllers/
    ├── LZMainViewController.h/.mm – Main UI, observes ViewModel via NSNotification
    └── LZLandingViewController.h/.m – Onboarding UI
```

---

## Problems fixed and how

### 1. Global variables (18 globals removed)
**Before:** `ViewController* ipad_vc`, `LDD* maindevptr`, `NSMutableAttributedString* fulllogtext`, etc.  
**After:** All state lives in `LZDeviceManager` (device pointers, disconnect flag) and `LZMainViewModel`
(log text, UI state). No file-scope variables.

### 2. ViewControllers passed as method parameters
**Before:** `- (void)startMonitoringUSBDevices:(UIViewController *)viewController ...`  
**After:** `LZDeviceManager` communicates upward only through `LZDeviceManagerDelegate`. The VC is
never touched by the service layer.

### 3. Double-pointer parameters (`LDD**`, `idevice_t**`)
**Before:** `[usbVC startMonitoringUSBDevices:self maindevptr:&maindevptr ...]`  
**After:** `LZDeviceManager` owns the device pointers internally. Callers never touch raw pointers.

### 4. C++ PlistModifier allocated with malloc
**Before:** `PlistModifier* p = (PlistModifier*)malloc(sizeof(PlistModifier))` – constructor never
called, leaks in several places.  
**After:** `LZPreferencesService` is an Objective-C singleton. ARC manages its lifetime. No manual
memory management.

### 5. `deadDevice` global bool racing across threads
**Before:** `extern bool deadDevice` read inside `LDD::openConnection()` from a different thread.  
**After:** `LZDeviceManager._deviceDisconnecting` is written on `_stateQueue` (serial) before
cancelling any in-flight connection attempts.

### 6. `[[NSRunLoop currentRunLoop] run]` blocking the calling thread forever
**Before:** `startMonitoringUSBDevices:` called `[[NSRunLoop currentRunLoop] run]`, permanently
blocking whichever thread called it.  
**After:** `LZDeviceManager` starts a dedicated `NSThread` (`_runMonitorLoop`) whose run loop is
controlled by `CFRunLoopRun()` / `CFRunLoopStop()`. The caller returns immediately.

### 7. Tag-based subview access (`viewWithTag:1`, `:2`, `:3`, `:5`)
**Before:** Magic integer tags scattered across `LiNUZE_VC.mm` and `USBUtils.mm`.  
**After:** Named `IBOutlet` properties on `LZMainViewController` (`deviceImageView`, `statusIconView`,
`statusDetailLabel`, `connectingSpinner`). No magic numbers.

### 8. `NSMutableAttributedString* fulllogtext` mutated from multiple threads
**Before:** Appended from dispatch callbacks on unrelated queues.  
**After:** `LZMainViewModel._appendLog:color:` asserts main thread; all log calls are dispatched to
the main queue before reaching it.

### 9. Memory leaks (C++ `new` without `delete`, malloc without free)
**Before:** `maindevptr = new LDD` – never deleted. Several malloc'd `PlistModifier` instances not
freed.  
**After:** `LZDeviceManager._freeDFUDevice` calls `delete` on the LDD pointer whenever the device
disconnects or monitoring stops. `LZPreferencesService` is ARC-managed.

### 10. Circular reference: method called with `self` as a parameter
**Before:** `[self displayCorrectBasicInterface:... VC:self]`  
**After:** The VC-parameter overload is gone. `LZMainViewController._updateStatusCard` uses `self`
directly.

---

## Threading model

```
Main thread      ──── all UIKit updates, ViewModel property reads, log appends
stateQueue       ──── serial; guards LZDeviceManager's device pointers and flags
operationQueue   ──── serial; runs libirecovery / libimobiledevice calls
monitorThread    ──── runs IOKit CFRunLoop; callbacks marshal to stateQueue then main
```

---

## How to wire up in a new storyboard

1. Set the root VC's class to `LZMainViewController`.
2. Wire all named outlets in Interface Builder.
3. In `AppDelegate -application:didFinishLaunchingWithOptions:`:

```objc
LZMainViewController *main = (LZMainViewController *)self.window.rootViewController;
main.viewModel = [[LZMainViewModel alloc] init];
```

4. Set the onboarding VC's storyboard identifier to `LZLandingVC` and its class to
   `LZLandingViewController`. `LZMainViewController` instantiates and presents it automatically.
