import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voice_to_text/app/widgets/native_speech.dart';
import 'package:flutter/foundation.dart';

class VoiceController extends GetxController {
  final RxBool isListening = false.obs;
  final RxString recognizedText = ''.obs;
  final RxString fullTranscript = ''.obs;
  final RxBool isLoading = false.obs;


  @override
  void onInit() {
    super.onInit();
    _requestMicrophonePermission();
    NativeSpeech.setResultHandler((text) {
      recognizedText.value = text;
      if (kDebugMode) {
        print("FlutterVoiceController - Received text: $text");
      }
    });
  }

  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  void startListening() {
    isListening.value = true;
    NativeSpeech.startListening();
  }

  void stopListening() {
    isListening.value = false;
    NativeSpeech.stopListening();
  }


  @override
  void onClose() {
    super.onClose();
  }
} 