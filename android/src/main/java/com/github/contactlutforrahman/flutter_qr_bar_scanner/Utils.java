package com.github.contactlutforrahman.flutter_qr_bar_scanner;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.media.Image;
import android.util.Log;

import org.opencv.core.Core;
import org.opencv.core.CvType;
import org.opencv.core.Mat;
import org.opencv.core.MatOfDouble;
import org.opencv.imgproc.Imgproc;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;

class Utils {
    static byte[] YUV420toNV21(Image image) {
        Rect crop = image.getCropRect();
        int format = image.getFormat();
        int width = crop.width();
        int height = crop.height();
        Image.Plane[] planes = image.getPlanes();
        byte[] data = new byte[width * height * ImageFormat.getBitsPerPixel(format) / 8];
        byte[] rowData = new byte[planes[0].getRowStride()];

        int channelOffset = 0;
        int outputStride = 1;
        for (int i = 0; i < planes.length; i++) {
            switch (i) {
                case 0:
                    channelOffset = 0;
                    outputStride = 1;
                    break;
                case 1:
                    channelOffset = width * height + 1;
                    outputStride = 2;
                    break;
                case 2:
                    channelOffset = width * height;
                    outputStride = 2;
                    break;
            }

            ByteBuffer buffer = planes[i].getBuffer();
            int rowStride = planes[i].getRowStride();
            int pixelStride = planes[i].getPixelStride();

            int shift = (i == 0) ? 0 : 1;
            int w = width >> shift;
            int h = height >> shift;
            buffer.position(rowStride * (crop.top >> shift) + pixelStride * (crop.left >> shift));
            for (int row = 0; row < h; row++) {
                int length;
                if (pixelStride == 1 && outputStride == 1) {
                    length = w;
                    buffer.get(data, channelOffset, length);
                    channelOffset += length;
                } else {
                    length = (w - 1) * pixelStride + 1;
                    buffer.get(rowData, 0, length);
                    for (int col = 0; col < w; col++) {
                        data[channelOffset] = rowData[col * pixelStride];
                        channelOffset += outputStride;
                    }
                }
                if (row < h - 1) {
                    buffer.position(buffer.position() + rowStride - length);
                }
            }
        }
        return data;
    }

    public static double getImageBlurValue(Mat image) {
        Mat matImageGrey = new Mat();
        Imgproc.cvtColor(image, matImageGrey, Imgproc.COLOR_BGR2GRAY);
        Mat laplacianImage = new Mat();
        Imgproc.Laplacian(matImageGrey, laplacianImage, CvType.CV_64F);


        MatOfDouble mean = new MatOfDouble();
        MatOfDouble std = new MatOfDouble();
        Core.meanStdDev(laplacianImage, mean, std);

        double[] means = mean.get(0, 0);
        double[] stds = std.get(0, 0);
        double score = 0.0;
        for (int i = 0; i < means.length; i++)
            score += means[i] - stds[i];

        return score;
    }

    public static String saveMat(Mat image, Context context){
        try {
            Bitmap bmp = Bitmap.createBitmap(image.cols(), image.rows(), Bitmap.Config.ARGB_8888);
            org.opencv.android.Utils.matToBitmap(image, bmp);
            // 360- mCorrectRotation


            FileOutputStream out = null;

            Long tsLong = System.currentTimeMillis()/1000;
            String filename = tsLong.toString();

            File outputDir = context.getCacheDir(); // context being the Activity pointer
            File outputFile = File.createTempFile(filename, ".jpeg", outputDir);

            out = new FileOutputStream(outputFile);
            bmp.compress(Bitmap.CompressFormat.JPEG, 100, out);

            return outputFile.getPath();
        } catch (Exception e) {
            e.printStackTrace();
            Log.d("MY LOG", e.getMessage());
            return "";
        }

    }
}
