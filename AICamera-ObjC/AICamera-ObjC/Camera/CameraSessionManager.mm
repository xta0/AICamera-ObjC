//
//  Copyright © 2019年 Vizlab. All rights reserved.
//

#import "CameraSessionManager.h"
#import "CameraHelper.h"
#include <ctime>

#define IMG_W 224
#define IMG_H 224




@interface CameraSessionManager()<AVCaptureVideoDataOutputSampleBufferDelegate>
@end

@implementation CameraSessionManager {
    dispatch_queue_t _sessionQueue;
    dispatch_queue_t _bufferQueue;
    AVCaptureVideoDataOutput* _videoOutput;
}

- (id)init {
    self = [super init];
    if(self){
        _session = [AVCaptureSession new];
        _session.sessionPreset = AVCaptureSessionPreset1920x1080;
        _sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
        _bufferQueue = dispatch_queue_create("buffer queue", DISPATCH_QUEUE_SERIAL);
        
        //request camera access
        [self _requestForCameraAccess];
        
        //configure camera session
        dispatch_async(_sessionQueue, ^{
            [self _configureCameraSession];
        });
    }
    return self;
}

- (void)startSession{
    dispatch_async(_sessionQueue, ^{
        switch (self.cameraSetupResult) {
            case CameraSetupSucceed:{
                [self.session startRunning];
                [self _addObserver];
                self->_isSessionRunning = YES;
                break;
            }
            case CameraSetupNotAuthorized: {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if([self.delegate respondsToSelector:@selector(cameraPermissionDenied)]){
                        [self.delegate cameraPermissionDenied];
                    }
                });
                break;
            }
            case CameraSetupFailed: {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if([self.delegate respondsToSelector:@selector(cameraSetupFailed)]){
                        [self.delegate cameraSetupFailed];
                    }
                });
                break;
            }
            default:
                break;
        }
    });

}

- (void)stopSession{
    [self _removeObserver];
    if(self.session.isRunning) {
        [self.session stopRunning];
    }
    _isSessionRunning = NO;
}

# pragma mark - private API

- (void)_requestForCameraAccess {
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusAuthorized:
            _cameraSetupResult = CameraSetupSucceed;
            break;
        case AVAuthorizationStatusNotDetermined: {
            dispatch_suspend(_sessionQueue);
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if(granted){
                    self->_cameraSetupResult = CameraSetupSucceed;
                }else{
                    self->_cameraSetupResult = CameraSetupNotAuthorized;
                }
                dispatch_resume(self->_sessionQueue);
            }];
            break;
        }
        case AVAuthorizationStatusDenied: {
            _cameraSetupResult = CameraSetupNotAuthorized;
            break;
        }
        default:
            break;
    }
}

- (void)_configureCameraSession {
    
    if(self.cameraSetupResult != CameraSetupSucceed){
        return;
    }
    [self.session beginConfiguration];
    
    //add camera input/output
    if(![self _configCameraInput] || ![self _configCameraOutput]) {
        _cameraSetupResult = CameraSetupFailed;
    } else {
        _cameraSetupResult = CameraSetupSucceed;
    }
    [self.session commitConfiguration];
}

- (BOOL)_configCameraInput {
    id videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                   mediaType:AVMediaTypeVideo
                                                    position:AVCaptureDevicePositionBack];
    NSAssert(videoDevice, @"camera is not available");
    NSError* error;
    AVCaptureDeviceInput* videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if(!error) {
        if([self.session canAddInput:videoDeviceInput]){
            [self.session addInput:videoDeviceInput];
            return YES;
        }
    }
    return NO;
}

- (BOOL)_configCameraOutput {
    
    _videoOutput = [AVCaptureVideoDataOutput new];
    [_videoOutput setSampleBufferDelegate:self queue:_bufferQueue];
    _videoOutput.alwaysDiscardsLateVideoFrames = YES;
    _videoOutput.videoSettings = @{(NSString* )kCVPixelBufferPixelFormatTypeKey: @(kCMPixelFormat_32BGRA)};
    if([self.session canAddOutput:_videoOutput]){
        [self.session addOutput:_videoOutput];
        return YES;
    }
    return NO;
}

- (void)_addObserver {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionWasInterrupted: ) name:AVCaptureSessionWasInterruptedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruptionEnded: ) name:AVCaptureSessionInterruptionEndedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self.session];
}

- (void)_removeObserver {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


# pragma mark - callback

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    CVPixelBufferRef pixelBuffer =  CMSampleBufferGetImageBuffer(sampleBuffer);
    if(pixelBuffer) {
        _cameraResulotion = cameraResolution(pixelBuffer);
        std::clock_t start;
        start = std::clock();
        CVPixelBufferRef croppedBuffer = resizePixelBuffer(pixelBuffer, IMG_W, IMG_H);
        auto data = normalizedBuffer(croppedBuffer, IMG_W, IMG_H);
        UIImage* sampleImage = nil;
        if(self.generateSampleImage){
            sampleImage = rgbImage2(croppedBuffer,IMG_W,IMG_H);
        }
        CVPixelBufferRelease(croppedBuffer);
        _prepareBuffer = ( std::clock() - start ) / (double) CLOCKS_PER_SEC;
        if(data){
            if([self.delegate respondsToSelector:@selector(cameraDidReceivePixelBuffer:sampleImage:)]){
                [self.delegate cameraDidReceivePixelBuffer:data sampleImage:sampleImage];
            }
        }
    }
}

# pragma mark - notificaiton callback

- (void)sessionWasInterrupted:(NSNotification* )notification {
    AVCaptureSessionInterruptionReason reason = (AVCaptureSessionInterruptionReason)[notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
    if(reason == AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient) {
        if([self.delegate respondsToSelector:@selector(cameraSessionWasInterrupted)]){
            [self.delegate cameraSessionWasInterrupted];
        }
    }
    
}
- (void)sessionInterruptionEnded:(NSNotification* )notification {
        //noop
}
- (void) sessionRuntimeError:(NSNotification*)notification
{
    NSError* error = notification.userInfo[AVCaptureSessionErrorKey];
    NSLog(@"Capture session runtime error: %@", error);
    
    // If media services were reset, and the last start succeeded, restart the session.
    if (error.code == AVErrorMediaServicesWereReset) {
        dispatch_async(self->_sessionQueue, ^{
            if (self.isSessionRunning) {
                [self.session startRunning];
            }
        });
    }
}

@end
