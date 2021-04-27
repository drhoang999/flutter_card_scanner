package com.github.contactlutforrahman.flutter_qr_bar_scanner

import android.content.Context
import android.media.Image
import android.os.AsyncTask
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.github.contactlutforrahman.flutter_qr_bar_scanner.Utils.saveMat
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import org.opencv.objdetect.CascadeClassifier
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.lang.ref.WeakReference
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.locks.Lock
import java.util.concurrent.locks.ReentrantLock


class CardDetector(private val context: Context, private val communicator: CardReaderCallbacks, private val detectType: DetectType)  {
    private val imageToCheckLock : Lock = ReentrantLock()
    private val nextImageLock: Lock = ReentrantLock()
    private val isScheduled: AtomicBoolean = AtomicBoolean(false)
    private val needsScheduling: AtomicBoolean = AtomicBoolean(false)

    private val nextImageSet = AtomicBoolean(false)

    private val imageToCheck = QrImage()
    private val nextImage = QrImage()
    var manuallyCapture = false

    fun detect(image: Image) {
        Log.v("CardDetector", "Working $manuallyCapture")
        needsScheduling.set(true)

        if (imageToCheckLock.tryLock()) {
            // copy image if not in use
            try {
                nextImageSet.set(false)
                imageToCheck.copyImage(image)
            } finally {
                imageToCheckLock.unlock()
            }
        } else if (nextImageLock.tryLock()) {
            // if first image buffer is in use, use second buffer
            // one or the other should always be free but if not this
            // frame is dropped..
            try {
                nextImageSet.set(true)
                nextImage.copyImage(image)
            } finally {
                nextImageLock.unlock()
            }
        }
        maybeStartProcessing()
    }

    fun maybeStartProcessing() {

        // start processing, only if scheduling is needed and
        // there isn't currently a scheduled task.
        if (needsScheduling.get() && !isScheduled.get()) {
            Log.v("maybeStartProcessing", "Scheduling")
            isScheduled.set(true)
            CardTaskV2(this).executeOnExecutor(AsyncTask.SERIAL_EXECUTOR)
        }
    }

    internal class CardTaskV2(detector: CardDetector) : AsyncTask<Void, Void, Boolean>() {
        private val detector: WeakReference<CardDetector> = WeakReference(detector)

        override fun doInBackground(vararg params: Void?): Boolean {
            val detector = this.detector.get() ?: return false
            Log.v("CardDetector", "doInBackground")
            detector.needsScheduling.set(false)
            detector.isScheduled.set(false)

            val data: ByteArray
            val width: Int
            val height: Int
            if (detector.nextImageSet.get()) {
                try {
                    detector.nextImageLock.lock()
                    data = detector.nextImage.toNv21(false)
                    width = detector.nextImage.width
                    height = detector.nextImage.height
                } finally {
                    detector.nextImageLock.unlock()
                }
            } else {
                try {
                    detector.imageToCheckLock.lock()
                    data = detector.imageToCheck.toNv21(false)
                    width = detector.imageToCheck.width
                    height = detector.imageToCheck.height
                } finally {
                    detector.imageToCheckLock.unlock()
                }
            }

            Log.v("CardDetector", "Image size ${data.size}")

            try {
                val mYuv = Mat(height + height / 2, width, CvType.CV_8UC1)
                val mBgra = Mat(height + height / 2, width, CvType.CV_8UC4)
                mYuv.put(0, 0, data)
                Imgproc.cvtColor(mYuv, mBgra, Imgproc.COLOR_YUV420sp2RGB, 4)
                mYuv.release()

                if (detector.manuallyCapture) {
                    val path = saveMat(mBgra, detector.context)
                    detector.communicator.cardRead(path)
                    detector.manuallyCapture = false
                    return true
                }

                val imgBlur = FlutterOpenCvModule.getImageBlurValue(mBgra)
                Log.v("CardDetector", "Image blur: $imgBlur")
                if (imgBlur < 100) {
                    return false
                }

                var isSuccess = false

                if (detector.detectType.value == 1) {
                    isSuccess = detector.cascadeCardDetect(mBgra)
                }

                if (detector.detectType.value == 2) {
                    isSuccess = detector.cascadeBackCardDetect(mBgra)
                }

                return isSuccess
            } catch (exception: CvException) {
                return false;
            }
        }

        override fun onPostExecute(result: Boolean?) {
            val detector = this.detector.get() ?: return

            detector.maybeStartProcessing()
        }
    }


    private fun cascadeBackCardDetect(image: Mat): Boolean {
        val imgResized: Mat = FlutterOpenCvModule.resizeImage(image, 400.0)
        val grayImage = Mat()
        Imgproc.cvtColor(imgResized, grayImage, Imgproc.COLOR_BGR2GRAY)
        imgResized.release()

        val mJavaDetector: CascadeClassifier
        var returnCardBB = Rect()
        try {
            val `is`: InputStream = context.resources.openRawResource(R.raw.cascade_back_card)
            val cascadeDir: File = context.getDir("cascade", Context.MODE_PRIVATE)
            val mCascadeFile = File(cascadeDir, "cascade_back_card.xml")
            if (mCascadeFile.length() == 0L) {
                val os = FileOutputStream(mCascadeFile)
                val buffer = ByteArray(4096)
                var bytesRead: Int
                while (`is`.read(buffer).also { bytesRead = it } != -1) {
                    os.write(buffer, 0, bytesRead)
                }
                `is`.close()
                os.close()
            }
            mJavaDetector = CascadeClassifier(mCascadeFile.absolutePath)
        } catch (e: IOException) {
            e.printStackTrace()
            Log.e("MY LOG", "Failed to load cascade. Exception thrown: $e")
            return false
        }

        Log.v("BackDetector", "Working")

        val contours = MatOfRect()
        mJavaDetector.detectMultiScale(grayImage, contours, 1.1, 2)
        grayImage.release()
        val listContours = contours.toList()

        val originSize = image.size()
        val ratio = originSize.width.toFloat() / 400.toFloat()

        for (i in listContours.indices) {
            val cardBB = listContours[i]
            returnCardBB = Rect((cardBB.x * ratio).toInt(),
                (cardBB.y * ratio).toInt(),
                (cardBB.width * ratio).toInt(),
                (cardBB.height * ratio).toInt())
            if (cardBB.x < 0) {
                cardBB.x = 0
            }
            if (cardBB.y < 0) {
                cardBB.y = 0
            }
            if (returnCardBB.x + returnCardBB.width > originSize.width) {
                returnCardBB.width = originSize.width.toInt() - returnCardBB.x
            }
            if (returnCardBB.y + returnCardBB.height > originSize.height) {
                returnCardBB.height = originSize.height.toInt() - returnCardBB.y
            }
            break
        }

        Log.i("BACK CARD DETECT: ", "x:" + returnCardBB.x + "y:" + returnCardBB.y + "w:" + returnCardBB.width + "h:" + returnCardBB.height)

        if (returnCardBB.width > 0) {
            val cardImg = Mat(image, returnCardBB)
            if (FlutterOpenCvModule.getImageBlurValue(cardImg) > 150) {
                val filePath: String = saveMat(cardImg, context)
                communicator.cardRead(filePath)
                return true
            }
        }
        return false
    }

    private fun cascadeCardDetect(image: Mat): Boolean {
        val imgResized: Mat = FlutterOpenCvModule.resizeImage(image, 600.0)
        val grayImage = Mat()
        Imgproc.cvtColor(imgResized, grayImage, Imgproc.COLOR_BGR2GRAY)
        imgResized.release()
        val mJavaDetector: CascadeClassifier
        var returnCardBB = Rect()
        try {
            val `is`: InputStream = context.resources.openRawResource(R.raw.lbpcascade_card)
            val cascadeDir: File = context.getDir("cascade", Context.MODE_PRIVATE)
            val mCascadeFile = File(cascadeDir, "lbpcascade_card.xml")
            if (mCascadeFile.length() == 0L) {
                val os = FileOutputStream(mCascadeFile)
                val buffer = ByteArray(4096)
                var bytesRead: Int
                while (`is`.read(buffer).also { bytesRead = it } != -1) {
                    os.write(buffer, 0, bytesRead)
                }
                `is`.close()
                os.close()
            }
            mJavaDetector = CascadeClassifier(mCascadeFile.absolutePath)
        } catch (e: IOException) {
            e.printStackTrace()
            Log.e("MY LOG", "Failed to load cascade. Exception thrown: $e")
            return false
        }
        val contours = MatOfRect()
        mJavaDetector.detectMultiScale(grayImage, contours, 1.1, 1)
        grayImage.release()

        val listContours = contours.toList()
        val originSize = image.size()
        val ratio = originSize.width.toFloat() / 600.toFloat()
        for (i in listContours.indices) {
            val cardBB: Rect = getCardBBFromSymbol(listContours[i])
            returnCardBB = Rect((cardBB.x * ratio).toInt(),
                (cardBB.y * ratio).toInt(),
                (cardBB.width * ratio).toInt(),
                (cardBB.height * ratio).toInt())
            if (cardBB.x < 0) {
                cardBB.x = 0
            }
            if (cardBB.y < 0) {
                cardBB.y = 0
            }
            if (returnCardBB.x + returnCardBB.width > originSize.width) {
                returnCardBB.width = originSize.width.toInt() - returnCardBB.x
            }
            if (returnCardBB.y + returnCardBB.height > originSize.height) {
                returnCardBB.height = originSize.height.toInt() - returnCardBB.y
            }
            break
        }
        Log.i("CARD DETECT: ", "x:" + returnCardBB.x + "y:" + returnCardBB.y + "w:" + returnCardBB.width + "h:" + returnCardBB.height)
        if (returnCardBB.width > 0) {
            val cardImg = Mat(image, returnCardBB)
            if (FlutterOpenCvModule.getImageBlurValue(cardImg) > 100) {
                val filePath: String = saveMat(cardImg, context)
                communicator.cardRead(filePath)
                return true
            }
        }
        return false
    }

    private fun getCardBBFromSymbol(bb: Rect): Rect {
        return Rect(
            (bb.x - bb.width.toFloat() * 0.25).toInt(),
            (bb.y - bb.height.toFloat() * 0.25).toInt(),
            (bb.width * 4.5).toInt(),
            (bb.height * 3)
        )
    }

    internal class QrImage {
        private var data : ByteArray = ByteArray(0);
        var width = 0
        var height = 0

        @RequiresApi(Build.VERSION_CODES.KITKAT)
        fun copyImage(image: Image) {
            width = image.width
            height = image.height
            data = Utils.YUV420toNV21(image)
        }

        fun toNv21(greyScale: Boolean): ByteArray {
            return data
        }
    }
}