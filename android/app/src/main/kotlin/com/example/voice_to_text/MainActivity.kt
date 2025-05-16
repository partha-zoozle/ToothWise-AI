package com.example.voice_to_text

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "native_speech"
    private var speechRecognizer: SpeechRecognizer? = null
    private lateinit var methodChannel: MethodChannel
    private var shouldBeListening = false
    private var currentPartialText = "" // To build up partial results if needed

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    shouldBeListening = true
                    currentPartialText = "" // Reset on new start
                    startNativeListening()
                    result.success(null)
                }
                "stopListening" -> {
                    shouldBeListening = false
                    stopNativeListening()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initializeSpeechRecognizer() {
        if (speechRecognizer == null) {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this.applicationContext)
            speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    Log.d("NativeSpeech", "onReadyForSpeech")
                }

                override fun onBeginningOfSpeech() {
                    Log.d("NativeSpeech", "onBeginningOfSpeech")
                    currentPartialText = "" // Reset when speech begins
                }

                override fun onRmsChanged(rmsdB: Float) {}

                override fun onBufferReceived(buffer: ByteArray?) {}

                override fun onEndOfSpeech() {
                    Log.d("NativeSpeech", "onEndOfSpeech")
                    if (shouldBeListening) {
                        // Restart listening after a brief pause to allow final results to process
                        // and to avoid overly rapid restarts which might be ignored by the OS.
                         handler.postDelayed({
                            if (shouldBeListening) startNativeListening()
                        }, 500) // 500ms delay, adjust as needed
                    }
                }

                override fun onError(error: Int) {
                    Log.e("NativeSpeech", "onError: $error")
                    // Consider more specific error handling here.
                    // For example, some errors might not warrant an immediate restart.
                    if (shouldBeListening) {
                        // Restart listening after a brief pause
                         handler.postDelayed({
                            if (shouldBeListening) startNativeListening()
                        }, 500) // 500ms delay
                    }
                }

                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    if (!matches.isNullOrEmpty()) {
                        val finalText = matches[0]
                        Log.d("NativeSpeech", "Final Result: $finalText")
                        methodChannel.invokeMethod("onResult", finalText)
                        currentPartialText = finalText // Update with final
                    }
                    // No automatic restart here to allow onEndOfSpeech to handle it
                    // or if you want restart after final, uncomment below and remove from onEndOfSpeech
                    // if (shouldBeListening) {
                    //     startNativeListening()
                    // }
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    if (!matches.isNullOrEmpty()) {
                        val partialText = matches[0]
                        // Log.d("NativeSpeech", "Partial Result: $partialText") // Can be very noisy
                        // Only send if it's different from the last sent partial text
                        // This avoids flooding Flutter if partial results are very similar
                        if (partialText != currentPartialText) {
                             currentPartialText = partialText
                             methodChannel.invokeMethod("onResult", partialText)
                        }
                    }
                }

                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
        }
    }

    private fun startNativeListening() {
        if (!shouldBeListening) {
            Log.d("NativeSpeech", "startNativeListening called but shouldBeListening is false.")
            return
        }
        if (SpeechRecognizer.isRecognitionAvailable(this.applicationContext)) {
            initializeSpeechRecognizer() // Ensure it's initialized

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                // putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 10000L) // Optional: Long silence
                // putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 10000L) // Optional: Long silence
            }
            try {
                speechRecognizer?.startListening(intent)
                Log.d("NativeSpeech", "Called startListening on SpeechRecognizer")
            } catch (e: Exception) {
                Log.e("NativeSpeech", "Error starting listening: ${e.message}")
                 // If starting fails, try to re-initialize and start again after a delay
                if(shouldBeListening) {
                    handler.postDelayed({
                        speechRecognizer = null // Force re-initialization
                        initializeSpeechRecognizer()
                        if(shouldBeListening) startNativeListening()
                    }, 1000)
                }
            }
        } else {
            Log.e("NativeSpeech", "Speech Recognition not available on this device.")
            // Optionally send an error back to Flutter
            methodChannel.invokeMethod("onError", "Speech Recognition not available")
            shouldBeListening = false // Stop trying if not available
        }
    }

    private fun stopNativeListening() {
        shouldBeListening = false
        speechRecognizer?.stopListening()
        speechRecognizer?.cancel()
        Log.d("NativeSpeech", "Called stopListening/cancel on SpeechRecognizer")
    }
    
    // Handler for delayed restarts
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())


    override fun onDestroy() {
        super.onDestroy()
        speechRecognizer?.destroy()
        handler.removeCallbacksAndMessages(null) // Clean up handler
    }
}
