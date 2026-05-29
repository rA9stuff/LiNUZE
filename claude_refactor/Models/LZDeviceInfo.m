// LZDeviceInfo.m

#import "LZDeviceInfo.h"

@implementation LZDeviceInfo

- (instancetype)initWithDisplayName:(NSString *)displayName
                      hardwareModel:(NSString *)hardwareModel
                        productType:(NSString *)productType
                               ecid:(NSString *)ecid
                               cpid:(NSString *)cpid
                            apNonce:(NSString *)apNonce
                           sepNonce:(NSString *)sepNonce
                             pwnTag:(NSString *)pwnTag
                           isPwned:(BOOL)isPwned
                     connectionMode:(LZDeviceConnectionMode)connectionMode {
    self = [super init];
    if (self) {
        _displayName    = [displayName copy];
        _hardwareModel  = [hardwareModel copy];
        _productType    = [productType copy];
        _ecid           = [ecid copy];
        _cpid           = [cpid copy];
        _apNonce        = [apNonce copy];
        _sepNonce       = [sepNonce copy];
        _pwnTag         = [pwnTag copy];
        _isPwned        = isPwned;
        _connectionMode = connectionMode;
    }
    return self;
}

+ (instancetype)normalModeDeviceWithName:(NSString *)name {
    return [[self alloc] initWithDisplayName:name
                               hardwareModel:@""
                                 productType:@""
                                        ecid:@""
                                        cpid:@""
                                     apNonce:@""
                                    sepNonce:@""
                                      pwnTag:nil
                                    isPwned:NO
                              connectionMode:LZDeviceConnectionModeNormal];
}

- (NSString *)connectionModeDisplayString {
    switch (_connectionMode) {
        case LZDeviceConnectionModeDFU:      return @"DFU";
        case LZDeviceConnectionModeRecovery: return @"Recovery";
        case LZDeviceConnectionModeNormal:   return @"Normal";
        case LZDeviceConnectionModeWTF:      return @"WTF";
        default:                             return @"Unknown";
    }
}

- (id)copyWithZone:(NSZone *)zone {
    // Immutable; safe to return self.
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<LZDeviceInfo: %@ [%@] ECID=%@ pwned=%@>",
            _displayName, [self connectionModeDisplayString], _ecid, _isPwned ? @"YES" : @"NO"];
}

@end
