//
//  CardDetector.m
//  flutter_qr_bar_scanner
//
//  Created by Huynh Phuc on 7/3/20.
//

#import "CardDetector.h"
#import "PlateResult.h"
#import "FiOpencv.mm"

static CardDetector *cardDetector;

@implementation CardDetector {

}

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cardDetector = [[self class] new];
    });
    return cardDetector;
}

- (instancetype) init {
    if (self = [super init]) {
    }
    return self;
    
}

- (void)capture:(CMSampleBufferRef)sampleBuffer
    orientation:(int)orientation
      onSuccess:(onCardDetectSuccess)success {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    int plane = 0;
     char *planeBaseAddress = (char *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, plane);
    
     size_t width = CVPixelBufferGetWidthOfPlane(imageBuffer, plane);
     size_t height = CVPixelBufferGetHeightOfPlane(imageBuffer, plane);
     size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, plane);
    
     int numChannels = 4;
    
    cv::Mat matImage = cv::Mat((int)height, (int)width, CV_8UC(numChannels), planeBaseAddress, (int)bytesPerRow);
    [FiOpencv rot90:matImage rotflag:orientation];
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    CFRelease(sampleBuffer);
    
    NSLog(@"Size: %d-%d", matImage.rows, matImage.cols);
    
    NSString * cardPath = [FiOpencv saveMatToTmp:matImage];
    PlateResult *result = [PlateResult new];
    result.plate = cardPath;
    success(result);
}

- (void)detect:(CMSampleBufferRef)sampleBuffer
    detectType:(int)detectType
    orientation:(int)orientation
    onSuccess:(onCardDetectSuccess)success
    onFailure:(onCardDetectFailed)failure {

   NSLog(@"log orientationToApply %i", orientation);

   CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
   CVPixelBufferLockBaseAddress(imageBuffer, 0);


   // // Y_PLANE
    int plane = 0;
    char *planeBaseAddress = (char *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, plane);
   
    size_t width = CVPixelBufferGetWidthOfPlane(imageBuffer, plane);
    size_t height = CVPixelBufferGetHeightOfPlane(imageBuffer, plane);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, plane);
   
    int numChannels = 4;
    
    
    cv::Mat matImage = cv::Mat((int)height, (int)width, CV_8UC(numChannels), planeBaseAddress, (int)bytesPerRow);
    [FiOpencv rot90:matImage rotflag:orientation];
    
    NSLog(@"Size: %d-%d", matImage.rows, matImage.cols);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    CFRelease(sampleBuffer);
   if([FiOpencv getImageBlurValue:matImage] < 30){
       failure(nil);
       return;
   }
    
   if(detectType == 1){
       cv::Rect cardBB = [FiOpencv cascadeCardDetect:matImage];
       if(cardBB.width > 0) {
           cv::Mat card = cv::Mat(matImage, cardBB);
           if([FiOpencv getImageBlurValue:card] < 50){
               failure(nil);
               return;
           }
           NSString * cardPath = [FiOpencv saveMatToTmp:card];
           PlateResult *result = [PlateResult new];
           result.plate = cardPath;
           success(result);
       } else {
           failure(nil);
       }
       return;
   }
   
   if(detectType == 2) {
       // detect back card
       cv::Rect cardBB = [FiOpencv cascadeBackCardDetect:matImage];
       if(cardBB.width > 0) {
           cv::Mat card = cv::Mat(matImage, cardBB);
           if([FiOpencv getImageBlurValue:card] < 50){
               failure(nil);
               return;
           }
           NSString * cardPath = [FiOpencv saveMatToTmp:card];
           PlateResult *result = [PlateResult new];
           result.plate = cardPath;
           success(result);
       } else {
           failure(nil);
       }
       return;
   }
}


@end
