//
//  CardDetector.h
//  Pods
//
//  Created by Huynh Phuc on 7/3/20.
//
#import <Foundation/Foundation.h>
#import "PlateResult.h"

#import <AVFoundation/AVFoundation.h>

#ifdef __cplusplus
#import <opencv2/imgproc/imgproc.hpp>
#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>

#include <vector>
#include <string>

//@import AssetsLibrary;

using namespace std;
using namespace cv;
#endif

@interface CardDetector : NSObject

typedef void(^onCardDetectSuccess)(PlateResult *);
typedef void(^onCardDetectFailed)(NSError *);

+ (instancetype)sharedInstance;
- (void) detect:(CMSampleBufferRef)sampleBuffer
     detectType:(int)detectType
    orientation:(int)orientation
      onSuccess:(onCardDetectSuccess)success
      onFailure:(onCardDetectFailed)failure;
- (void)capture:(CMSampleBufferRef)sampleBuffer
    orientation:(int)orientation
      onSuccess:(onCardDetectSuccess)success;
@end


