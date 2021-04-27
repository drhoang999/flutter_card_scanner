package com.github.contactlutforrahman.flutter_qr_bar_scanner;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.pm.PackageManager;
import androidx.core.app.ActivityCompat;

import android.util.DisplayMetrics;
import android.util.Log;

import org.jetbrains.annotations.NotNull;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.view.TextureRegistry;

import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;


/**
 * FlutterQrBarScannerPlugin
 */
public class FlutterQrBarScannerPlugin implements MethodCallHandler, QrReaderCallbacks, CardReaderCallbacks,QrReader.QRReaderStartedCallback, PluginRegistry.RequestPermissionsResultListener {

    private static final String TAG = "cgl.fqs.FlutterQrBarScannerPlugin";
    private static final int REQUEST_PERMISSION = 1;
    private final MethodChannel channel;
    private final Activity context;
    private final TextureRegistry textures;
    private Integer lastHeartbeatTimeout;
    private boolean waitingForPermissionResult;
    private boolean permissionDenied;
    private ReadingInstance readingInstance;
    private int screenWidth;
    private int screenHeight;

    public FlutterQrBarScannerPlugin(MethodChannel channel, Activity context, TextureRegistry textures) {
        this.textures = textures;
        this.channel = channel;
        this.context = context;
        DisplayMetrics displayMetrics = new DisplayMetrics();
        context.getWindowManager().getDefaultDisplay().getMetrics(displayMetrics);
        screenHeight = displayMetrics.heightPixels;
        screenWidth = displayMetrics.widthPixels;
    }

    public FlutterQrBarScannerPlugin(MethodChannel channel, Activity context, TextureRegistry textures, int screenHeight, int screenWidth) {
        this.textures = textures;
        this.channel = channel;
        this.context = context;
        this.screenHeight = screenHeight;
        this.screenWidth = screenWidth;
    }

    public static FlutterQrBarScannerPlugin getInstance(MethodChannel channel, Activity context, TextureRegistry textures) {
        int screenHeight = 0;
        int screenWidth = 0;
        try {
            DisplayMetrics displayMetrics = new DisplayMetrics();
            context.getWindowManager().getDefaultDisplay().getMetrics(displayMetrics);
            screenHeight = displayMetrics.heightPixels;
            screenWidth = displayMetrics.widthPixels;
        } catch (Exception exception) {
            exception.printStackTrace();
        }

        return new FlutterQrBarScannerPlugin(channel, context, textures, screenHeight, screenWidth);
    }

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "com.github.contactlutforrahman/flutter_qr_bar_scanner");
        FlutterQrBarScannerPlugin FlutterQrBarScannerPlugin = getInstance(channel, registrar.activity(), registrar.textures());
        channel.setMethodCallHandler(FlutterQrBarScannerPlugin);
        registrar.addRequestPermissionsResultListener(FlutterQrBarScannerPlugin);
    }

    @SuppressLint("LongLogTag")
    @Override
    public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode == REQUEST_PERMISSION) {
            waitingForPermissionResult = false;
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.i(TAG, "Permissions request granted.");
                stopReader();
            } else {
                Log.i(TAG, "Permissions request denied.");
                permissionDenied = true;
                startingFailed(new QrReader.Exception(QrReader.Exception.Reason.noPermissions));
                stopReader();
            }
            return true;
        }
        return false;
    }

    private void stopReader() {
        readingInstance.reader.stop();
        readingInstance.textureEntry.release();
        readingInstance = null;
        lastHeartbeatTimeout = null;
    }

    private void pauseReader() {
        if (readingInstance.reader.qrCamera instanceof QrCameraC2) {
            readingInstance.reader.qrCamera.completeDetect();
        }
    }

    private void resumeReader() {
        if (readingInstance.reader.qrCamera instanceof QrCameraC2) {
            readingInstance.reader.qrCamera.resumeDetect();
        }
    }

    private void captureReader() {
        if (readingInstance.reader.qrCamera instanceof QrCameraC2) {
            readingInstance.reader.qrCamera.capture();
        }
    }

    @Override
    public void onMethodCall(MethodCall methodCall, Result result) {
        switch (methodCall.method) {
            case "start": {
                if (permissionDenied) {
                    permissionDenied = false;
                    result.error("QRREADER_ERROR", "noPermission", null);
                } else if (readingInstance != null) {
                    // stopReader();
                    // result.error("ALREADY_RUNNING", "Start cannot be called when already running", "");
                    lastHeartbeatTimeout = methodCall.argument("heartbeatTimeout");
                    Integer targetWidth = methodCall.argument("targetWidth");
                    Integer targetHeight = methodCall.argument("targetHeight");
                    Integer detectType = methodCall.argument("detectType");
                    detectType = detectType != null ? detectType : 0;
                    List<String> formatStrings = methodCall.argument("formats");

                    if (targetWidth == null || targetHeight == null) {
                        result.error("INVALID_ARGUMENT", "Missing a required argument", "Expecting targetWidth, targetHeight, and optionally heartbeatTimeout");
                        break;
                    }

                    targetWidth = targetWidth < screenWidth ? screenWidth : targetWidth;
                    targetHeight = targetHeight < screenHeight ? screenHeight : targetHeight;

                    int barcodeFormats = BarcodeFormats.intFromStringList(formatStrings);

                    TextureRegistry.SurfaceTextureEntry textureEntry = textures.createSurfaceTexture();
                    QrReader reader = new QrReader(targetWidth, targetHeight, DetectType.values()[detectType], context, barcodeFormats,
                        this, this, this, textureEntry.surfaceTexture());

                    readingInstance = new ReadingInstance(reader, textureEntry, result);
                    try {
                        reader.start(
                            lastHeartbeatTimeout == null ? 0 : lastHeartbeatTimeout
                        );
                    } catch (IOException e) {
                        e.printStackTrace();
                        result.error("IOException", "Error starting camera because of IOException: " + e.getLocalizedMessage(), null);
                    } catch (QrReader.Exception e) {
                        e.printStackTrace();
                        result.error(e.reason().name(), "Error starting camera for reason: " + e.reason().name(), null);
                    } catch (NoPermissionException e) {
                        waitingForPermissionResult = true;
                        ActivityCompat.requestPermissions(context,
                            new String[]{Manifest.permission.CAMERA}, REQUEST_PERMISSION);
                    }
                } else {
                    lastHeartbeatTimeout = methodCall.argument("heartbeatTimeout");
                    Integer targetWidth = methodCall.argument("targetWidth");
                    Integer targetHeight = methodCall.argument("targetHeight");
                    Integer detectType = methodCall.argument("detectType");
                    detectType = detectType != null ? detectType : 0;

                    List<String> formatStrings = methodCall.argument("formats");

                    if (targetWidth == null || targetHeight == null) {
                        result.error("INVALID_ARGUMENT", "Missing a required argument", "Expecting targetWidth, targetHeight, and optionally heartbeatTimeout");
                        break;
                    }

                    targetWidth = targetWidth < screenWidth ? screenWidth : targetWidth;
                    targetHeight = targetHeight < screenHeight ? screenHeight : targetHeight;

                    int barcodeFormats = BarcodeFormats.intFromStringList(formatStrings);

                    TextureRegistry.SurfaceTextureEntry textureEntry = textures.createSurfaceTexture();
                    QrReader reader = new QrReader(targetWidth, targetHeight, DetectType.values()[detectType], context, barcodeFormats,
                        this, this, this, textureEntry.surfaceTexture());

                    readingInstance = new ReadingInstance(reader, textureEntry, result);
                    try {
                        reader.start(
                            lastHeartbeatTimeout == null ? 0 : lastHeartbeatTimeout
                        );
                    } catch (IOException e) {
                        e.printStackTrace();
                        result.error("IOException", "Error starting camera because of IOException: " + e.getLocalizedMessage(), null);
                    } catch (QrReader.Exception e) {
                        e.printStackTrace();
                        result.error(e.reason().name(), "Error starting camera for reason: " + e.reason().name(), null);
                    } catch (NoPermissionException e) {
                        waitingForPermissionResult = true;
                        ActivityCompat.requestPermissions(context,
                            new String[]{Manifest.permission.CAMERA}, REQUEST_PERMISSION);
                    }
                }
                break;
            }
            case "stop": {
                if (readingInstance != null && !waitingForPermissionResult) {
                    stopReader();
                }
                result.success(null);
                break;
            }
            case "heartbeat": {
                if (readingInstance != null) {
                    readingInstance.reader.heartBeat();
                }
                result.success(null);
                break;
            }
            case "pause":
                if (readingInstance != null && !waitingForPermissionResult) {
                    pauseReader();
                }
                result.success(null);
                break;
            case "resume":
                if (readingInstance != null && !waitingForPermissionResult) {
                    resumeReader();
                }
                result.success(null);
                break;
            case "capture":
                if (readingInstance != null && !waitingForPermissionResult) {
                    captureReader();
                }
                result.success(null);
                break;
            case "focus":
                if (readingInstance != null && !waitingForPermissionResult) {
                    Integer x = methodCall.argument("x");
                    Integer y = methodCall.argument("y");
                    if (x == null || y == null) {
                        result.error("INVALID_ARGUMENT", "Missing a required argument", "Expecting x, y");
                        break;
                    }

                    focusReader(x, y);
                }
                result.success(null);
                break;
            default:
                result.notImplemented();
        }
    }

    private void focusReader(int x, int y) {
        if (readingInstance.reader != null && readingInstance.reader.qrCamera != null) {
            readingInstance.reader.qrCamera.focus(x, y);
        }
    }

    @Override
    public void qrRead(String data) {
        channel.invokeMethod("qrRead", data);
    }

    @Override
    public void started() {
        Map<String, Object> response = new HashMap<>();
        response.put("surfaceWidth", readingInstance.reader.qrCamera.getWidth());
        response.put("surfaceHeight", readingInstance.reader.qrCamera.getHeight());
        response.put("surfaceOrientation", readingInstance.reader.qrCamera.getOrientation());
        response.put("textureId", readingInstance.textureEntry.id());
        readingInstance.startResult.success(response);
    }

    private List<String> stackTraceAsString(StackTraceElement[] stackTrace) {
        if (stackTrace == null) {
            return null;
        }

        List<String> stackTraceStrings = new ArrayList<>(stackTrace.length);
        for (StackTraceElement el : stackTrace) {
            stackTraceStrings.add(el.toString());
        }
        return stackTraceStrings;
    }

    @SuppressLint("LongLogTag")
    @Override
    public void startingFailed(Throwable t) {
        Log.w(TAG, "Starting Flutter Qr Scanner failed", t);
        List<String> stackTraceStrings = stackTraceAsString(t.getStackTrace());

        if (t instanceof QrReader.Exception) {
            QrReader.Exception qrException = (QrReader.Exception) t;
            readingInstance.startResult.error("QRREADER_ERROR", qrException.reason().name(), stackTraceStrings);
        } else {
            readingInstance.startResult.error("UNKNOWN_ERROR", t.getMessage(), stackTraceStrings);
        }
    }

    @Override
    public void cardRead(@NotNull final String data) {
        context.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                channel.invokeMethod("cardRead", data);
            }
        });
    }

    private class ReadingInstance {
        final QrReader reader;
        final TextureRegistry.SurfaceTextureEntry textureEntry;
        final Result startResult;

        private ReadingInstance(QrReader reader, TextureRegistry.SurfaceTextureEntry textureEntry, Result startResult) {
            this.reader = reader;
            this.textureEntry = textureEntry;
            this.startResult = startResult;
        }
    }
}