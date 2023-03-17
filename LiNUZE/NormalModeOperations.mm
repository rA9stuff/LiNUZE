//
//  NormalModeOperations.m
//  LiNUZE
//
//  Created by rA9stuff on 26.02.2023.
//  Copyright © 2023 rA9stuff. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "NormalModeOperations.h"

int tryNormalModeConnection(int tries) {
    
    idevice_t deviceNormal = NULL;
    const char* udid = NULL;
    int use_network = 0;
    for (int i = 0; i < tries; i++) {
        if (idevice_new_with_options(&deviceNormal, udid, (use_network) ? IDEVICE_LOOKUP_NETWORK : IDEVICE_LOOKUP_USBMUX) != IDEVICE_E_SUCCESS)
            return -1;
        usleep(500000);
    }
    idevice_free(deviceNormal);
    return 0;
}

int openNormalModeConnection(idevice_t* devptr, int tries) {
    
    const char* udid = NULL;
    int use_network = 0;
    idevice_error_t err;
    for (int i = 0; i < tries; i++) {
        err = idevice_new_with_options(devptr, udid, (use_network) ? IDEVICE_LOOKUP_NETWORK : IDEVICE_LOOKUP_USBMUX);
        if (err == IDEVICE_E_SUCCESS)
            return 0;
        usleep(500000);
    }
    return -1;
}

NSString* getDeviceName(idevice_t* device, lockdownd_client_t* lockdown) {
    char* name = NULL;
    __block NSString* formattedName;
    lockdownd_error_t err = lockdownd_client_new(*device, lockdown, "dingus");
    
    if (err != LOCKDOWN_E_SUCCESS)
        return @"err";
        
    err = lockdownd_client_new_with_handshake(*device, lockdown, "dingus");
    
    if (err == LOCKDOWN_E_PAIRING_DIALOG_RESPONSE_PENDING) {
        return @"err_pair";
    }
    
    lockdownd_get_device_name(*lockdown, &name);
    @try {
        formattedName = [NSString stringWithUTF8String:name];
    }
    @catch (...) {
        formattedName = @"an unknown device";
    }
    @finally {
        return formattedName;
    }
}

