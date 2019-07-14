//
//  Copyright © 2019年 Vizlab. All rights reserved.
//

#import "CameraHelper.h"

void releaseCVPixelBuffer(void * CV_NULLABLE releaseRefCon, const void * CV_NULLABLE baseAddress){
    if(releaseRefCon == baseAddress){
        free(releaseRefCon);
    }
}
