//
//  Copyright © 2019年 Vizlab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, CameraSetupResult) {
    CameraSetupSucceed,
    CameraSetupFailed,
    CameraSetupNotAuthorized
};

@protocol CameraSeesion <NSObject>
- (void)cameraDidReceivePixelBuffer:(NSData*) pixels sampleImage:(UIImage* _Nullable)image;
- (void)cameraPermissionDenied;
- (void)cameraSetupFailed;
- (void)cameraSessionWasInterrupted;
@end

@interface CameraSessionManager : NSObject

@property(nonatomic,assign, readonly) CGSize cameraResulotion;
@property(nonatomic,assign, readonly) NSTimeInterval prepareBuffer;
@property(nonatomic,assign, readonly) CameraSetupResult cameraSetupResult;
@property(nonatomic,strong, readonly) AVCaptureSession* session;
@property(nonatomic,assign, readonly) BOOL isSessionRunning;
@property(nonatomic,weak) id<CameraSeesion> delegate;
@property(nonatomic,assign) BOOL generateSampleImage;

- (void)startSession;
- (void)stopSession;

@end

NS_ASSUME_NONNULL_END
