package com.github.contactlutforrahman.flutter_qr_bar_scanner

import android.util.Log
import org.opencv.core.*
import org.opencv.imgproc.Imgproc


class FlutterOpenCvModule {
    companion object {
        fun resizeImage(image: Mat, newWidth: Double) : Mat {
            val imageSize = image.size()
            val ratio: Double = imageSize.width / imageSize.height
            val resizeimage = Mat()
            val scaleSize = Size(newWidth, (newWidth / ratio))

            Imgproc.resize(image, resizeimage, scaleSize, 0.0, 0.0, Imgproc.INTER_AREA)
            return resizeimage
        }

        fun getImageBlurValue(image: Mat) : Double {
            val matImageGrey = Mat()
            Imgproc.cvtColor(image, matImageGrey, Imgproc.COLOR_BGR2GRAY)
            val laplacianImage = Mat()
            Imgproc.Laplacian(matImageGrey, laplacianImage, CvType.CV_64F)


            val mean = MatOfDouble()
            val std = MatOfDouble()
            Core.meanStdDev(laplacianImage, mean, std)
            val score = Math.pow(std[0, 0][0], 2.0)
            Log.i("MY LOG", ": BLUR VALUE $score")
            return score
        }
    }
}