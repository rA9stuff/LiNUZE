// LZTypes.h – Shared enums and constants for the LiNUZE refactor.

#ifndef LZTypes_h
#define LZTypes_h

typedef NS_ENUM(NSInteger, LZDeviceConnectionMode) {
    LZDeviceConnectionModeNone,
    LZDeviceConnectionModeDFU,
    LZDeviceConnectionModeRecovery,
    LZDeviceConnectionModeNormal,
    LZDeviceConnectionModeWTF
};

typedef NS_ENUM(NSInteger, LZMainViewState) {
    LZMainViewStateIdle,        // No device connected
    LZMainViewStateConnecting,  // Handshaking with a detected device
    LZMainViewStateConnected,   // Device ready, buttons active
    LZMainViewStateOperating,   // Operation (pwn, recovery, …) in flight
    LZMainViewStateError        // Last operation failed; shows error status
};

#endif /* LZTypes_h */
