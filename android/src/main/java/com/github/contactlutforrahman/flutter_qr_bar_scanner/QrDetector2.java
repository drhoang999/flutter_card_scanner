package com.github.contactlutforrahman.flutter_qr_bar_scanner;

import android.annotation.TargetApi;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.graphics.YuvImage;
import android.media.Image;
import android.os.AsyncTask;
import android.os.Build;
import android.util.Log;
import android.util.SparseArray;

import androidx.annotation.RequiresApi;

import com.google.android.gms.vision.Detector;
import com.google.android.gms.vision.Frame;
import com.google.android.gms.vision.barcode.Barcode;
import com.google.android.gms.vision.barcode.BarcodeDetector;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.BinaryBitmap;
import com.google.zxing.DecodeHintType;
import com.google.zxing.MultiFormatReader;
import com.google.zxing.NotFoundException;
import com.google.zxing.PlanarYUVLuminanceSource;
import com.google.zxing.Result;
import com.google.zxing.common.HybridBinarizer;

import java.io.ByteArrayOutputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.lang.ref.WeakReference;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.EnumMap;
import java.util.EnumSet;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

/**
 * Allows QrCamera classes to send frames to a Detector
 */
@TargetApi(21)
class QrDetector2 {
    private static final String TAG = "cgl.fqs.QrDetector";
    public final QrReaderCallbacks communicator;
    private final Detector<Barcode> detector;
    private final Lock imageToCheckLock = new ReentrantLock();
    private final Lock nextImageLock = new ReentrantLock();
    private final AtomicBoolean isScheduled = new AtomicBoolean(false);
    private final AtomicBoolean needsScheduling = new AtomicBoolean(false);
    private final Context context;
    private final Frame.Builder frameBuilder = new Frame.Builder();
    private long lastEvent = System.currentTimeMillis();

    MultiFormatReader multiFormatReader = new MultiFormatReader();


    private final AtomicBoolean nextImageSet = new AtomicBoolean(false);

    private QrImage imageToCheck = new QrImage();
    private QrImage nextImage = new QrImage();

    QrDetector2(QrReaderCallbacks communicator, Context context, int formats) {

        Log.i(TAG, "Making detector2 for formats: " + formats);
        this.communicator = communicator;
        this.detector = new BarcodeDetector.Builder(context.getApplicationContext()).setBarcodeFormats(formats).build();
        this.context = context;
        EnumMap<DecodeHintType, Object> hints = new EnumMap<>(DecodeHintType.class);
        EnumSet<BarcodeFormat> decodeFormats = EnumSet.noneOf(BarcodeFormat.class);
        hints.put(DecodeHintType.POSSIBLE_FORMATS, decodeFormats);
        this.multiFormatReader.setHints(hints);
    }

    public void maybeStartProcessing() {
        // start processing, only if scheduling is needed and
        // there isn't currently a scheduled task.
        if (needsScheduling.get() && !isScheduled.get()) {
            isScheduled.set(true);
            new BarcodeScanAsyncTask(this, this.multiFormatReader,imageToCheck.toNv21(false),imageToCheck.width, imageToCheck.height ).executeOnExecutor(AsyncTask.SERIAL_EXECUTOR);
        }
    }

    void detect(Image image) {
        needsScheduling.set(true);

        if (imageToCheckLock.tryLock()) {
            // copy image if not in use
            try {
                nextImageSet.set(false);
                imageToCheck.copyImage(image);
            } finally {
                imageToCheckLock.unlock();
            }
        } else if (nextImageLock.tryLock()) {
            // if first image buffer is in use, use second buffer
            // one or the other should always be free but if not this
            // frame is dropped..
            try {
                nextImageSet.set(true);
                nextImage.copyImage(image);
            } finally {
                nextImageLock.unlock();
            }
        }
        maybeStartProcessing();
    }

//    static class QrImage {
//        int width;
//        int height;
//        int yPlanePixelStride;
//        int uPlanePixelStride;
//        int vPlanePixelStride;
//        int yPlaneRowStride;
//        int uPlaneRowStride;
//        int vPlaneRowStride;
//        byte[] yPlaneBytes = new byte[0];
//        byte[] uPlaneBytes = new byte[0];
//        byte[] vPlaneBytes = new byte[0];
//
//        void copyImage(Image image) {
//            Image.Plane[] planes = image.getPlanes();
//            Image.Plane yPlane = planes[0];
//            Image.Plane uPlane = planes[1];
//            Image.Plane vPlane = planes[2];
//
//            ByteBuffer yBufferDirect = yPlane.getBuffer(),
//                uBufferDirect = uPlane.getBuffer(),
//                vBufferDirect = vPlane.getBuffer();
//
//            if (yPlaneBytes.length != yBufferDirect.capacity()) {
//                yPlaneBytes = new byte[yBufferDirect.capacity()];
//            }
//            if (uPlaneBytes.length != uBufferDirect.capacity()) {
//                uPlaneBytes = new byte[uBufferDirect.capacity()];
//            }
//            if (vPlaneBytes.length != vBufferDirect.capacity()) {
//                vPlaneBytes = new byte[vBufferDirect.capacity()];
//            }
//
//            yBufferDirect.get(yPlaneBytes);
//            uBufferDirect.get(uPlaneBytes);
//            vBufferDirect.get(vPlaneBytes);
//
//            width = image.getWidth();
//            height = image.getHeight();
//
//            yPlanePixelStride = yPlane.getPixelStride();
//            uPlanePixelStride = uPlane.getPixelStride();
//            vPlanePixelStride = vPlane.getPixelStride();
//
//            yPlaneRowStride = yPlane.getRowStride();
//            uPlaneRowStride = uPlane.getRowStride();
//            vPlaneRowStride = vPlane.getRowStride();
//        }
//
//        private ByteBuffer toNv21(boolean greyScale) {
//            int halfWidth = width / 2;
//            int numPixels = width * height;
//
//            byte[] nv21ImageBytes = new byte[numPixels * 2];
//
//            if (greyScale) {
//                Arrays.fill(nv21ImageBytes, (byte) 127);
//            }
//
//            ByteBuffer nv21Buffer = ByteBuffer.wrap(nv21ImageBytes);
//
//            for (int i = 0; i < height; ++i) {
//                nv21Buffer.put(yPlaneBytes, i * yPlaneRowStride, width);
//            }
//
//            if (!greyScale) {
//                for (int row = 0; row < height / 2; ++row) {
//                    int uRow = row * uPlaneRowStride, vRow = row * vPlaneRowStride;
//                    for (int count = 0, u = 0, v = 0; count < halfWidth; u += uPlanePixelStride, v += vPlanePixelStride, count++) {
//                        nv21Buffer.put(uPlaneBytes[uRow + u]);
//                        nv21Buffer.put(vPlaneBytes[vRow + v]);
//                    }
//                }
//            }
//
//            return nv21Buffer;
//        }
//    }

    static class QrImage {
        private byte[] data = new byte[0];
        private int width = 0;
        private int height = 0;

        @RequiresApi(Build.VERSION_CODES.KITKAT)
        void copyImage(Image image) {
            width = image.getWidth();
            height = image.getHeight();
            data = Utils.YUV420toNV21(image);
        }

        byte[] toNv21(Boolean greyScale) {
            return data;
        }
    }

    private static class QrTaskV2 extends AsyncTask<Void, Void, SparseArray<Barcode>> {

        private final WeakReference<QrDetector2> qrDetector;
        private final WeakReference<Frame.Builder> frameBuilder;

        private QrTaskV2(QrDetector2 qrDetector, Frame.Builder frameBuilder) {
            this.qrDetector = new WeakReference<>(qrDetector);
            this.frameBuilder = new WeakReference<>(frameBuilder);
        }

        @Override
        protected SparseArray<Barcode> doInBackground(Void... voids) {

            QrDetector2 qrDetector = this.qrDetector.get();
            if (qrDetector == null) return null;

            qrDetector.needsScheduling.set(false);
            qrDetector.isScheduled.set(false);

            ByteBuffer imageBuffer;
            int width;
            int height;
            if (qrDetector.nextImageSet.get()) {
                try {
                    qrDetector.nextImageLock.lock();
                    imageBuffer = ByteBuffer.wrap(qrDetector.nextImage.toNv21(false));
                    width = qrDetector.nextImage.width;
                    height = qrDetector.nextImage.height;
                } finally {
                    qrDetector.nextImageLock.unlock();
                }
            } else {
                try {
                    qrDetector.imageToCheckLock.lock();
                    imageBuffer = ByteBuffer.wrap(qrDetector.nextImage.toNv21(false));
                    width = qrDetector.imageToCheck.width;
                    height = qrDetector.imageToCheck.height;
                } finally {
                    qrDetector.imageToCheckLock.unlock();
                }
            }

            byte[] data = new byte[imageBuffer.remaining()];
            imageBuffer.get(data);

//            YuvImage yuvImage = new YuvImage(data, ImageFormat.NV21, width, height, null);
//            ByteArrayOutputStream os = new ByteArrayOutputStream();
//            yuvImage.compressToJpeg(new Rect(0, 0, width, height), 100, os);
//            byte[] jpegByteArray = os.toByteArray();
//            Bitmap bitmap = BitmapFactory.decodeByteArray(jpegByteArray, 0, jpegByteArray.length);
            FileOutputStream fos = null;
            try {
                fos = new FileOutputStream(qrDetector.context.getApplicationContext().getFilesDir().getAbsolutePath() + "/imagename" + System.currentTimeMillis() + ".jpg");
            } catch (FileNotFoundException e) {
                e.printStackTrace();
            }

//            bitmap.compress(Bitmap.CompressFormat.PNG, 100, fos);
            try {
                fos.write(data);
                fos.close();
            } catch (Exception e) {
                e.printStackTrace();
            }

            frameBuilder.get().setImageData(imageBuffer, width, height, ImageFormat.NV21);
            return qrDetector.detector.detect(frameBuilder.get().build());
        }

        @Override
        protected void onPostExecute(SparseArray<Barcode> detectedItems) {
            QrDetector2 qrDetector = this.qrDetector.get();
            if (qrDetector == null) return;

            if (detectedItems != null) {
                for (int i = 0; i < detectedItems.size(); ++i) {
                    Log.i(TAG, "Item read: " + detectedItems.valueAt(i).rawValue);
                    final long now = System.currentTimeMillis();
                    if (now - qrDetector.lastEvent > 500) {
                        qrDetector.lastEvent = now;
                        qrDetector.communicator.qrRead(detectedItems.valueAt(i).rawValue);
                    }
                    else {
                        Log.i(TAG, "Item read events are too close");
                    }
                }
            }

            // if needed keep processing.
            qrDetector.maybeStartProcessing();
        }
    }

    private static class BarcodeScanAsyncTask extends android.os.AsyncTask<Void, Void, Result> {
        private byte[] mImageData;
        private int mWidth;
        private int mHeight;
        private WeakReference<QrDetector2> mDelegate;
        private final MultiFormatReader mMultiFormatReader;

        //  note(sjchmiela): From my short research it's ok to ignore rotation of the image.
        public BarcodeScanAsyncTask(
            QrDetector2 delegate,
            MultiFormatReader multiFormatReader,
            byte[] imageData,
            int width,
            int height
        ) {
            mImageData = imageData;
            mWidth = width;
            mHeight = height;
            mDelegate = new WeakReference<>(delegate);
            mMultiFormatReader = multiFormatReader;
        }

        @Override
        protected Result doInBackground(Void... ignored) {
            if (isCancelled() || mDelegate == null) {
                return null;
            }

            Result result = null;

            mDelegate.get().needsScheduling.set(false);
            mDelegate.get().isScheduled.set(false);

            try {
                BinaryBitmap bitmap = generateBitmapFromImageData(
                    mImageData,
                    mWidth,
                    mHeight,
                    false
                );
                result = mMultiFormatReader.decodeWithState(bitmap);
            } catch (NotFoundException e) {
                BinaryBitmap bitmap = generateBitmapFromImageData(
                    rotateImage(mImageData,mWidth, mHeight),
                    mHeight,
                    mWidth,
                    false
                );
                try {
                    result = mMultiFormatReader.decodeWithState(bitmap);
                } catch (NotFoundException e1) {
                    BinaryBitmap invertedBitmap = generateBitmapFromImageData(
                        mImageData,
                        mWidth,
                        mHeight,
                        true
                    );
                    try {
                        result = mMultiFormatReader.decodeWithState(invertedBitmap);
                    } catch (NotFoundException e2) {
                        BinaryBitmap invertedRotatedBitmap = generateBitmapFromImageData(
                            rotateImage(mImageData,mWidth, mHeight),
                            mHeight,
                            mWidth,
                            true
                        );
                        try {
                            result = mMultiFormatReader.decodeWithState(invertedRotatedBitmap);
                        } catch (NotFoundException e3) {
                            //no barcode Found
                        }
                    }
                }
            } catch (Throwable t) {
                t.printStackTrace();
            }

            return result;
        }
        private byte[] rotateImage(byte[]imageData,int width, int height) {
            byte[] rotated = new byte[imageData.length];
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    rotated[x * height + height - y - 1] = imageData[x + y * width];
                }
            }
            return rotated;
        }
        @Override
        protected void onPostExecute(Result result) {
            QrDetector2 qrDetector = this.mDelegate.get();
            if (qrDetector == null) return;

            if (result != null) {
                Log.v(TAG, "Result " + result.getText());
                mDelegate.get().communicator.qrRead(result.getText());
            }

            mDelegate.get().maybeStartProcessing();
        }

        private BinaryBitmap generateBitmapFromImageData(byte[] imageData, int width, int height, boolean inverse) {
            PlanarYUVLuminanceSource source = new PlanarYUVLuminanceSource(
                imageData, // byte[] yuvData
                width, // int dataWidth
                height, // int dataHeight
                0, // int left
                0, // int top
                width, // int width
                height, // int height
                false // boolean reverseHorizontal
            );
            if (inverse) {
                return new BinaryBitmap(new HybridBinarizer(source.invert()));
            } else {
                return new BinaryBitmap(new HybridBinarizer(source));
            }
        }
    }
}
