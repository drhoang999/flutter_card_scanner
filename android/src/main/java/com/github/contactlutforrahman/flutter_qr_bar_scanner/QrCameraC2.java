package com.github.contactlutforrahman.flutter_qr_bar_scanner;

import android.annotation.TargetApi;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.graphics.SurfaceTexture;
import android.graphics.YuvImage;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CameraMetadata;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.TotalCaptureResult;
import android.hardware.camera2.params.MeteringRectangle;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.util.Log;
import android.util.Size;
import android.util.SparseIntArray;
import android.view.Surface;

import java.io.ByteArrayOutputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;

import androidx.annotation.NonNull;

import static android.hardware.camera2.CameraMetadata.CONTROL_AF_MODE_AUTO;
import static android.hardware.camera2.CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_PICTURE;
import static android.hardware.camera2.CameraMetadata.CONTROL_AF_MODE_CONTINUOUS_VIDEO;
import static android.hardware.camera2.CameraMetadata.CONTROL_AF_MODE_OFF;
import static android.hardware.camera2.CameraMetadata.LENS_FACING_BACK;

/**
 * Implements QrCamera using Camera2 API
 */
@TargetApi(21)
class QrCameraC2 implements QrCamera {

    private static final String TAG = "cgl.fqs.QrCameraC2";
    private static final SparseIntArray ORIENTATIONS = new SparseIntArray();

    static {
        ORIENTATIONS.append(Surface.ROTATION_0, 90);
        ORIENTATIONS.append(Surface.ROTATION_90, 0);
        ORIENTATIONS.append(Surface.ROTATION_180, 270);
        ORIENTATIONS.append(Surface.ROTATION_270, 180);
    }

    private final int targetWidth;
    private final int targetHeight;
    private final Context context;
    private final SurfaceTexture texture;
    private Size size;
    private ImageReader reader;
    private CaptureRequest.Builder previewBuilder;
    private CameraCaptureSession previewSession;
    private Size jpegSizes[] = null;
    private QrDetector2 detector;
    private CardDetector cardDetector;
    private int orientation;
    private CameraDevice cameraDevice;
    private CameraCharacteristics cameraCharacteristics;

    private boolean isDetectCard = false;
    private boolean isDetectQr = false;
    private boolean isDetectCompleted = false;
    private boolean manuallyCapture = false;

    QrCameraC2(int width, int height, Context context, SurfaceTexture texture, QrDetector2 detector) {
        this.targetWidth = width;
        this.targetHeight = height;
        this.context = context;
        this.texture = texture;
        this.detector = detector;
        this.isDetectQr = true;
    }

    QrCameraC2(int width, int height, Context context, SurfaceTexture texture, CardDetector detector) {
        this.targetWidth = width;
        this.targetHeight = height;
        this.context = context;
        this.texture = texture;
        this.cardDetector = detector;
        this.isDetectCard = true;
    }

    QrCameraC2(int width, int height, Context context, SurfaceTexture texture) {
        this.targetWidth = width;
        this.targetHeight = height;
        this.context = context;
        this.texture = texture;
    }

    @Override
    public int getWidth() {
        return size.getWidth();
    }

    @Override
    public int getHeight() {
        return size.getHeight();
    }

    @Override
    public void completeDetect() {
        isDetectCompleted = true;
    }

    @Override
    public void resumeDetect() {
        isDetectCompleted = false;
    }

    @Override
    public void capture() {
        manuallyCapture = true;
        isDetectCompleted = true;
    }

    @Override
    public void focus(int x, int y) {
        CameraCaptureSession.CaptureCallback listener = new CameraCaptureSession.CaptureCallback() {
            @Override
            public void onCaptureCompleted(@NonNull CameraCaptureSession session, @NonNull CaptureRequest request, @NonNull TotalCaptureResult result) {
                super.onCaptureCompleted(session, request, result);
                int controlAfTrigger = CameraMetadata.CONTROL_AF_TRIGGER_IDLE;
                try {
                    controlAfTrigger = request.<Integer>get(CaptureRequest.CONTROL_AF_TRIGGER);
                } catch (NullPointerException exception) {
                    exception.printStackTrace();
                }

                if (controlAfTrigger == CameraMetadata.CONTROL_AF_TRIGGER_START) {
                    Log.v(TAG, "Manually focused. Start repeating ...");
                    previewBuilder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_IDLE);
                    try {
                        previewSession.setRepeatingRequest(previewBuilder.build(), this, null);
                    } catch (CameraAccessException e) {
                        e.printStackTrace();
                    }
                }
            }
        };
        Log.v(TAG, "Performing manually focus");
        Rect newRect = new Rect(Math.max(x - 200, 0), Math.max(y - 200, 0), Math.max(x + 200, 0), Math.max(y + 200, 0));
        MeteringRectangle meteringRectangle = new MeteringRectangle(newRect, MeteringRectangle.METERING_WEIGHT_DONT_CARE);
        MeteringRectangle[] areas = new MeteringRectangle[]{ meteringRectangle };
        previewBuilder.set(CaptureRequest.CONTROL_AF_REGIONS, areas);
        previewBuilder.set(CaptureRequest.CONTROL_AF_MODE, CameraMetadata.CONTROL_AF_MODE_AUTO);
        previewBuilder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_START);
        try {
            previewSession.capture(previewBuilder.build(), listener, null);
        } catch (CameraAccessException e) {
            e.printStackTrace();
        }

    }

    @Override
    public int getOrientation() {
        return orientation;
    }

    @Override
    public void start() throws QrReader.Exception {
        CameraManager manager = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);

        if (manager == null) {
            throw new RuntimeException("Unable to get camera manager.");
        }

        String cameraId = null;
        try {
            String[] cameraIdList = manager.getCameraIdList();
            for (String id : cameraIdList) {
                CameraCharacteristics cameraCharacteristics = manager.getCameraCharacteristics(id);
                Integer integer = cameraCharacteristics.get(CameraCharacteristics.LENS_FACING);
                if (integer != null && integer == LENS_FACING_BACK) {
                    cameraId = id;
                    break;
                }
            }
        } catch (CameraAccessException e) {
            Log.w(TAG, "Error getting back camera.", e);
            throw new RuntimeException(e);
        }

        if (cameraId == null) {
            throw new QrReader.Exception(QrReader.Exception.Reason.noBackCamera);
        }

        try {
            cameraCharacteristics = manager.getCameraCharacteristics(cameraId);
            StreamConfigurationMap map = cameraCharacteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
            // it seems as though the orientation is already corrected, so setting to 0
            // orientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION);
            orientation = 0;

            size = getAppropriateSizeV2(map.getOutputSizes(SurfaceTexture.class));
            final Size size2 = getAppropriateSize(map.getOutputSizes(SurfaceTexture.class));
            jpegSizes = map.getOutputSizes(ImageFormat.YUV_420_888);

            manager.openCamera(cameraId, new CameraDevice.StateCallback() {
                @Override
                public void onOpened(@NonNull CameraDevice device) {
                    cameraDevice = device;
                    startCamera();
                }

                @Override
                public void onDisconnected(@NonNull CameraDevice device) {
                }

                @Override
                public void onError(@NonNull CameraDevice device, int error) {
                    Log.w(TAG, "Error opening camera: " + error);
                }
            }, null);
        } catch (CameraAccessException e) {
            Log.w(TAG, "Error getting camera configuration.", e);
        }
    }

    private Integer afMode(CameraCharacteristics cameraCharacteristics) {

        int[] afModes = cameraCharacteristics.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);

        if (afModes == null) {
            return null;
        }

        HashSet<Integer> modes = new HashSet<>(afModes.length * 2);
        for (int afMode : afModes) {
            modes.add(afMode);
        }

        if (modes.contains(CONTROL_AF_MODE_CONTINUOUS_PICTURE)) {
            return CONTROL_AF_MODE_CONTINUOUS_PICTURE;
        } else if (modes.contains(CONTROL_AF_MODE_CONTINUOUS_VIDEO)) {
            return CONTROL_AF_MODE_CONTINUOUS_VIDEO;
        } else if (modes.contains(CONTROL_AF_MODE_AUTO)) {
            return CONTROL_AF_MODE_AUTO;
        } else {
            return CONTROL_AF_MODE_OFF;
        }
    }

    private void startCamera() {
        List<Surface> list = new ArrayList<>();

        Size jpegSize = getAppropriateSizeV2(jpegSizes);

        final int width = jpegSize.getWidth(), height = jpegSize.getHeight();
        reader = ImageReader.newInstance(width, height, ImageFormat.YUV_420_888, 5);

        list.add(reader.getSurface());

        ImageReader.OnImageAvailableListener imageAvailableListener = new ImageReader.OnImageAvailableListener() {
            @Override
            public void onImageAvailable(ImageReader reader) {
                try (Image image = reader.acquireLatestImage()) {
                    if (image == null) return;
                    if (manuallyCapture) {
                        cardDetector.setManuallyCapture(true);
                        manuallyCapture = false;
                    }
                    else if (isDetectCompleted) {
                        return;
                    }

                    if (isDetectCard) {
                        cardDetector.detect(image);
                    }
                    else if (isDetectQr) {
                        detector.detect(image);
                    }
                } catch (Throwable t) {
                    t.printStackTrace();
                }
            }
        };

        reader.setOnImageAvailableListener(imageAvailableListener, null);

        texture.setDefaultBufferSize(size.getWidth(), size.getHeight());
        list.add(new Surface(texture));
        try {
            previewBuilder = cameraDevice.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
            previewBuilder.addTarget(list.get(0));
            previewBuilder.addTarget(list.get(1));

            Integer afMode = afMode(cameraCharacteristics);

            previewBuilder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO);
            previewBuilder.set(CaptureRequest.LENS_FOCUS_DISTANCE, 16f);

            if (afMode != null) {
                previewBuilder.set(CaptureRequest.CONTROL_AF_MODE, afMode);
                if (afMode == CONTROL_AF_MODE_AUTO) {
                    previewBuilder.set(CaptureRequest.CONTROL_AF_TRIGGER, CaptureRequest.CONTROL_AF_TRIGGER_START);
                }
                else {
                    previewBuilder.set(CaptureRequest.CONTROL_AF_TRIGGER, CaptureRequest.CONTROL_AF_TRIGGER_IDLE);
                }

                Log.i(TAG, "Setting af mode to: " + afMode);
            }

        } catch (java.lang.Exception e) {
            e.printStackTrace();
            return;
        }

        try {
            cameraDevice.createCaptureSession(list, new CameraCaptureSession.StateCallback() {
                @Override
                public void onConfigured(@NonNull CameraCaptureSession session) {
                    previewSession = session;
                    startPreview();
                }

                @Override
                public void onConfigureFailed(@NonNull CameraCaptureSession session) {
                    System.out.println("### Configuration Fail ###");
                }
            }, null);
        } catch (Throwable t) {
            t.printStackTrace();

        }
    }

    private void startPreview() {
        CameraCaptureSession.CaptureCallback listener = new CameraCaptureSession.CaptureCallback() {
            @Override
            public void onCaptureCompleted(@NonNull CameraCaptureSession session, @NonNull CaptureRequest request, @NonNull TotalCaptureResult result) {
                super.onCaptureCompleted(session, request, result);
                if (request.get(CaptureRequest.CONTROL_AF_TRIGGER) == CameraMetadata.CONTROL_AF_TRIGGER_START) {
                    previewBuilder.set(CaptureRequest.CONTROL_AF_TRIGGER, CameraMetadata.CONTROL_AF_TRIGGER_IDLE);
                    try {
                        previewSession.setRepeatingRequest(previewBuilder.build(), this, null);
                    } catch (CameraAccessException e) {
                        e.printStackTrace();
                    }
                }
            }
        };

        if (cameraDevice == null) return;

        try {

            previewSession.setRepeatingRequest(previewBuilder.build(), listener, null);
        } catch (java.lang.Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void stop() {
        if (cameraDevice != null) {
            cameraDevice.close();
        }
        if (reader != null) {
            reader.close();
        }
    }

    private Size getAppropriateSizeV2(Size[] sizes) {
        if (sizes.length == 1) {
            return sizes[0];
        }

        int bestWidth = 0, bestHeight = 0;
        float aspect = (float)targetHeight / targetWidth;
        for (Size psize : sizes) {
            int w = psize.getWidth(), h = psize.getHeight();
            float diff = Math.abs(aspect - (float)w/h);
            Log.d(TAG, "trying size: "+w+"x"+h + " aspect " + aspect+ " - target: " + targetHeight + " " + targetWidth);
            Log.d(TAG, "Best: " + bestWidth + " " + bestHeight + " - Aspect diff: " + diff);
            if (bestWidth <= w && bestHeight <= h && diff < 0.2  && targetWidth >= h && targetHeight >= targetWidth) {
                Log.d(TAG,"Match: " + w + "-" + h);
                bestWidth = w;
                bestHeight = h;
            }
        }
        Log.i(TAG, "best size: "+bestWidth+"x"+bestHeight);
        if( bestWidth == 0 || bestHeight == 0)
            return sizes[0];
        else {
            return new Size(bestWidth, bestHeight);
        }
    }

    private Size getAppropriateSize(Size[] sizes) {
        // assume sizes is never 0
        if (sizes.length == 1) {
            return sizes[0];
        }

        Size s = sizes[0];
        Size s1 = sizes[1];

        if (s1.getWidth() > s.getWidth() || s1.getHeight() > s.getHeight()) {
            // ascending
            if (orientation % 180 == 0) {
                for (Size size : sizes) {
                    s = size;
                    if (size.getHeight() > targetHeight && size.getWidth() > targetWidth) {
                        break;
                    }
                }
            } else {
                for (Size size : sizes) {
                    s = size;
                    if (size.getHeight() > targetWidth && size.getWidth() > targetHeight) {
                        break;
                    }
                }
            }
        } else {
            // descending
            if (orientation % 180 == 0) {
                for (Size size : sizes) {
                    if (size.getHeight() < targetHeight || size.getWidth() < targetWidth) {
                        break;
                    }
                    s = size;
                }
            } else {
                for (Size size : sizes) {
                    if (size.getHeight() < targetWidth || size.getWidth() < targetHeight) {
                        break;
                    }
                    s = size;
                }
            }
        }
        return s;
    }


}
