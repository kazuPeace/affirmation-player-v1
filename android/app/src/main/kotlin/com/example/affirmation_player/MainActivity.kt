package com.example.affirmation_player

import android.os.Handler
import android.os.Looper
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val channelName = "affirmation_player/voicevox"
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var nativeLibrariesLoaded = false

    private external fun nativeInitialize(
        onnxruntimePath: String,
        openJtalkDictDir: String,
    ): String

    private external fun nativeLoadModel(modelPath: String): String

    private external fun nativeSynthesize(text: String, styleId: Int): ByteArray

    private external fun nativeRelease()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        executor.execute {
                            runCatching {
                                ensureNativeLibrariesLoaded()
                                val runtimeDir = File(filesDir, "voicevox_runtime")
                                val dictDir = File(runtimeDir, "dict/open_jtalk_dic_utf_8-1.11")
                                val modelFiles = listOf(
                                    File(runtimeDir, "models/0.vvm"),
                                    File(runtimeDir, "models/13.vvm"),
                                    File(runtimeDir, "models/19.vvm"),
                                    File(runtimeDir, "models/21.vvm"),
                                )
                                val flutterAssetBase =
                                    FlutterInjector.instance().flutterLoader().findAppBundlePath()

                                copyAssetTree(
                                    "$flutterAssetBase/assets/voicevox/dict/open_jtalk_dic_utf_8-1.11",
                                    dictDir,
                                )
                                modelFiles.forEachIndexed { index, modelFile ->
                                    val assetName = when (index) {
                                        0 -> "0.vvm"
                                        1 -> "13.vvm"
                                        2 -> "19.vvm"
                                        else -> "21.vvm"
                                    }
                                    copyAssetTree(
                                        "$flutterAssetBase/assets/voicevox/models/$assetName",
                                        modelFile,
                                    )
                                }

                                val onnxruntimePath =
                                    "${applicationInfo.nativeLibraryDir}/libvoicevox_onnxruntime.so"
                                nativeInitialize(onnxruntimePath, dictDir.absolutePath)
                                var metasJson = ""
                                modelFiles.forEach { modelFile ->
                                    metasJson = nativeLoadModel(modelFile.absolutePath)
                                }
                                metasJson
                            }.onSuccess { metasJson ->
                                replySuccess(result, metasJson)
                            }.onFailure { throwable ->
                                replyError(result, "initialize_failed", throwable)
                            }
                        }
                    }

                    "synthesize" -> {
                        val text = call.argument<String>("text")?.trim().orEmpty()
                        val styleId = call.argument<Int>("styleId")

                        if (text.isEmpty()) {
                            result.error("invalid_text", "Text is empty.", null)
                            return@setMethodCallHandler
                        }
                        if (styleId == null) {
                            result.error("invalid_style", "styleId is missing.", null)
                            return@setMethodCallHandler
                        }

                        executor.execute {
                            runCatching {
                                nativeSynthesize(text, styleId)
                            }.onSuccess { wavBytes ->
                                replySuccess(result, wavBytes)
                            }.onFailure { throwable ->
                                replyError(result, "synthesize_failed", throwable)
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        if (nativeLibrariesLoaded) {
            nativeRelease()
        }
        executor.shutdown()
        super.onDestroy()
    }

    @Synchronized
    private fun ensureNativeLibrariesLoaded() {
        if (nativeLibrariesLoaded) {
            return
        }

        System.loadLibrary("voicevox_onnxruntime")
        System.loadLibrary("voicevox_core")
        System.loadLibrary("voicevox_bridge")
        nativeLibrariesLoaded = true
    }

    private fun copyAssetTree(assetPath: String, destination: File) {
        val children = assets.list(assetPath).orEmpty()
        if (children.isEmpty()) {
            destination.parentFile?.mkdirs()
            if (!destination.exists()) {
                assets.open(assetPath).use { input ->
                    FileOutputStream(destination).use { output ->
                        input.copyTo(output)
                    }
                }
            }
            return
        }

        destination.mkdirs()
        children.forEach { child ->
            copyAssetTree("$assetPath/$child", File(destination, child))
        }
    }

    private fun replySuccess(result: MethodChannel.Result, payload: Any?) {
        mainHandler.post { result.success(payload) }
    }

    private fun replyError(result: MethodChannel.Result, code: String, throwable: Throwable) {
        val message = throwable.message ?: throwable::class.java.simpleName
        mainHandler.post { result.error(code, message, null) }
    }
}
