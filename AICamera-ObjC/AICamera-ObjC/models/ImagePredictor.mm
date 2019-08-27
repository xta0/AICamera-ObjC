//
//  Copyright © 2019年 Vizlab. All rights reserved.
//

#import "ImagePredictor.h"
#import <PytorchExpObjC/PytorchExpObjC.h>
#include <ctime>


@interface ImagePredictor()
@end

@implementation ImagePredictor{
    PTHModule* _module;
    std::vector<std::string> _labels;
}

#define IMG_W 224
#define IMG_H 224
#define IMG_C 3

- (CGSize)imageSize {
    return (CGSize){IMG_W, IMG_H};
}
- (NSString* )modelName{
    return @"ResNet18";
}

- (BOOL)loadModel:(NSString* )modelPath andLabels:(NSString*) labelPath {
    if(!modelPath || !labelPath){
        return NO;
    }
    _module = [PTHModule loadTorchscriptModel:modelPath];
    NSError* err;
    NSArray* labels = [[NSString stringWithContentsOfFile:labelPath
                                                 encoding:NSUTF8StringEncoding
                                                    error:&err] componentsSeparatedByString:@"\n"];
    if(err){
        return NO;
    }
    for(NSString* label in labels){
        _labels.push_back({[label cStringUsingEncoding:NSUTF8StringEncoding]});
    }
    return YES;
}

- (void)predict:(std::shared_ptr<uint8_t>)rawData completion:(void(^__nullable)(std::vector<std::tuple<float, std::string>>&& results))completion{
    if(_isPredicting){
        return;
    }
    self->_isPredicting = true;
    std::clock_t start;
    start = std::clock();
    std::shared_ptr<uint8_t> tensorBuffer(rawData);
    
    PTHTensor* imageTensor = [PTHTensor newWithType:PTHTensorTypeByte Size:@[ @(1), @(IMG_W), @(IMG_H), @(IMG_C) ] Data:tensorBuffer.get()];
    imageTensor = [imageTensor permute:@[@(0),@(3),@(1),@(2)]];
    imageTensor = [imageTensor to:PTHTensorTypeFloat];
    //normalize the tensor
    imageTensor = [imageTensor div_:255.0];
    [[imageTensor[0][0] sub_:0.485] div_:0.229];
    [[imageTensor[0][1] sub_:0.485] div_:0.229];
    [[imageTensor[0][2] sub_:0.485] div_:0.229];
    PTHIValue* inputIValue = [PTHIValue newIValueWithTensor:imageTensor];
    PTHTensor* outputTensor = [[_module forward:@[inputIValue]] toTensor];
     self->_inferenceTime = ( std::clock() - start ) / (double) CLOCKS_PER_SEC;
    //collect the top10 results
    NSArray<PTHTensor* >* topkResults = [outputTensor topKResult:@(10) Dim:@(-1) isLargest:YES isSorted:YES];
    PTHTensor* scores = [topkResults[0] view:@[@(-1)]];
    PTHTensor* idxs   = [topkResults[1] view:@[@(-1)]];
    
    std::vector<std::tuple<float,std::string>> results;
    for (int i = 0; i < 5; ++i) {
        results.push_back({
            scores[i].item.floatValue,
            self->_labels[idxs[i].item.longValue]
        });
    }
    self->_isPredicting = false;
    if(completion){
        completion(std::move(results));
    }
}

@end
