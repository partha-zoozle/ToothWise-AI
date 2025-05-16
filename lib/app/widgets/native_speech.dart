import 'package:flutter/services.dart';

class NativeSpeech {
  static const MethodChannel _channel = MethodChannel('native_speech');

  static Future<void> startListening() async {
    await _channel.invokeMethod('startListening');
  }

  static Future<void> stopListening() async {
    await _channel.invokeMethod('stopListening');
  }

  static void setResultHandler(Function(String) onResult) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onResult') {
        onResult(call.arguments as String);
      }
    });
  }
} 