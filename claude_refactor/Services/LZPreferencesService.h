// LZPreferencesService.h – Singleton that owns all app preferences.
// Replaces the C++ PlistModifier class: no manual malloc/free,
// no static C++ methods, no mixed memory management.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LZPreferencesService : NSObject

+ (instancetype)sharedService;

- (BOOL)boolForKey:(NSString *)key;
- (void)setBool:(BOOL)value forKey:(NSString *)key;

- (nullable NSString *)stringForKey:(NSString *)key;
- (void)setString:(NSString *)value forKey:(NSString *)key;

// Typed convenience properties for the keys the app actually uses.
@property (nonatomic) BOOL devConsoleEnabled;
@property (nonatomic) BOOL hasLanded;
@property (nonatomic, nullable) NSString *nightlyHash;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
