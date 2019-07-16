//
//  Copyright © 2019年 Vizlab. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "ViewController.h"
#import "CameraPreview.h"
#import "CameraSessionManager.h"
#import "ImagePredictor.h"
#import "CameraHelper.h"
#import <memory>


@interface ViewController ()<CameraSeesion>

@property (weak, nonatomic) IBOutlet CameraPreview *cameraPreview;
@property (weak, nonatomic) IBOutlet UITextView *statusView;
@property (weak, nonatomic) IBOutlet UITextView *resultView;
@property (weak, nonatomic) IBOutlet UIImageView *sampleImageView;

@property(nonatomic, strong) CameraSessionManager* sessionManager;
@property(nonatomic, strong) ImagePredictor* modelManager;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //init Image predictor
    self.modelManager = [ImagePredictor new];
    if(![self.modelManager loadModel:[[NSBundle mainBundle] pathForResource:@"resnet18" ofType:@"pt"]
                          andLabels:[[NSBundle mainBundle] pathForResource:@"lables" ofType:@"txt"]]){
        NSAssert(FALSE, @"Can't load Pytorch model");
        return;
    }
    self.sessionManager = [CameraSessionManager new];
    self.sessionManager.delegate = self;
    
    self.cameraPreview.videoPrevig_callocReleaseCallbackewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    self.cameraPreview.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.cameraPreview.session = self.sessionManager.session;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.sessionManager startSession];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear: animated];
    [self.sessionManager stopSession];
}

- (void)cameraDidReceivePixelBuffer:(std::shared_ptr<uint8_t>)tensor sampleImage:(UIImage *)image {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusView.text = [self status];
        if(image){
            self.sampleImageView.image = image;
        }
    });
    __block NSString* content = @"";
    [self.modelManager predict:tensor
                    completion:^(std::vector<std::tuple<float, std::string>>&& results) {
        for(auto& result: results){
            NSString* str = [NSString stringWithFormat:@"score: %.3f, label: %s \n", std::get<0>(result), std::get<1>(result).c_str()];
            content = [content stringByAppendingString:str];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.resultView.text = content;
            });
        }
    }];
}

- (void)cameraPermissionDenied {
    //TODO: display an alert
}

- (void)cameraSetupFailed {
    //TODO: display an alert
}

- (void)cameraSessionWasInterrupted {
    //TODO: restart the session
}

- (NSString* )status{
    NSString* status = @"";
    status = [status stringByAppendingString:[NSString stringWithFormat:@"model: %@\n", self.modelManager.modelName]];
    status = [status stringByAppendingString:[NSString stringWithFormat:@"resolution: %d x %d\n",(int)self.sessionManager.cameraResulotion.width,(int)self.sessionManager.cameraResulotion.height]];
    status = [status stringByAppendingString:[NSString stringWithFormat:@"crop: %ld x %ld\n",(NSUInteger)self.modelManager.imageSize.width, (NSUInteger)self.modelManager.imageSize.height]];
    status = [status stringByAppendingString:[NSString stringWithFormat:@"preprocessing time: %.3fs\n",self.sessionManager.prepareBuffer]];
    status = [status stringByAppendingString:[NSString stringWithFormat:@"inference time: %.3f\n",self.modelManager.inferenceTime]];
    return status;
}

@end
