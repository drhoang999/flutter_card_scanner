Pod::Spec.new do |s|
  s.name             = 'flutter_qr_bar_scanner'
  s.version          = '0.0.1'
  s.summary          = "A Plugin for reading/scanning QR & Bar codes"
  s.description      = <<-DESC
A Plugin for reading/scanning QR & Bar codes.
                       DESC
  s.homepage         = 'https://github.com/contactlutforrahman/flutter_qr_bar_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Lutfor Rahman' => 'contact.lutforrahman@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'

  s.ios.deployment_target = '9.0'
  
  s.prefix_header_contents = <<-EOS

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
// And more if you need, like:
#import <opencv2/core/core.hpp>
#import <opencv2/imgcodecs/ios.h>
#endif

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif

#ifndef PrefixHeader_pch
#define PrefixHeader_pch
#endif
EOS
  # s.libraries = 'c++', 'z'
  s.libraries         = 'z', 'bz2', 'c++', 'iconv'
  s.xcconfig = { 'FRAMEWORK_SEARCH_PATHS' => '"${PODS_ROOT}/../"' }

  s.weak_framework = 'opencv2'
  s.static_framework = true
end
