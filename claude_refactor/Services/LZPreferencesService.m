// LZPreferencesService.m

#import "LZPreferencesService.h"

static NSString * const kPlistFileName = @"LiNUZEPrefs.plist";

static NSString * const kKeyDevConsole = @"DevConsoleEnabled";
static NSString * const kKeyLanded     = @"Landed";
static NSString * const kKeyNightly    = @"nightlyHash";

@interface LZPreferencesService ()
@property (nonatomic, copy) NSString *plistPath;
@end

@implementation LZPreferencesService

+ (instancetype)sharedService {
    static LZPreferencesService *instance;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        instance = [[self alloc] _init];
    });
    return instance;
}

- (instancetype)_init {
    self = [super init];
    if (self) {
        _plistPath = [[[NSBundle mainBundle] resourcePath]
                      stringByAppendingPathComponent:kPlistFileName];
    }
    return self;
}

- (NSMutableDictionary *)_loadDict {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:self.plistPath];
    return dict ?: [NSMutableDictionary dictionary];
}

- (void)_saveDict:(NSDictionary *)dict {
    [dict writeToFile:self.plistPath atomically:YES];
}

- (nullable NSString *)stringForKey:(NSString *)key {
    return [self _loadDict][key];
}

- (void)setString:(NSString *)value forKey:(NSString *)key {
    NSMutableDictionary *dict = [self _loadDict];
    dict[key] = value;
    [self _saveDict:dict];
}

- (BOOL)boolForKey:(NSString *)key {
    return [[self stringForKey:key] isEqualToString:@"1"];
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
    [self setString:(value ? @"1" : @"0") forKey:key];
}

#pragma mark - Typed properties

- (BOOL)devConsoleEnabled           { return [self boolForKey:kKeyDevConsole]; }
- (void)setDevConsoleEnabled:(BOOL)v { [self setBool:v forKey:kKeyDevConsole]; }

- (BOOL)hasLanded                   { return [self boolForKey:kKeyLanded]; }
- (void)setHasLanded:(BOOL)v        { [self setBool:v forKey:kKeyLanded]; }

- (nullable NSString *)nightlyHash  { return [self stringForKey:kKeyNightly]; }
- (void)setNightlyHash:(NSString *)v { [self setString:v forKey:kKeyNightly]; }

@end
