import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_qr_bar_scanner/flutter_qr_bar_scanner.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

final WidgetBuilder _defaultNotStartedBuilder =
    (context) => new Text("Loading Scanner Camera...");
final WidgetBuilder _defaultOffscreenBuilder =
    (context) => new Text("Scanner Camera Paused.");
final ErrorCallback _defaultOnError = (BuildContext context, Object error) {
  print("Error reading from scanner camera: $error");
  return new Text("Error reading from scanner camera...");
};

typedef Widget ErrorCallback(BuildContext context, Object error);

class QRBarScannerCamera extends StatefulWidget {
  QRBarScannerCamera({
    Key key,
    @required this.qrCodeCallback,
    @required this.cardCallback,
    this.child,
    this.fit = BoxFit.cover,
    WidgetBuilder notStartedBuilder,
    WidgetBuilder offscreenBuilder,
    ErrorCallback onError,
    this.formats,
    this.detectType = 1,
    this.isPaused,
    this.isInitialzed,
  })  : notStartedBuilder = notStartedBuilder ?? _defaultNotStartedBuilder,
        offscreenBuilder =
            offscreenBuilder ?? notStartedBuilder ?? _defaultOffscreenBuilder,
        onError = onError ?? _defaultOnError,
        assert(fit != null),
        super(key: key);

  final BoxFit fit;
  final ValueChanged<String> qrCodeCallback;
  final ValueChanged<String> cardCallback;
  final Widget child;
  final WidgetBuilder notStartedBuilder;
  final WidgetBuilder offscreenBuilder;
  final ErrorCallback onError;
  final List<BarcodeFormats> formats;
  final ValueNotifier<bool> isPaused;
  final ValueNotifier<bool> isInitialzed;
  final int detectType;

  @override
  QRBarScannerCameraState createState() => new QRBarScannerCameraState();
}

class QRBarScannerCameraState extends State<QRBarScannerCamera>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isPaused != null) {
      widget.isPaused.addListener(() {
        if (widget.isPaused.value) {
          stop();
        } else {
          resume();
        }
      });
    }
  }

  @override
  dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => onScreen = true);
    } else {
      if (_asyncInitOnce != null && onScreen) {
        FlutterQrReader.stop();
      }
      setState(() {
        onScreen = false;
        _asyncInitOnce = null;
      });
    }
  }

  bool onScreen = true;
  Future<PreviewDetails> _asyncInitOnce;

  Future<PreviewDetails> _asyncInit(num height, num width) async {
    var previewDetails = await FlutterQrReader.start(
      height: height.toInt(),
      width: width.toInt(),
      qrCodeHandler: widget.qrCodeCallback,
      formats: widget.formats,
      cardHandler: widget.cardCallback,
      detectType: widget.detectType,
    );
    return previewDetails;
  }

  /// This method can be used to restart scanning
  ///  the event that it was paused.
  void restart() {
    (() async {
      await FlutterQrReader.stop();
      setState(() {
        _asyncInitOnce = null;
      });
    })();
  }

  void resume() {
    setState(() {
      _asyncInitOnce = null;
    });
  }

  /// This method can be used to manually stop the
  /// camera.
  void stop() {
    (() async {
      await FlutterQrReader.stop();
    })();
  }

  @override
  deactivate() {
    super.deactivate();
    FlutterQrReader.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
          if (_asyncInitOnce == null && onScreen) {
            _asyncInitOnce =
                _asyncInit(constraints.maxHeight, constraints.maxWidth);
          } else if (!onScreen) {
            return widget.offscreenBuilder(context);
          }

          return new FutureBuilder(
            future: _asyncInitOnce,
            builder:
                (BuildContext context, AsyncSnapshot<PreviewDetails> details) {
              switch (details.connectionState) {
                case ConnectionState.none:
                case ConnectionState.waiting:
                  return widget.notStartedBuilder(context);
                case ConnectionState.done:
                  if (widget.isInitialzed != null) {
                    widget.isInitialzed?.value = true;
                  }
                  if (details.hasError) {
                    debugPrint(details.error.toString());
                    return widget.onError(context, details.error);
                  }
                  Widget preview = new SizedBox(
                    height: constraints.maxHeight,
                    width: constraints.maxWidth,
                    child: PreviewWithFocus(
                      previewDetails: details.data,
                      targetHeight: constraints.maxHeight,
                      targetWidth: constraints.maxWidth,
                      fit: widget.fit,
                    ),
                  );

                  if (widget.child != null) {
                    return new Stack(
                      children: [
                        preview,
                        widget.child,
                      ],
                    );
                  }
                  return preview;

                default:
                  if (widget.isInitialzed != null) {
                    widget.isInitialzed?.value = true;
                  }
                  throw new AssertionError(
                      "${details.connectionState} not supported.");
              }
            },
          );
        }),
      ),
    );
  }
}

class PreviewWithFocus extends StatefulWidget {
  final double height;
  final double width;
  final double targetWidth, targetHeight;
  final int textureId;
  final int orientation;
  final BoxFit fit;

  PreviewWithFocus({
    @required PreviewDetails previewDetails,
    @required this.targetHeight,
    @required this.targetWidth,
    @required this.fit,
  })  : assert(previewDetails != null),
        textureId = previewDetails.textureId,
        height = previewDetails.height.toDouble(),
        width = previewDetails.width.toDouble(),
        orientation = previewDetails.orientation;
  @override
  _PreviewWithFocusState createState() => _PreviewWithFocusState();
}

class _PreviewWithFocusState extends State<PreviewWithFocus> {
  bool isManuallyFocus = false;
  int focusX = -1;
  int focusY = -1;
  Timer manuallyFocusStateTimer;

  void setUpDisplayTimeForManuallyFocus() {
    manuallyFocusStateTimer?.cancel();
    manuallyFocusStateTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          isManuallyFocus = false;
        });
      }
    });
  }

  @override
  void dispose() {
    manuallyFocusStateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double frameHeight, frameWidth;

    return new NativeDeviceOrientationReader(
      builder: (context) {
        var nativeOrientation =
            NativeDeviceOrientationReader.orientation(context);

        int baseOrientation = 0;
        if (widget.orientation != 0 && (widget.width > widget.height)) {
          baseOrientation = widget.orientation ~/ 90;
          frameHeight = widget.height;
          frameWidth = widget.width;
        } else {
          frameWidth = widget.height;
          frameHeight = widget.width;
        }

        int nativeOrientationInt;
        switch (nativeOrientation) {
          case NativeDeviceOrientation.landscapeLeft:
            nativeOrientationInt = Platform.isAndroid ? 3 : 1;
            break;
          case NativeDeviceOrientation.landscapeRight:
            nativeOrientationInt = Platform.isAndroid ? 1 : 3;
            break;
          case NativeDeviceOrientation.portraitDown:
            nativeOrientationInt = 2;
            break;
          case NativeDeviceOrientation.portraitUp:
          case NativeDeviceOrientation.unknown:
            nativeOrientationInt = 0;
        }

        final manuallyFocusWindowSize =
            min(widget.width / 10, widget.height / 10);

        return GestureDetector(
          onTapDown: (detail) {
            if (Platform.isAndroid) {
              FlutterQrReader.focus(detail.localPosition.dx.toInt(),
                  detail.localPosition.dy.toInt());
              setState(() {
                isManuallyFocus = true;
                focusX = detail.localPosition.dx.toInt();
                focusY = detail.localPosition.dy.toInt();
              });
              setUpDisplayTimeForManuallyFocus();
              print(
                  "Focusing at: ${detail.localPosition.dx}-${detail.localPosition.dy}");
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              new FittedBox(
                fit: widget.fit,
                child: new RotatedBox(
                  quarterTurns: baseOrientation + nativeOrientationInt,
                  child: Platform.isAndroid
                      ? SizedBox(
                          height: frameHeight,
                          width: frameWidth,
                          child: Texture(
                            textureId: widget.textureId,
                          ),
                        )
                      : SizedBox(
                          height: widget.height,
                          width: widget.width,
                          child: Texture(
                            textureId: widget.textureId,
                          ),
                        ),
                ),
              ),
              isManuallyFocus
                  ? Positioned(
                      left: max(focusX - manuallyFocusWindowSize / 2, 0)
                          .toDouble(),
                      top: max(focusY - manuallyFocusWindowSize / 2, 0)
                          .toDouble(),
                      width: manuallyFocusWindowSize,
                      height: manuallyFocusWindowSize,
                      child: Image.asset(
                        "assets/ic_focus.png",
                        width: manuallyFocusWindowSize,
                        height: manuallyFocusWindowSize,
                        package: "flutter_qr_bar_scanner",
                        color: Colors.white,
                      ),
                    )
                  : Container(
                      width: 0,
                      height: 0,
                    ),
            ],
          ),
        );
      },
    );
  }
}

class Preview extends StatelessWidget {
  final double height;
  final double width;
  final double targetWidth, targetHeight;
  final int textureId;
  final int orientation;
  final BoxFit fit;

  Preview({
    @required PreviewDetails previewDetails,
    @required this.targetHeight,
    @required this.targetWidth,
    @required this.fit,
  })  : assert(previewDetails != null),
        textureId = previewDetails.textureId,
        height = previewDetails.height.toDouble(),
        width = previewDetails.width.toDouble(),
        orientation = previewDetails.orientation;

  @override
  Widget build(BuildContext context) {
    double frameHeight, frameWidth;

    return new NativeDeviceOrientationReader(
      builder: (context) {
        var nativeOrientation =
            NativeDeviceOrientationReader.orientation(context);

        int baseOrientation = 0;
        if (orientation != 0 && (width > height)) {
          baseOrientation = orientation ~/ 90;
          frameHeight = height;
          frameWidth = width;
        } else {
          frameWidth = height;
          frameHeight = width;
        }

        int nativeOrientationInt;
        switch (nativeOrientation) {
          case NativeDeviceOrientation.landscapeLeft:
            nativeOrientationInt = Platform.isAndroid ? 3 : 1;
            break;
          case NativeDeviceOrientation.landscapeRight:
            nativeOrientationInt = Platform.isAndroid ? 1 : 3;
            break;
          case NativeDeviceOrientation.portraitDown:
            nativeOrientationInt = 2;
            break;
          case NativeDeviceOrientation.portraitUp:
          case NativeDeviceOrientation.unknown:
            nativeOrientationInt = 0;
        }

        return GestureDetector(
          onTap: () {
            print("Tapped on Camera preview");
          },
          onTapDown: (detail) {
            FlutterQrReader.focus(detail.localPosition.dx.toInt(),
                detail.localPosition.dy.toInt());
          },
          child: new FittedBox(
            fit: fit,
            child: new RotatedBox(
              quarterTurns: baseOrientation + nativeOrientationInt,
              child: Platform.isAndroid
                  ? SizedBox(
                      height: frameHeight,
                      width: frameWidth,
                      child: Texture(
                        textureId: textureId,
                      ),
                    )
                  : SizedBox(
                      height: height,
                      width: width,
                      child: Texture(
                        textureId: textureId,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
