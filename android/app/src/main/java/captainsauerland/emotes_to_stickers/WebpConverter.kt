package captainsauerland.emotes_to_stickers

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.util.Log
import androidx.annotation.Dimension
import androidx.appcompat.app.AppCompatActivity
import com.aureusapps.android.webpandroid.decoder.WebPDecoder
import com.aureusapps.android.webpandroid.encoder.WebPAnimEncoder
import com.aureusapps.android.webpandroid.encoder.WebPAnimEncoderOptions
import com.aureusapps.android.webpandroid.encoder.WebPConfig
import com.aureusapps.android.webpandroid.encoder.WebPEncoder
import com.aureusapps.android.webpandroid.encoder.WebPMuxAnimParams
import com.aureusapps.android.webpandroid.encoder.WebPPreset
import java.io.File
import java.io.IOException

class WebpConverter : AppCompatActivity() {

    companion object {
        final var TAG = "meine app"

        fun convertWebP(filename: String, applicationContext: Context): String {
            val tempFolder = "file://" + applicationContext.cacheDir.path + "/"

            try {
                val uriString = "$tempFolder$filename.webp"
                val uri = Uri.parse(uriString)
                //println("webp: " + uri.path)

                var size = Long.MAX_VALUE
                var path = ""
                var qualityDowngrade = 0
                var framesPercent = 1F
                var quality = 90f

                val webPDecoder = WebPDecoder(applicationContext)

                webPDecoder.setDataSource(uri)
                val frameCount = webPDecoder.decodeInfo().frameCount

                if (frameCount > 1){
                    //val startTime = System.currentTimeMillis() //DEBUG

                    val settings = calculateQualitySettings(webPDecoder, applicationContext)

                    //val endTime = System.currentTimeMillis() //DEBUG
                    //val duration = endTime - startTime
                    //println("Calculate quality took $duration milliseconds") //DEBUG

                    quality = settings.first
                    framesPercent = settings.second
                }

                while (true){
                    quality -= qualityDowngrade

                    webPDecoder.reset()

                    //val startTime = System.currentTimeMillis() //DEBUG

                    path = convertWebPByQuality(webPDecoder, filename, applicationContext, quality, frameCount, framesPercent)

                    //val endTime = System.currentTimeMillis() //DEBUG
                    //val duration = endTime - startTime
                    //println("Convert to webp took $duration milliseconds") //DEBUG

                    size = getFileSizeInBytes(path)

                    if (size <= 500_000){
                        break;
                    }else{
                        val sizeDiff = size / 500_000
                        var qualtiyDowngradeDiff:Int
                        var framesPercentDiff:Float
                        if (sizeDiff > 2){
                            qualtiyDowngradeDiff = 20
                            framesPercentDiff = 0.3F
                        } else if (sizeDiff > 1.5F){
                            qualtiyDowngradeDiff = 10
                            framesPercentDiff = 0.2F
                        } else { //sizeDiff > 1.25F
                            qualtiyDowngradeDiff = 5
                            framesPercentDiff = 0.2F
                        }
//                        else{
//                            qualtiyDowngradeDiff = 3
//                            framesPercentDiff = 0.05F
//                        }
                        qualityDowngrade = 25.coerceAtMost(qualityDowngrade + qualtiyDowngradeDiff)
                        framesPercent = 0.1F.coerceAtLeast(framesPercent - framesPercentDiff)

                        deleteFile(path)
                        //Log.d(TAG, "$size b is too big, so quality is now -$qualityDowngrade and frames are $framesPercent ($framesPercentDiff)")
                        //Log.d(TAG, "real size by frame: ${size/frameCount.toDouble()}")
                    }
                }
                webPDecoder.release()

                return path
            } catch (e: IOException) {
                e.printStackTrace()
                throw IOException(e)
            }
        }

        fun calculateQualitySettings(webPDecoder: WebPDecoder, applicationContext: Context): Pair<Float, Float>{
            val frameCount = webPDecoder.decodeInfo().frameCount
            var quality = 70f //starts default at 70
            var framesPercent = 1f
            var expectedSize = Long.MAX_VALUE

            //probably small enough
            if (frameCount < 20){
                return Pair(quality, framesPercent)
            }else if (frameCount > 100){
                framesPercent = 0.7f
            }

            while (true){
                Log.d(TAG, "current expected size: ${expectedSize} - quality: $quality - framePercent: $framesPercent")
                val currentAvgSize = calculateAvgSizeForQuality(webPDecoder, applicationContext, quality)
                expectedSize = (currentAvgSize * frameCount * framesPercent).toLong()
                if (expectedSize < 490_000){
                    break;
                }
                if (expectedSize - 500_000 > 100_000){
                    quality -= 20f
                    framesPercent -= 0.2f
                }else {
                    quality -= 10f
                    framesPercent -= 0.1f
                }

                if (quality < 0 || framesPercent < 0){
                    break
                }
            }

            return Pair(quality, framesPercent)
        }

        private fun calculateAvgSizeForQuality(webPDecoder: WebPDecoder, applicationContext: Context, quality: Float): Long{
            val frameCount = webPDecoder.decodeInfo().frameCount

            //d must never be 0 or else the loop will be stuck
            val d = if (frameCount > 5) frameCount/5 else 1

            val samples = mutableListOf<Int>()
            var current = 0
            while (current <= frameCount) {
                samples.add(current)
                current += d
            }
            samples.toIntArray()

            val result = mutableListOf<Long>()

            for (i in samples){
                webPDecoder.reset()
                result.add(convertOneImageAndGetSize(webPDecoder, applicationContext, quality, i))
            }
            result.toLongArray()

            return result.average().toLong()
        }

        private fun convertOneImageAndGetSize(webPDecoder: WebPDecoder, applicationContext: Context, quality: Float, index: Int): Long{
            val webPEncoder = WebPEncoder(applicationContext, 512, 512)

            // Configure the encoder
            webPEncoder.configure(
                config = WebPConfig(
                    lossless = WebPConfig.COMPRESSION_LOSSY,
                    quality = quality
                ),
                preset = WebPPreset.WEBP_PRESET_PICTURE
            )

            for (i in 1..index) {
                webPDecoder.decodeNextFrame()
            }
            val frameDecodeResult = webPDecoder.decodeNextFrame()
            val bitmap = frameDecodeResult.frame
            if (bitmap != null) {
                val resized = resizeBitmapTo512x512(bitmap)

                val outputUri = Uri.parse("file://" +applicationContext.cacheDir.path + "/${System.currentTimeMillis()}.webp")

                webPEncoder.encode(resized, outputUri)

                val sizeInBytes = getFileSizeInBytes(outputUri.path.toString())
                deleteFile(outputUri.path.toString())
                return sizeInBytes
            }
            return -1;
        }

        private fun convertWebPByQuality(webPDecoder: WebPDecoder, filename: String, applicationContext: Context, quality: Float, frames: Int, framesPercent: Float): String {
            val webPAnimEncoder = WebPAnimEncoder(
                applicationContext,
                512,
                512,
                WebPAnimEncoderOptions(
                    minimizeSize = false,
                    allowMixed = true,
                    animParams = WebPMuxAnimParams(
                        backgroundColor = Color.argb(255, 255, 255, 255),
                        loopCount = 0
                    )
                )
            )

            webPAnimEncoder.configure(
                config = WebPConfig(
                    lossless = WebPConfig.COMPRESSION_LOSSY,
                    quality = quality
                ),
                preset = WebPPreset.WEBP_PRESET_PICTURE
            )

            var endTimestamp = 0L
            var skipEvery = 1 - framesPercent
            var skipSum = 0F
            var frameLength = 0L
            var framesBuffer = mutableListOf<Pair<Bitmap, Long>>()
            val isShortAnimation = frames in 2..10;

            while (webPDecoder.hasNextFrame()) {
                val frameDecodeResult = webPDecoder.decodeNextFrame()
                val timestamp = frameDecodeResult.timestamp
                val endTimestampNew = timestamp.toLong()

                //emotes cant be longer than 10s
                if (endTimestampNew >= 10000){
                    break;
                }

                frameLength = endTimestampNew - endTimestamp

                endTimestamp = endTimestampNew

                val bitmap = frameDecodeResult.frame
                if (bitmap != null){
                    val resized = resizeBitmapTo512x512(bitmap)

                    if (skipSum < 1){
                        webPAnimEncoder.addFrame(timestamp = timestamp.toLong(), resized)
                    }else{
                        skipSum -= 1
                    }
                    skipSum += skipEvery;

                    if (isShortAnimation){
                        framesBuffer.add(Pair(resized, frameLength))
                    }
                    if (frames == 1){
                        webPAnimEncoder.addFrame(timestamp = timestamp.toLong()+10L, alterBitmapSlightly(resized))
                        endTimestamp += 20L
                    }
                }
            }
            //extend short animation
            val emoteLength = endTimestamp;
            if (isShortAnimation){
                //extend to x frames
                val multiplier = 20 / frames

                for (i in 1..< multiplier) {
                    Log.d(TAG, "next: $i")
                    if ((i+1) * emoteLength >= 10000){
                        break
                    }
                    for (frame in framesBuffer) {
                        endTimestamp += frame.second;
                        webPAnimEncoder.addFrame(timestamp = endTimestamp, frame.first)
                    }
                }
            }
            val outputUri = Uri.parse("file://" +applicationContext.cacheDir.path + "/" + filename +"_c.webp")

            var lastTimestamp = endTimestamp + frameLength;

            webPAnimEncoder.assemble(lastTimestamp, outputUri)
            webPAnimEncoder.release()

            return outputUri.path.toString()
        }

        private fun resizeBitmapTo512x512(bitmap: Bitmap): Bitmap {

            val targetWidth = 512
            val targetHeight = 512

            // Calculate the scaling factor
            val scale = Math.min(
                targetWidth.toFloat() / bitmap.width,
                targetHeight.toFloat() / bitmap.height
            )

            // Calculate the new dimensions
            val newWidth = (bitmap.width * scale).toInt()
            val newHeight = (bitmap.height * scale).toInt()

            // Create a new bitmap with the target dimensions
            val resizedBitmap = Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, false)

            // Create a new bitmap with the target size and a transparent background
            val outputBitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(outputBitmap)
            canvas.drawColor(Color.TRANSPARENT)

            // Calculate the position to center the resized bitmap
            val left = (targetWidth - newWidth) / 2
            val top = (targetHeight - newHeight) / 2

            // Draw the resized bitmap onto the output bitmap
            canvas.drawBitmap(resizedBitmap, left.toFloat(), top.toFloat(), Paint())

            return outputBitmap
        }

        private fun alterBitmapSlightly(bitmap: Bitmap): Bitmap {
            val alteredBitmap = bitmap.copy(bitmap.config, true)
            val pixel = alteredBitmap.getPixel(bitmap.width/2, bitmap.height/2)
            val alteredPixel = pixel xor 0x10000011
            alteredBitmap.setPixel(0, 0, alteredPixel)

            return alteredBitmap
        }

        private fun getFileSizeInBytes(filePath: String): Long {
            val file = File(filePath)
            return if (file.exists()) {
                file.length()
            } else {
                0L
            }
        }

        private fun deleteFile(filePath: String): Boolean {
            val file = File(filePath)
            return if (file.exists()) {
                file.delete()
            } else {
                false
            }
        }
    }
}