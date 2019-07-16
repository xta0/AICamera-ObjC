//
//  Copyright © 2019年 Vizlab. All rights reserved.
//

#ifndef CameraHelper_h
#define CameraHelper_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreImage/CoreImage.h>
#include <memory>

void g_cvPixelBufferReleaseCallback(void * __nullable releaseRefCon, const void * __nullable baseAddress);
void g_dataProviderReleaseCallback(void * __nullable info, const void * __nullable  data, size_t size);
void g_callocReleaseCallback(void* __nullable p);

static inline CGSize getCameraResolution(CVPixelBufferRef _Nonnull pixelBuffer){
    static dispatch_once_t onceToken;
    static size_t width = 0;
    static size_t height = 0;
    dispatch_once(&onceToken, ^{
        width = CVPixelBufferGetWidth(pixelBuffer);
        height = CVPixelBufferGetHeight(pixelBuffer);
    });
    return (CGSize){(CGFloat)width,(CGFloat)height};
}

static inline CVPixelBufferRef _Nullable createPixelBufferForTensor(CVPixelBufferRef _Nonnull pixelBuffer ,size_t width, size_t height) {
    size_t imageWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t imageHeight = CVPixelBufferGetHeight(pixelBuffer);
    NSCAssert(CVPixelBufferGetPixelFormatType(pixelBuffer) == kCMPixelFormat_32BGRA, @"Pixel buffer is in wrong format");
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    size_t bytesPerPixel = 4;
    size_t croppedImageSize = MIN(imageWidth, imageHeight);
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    NSUInteger originX = 0;
    NSUInteger originY = 0;
    if(imageWidth > imageHeight){
        originX = (imageWidth - imageHeight) / 2;
    } else {
        originY = (imageHeight - imageWidth) / 2;
    }
    void* baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    NSUInteger startpos = originY * bytesPerRow + originX*bytesPerPixel;
    vImage_Buffer inBuff = { (uint8_t* )baseAddress + startpos, croppedImageSize, croppedImageSize, bytesPerRow };
    uint8_t *dstData = (uint8_t*)calloc(width*height*bytesPerPixel, sizeof(uint8_t)); //will be freed by g_cvPixelBufferReleaseCallback
    vImage_Buffer outBuff = {dstData, width, height, bytesPerPixel*width};
    vImage_Error err = vImageScale_ARGB8888(&inBuff, &outBuff, NULL, 0);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    if (err != kvImageNoError) {
        free(dstData);
        return nil;
    }
    CVPixelBufferRef dstPixelBuffer;
    OSType pixelType = CVPixelBufferGetPixelFormatType(pixelBuffer);
    CVReturn status = CVPixelBufferCreateWithBytes(nil, width, height,
                                 pixelType,
                                 dstData,
                                 width*4,
                                 g_cvPixelBufferReleaseCallback, nil, nil,
                                 &dstPixelBuffer);
    
    if(status != kCVReturnSuccess){
        free(dstData);
        return nil;
    }
    return dstPixelBuffer;
}

//static inline uint8_t* _Nullable tensorData(CVPixelBufferRef _Nonnull pixelBuff, int w, int h) {
//    CVPixelBufferLockBaseAddress(pixelBuff,kCVPixelBufferLock_ReadOnly);
//    uint8_t* srcData = (uint8_t* )CVPixelBufferGetBaseAddress(pixelBuff);
//    auto dstData = (uint8_t* )calloc(w*h*3,sizeof(uint8_t));
//    if(dstData){
//        for(int i=0;i<w*h;++i){
//            //remove alpha channel
//            dstData[i*3+0] = srcData[i*4+2]; //R
//            dstData[i*3+1] = srcData[i*4+1]; //G
//            dstData[i*3+2] = srcData[i*4+0]; //B
//        }
//    }
//    CVPixelBufferUnlockBaseAddress(pixelBuff,kCVPixelBufferLock_ReadOnly);
//    return dstData;
//}
static inline std::shared_ptr<uint8_t> tensorData(CVPixelBufferRef _Nonnull pixelBuff, int w, int h) {
    CVPixelBufferLockBaseAddress(pixelBuff,kCVPixelBufferLock_ReadOnly);
    uint8_t* srcData = (uint8_t* )CVPixelBufferGetBaseAddress(pixelBuff);
    std::shared_ptr<uint8_t> dstData((uint8_t* )calloc(w*h*3,sizeof(uint8_t)),g_callocReleaseCallback);
    if(dstData){
        for(int i=0;i<w*h;++i){
            //remove alpha channel
            dstData.get()[i*3+0] = srcData[i*4+2]; //R
            dstData.get()[i*3+1] = srcData[i*4+1]; //G
            dstData.get()[i*3+2] = srcData[i*4+0]; //B
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuff,kCVPixelBufferLock_ReadOnly);
    return dstData;
}

static inline UIImage* _Nullable rgbImage(CVPixelBufferRef _Nonnull pixelBuff, size_t w, size_t h){
    CVPixelBufferLockBaseAddress(pixelBuff,kCVPixelBufferLock_ReadOnly);
    CIImage* ciImage = [CIImage imageWithCVPixelBuffer:pixelBuff];
    CIContext* ciContext = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [ciContext createCGImage:ciImage fromRect:(CGRect){0,0,(CGFloat)w,(CGFloat)h}];
    UIImage* image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CVPixelBufferUnlockBaseAddress(pixelBuff,kCVPixelBufferLock_ReadOnly);
    return image;
}

static inline UIImage* _Nullable rgbImage2(CVPixelBufferRef _Nonnull pixelBuff, size_t w, size_t h){
    CVPixelBufferLockBaseAddress(pixelBuff, kCVPixelBufferLock_ReadOnly);
    uint8_t* dstData = (uint8_t* )calloc(w*h*4, sizeof(uint8_t)); //will be freed by CGDataProviderRef
    uint8_t* srcData = (uint8_t* )CVPixelBufferGetBaseAddress(pixelBuff);
    memcpy(dstData,srcData,w*h*4*sizeof(uint8_t));
    for(int i=0;i<w*h;++i){
        std::swap(dstData[i*4+0],dstData[i*4+2]); //32BGRA -> 32RGBA
    }
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(nil, dstData, w*h*4, g_dataProviderReleaseCallback);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast; //RGBA
    CGImageRef cgImage = CGImageCreate(w, h, 8, 32, w*4, colorSpace, bitmapInfo, dataProvider, NULL, NO, kCGRenderingIntentDefault);
    CVPixelBufferUnlockBaseAddress(pixelBuff,kCVPixelBufferLock_ReadOnly);
    UIImage* image =  [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGDataProviderRelease(dataProvider);
    CVPixelBufferUnlockBaseAddress(pixelBuff,kCVPixelBufferLock_ReadOnly);
    return image;
}

#endif /* CameraHelper_h */
