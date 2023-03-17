//
//  PlistModifier.m
//  LeetDown
//
//  Created by rA9stuff on 1.02.2022.
//


#include "PlistModifier.h"


void PlistModifier::modifyPref(NSString* key, NSString* val) {
    
    NSString* preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LiNUZPrefs.plist"];
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] initWithContentsOfFile:preferencePlist];
    [dict setValue:val forKey: key];
    [dict writeToFile:preferencePlist atomically:YES];
    
}

NSString* PlistModifier::getPref(NSString* key) {
    
    NSString *preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/LiNUZPrefs.plist"];
    NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
    return dict[key];
}
