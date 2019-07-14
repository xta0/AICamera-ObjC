//
//  Copyright © 2019年 Vizlab. All rights reserved.
//

#import "ImagePredictor.h"
#import <torch/script.h>
#include <ctime>

@implementation ImagePredictor{
    torch::jit::script::Module _module;
    std::vector<std::string> _labels;
}

#define IMG_W 224
#define IMG_H 224
#define IMG_C 3

- (CGSize)imageSize {
    return (CGSize){IMG_W, IMG_H};
}

- (void)loadModel:(NSString* )modelPath andLabels:(NSString*) labelPath {
    _module = torch::jit::load([modelPath cStringUsingEncoding:NSASCIIStringEncoding]);
    NSError* err;
    NSArray* labels = [[NSString stringWithContentsOfFile:labelPath
                                                 encoding:NSUTF8StringEncoding
                                                    error:&err] componentsSeparatedByString:@"\n"];
    for(NSString* label in labels){
        _labels.push_back({[label cStringUsingEncoding:NSUTF8StringEncoding]});
    }
}

- (void)predict:(void* )data completion:(void(^__nullable)(std::vector<std::tuple<float, std::string>> results))completion{
    if(_isPredicting){
        return;
    }
    _isPredicting = true;
    std::clock_t start;
    start = std::clock();
    at::Tensor img_tensor = torch::from_blob(data, {1, IMG_W, IMG_H, IMG_C}, at::kByte).clone();
    // pixel buffer is in WxHxC, make it CxWxH
    img_tensor = img_tensor.permute({0,3,1,2});
    img_tensor = img_tensor.toType(at::kFloat);
    img_tensor.div_(255);
    // normalize the input tensor
    img_tensor[0][0].sub_(0.485).div_(0.229);
    img_tensor[0][1].sub_(0.456).div_(0.224);
    img_tensor[0][2].sub_(0.406).div_(0.225);
    
    std::vector<torch::jit::IValue> inputs{img_tensor};
    auto outputs= self->_module.forward(inputs).toTensor();
    self->_inferenceTime = ( std::clock() - start ) / (double) CLOCKS_PER_SEC;
    auto result = outputs.topk(5, -1);
    //flat socres and indexes
    auto scores = std::get<0>(result).view(-1);
    auto idxs = std::get<1>(result).view(-1);
    //collect top 10 results
    std::vector<std::tuple<float,std::string>> results;
    for (int i = 0; i < 5; ++i) {
        results.push_back({
            scores[i].item().toFloat(),
            self->_labels[idxs[i].item().toInt()]
        });
    }
    _isPredicting = false;
    if(completion){
        completion(results);
    }
    
}

@end
