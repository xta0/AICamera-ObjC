//
//  Copyright © 2019年 Vizlab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
#import <vector>
#import <tuple>
#import <string>
#import <memory>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface ImagePredictor : NSObject

@property(nonatomic,assign, readonly) NSString* modelName;
@property(nonatomic,assign, readonly) NSTimeInterval inferenceTime;
@property(nonatomic,assign, readonly) CGSize imageSize;
@property(nonatomic,assign, readonly) BOOL isPredicting;

- (BOOL)loadModel:(NSString* _Nonnull )modelPath andLabels:(NSString* _Nonnull) labelPath ;
- (void)predict:(std::shared_ptr<float> )data completion:(void(^__nullable)(NSArray<NSDictionary* >* sortedResults))completion;

@end

NS_ASSUME_NONNULL_END
