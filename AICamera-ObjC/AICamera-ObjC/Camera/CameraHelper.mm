//
//  Copyright © 2019年 Vizlab. All rights reserved.
//

#import "CameraHelper.h"

void g_cvPixelBufferReleaseCallback(void * __nullable releaseRefCon, const void * __nullable baseAddress){
    if(baseAddress){
        free((void* )baseAddress);
    }
}
void g_dataProviderReleaseCallback(void * __nullable info, const void *  data, size_t size){
    
    if(data){
        free((void* )data);
    }
}
void g_callocReleaseCallback(void* p){
    if(p) {
        free(p);
    }
}
