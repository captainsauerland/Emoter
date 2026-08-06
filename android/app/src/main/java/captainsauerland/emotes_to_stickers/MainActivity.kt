package captainsauerland.emotes_to_stickers

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "captainsauerland/native"
    private val conversionExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
            val args = call.arguments as? String
            if (args == null) {
                result.error("INVALID_ARGUMENT", "Expected filename as String", null)
                return@setMethodCallHandler
            }

            when (call.method) {
                "convertWebP" -> {
                    runConversion(result) {
                        WebpConverter.convertWebP(args, applicationContext)
                    }
                }
                "convertToTray" -> {
                    runConversion(result) {
                        TrayConverter.toTrayImage(args, applicationContext)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun runConversion(result: MethodChannel.Result, conversion: () -> String) {
        conversionExecutor.execute {
            try {
                val resultString = conversion()
                runOnUiThread { result.success(resultString) }
            } catch (e: Exception) {
                val message = e.message ?: "Native conversion failed"
                runOnUiThread { result.error("CONVERSION_ERROR", message, null) }
            }
        }
    }

    override fun onDestroy() {
        conversionExecutor.shutdown()
        super.onDestroy()
    }
}