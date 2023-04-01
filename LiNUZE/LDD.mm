//
//  LDD.cpp
//  LiNUZ
//
//  Created by rA9stuff on 26.01.2022.
//

#include "LDD.h"
#include <Foundation/Foundation.h>
#import "LiNUZE_VC.h"

extern bool deadDevice;

using namespace std;

int LDD::openConnection(int tries) {
    
    for (int i = 0; i < tries; i++) {
        if (deadDevice)
            return -1;
        printf("[%s]: attempting to connect %i/%i\n", __func__, i+1, tries);
        client = NULL;
        irecv_error_t error = irecv_open_with_ecid(&client, initECID);
        if (error == IRECV_E_SUCCESS) {
            printf("[%s]: connected %i/%i\n", __func__, i+1, tries);
            setAllDeviceInfo();
            return 0;
        }
        usleep(500000);
    }
    return -1;
}

int LDD::checkConnection() {
    
    if (client != NULL) {
        printf("[%s]: [!] Device [%p] is occupied, freeing pointer\n", __func__, *&client);
        this -> freeDevice();
        printf("[%s]: [!] Address freed: [%p]\n", __func__, *&client);
    }
    sleep(1);
    irecv_error_t err = irecv_open_with_ecid(&client, 0);
    
    if (err == IRECV_E_SUCCESS) {
        return 0;
    }
    return -1;
}

int LDD::sendFile(const char* filename, bool withReconnect) {

    if (withReconnect) {
        printf("[%s]: [!] reconnect requested, freeing pointer and calling openConnection()\n", __func__);
        this -> freeDevice();
        usleep(500000);
        if (this -> openConnection(5) != 0) {
            printf("[%s]: error connecting to device, stopping here\n", __func__);
            return -1;
        }
        usleep(500000);
        this -> setAllDeviceInfo();
        usleep(500000);
    }
    usleep(500000);
    irecv_error_t stat = irecv_send_file(this -> client, filename, 1);
    usleep(500000);
    
    if (stat == IRECV_E_SUCCESS)
        return 0;
    else if (stat == IRECV_E_USB_UPLOAD && strcmp(filename, "/dev/null") == 0)
        return 0;
    else
        return -1;
    return -1;
}

int LDD::sendCommand(const char *cmd, bool withReconnect) {
    
    if (withReconnect) {
        printf("[%s]: [!] reconnect requested, freeing pointer and calling openConnection()\n", __func__);
        this -> freeDevice();
        usleep(500000);
        if (this -> openConnection(5) != 0) {
            printf("[%s]: error connecting to device, stopping here\n", __func__);
            return -1;
        }
    }
    
    irecv_error_t stat = irecv_send_command(this -> client, cmd);
    if (stat == IRECV_E_SUCCESS)
        return 0;
    return -1;
}

void LDD::setAllDeviceInfo() {
    
    irecv_devices_get_device_by_client(client, &device);
    this -> displayName = device -> display_name;
    this -> hardwareModel = device -> hardware_model;
    this -> productType = device -> product_type;
    this -> devinfo = irecv_get_device_info(this -> client);
    
}

void LDD::freeDevice() {
    
    irecv_close(this -> client);
    
    this -> client = NULL;
    this -> device = NULL;
    this -> initECID = 0;
}

const char* LDD::getDeviceMode() {
    int ret, mode;
    ret = irecv_get_mode(client, &mode);
    switch (mode) {
        case IRECV_K_RECOVERY_MODE_1:
        case IRECV_K_RECOVERY_MODE_2:
        case IRECV_K_RECOVERY_MODE_3:
        case IRECV_K_RECOVERY_MODE_4:
            return "Recovery";
            break;
        case IRECV_K_DFU_MODE:
            return "DFU";
            break;
        case IRECV_K_WTF_MODE:
            return "WTF";
            break;
        default:
            return "Unknown";
            break;
    }
}

bool LDD::deviceConnected() {
    
    irecv_error_t error = irecv_open_with_ecid(&client, initECID);
    if (error == IRECV_E_SUCCESS) {
        irecv_close(client);
        return true;
    }
    return false;
}

bool LDD::checkPwn() {
    
    if (this -> client == NULL) {
        if (this -> openConnection(5) != 0)  // we need to take over the device after iPwnder completes.
            return false;
        this -> setAllDeviceInfo();
    }
    string pwnstr = this -> devinfo -> serial_string;
    if (pwnstr.find("PWND") != string::npos) {
        // update pwnd string
        NSString *pwnd_str = [NSString stringWithUTF8String: getDevInfo()->serial_string];
        NSRange pwndRange = [pwnd_str rangeOfString:@"PWND:["];
        NSRange closingBracketRange = [pwnd_str rangeOfString:@"]" options:0 range:NSMakeRange(pwndRange.location + pwndRange.length, pwnd_str.length - pwndRange.location - pwndRange.length)];
        NSString *pwndValue = [pwnd_str substringWithRange:NSMakeRange(pwndRange.location + pwndRange.length, closingBracketRange.location - pwndRange.location - pwndRange.length)];
        pwndStr = pwndValue.UTF8String;
        return true;
    }
    return false;
}
