package captainsauerland.emotes_to_stickers

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

//import androidx.appcompat.app.AppCompatActivity
import com.aureusapps.android.webpandroid.decoder.WebPDecoder
import captainsauerland.emotes_to_stickers.WebpConverter.Companion.convertWebP
import captainsauerland.emotes_to_stickers.TrayConverter.Companion.toTrayImage

class MainActivity: FlutterActivity() {
    private val CHANNEL = "captainsauerland/native"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
            val context = applicationContext
            val args = call.arguments as String
            when (call.method) {
                "convertWebP" -> {
                    //TrayConverter.toTrayImage(call.arguments as String, applicationContext)
                    val resultString = WebpConverter.convertWebP(args, context)
                    result.success(resultString)
                }
                "convertToTray" -> {
                    val resultString = TrayConverter.toTrayImage(args, context) //toTray(args, context)
                    result.success(resultString)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    fun toTray(filename: String, applicationContext: Context): String{
        return TrayConverter.toTrayImage(filename, applicationContext);
    }
}