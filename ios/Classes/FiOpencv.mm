#import <Photos/Photos.h>

#ifdef __cplusplus
#import <opencv2/imgproc/imgproc.hpp>

#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgcodecs/ios.h>

#include <vector>
#include <string>

//@import AssetsLibrary;

using namespace std;
using namespace cv;
#endif


@interface FiOpencv : NSObject
+ (void) saveImage:(cv::Mat)image;
+ (cv::Mat) resizeImage:(cv::Mat)image
    newWidth:(int)newWidth ;
+ (std::vector<std::vector<cv::Point> > ) getContours:(cv::Mat) image
    isGray:(BOOL)isGray;
+ (std::vector<cv::Point>) findMaxContours:(std::vector<std::vector<cv::Point> > ) contours;
+ (cv::Rect) findCardContours:(cv::Mat) edged;
+ (double) getImageBlurValue:(cv::Mat) image;
+ (void) rot90:(cv::Mat&)matImage rotflag:(int)rotflag;
+ (std::vector<cv::Rect>) detectFace:(cv::Mat) image;
+ (cv::Rect) cascadeCardDetect:(cv::Mat) image;
+ (cv::Rect) cascadeBackCardDetect:(cv::Mat) image;
+ (cv::Rect) getCardBBFromSymbol:(cv::Rect) bb;
+ (NSString *) saveMatToTmp:(cv::Mat) matImage;
@end


const int NO_CARD_CONTOUR = 1;

@implementation FiOpencv

//ImagemConverter::ImagemConverter() {}

static const std::string base64_chars =
"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
"abcdefghijklmnopqrstuvwxyz"
"0123456789+/";

+ (bool) is_base64:(unsigned char) c
{
  return (isalnum(c) || (c == '+') || (c == '/'));
}

+ (std::string) base64_encode:(uchar *)bytes_to_encode in_len:(int)in_len
{
  std::string ret;

  int i = 0;
  int j = 0;
  unsigned char char_array_3[3];
  unsigned char char_array_4[4];

  while (in_len--)
  {
    char_array_3[i++] = *(bytes_to_encode++);
    if (i == 3)
    {
      char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
      char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
      char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
      char_array_4[3] = char_array_3[2] & 0x3f;

      for (i = 0; (i <4); i++)
      {
        ret += base64_chars[char_array_4[i]];
      }
      i = 0;
    }
  }

  if (i)
  {
    for (j = i; j < 3; j++)
    {
      char_array_3[j] = '\0';
    }

    char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
    char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
    char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
    char_array_4[3] = char_array_3[2] & 0x3f;

    for (j = 0; (j < i + 1); j++)
    {
      ret += base64_chars[char_array_4[j]];
    }
    
    while ((i++ < 3))
    {
      ret += '=';
    }
  }

  return ret;

}

+ (std::string) mat2str:(cv::Mat)m
{
  
  int params[3] = {0};
  params[0] = cv::IMWRITE_JPEG_QUALITY;
  params[1] = 80;

    std::vector<uchar> buf;
  bool code = cv::imencode(".jpg", m, buf, std::vector<int>(params, params+2));
  uchar* result = reinterpret_cast<uchar*> (&buf[0]);

  return [self base64_encode:result  in_len:buf.size()];

}


- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

//RCT_EXPORT_METHOD(detectFromFile:(NSString *)urlImage type:(int)type callback:(RCTResponseSenderBlock)callback) {
//  NSString *uri = urlImage;
//  if (uri == nil) {
////      reject(@"E_FACE_DETECTION_FAILED", @"You must define a URI.", nil);
//      return;
//  }
//
//  float scale = 1.0f;
////  NSString resizeMode = @"contain";
//  NSURL *url = [NSURL URLWithString:uri];
//
//  CGSize size = CGSizeMake(0, 0);
//
////  NSURL* url = [NSURL URLWithString:imageUri];
//  PHFetchResult *results = nil;
//  if ([url.scheme isEqualToString:@"ph"]) {
//      results = [PHAsset fetchAssetsWithLocalIdentifiers:@[[uri substringFromIndex: 5]] options:nil];
//  } else {
//      results = [PHAsset fetchAssetsWithALAssetURLs:@[url] options:nil];
//  }
//
//  if (results.count == 0) {
//      NSString *errorText = [NSString stringWithFormat:@"Failed to fetch PHAsset with local identifier %@ with no error message.", uri];
//
//      NSMutableDictionary* details = [NSMutableDictionary dictionary];
//      [details setValue:errorText forKey:NSLocalizedDescriptionKey];
//      NSError *error = [NSError errorWithDomain:@"RNFS" code:500 userInfo:details];
////      reject(@"EUNSPECIFIED", error, nil);
////        [self reject: reject withError:error];
//    callback(@[[NSNull null], @"EUNSPECIFIED"]);
//      return;
//  }
//
//  PHAsset *asset = [results firstObject];
//  PHImageRequestOptions *imageOptions = [PHImageRequestOptions new];
//
//  // Allow us to fetch images from iCloud
//  imageOptions.networkAccessAllowed = YES;
//
//
//  // Note: PhotoKit defaults to a deliveryMode of PHImageRequestOptionsDeliveryModeOpportunistic
//  // which means it may call back multiple times - we probably don't want that
//  imageOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
//
//  BOOL useMaximumSize = CGSizeEqualToSize(size, CGSizeZero);
//  CGSize targetSize;
//  if (useMaximumSize) {
//      targetSize = PHImageManagerMaximumSize;
//      imageOptions.resizeMode = PHImageRequestOptionsResizeModeNone;
//  } else {
//      targetSize = CGSizeApplyAffineTransform(size, CGAffineTransformMakeScale(scale, scale));
//      imageOptions.resizeMode = PHImageRequestOptionsResizeModeFast;
//  }
//
//  PHImageContentMode contentMode = PHImageContentModeAspectFill;
////  if (resizeMode == @"contain") {
//      contentMode = PHImageContentModeAspectFit;
////  }
//
//
//  // PHImageRequestID requestID =
//  [[PHImageManager defaultManager] requestImageForAsset:asset
//                                             targetSize:targetSize
//                                            contentMode:contentMode
//                                                options:imageOptions
//                                          resultHandler:^(UIImage *result, NSDictionary<NSString *, id> *info) {
//      if (result) {
//          cv::Mat matImage = [self convertUIImageToCVMat:result];
//
//          if(type == 1){
//              cv::Rect cardBB = [FiOpencv cascadeCardDetect:matImage];
//              NSMutableArray *cardArray = [[NSMutableArray alloc] init];
//              NSDictionary *cardData = @{@"x": @(cardBB.x), @"y": @(cardBB.y), @"w": @(cardBB.width), @"h": @(cardBB.height)};
//              NSDictionary *returnData = @{@"cards": cardArray};
//              callback(@[[NSNull null], returnData]);
//          }
//          else{
//              std::vector<cv::Rect> faces = [FiOpencv detectFace:matImage];
//              NSMutableArray *facesArray = [[NSMutableArray alloc] init];
//                 for(size_t i=0; i< faces.size(); i++){
//                     NSDictionary *faceData = @{@"x": @(faces[i].x), @"y": @(faces[i].y), @"w": @(faces[i].width), @"h": @(faces[i].height)};
//                     RCTLogInfo(@"====> x: %d, y:%d, w:%d, h:%d ", faces[i].x, faces[i].y, faces[i].width, faces[i].height);
//                     [facesArray addObject:faceData ];
//                 }
//
//              NSDictionary *returnData = @{@"faces": facesArray};
//              callback(@[[NSNull null], returnData]);
//              return;
//          }
//
//          callback(@[[NSNull null], @{
//              @"uri" : url,
//              @"width" : @(result.size.width),
//              @"height" : @(result.size.height),
//        //      @"orientation" : @([self exifOrientationFor:image.imageOrientation])
//            }]);
//      } else {
//          NSMutableDictionary* details = [NSMutableDictionary dictionary];
//          [details setValue:info[PHImageErrorKey] forKey:NSLocalizedDescriptionKey];
//          NSError *error = [NSError errorWithDomain:@"RNFS" code:501 userInfo:details];
////          reject(@"EUNSPECIFIED", error, nil);
//callback(@[[NSNull null], @"EUNSPECIFIED"]);
////            [self reject: reject withError:error];
//
//      }
//  }];
//
//  return;
//
//}
//
//RCT_EXPORT_METHOD(detectFromBase64:(NSString *)imageAsBase64 type:(int)type callback:(RCTResponseSenderBlock)callback) {
//    UIImage* image = [self decodeBase64ToImage:imageAsBase64];
//    cv::Mat matImage = [self convertUIImageToCVMat:image];
//    if(type == 1){
//        [self findCard:matImage];
//    }
//    else{
//        std::vector<cv::Rect> faces = [FiOpencv detectFace:matImage];
//    }
//}

- (void)findCard:(cv::Mat) matImage
{
    try
      {
      
      cv::cvtColor(matImage, matImage, cv::COLOR_RGB2BGR);
      //
      std::vector<std::vector<cv::Point>> contours = [FiOpencv getContours:matImage  isGray:false];
      BOOL valid = false;
      BOOL haveSymbol = false;
      BOOL haveImage = false;
      int width = 1000;
      cv::Size originSize = matImage.size();
      float ratio = (float)width / (float)originSize.width;
      cv::Mat imgResized = [FiOpencv resizeImage:matImage newWidth:width];

      cv::Size blurSize = cv::Size(1,1);
      cv::Mat imgBlurred;
      cv::GaussianBlur(imgResized, imgBlurred, blurSize, 0);
      
      cv::Mat imgGray;
      cv::cvtColor(imgResized, imgGray, cv::COLOR_BGR2GRAY);

      cv::Mat edged;
      cv::Canny(imgGray, edged, 20, 150);
      
      cv::Rect cardContours = [FiOpencv findCardContours:edged];
      if(!cardContours.x && !cardContours.y && !cardContours.height && !cardContours.width) {
        throw NO_CARD_CONTOUR;
      }
      cv::Mat cardImage = cv::Mat(imgResized, cardContours);
      int cardWidth = 400;
      cv::Mat cardResized = [FiOpencv resizeImage:cardImage newWidth:cardWidth];
      blurSize = cv::Size(5,5);
      cv::GaussianBlur(cardResized, cardResized, blurSize, 2);
    
      cv::Mat cardGray;
      cv::cvtColor(cardResized, cardGray, cv::COLOR_BGR2GRAY);
      
      cv::Canny(cardGray, cardGray, 0, 80);
      std::vector<std::vector<cv::Point> > contoursInCard = [FiOpencv getContours:cardGray isGray:true];
      
      for( size_t i = 0; i < contoursInCard.size(); i++ )
      {

        cv::Rect rect;
        rect = cv::boundingRect(contoursInCard[i]);
        if( rect.x > 30 && rect.x < 140
          && rect.y> 20 && rect.y < 50
          && rect.width > 30 && rect.width < 80
          && rect.height > 30 && rect.height < 80) {
          haveSymbol = true;
        }
                       
        if( rect.x > 10 && rect.x < 140
         && rect.y > 60 && rect.y < 150
         && rect.width > 50 && rect.width < 120
         && rect.height > 80 && rect.height < 150 ){
          haveImage = true;
        }

      }
     
      if (haveSymbol && haveImage){
        valid = true;
        int fixedX = cardContours.x / ratio;
        int fixedY = cardContours.y / ratio;
        int fixedW = cardContours.width / ratio;
        int fixedH = cardContours.height / ratio;
        
        NSLog(@"x: %d, y:%d, w:%d, h:%d ", fixedX, fixedY, fixedW, fixedH);
      } else {
          NSLog(@"Invalid@");
      }
    }
    catch (int e)
    {
      if(e == NO_CARD_CONTOUR) {
        NSLog(@"No card found");
      }
      NSLog(@"Invalid");
      return;
    }
}

- (cv::Mat)convertUIImageToCVMat:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    size_t numberOfComponents = CGColorSpaceGetNumberOfComponents(colorSpace);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;

    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault;

    // check whether the UIImage is greyscale already
    if (numberOfComponents == 1){
        cvMat = cv::Mat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
        bitmapInfo = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
    }

    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,             // Pointer to backing data
                                                cols,                       // Width of bitmap
                                                rows,                       // Height of bitmap
                                                8,                          // Bits per component
                                                cvMat.step[0],              // Bytes per row
                                                colorSpace,                 // Colorspace
                                                bitmapInfo);              // Bitmap info flags

    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);

    return cvMat;
}

- (UIImage *)decodeBase64ToImage:(NSString *)strEncodeData {
  NSData *data = [[NSData alloc]initWithBase64EncodedString:strEncodeData options:NSDataBase64DecodingIgnoreUnknownCharacters];
  return [UIImage imageWithData:data];
}

//save image to debbug
+ (void) saveImage:(cv::Mat)image {
//  cv::Mat resizedImage = [self resizeImage:image newWidth:300];
//  NSData *data = [NSData dataWithBytes:resizedImage.data length:resizedImage.elemSize()*resizedImage.total()];
//  NSString * base64String = [data base64EncodedStringWithOptions:0];
  
  std::string base64String = [self mat2str:image];
  NSString* result = [NSString stringWithUTF8String:base64String.c_str()];

  NSLog(@"HERE-base %@", result);
  
}

//resize image
+ (cv::Mat) resizeImage:(cv::Mat)image
  newWidth:(int)newWidth {
  cv::Size size = image.size();
  float ratio = (float)size.width / (float)size.height;
  int newHeight = (int)(newWidth / ratio);
  cv::Size newSize = cv::Size(newWidth, newHeight);
  cv::Mat resizedImage = cv::Mat();
  cv::resize(image, resizedImage, cv::Size((int)newWidth, (int)newHeight));
  return resizedImage;
}
//get Contours
+ (std::vector<std::vector<cv::Point> > ) getContours:(cv::Mat) image
  isGray:(BOOL)isGray{
  cv::Mat gray;
  if(isGray) {
    gray = image;
  }
  else {
    cv::cvtColor(image, gray, cv::COLOR_BGR2GRAY);
  }
  std::vector<std::vector<cv::Point> > contours;
  findContours(gray, contours, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE);
  return contours;
}
// find countours have larges react bounding
+ (std::vector<cv::Point>) findMaxContours:(std::vector<std::vector<cv::Point> > ) contours {
  std::vector<cv::Point> maxContour;
  for( size_t i = 0; i < contours.size(); i++ )
  {
    cv::Rect rect;
    rect = cv::boundingRect(contours[i]);
    if(rect.width > 350 && (float)rect.width/(float)rect.height >= 1.5 && (float)rect.width/(float)rect.height <= 2) {
      cv::Rect maxRect;
      maxRect = cv::boundingRect(maxContour);
      if (rect.width*rect.height > maxRect.width*maxRect.height) {
        maxContour = contours[i];
      }
    }
  }
  return maxContour;
}
// find could bbe card contour
+ (cv::Rect) findCardContours:(cv::Mat) edged {
  std::vector<std::vector<cv::Point> > cnts = [self getContours:edged isGray:true];
  std::vector<cv::Point> c = [self findMaxContours:cnts];
  cv::Rect rect = cv::boundingRect(c);
  NSLog(@"x: %d, y:%d, w:%d, h:%d ", rect.x, rect.y, rect.width, rect.height);
  return rect;
}


- (BOOL) isImageBlurry:(UIImage *) image {
  // converting UIImage to OpenCV format - Mat
  
  cv::Mat matImage = [self convertUIImageToCVMat:image];
  

  cv::Mat matImageGrey;
  // converting image's color space (RGB) to grayscale
  cv::cvtColor(matImage, matImageGrey, cv::COLOR_BGR2GRAY);
  
  cv::Mat dst2 = [self convertUIImageToCVMat:image];
  cv::Mat laplacianImage;
  dst2.convertTo(laplacianImage, CV_8UC1);
  
  // applying Laplacian operator to the image
  cv::Laplacian(matImageGrey, laplacianImage, CV_8U);
  cv::Mat laplacianImage8bit;
  laplacianImage.convertTo(laplacianImage8bit, CV_8UC1);
  
  unsigned char *pixels = laplacianImage8bit.data;
  
  // 16777216 = 256*256*256
  int maxLap = -16777216;
  for (int i = 0; i < ( laplacianImage8bit.elemSize()*laplacianImage8bit.total()); i++) {
    if (pixels[i] > maxLap) {
      maxLap = pixels[i];
    }
  }
  // one of the main parameters here: threshold sets the sensitivity for the blur check
  // smaller number = less sensitive; default = 180
  int threshold = 180;
  
  return (maxLap <= threshold);
}

+ (double) getImageBlurValue:(cv::Mat) image {
    cv::Mat laplacianImage;
    cv::Laplacian(image, laplacianImage, CV_64F);
    cv::Scalar mean;
    cv::Scalar std;
    cv::meanStdDev(laplacianImage, mean, std);
    double score = 0.0;
    score = std[0] * std[0];
    NSLog(@"Blur value %f", score);
    return score;
  }
+ (void) rot90:(cv::Mat&)matImage rotflag:(int)rotflag {
    // 1=CW, 2=CCW, 3=180
    if (rotflag == 1) {
        // transpose+flip(1)=CW
        transpose(matImage, matImage);
        flip(matImage, matImage, 0);
    } else if (rotflag == 2) {
        // transpose+flip(0)=CCW
        transpose(matImage, matImage);
        flip(matImage, matImage, 0);
    } else if (rotflag == 4){
        // flip(-1)=180
        flip(matImage, matImage, -1);
    }
}

+ (std::vector<cv::Rect>) detectFace:(cv::Mat) image {
     NSLog(@"Checking Face");
    cv::Mat imgResized = [FiOpencv resizeImage:image newWidth:500];
    cv::Mat grayImage;
    cv::cvtColor(imgResized, grayImage, cv::COLOR_BGR2GRAY);
    cv::CascadeClassifier faceCascade;
    std::vector<cv::Rect> listContours;
    NSString *face_cascade_name = [[NSBundle mainBundle] pathForResource:@"lbpcascade_frontalface_improved" ofType:@"xml"];
    if( !faceCascade.load( std::string([face_cascade_name UTF8String]) ) ) {
        NSLog(@"Cant load haar file");
        return listContours;
    };
    faceCascade.detectMultiScale(grayImage, listContours, 1.1, 1);
    
    cv::Size originSize = image.size();
    float ratio = (float)originSize.width / (float)500;
    std::vector<cv::Rect> fixedListBB;
    for( size_t i = 0; i < listContours.size(); i++ )
    {
        cv::Rect fixedBB = cv::Rect(listContours[i].x * ratio, listContours[i].y * ratio, listContours[i].width * ratio, listContours[i].height * ratio);
        fixedListBB.push_back(fixedBB);
    }
    NSLog(@"Total Face %d", listContours.size());
    return fixedListBB;
}

+ (cv::Rect) cascadeCardDetect:(cv::Mat) image {
    NSLog(@"Checking Card");
    cv::Mat imgResized = [FiOpencv resizeImage:image newWidth:600];
    cv::Mat grayImage;
    cv::Rect cardBB = cv::Rect();
    cv::cvtColor(imgResized, grayImage, cv::COLOR_BGR2GRAY);
    cv::CascadeClassifier cardCascade;
    std::vector<cv::Rect> listContours;
    NSString *cardCascadeFile = [[NSBundle mainBundle] pathForResource:@"lbpcascade_card" ofType:@"xml"];
    if( !cardCascade.load( std::string([cardCascadeFile UTF8String]) ) ) {
        NSLog(@"Cant load haar file");

        return cardBB;
    };
    cardCascade.detectMultiScale(grayImage, listContours, 1.1, 1);
    cv::Size originSize = image.size();
    float ratio = (float)originSize.width / (float)600;
    std::vector<cv::Rect> fixedListBB;
    for( size_t i = 0; i < listContours.size(); i++ )
    {
        cardBB = [FiOpencv getCardBBFromSymbol:listContours[i]];
        //fix ratio
        cardBB = cv::Rect(
                  cardBB.x * ratio ,
                  cardBB.y * ratio,
                  cardBB.width * ratio,
                  cardBB.height * ratio);
        if(cardBB.x < 0) {
            cardBB.x = 0;
        }
        if(cardBB.y < 0) {
            cardBB.y = 0;
        }
        if(cardBB.x + cardBB.width > originSize.width) {
            cardBB = cv::Rect();
        }
        if(cardBB.y + cardBB.height > originSize.height) {
            cardBB = cv::Rect();
        }
        break;
    }
    NSLog(@"Card BB %d %d %d %d", cardBB.x, cardBB.y, cardBB.width, cardBB.height);
    return cardBB;
}


+ (cv::Rect) cascadeBackCardDetect:(cv::Mat) image {
    NSLog(@"Checking Card");
    cv::Mat imgResized = [FiOpencv resizeImage:image newWidth:400];
    cv::Mat grayImage;
    cv::Rect cardBB = cv::Rect();
    cv::cvtColor(imgResized, grayImage, cv::COLOR_BGR2GRAY);
    cv::CascadeClassifier cardCascade;
    std::vector<cv::Rect> listContours;
    NSString *cardCascadeFile = [[NSBundle mainBundle] pathForResource:@"cascade_back_card" ofType:@"xml"];
    if( !cardCascade.load( std::string([cardCascadeFile UTF8String]) ) ) {
        NSLog(@"Cant load haar file");

        return cardBB;
    };
    cardCascade.detectMultiScale(grayImage, listContours, 1.1, 2);
    cv::Size originSize = image.size();
    float ratio = (float)originSize.width / (float)400;
    std::vector<cv::Rect> fixedListBB;
    for( size_t i = 0; i < listContours.size(); i++ )
    {
        cardBB = listContours[i];
        //fix ratio
        cardBB = cv::Rect(
                  cardBB.x * ratio ,
                  cardBB.y * ratio,
                  cardBB.width * ratio,
                  cardBB.height * ratio);
        if(cardBB.x < 0) {
            cardBB.x = 0;
        }
        if(cardBB.y < 0) {
            cardBB.y = 0;
        }
        if(cardBB.x + cardBB.width > originSize.width) {
            cardBB = cv::Rect();
        }
        if(cardBB.y + cardBB.height > originSize.height) {
            cardBB = cv::Rect();
        }
        break;
    }
    NSLog(@"Card BB %d %d %d %d", cardBB.x, cardBB.y, cardBB.width, cardBB.height);
    return cardBB;
}


+ (cv::Rect) getCardBBFromSymbol:(cv::Rect) bb {
    cv::Rect cardBB = cv::Rect(
       bb.x - ( (float)bb.width * 0.3 ),
        bb.y - ( (float)bb.height * 0.3 ),
        bb.width * 4.5,
        bb.height * 3.2
    );
    return cardBB;
}


+ (NSString *) saveMatToTmp:(cv::Mat) matImage
{
    cv::cvtColor(matImage, matImage, cv::COLOR_BGR2RGB);
    UIImage *image = MatToUIImage(matImage);
    
    NSData *data = [NSData dataWithData:UIImageJPEGRepresentation(image, 1)];
    NSLog(@"%@", [data base64EncodedStringWithOptions:0]);

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);

    NSDate *date = [NSDate date];
    NSString *name = [NSString stringWithFormat:@"%ld.jpeg", [@(floor([date timeIntervalSince1970])) longLongValue]];

    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *localFilePath = [documentsDirectory stringByAppendingPathComponent:name];
    NSLog(@"%@", localFilePath);
    [data writeToFile:localFilePath atomically:YES];
    return localFilePath;
}

@end
