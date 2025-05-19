import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NativeSpeech {
  static const MethodChannel _channel = MethodChannel('native_speech');

  static Future<void> startListening() async {
    await _channel.invokeMethod('startListening');
  }

  static Future<void> stopListening() async {
    await _channel.invokeMethod('stopListening');
  }

  static void setResultHandler(Function(dynamic arg1, [dynamic arg2]) onResult) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onResult') {
        if (kDebugMode) print("NativeSpeech - MethodChannel: Received onResult from native. Args: ${call.arguments}");
        if (call.arguments is Map && call.arguments.containsKey('isFinal')) {
             final args = call.arguments as Map;
             final text = args['text'] as String? ?? '';
             final isFinal = args['isFinal'] as bool? ?? true;
             onResult(text, isFinal);
        } else if (call.arguments is String) {
            onResult(call.arguments as String, true);
        } else {
            if (kDebugMode) print("NativeSpeech - MethodChannel: Received unexpected argument type or structure: ${call.arguments}");
        }
      }
    });
  }
} 