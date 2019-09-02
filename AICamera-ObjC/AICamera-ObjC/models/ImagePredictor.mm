//
//  Copyright © 2019年 Vizlab. All rights reserved.
//

#import "ImagePredictor.h"
#import <PytorchExpObjC/PytorchExpObjC.h>
#include <ctime>


@interface ImagePredictor()
@end

@implementation ImagePredictor{
    TorchModule* _module;
    NSArray*     _labels;
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
    _module = [TorchModule loadTorchscriptModel:modelPath];
    NSError* err;
    NSArray* labels = [[NSString stringWithContentsOfFile:labelPath
                                                 encoding:NSUTF8StringEncoding
                                                    error:&err] componentsSeparatedByString:@"\n"];
    if(err){
        return NO;
    }
    _labels = [labels copy];
    return YES;
}

- (void)predict:(std::shared_ptr<float>)rawData completion:(void(^__nullable)(NSArray<NSDictionary* >* sortedResults))completion{
    if(_isPredicting){
        return;
    }
    self->_isPredicting = true;
    std::clock_t start;
    start = std::clock();
    std::shared_ptr<float> tensorBuffer(rawData);
    
    TorchTensor* imageTensor = [TorchTensor newWithType:TorchTensorTypeFloat Size:@[ @(1), @(IMG_C), @(IMG_H), @(IMG_W) ] Data:tensorBuffer.get()];
    TorchIValue* inputIValue = [TorchIValue newWithTensor:imageTensor];
    TorchTensor* outputTensor = [[_module forward:@[inputIValue]] toTensor];
     self->_inferenceTime = ( std::clock() - start ) / (double) CLOCKS_PER_SEC;
    //collect the top10 results
    NSArray<NSDictionary* >* sortedResults = [self topN:10 fromResults:outputTensor];
    self->_isPredicting = false;
    if(completion){
        completion(sortedResults);
    }
}

- (NSArray<NSDictionary* >* )topN:(NSUInteger)k fromResults:(TorchTensor* ) results{
    int64_t totalCount = results.size[1].integerValue;
    NSMutableDictionary* scores = [NSMutableDictionary new];
    for(int i = 0; i<totalCount; ++i){
        scores[@(results[0][i].item.floatValue)] = @(i);
    }
    NSArray* keys = [scores allKeys];
    NSArray* sortedArray = [keys sortedArrayUsingComparator:^NSComparisonResult(NSNumber* obj1, NSNumber* obj2) {
        if (obj1.floatValue < obj2.floatValue){
            return NSOrderedDescending;
        }else if(obj1.floatValue > obj2.floatValue){
            return NSOrderedAscending;
        }else{
            return NSOrderedAscending;
        }
    }];
    NSMutableArray<NSDictionary* >* sortedResult = [NSMutableArray new];
    for(int i=0;i<k;i++){
        NSNumber* score = sortedArray[i];
        NSNumber* index = scores[score];
        NSString* label = _labels[index.integerValue];
        [sortedResult addObject:@{score:label}];
    }
    return sortedResult;
}

@end
