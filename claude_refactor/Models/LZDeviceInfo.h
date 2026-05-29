// LZDeviceInfo.h – Immutable value object describing a connected iOS device.
// Built by LZDeviceManager and handed to consumers; never holds raw C pointers.

#import <Foundation/Foundation.h>
#import "LZTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface LZDeviceInfo : NSObject <NSCopying>

@property (nonatomic, copy, readonly) NSString *displayName;
@property (nonatomic, copy, readonly) NSString *hardwareModel;
@property (nonatomic, copy, readonly) NSString *productType;
@property (nonatomic, copy, readonly) NSString *ecid;
@property (nonatomic, copy, readonly) NSString *cpid;
@property (nonatomic, copy, readonly) NSString *apNonce;
@property (nonatomic, copy, readonly) NSString *sepNonce;
@property (nonatomic, copy, readonly, nullable) NSString *pwnTag;
@property (nonatomic, readonly) BOOL isPwned;
@property (nonatomic, readonly) LZDeviceConnectionMode connectionMode;

// Designated initialiser. Pass nil for optional fields.
- (instancetype)initWithDisplayName:(NSString *)displayName
                      hardwareModel:(NSString *)hardwareModel
                        productType:(NSString *)productType
                               ecid:(NSString *)ecid
                               cpid:(NSString *)cpid
                            apNonce:(NSString *)apNonce
                           sepNonce:(NSString *)sepNonce
                             pwnTag:(nullable NSString *)pwnTag
                           isPwned:(BOOL)isPwned
                     connectionMode:(LZDeviceConnectionMode)connectionMode NS_DESIGNATED_INITIALIZER;

// Convenience initialiser for normal-mode devices (no libirecovery info).
+ (instancetype)normalModeDeviceWithName:(NSString *)name;

- (NSString *)connectionModeDisplayString;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
