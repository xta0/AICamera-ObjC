//
//  Copyright © 2019年 Vizlab. All rights reserved.
//

#import "CameraPreview.h"

@implementation CameraPreview

+ (Class)layerClass{
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureVideoPreviewLayer*) videoPreviewLayer{
    return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (AVCaptureSession*) session{
    return self.videoPreviewLayer.session;
}

- (void)setSession:(AVCaptureSession*) session{
    self.videoPreviewLayer.session = session;
}

@end
