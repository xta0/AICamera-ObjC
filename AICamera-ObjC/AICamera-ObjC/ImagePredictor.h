//
//  Copyright © 2019年 Vizlab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
#import <vector>
#import <tuple>
#import <string>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface ImagePredictor : NSObject

@property(nonatomic,assign, readonly) NSTimeInterval inferenceTime;
@property(nonatomic,assign, readonly) CGSize imageSize;
@property(nonatomic,assign, readonly) BOOL isPredicting;

- (void)loadModel:(NSString* )modelPath andLabels:(NSString*) labelPath ;
- (void)predict:(void* )rgbData completion:(void(^__nullable)( std::vector<std::tuple<float, std::string>> results))completion;

@end

NS_ASSUME_NONNULL_END
