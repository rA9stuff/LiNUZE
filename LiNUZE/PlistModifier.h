//
//  PlistModifier.h
//  LeetDown
//
//  Created by rA9stuff on 3.02.2022.
//

#ifndef PlistModifier_h
#define PlistModifier_h

#include <iostream>
#import <Foundation/Foundation.h>


class PlistModifier {
       
public:
    void modifyPref(NSString* key, NSString* val);
    NSString* getPref(NSString* key);
};


#endif /* PlistModifier_h */
