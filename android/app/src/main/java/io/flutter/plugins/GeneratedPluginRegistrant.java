package io.flutter.plugins;

import io.flutter.plugin.common.PluginRegistry;
import com.github.rmtmckenzie.nativedeviceorientation.NativeDeviceOrientationPlugin;
import com.github.contactlutforrahman.flutter_qr_bar_scanner.FlutterQrBarScannerPlugin;

/**
 * Generated file. Do not edit.
 */
public final class GeneratedPluginRegistrant {
  public static void registerWith(PluginRegistry registry) {
    if (alreadyRegisteredWith(registry)) {
      return;
    }
    NativeDeviceOrientationPlugin.registerWith(registry.registrarFor("com.github.rmtmckenzie.nativedeviceorientation.NativeDeviceOrientationPlugin"));
    FlutterQrBarScannerPlugin.registerWith(registry.registrarFor("com.github.contactlutforrahman.flutter_qr_bar_scanner.FlutterQrBarScannerPlugin"));
  }

  private static boolean alreadyRegisteredWith(PluginRegistry registry) {
    final String key = GeneratedPluginRegistrant.class.getCanonicalName();
    if (registry.hasPlugin(key)) {
      return true;
    }
    registry.registrarFor(key);
    return false;
  }
}
