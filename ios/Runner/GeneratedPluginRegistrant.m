//
//  Generated file. Do not edit.
//

#import "GeneratedPluginRegistrant.h"

#if __has_include(<native_device_orientation/NativeDeviceOrientationPlugin.h>)
#import <native_device_orientation/NativeDeviceOrientationPlugin.h>
#else
@import native_device_orientation;
#endif

#if __has_include(<flutter_qr_bar_scanner/FlutterQrBarScannerPlugin.h>)
#import <flutter_qr_bar_scanner/FlutterQrBarScannerPlugin.h>
#else
@import flutter_qr_bar_scanner;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [NativeDeviceOrientationPlugin registerWithRegistrar:[registry registrarForPlugin:@"NativeDeviceOrientationPlugin"]];
  [FlutterQrBarScannerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterQrBarScannerPlugin"]];
}

@end
