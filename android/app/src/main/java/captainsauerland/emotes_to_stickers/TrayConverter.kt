package captainsauerland.emotes_to_stickers

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import androidx.appcompat.app.AppCompatActivity
import com.aureusapps.android.webpandroid.decoder.WebPDecoder
import com.aureusapps.android.webpandroid.encoder.WebPAnimEncoder
import com.aureusapps.android.webpandroid.encoder.WebPAnimEncoderOptions
import com.aureusapps.android.webpandroid.encoder.WebPConfig
import com.aureusapps.android.webpandroid.encoder.WebPMuxAnimParams
import com.aureusapps.android.webpandroid.encoder.WebPPreset
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class TrayConverter  : AppCompatActivity() {

    companion object {
        fun toTrayImage(filename: String, applicationContext: Context): String {
            val tempFolder = "file://" + applicationContext.cacheDir.path + "/"

            try {
                val uriString = "$tempFolder$filename.webp"
                val uri = Uri.parse(uriString)

                println(uri.path)

                val webPDecoder = WebPDecoder(applicationContext)

                webPDecoder.setDataSource(uri)

                var bitmap: Bitmap?

                if (webPDecoder.hasNextFrame()) {
                    val frameDecodeResult = webPDecoder.decodeNextFrame();
                    bitmap = frameDecodeResult.frame;
                } else {
                    bitmap = null
                }

                if (bitmap == null) {
                    bitmap = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
                }

                val resizedBitmap = Bitmap.createScaledBitmap(bitmap, 96, 96, true)
                val outputFilePath = applicationContext.cacheDir.path + "/" + filename + "_coverted.png"

                // Save the resized bitmap to the output file as a PNG
                var outputStream: FileOutputStream? = null
                try {
                    outputStream = FileOutputStream(File(outputFilePath))
                    resizedBitmap.compress(Bitmap.CompressFormat.PNG, 70, outputStream)
                } catch (e: IOException) {
                    e.printStackTrace()
                } finally {
                    try {
                        outputStream?.close()
                    } catch (e: IOException) {
                        e.printStackTrace()
                    }
                }
                return  outputFilePath
            }catch (e:Exception){
                e.printStackTrace()
            }
            return ""
        }
    }
}