@import AVFoundation;

#import "FlutterQrBarScannerPlugin.h"
#import "CardDetector.h"
#import <libkern/OSAtomic.h>

#pragma mark OpenCV -

@interface NSError (FlutterError)
@property(readonly, nonatomic) FlutterError *flutterError;
@end

@implementation NSError (FlutterError)
- (FlutterError *)flutterError {
    return [FlutterError errorWithCode:[NSString stringWithFormat:@"Error %d", (int)self.code]
                               message:self.domain
                               details:self.localizedDescription];
}
@end

@interface QrReader: NSObject<FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate>
@property(readonly, nonatomic) int64_t textureId;
@property(nonatomic, copy) void (^onFrameAvailable)(void);
@property(nonatomic) FlutterEventChannel *eventChannel;
@property(nonatomic) FlutterEventSink eventSink;
@property(readonly, nonatomic) AVCaptureSession *captureSession;
@property(readonly, nonatomic) AVCaptureMetadataOutput *metaDataOutput;
@property(readonly, nonatomic) AVCaptureDevice *captureDevice;
@property(readonly) CVPixelBufferRef volatile latestPixelBuffer;
@property(readonly, nonatomic) CMVideoDimensions previewSize;
@property(readonly, nonatomic) dispatch_queue_t mainQueue;
@property(readonly, nonatomic) dispatch_queue_t backgroundQueue;
@property(assign, nonatomic) NSInteger detectType;

@property(nonatomic, copy) void (^onCodeAvailable)(NSString *);
@property(nonatomic, copy) void (^onCardAvailable)(NSString *);
@property(assign, nonatomic, nullable) NSNumber *orientation;
@property(nonatomic, strong) AVCaptureDeviceInput *videoCaptureDeviceInput;
@property (nonatomic, copy) NSDate *startDetect;
@property (nonatomic, assign) BOOL finishedDetecting;
@property (nonatomic, assign) BOOL completeDetect;
@property (nonatomic, assign) BOOL manuallyCapture;

- (AVCaptureVideoOrientation)videoOrientationForInterfaceOrientation:(UIInterfaceOrientation)orientation;

- (instancetype)initWithErrorRef:(NSError **)error;

@end

@implementation QrReader

- (instancetype)initWithErrorRef:(NSError **)error {
    self = [super init];
    
    self.finishedDetecting = true;
    self.startDetect = [NSDate date];
    self.completeDetect = false;
    self.manuallyCapture = false;
    
    NSAssert(self, @"super init cannot be nil");
    _captureSession = [[AVCaptureSession alloc] init];
    
    if (@available(iOS 10.0, *)) {
        _captureDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    } else {
        for(AVCaptureDevice* device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
            if (device.position == AVCaptureDevicePositionBack) {
                _captureDevice = device;
                break;
            }
        }

        if (_captureDevice == nil) {
            _captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        }
    }
    
    _mainQueue = dispatch_get_main_queue();
    _backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
    
    NSError *localError = nil;
    _videoCaptureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_captureDevice error:&localError];
    if (localError) {
        *error = localError;
        return nil;
    }
    _previewSize = CMVideoFormatDescriptionGetDimensions([[_captureDevice activeFormat] formatDescription]);
    
    AVCaptureVideoDataOutput *output = [AVCaptureVideoDataOutput new];
    
    output.videoSettings =
    @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
    [output setAlwaysDiscardsLateVideoFrames:YES];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [output setSampleBufferDelegate:self queue:queue];
    
    AVCaptureConnection *connection =
    [AVCaptureConnection connectionWithInputPorts:_videoCaptureDeviceInput.ports output:output];
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    [_captureSession addInputWithNoConnections:_videoCaptureDeviceInput];
    [_captureSession addOutputWithNoConnections:output];
    [_captureSession addConnection:connection];
    
    if (_detectType == 0) {
        _metaDataOutput = [[AVCaptureMetadataOutput alloc] init];
        [_metaDataOutput setMetadataObjectsDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul)];
        [_captureSession addOutput:_metaDataOutput];
        
        
        
        NSArray *array = @[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypePDF417Code];
        _metaDataOutput.metadataObjectTypes = array;
    }
        
    return self;
}

- (void)start {
    NSAssert(_onFrameAvailable, @"On Frame Available must be set!");
    NSAssert(_onCodeAvailable, @"On Code Available must be set!");
    [_captureSession startRunning];
}

- (void)stop {
    [_captureSession stopRunning];
}

// This returns a CGImageRef that needs to be released!
- (CGImageRef)cgImageRefFromCMSampleBufferRef:(CMSampleBufferRef)sampleBuffer {
    CIContext *ciContext = [CIContext contextWithOptions:nil];
    CVPixelBufferRef newBuffer1 = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:newBuffer1];
    return [ciContext createCGImage:ciImage fromRect:ciImage.extent];
}

- (void)detectSuccessCallback:(int) type
                       result:(PlateResult*) result
{
    self.finishedDetecting = true;
    self.completeDetect = true;
    
    dispatch_async(_mainQueue, ^{
        self->_onCardAvailable(result.plate);
    });
}

- (void)detectFailureCallback:(NSError*) err
{
    if(err != nil){
        NSLog(@"Error: %@", err);
        self.completeDetect = true;
    }
    self.finishedDetecting = true;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    if (metadataObjects.firstObject != nil && !self.completeDetect && _detectType == 0) {
        AVMetadataMachineReadableCodeObject *code = (AVMetadataMachineReadableCodeObject *) metadataObjects.firstObject;
        if (code != nil) {
            NSLog(@"Found code: %@", code.stringValue);
            self.completeDetect = true;
            dispatch_async(_mainQueue, ^{
                self->_onCodeAvailable(code.stringValue);
            });
        }
    }
}


- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if (self.manuallyCapture) {
        CFRetain(sampleBuffer);
        dispatch_async(_backgroundQueue, ^{
            int intOrientation =(int) [[UIDevice currentDevice] orientation];
                           NSInteger position = _videoCaptureDeviceInput.device.position;
                           if(position == 2) {
                               if(intOrientation == 3) {
                                   intOrientation = 4;
                               }
                               else {
                                   if(intOrientation == 4) {
                                       intOrientation = 3;
                                   }
                               }
                           }
            [[CardDetector sharedInstance] capture:sampleBuffer
                                       orientation:intOrientation
                                         onSuccess:^(PlateResult *result) {[self detectSuccessCallback:(int)self.detectType result:result];}];
        });
        self.manuallyCapture = false;
        return;
    }
    if (self.completeDetect) {
        return;
    }
    CVPixelBufferRef newBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

    CFRetain(newBuffer);
    CVPixelBufferRef old = _latestPixelBuffer;
    while (!OSAtomicCompareAndSwapPtrBarrier(old, newBuffer, (void **)&_latestPixelBuffer)) {
        old = _latestPixelBuffer;
    }
    if (old != nil) {
        CFRelease(old);
    }
    dispatch_sync(_mainQueue, ^{
        self.onFrameAvailable();
    });
    
    if (_detectType == 0 || _detectType == 3) {
        // We already handle QRCode at above function
        return;
    }
    
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval timePassedSinceSubmittingForDetect = [methodFinish timeIntervalSinceDate:self.startDetect];
   
    BOOL canSubmitForDetection = timePassedSinceSubmittingForDetect > 0.5 && _finishedDetecting;
    if (canSubmitForDetection) {
        CFRetain(sampleBuffer);
        dispatch_async(_backgroundQueue, ^{
            self->_finishedDetecting = false;
            self.startDetect = [NSDate date];
            if (self->_detectType != 0) {
                int intOrientation =(int) [[UIDevice currentDevice] orientation];
                NSInteger position = self->_videoCaptureDeviceInput.device.position;
                if(position == 2) {
                    if(intOrientation == 3) {
                        intOrientation = 4;
                    }
                    else {
                        if(intOrientation == 4) {
                            intOrientation = 3;
                        }
                    }
                }
                NSLog(@"DETECT TYPE: %ld", (long)self.detectType);
                [[CardDetector sharedInstance] detect:sampleBuffer
                                           detectType:(int)self.detectType
                                          orientation:intOrientation
                                            onSuccess:^(PlateResult *result) {[self detectSuccessCallback:(int)self.detectType result:result];}
                                            onFailure:^(NSError *err) {[self detectFailureCallback:err];}];
            }
        });
    }
}

- (void)heartBeat {
    // TODO: implement
}
                       
                                              
+ (AVCaptureVideoOrientation)videoOrientationForInterfaceOrientation:(UIInterfaceOrientation)orientation
{
  switch (orientation) {
      case UIInterfaceOrientationPortrait:
          return AVCaptureVideoOrientationPortrait;
      case UIInterfaceOrientationPortraitUpsideDown:
          return AVCaptureVideoOrientationPortraitUpsideDown;
      case UIInterfaceOrientationLandscapeRight:
          return AVCaptureVideoOrientationLandscapeRight;
      case UIInterfaceOrientationLandscapeLeft:
          return AVCaptureVideoOrientationLandscapeLeft;
      default:
          return 0;
  }
}

- (CVPixelBufferRef)copyPixelBuffer {
    CVPixelBufferRef pixelBuffer = _latestPixelBuffer;
    while (!OSAtomicCompareAndSwapPtrBarrier(pixelBuffer, nil, (void **)&_latestPixelBuffer)) {
        pixelBuffer = _latestPixelBuffer;
    }
    return pixelBuffer;
}

- (void)dealloc {
    if (_latestPixelBuffer) {
        CFRelease(_latestPixelBuffer);
    }
}

@end


@interface FlutterQrBarScannerPlugin ()
@property(readonly, nonatomic) NSObject<FlutterTextureRegistry> *registry;
@property(readonly, nonatomic) FlutterMethodChannel *channel;

@property(readonly, nonatomic) QrReader *reader;
@property(readonly, nonatomic) int detectType;
@end

@implementation FlutterQrBarScannerPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"com.github.contactlutforrahman/flutter_qr_bar_scanner"
                                     binaryMessenger:[registrar messenger]];
    FlutterQrBarScannerPlugin* instance = [[FlutterQrBarScannerPlugin alloc] initWithRegistry:[registrar textures] channel:channel];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithRegistry:(NSObject<FlutterTextureRegistry> *)registry
                         channel:(FlutterMethodChannel *)channel {
    self = [super init];
    NSAssert(self, @"super init cannot be nil");
    _registry = registry;
    _channel = channel;
    _reader = nil;
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
    if ([@"start" isEqualToString:call.method]) {
        // NSNumber *heartbeatTimeout = call.arguments[@"heartbeatTimeout"];
        NSNumber *targetHeight = call.arguments[@"targetHeight"];
        NSNumber *targetWidth = call.arguments[@"targetWidth"];
        NSNumber *targetDetectType = call.arguments[@"detectType"];
        _detectType = [targetDetectType intValue];
        if (_detectType == nil) {
            _detectType = 0;
        }
        
        if (targetHeight == nil || targetWidth == nil) {
            result([FlutterError errorWithCode:@"INVALID_ARGS"
                                       message: @"Missing a required argument"
                                       details: @"Expecting targetHeight, targetWidth, and optionally heartbeatTimeout"]);
            return;
        }
        [self startWithCallback:^(int height, int width, int orientation, int64_t textureId, int detectType) {
            result(@{
                     @"surfaceHeight": @(height),
                     @"surfaceWidth": @(width),
                     @"surfaceOrientation": @(orientation),
                     @"textureId": @(textureId),
                     @"detectType": @(detectType)
                     });
        } orFailure: ^ (NSError *error) {
            result(error.flutterError);
        }];
    } else if ([@"stop" isEqualToString:call.method]) {
        [self stop];
        result(nil);
    } else if ([@"heartbeat" isEqualToString:call.method]) {
        [self heartBeat];
        result(nil);
    } else if ([@"pause" isEqualToString:call.method]) {
        [self pause];
    } else if ([@"resume" isEqualToString:call.method]) {
        [self resume];
    } else if ([@"capture" isEqualToString:call.method]) {
        [self capture];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)startWithCallback:(void (^)(int height, int width, int orientation, int64_t textureId, int detectType))completedCallback orFailure:(void (^)(NSError *))failureCallback {
    
    if (_reader) {
        failureCallback([NSError errorWithDomain:@"flutter_qr_bar_scanner" code:1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Reader already running.", nil)}]);
        return;
    }

    NSError* localError = nil;
    _reader = [[QrReader alloc] initWithErrorRef: &localError];
    
    _reader.detectType = _detectType;

    if (localError) {
        failureCallback(localError);
        return;
    }

    NSObject<FlutterTextureRegistry> * __weak registry = _registry;
    int64_t textureId = [_registry registerTexture:_reader];
    _reader.onFrameAvailable = ^{
        [registry textureFrameAvailable:textureId];
    };

    FlutterMethodChannel * __weak channel = _channel;
    _reader.onCodeAvailable = ^(NSString *value) {
        [channel invokeMethod:@"qrRead" arguments: value];
    };
    _reader.onCardAvailable = ^(NSString *value) {
        [channel invokeMethod:@"cardRead" arguments: value];
    };

    [_reader start];

    ///////// texture, width, height
    completedCallback(_reader.previewSize.width, _reader.previewSize.height, 0, textureId, _detectType);
}

- (void)stop {
    if (_reader) {
        [_reader stop];
        _reader = nil;
    }
}

- (void)heartBeat {
    if (_reader) {
        [_reader heartBeat];
    }
}

- (void)pause {
    if (_reader) {
        [_reader setCompleteDetect:true];
    }
}

- (void)resume {
    if (_reader) {
        [_reader setCompleteDetect:false];
    }
}

- (void)capture {
    if (_reader) {
        [_reader setManuallyCapture:true];
        [_reader setCompleteDetect:true];
    }
}


                       
@end
