//
//  Copyright © 2019年 Vizlab. All rights reserved.
//

#import "CameraHelper.h"

void g_releaseCVPixelBuffer(void * CV_NULLABLE releaseRefCon, const void * CV_NULLABLE baseAddress){
    if(releaseRefCon == baseAddress){
        free(releaseRefCon);
    }
}
void g_dataProviderReleaseCallback(void * __nullable info, const void *  data, size_t size){
    if(data){
        free((void* )data);
    }
}
