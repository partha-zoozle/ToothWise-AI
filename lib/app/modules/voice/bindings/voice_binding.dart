import 'package:get/get.dart';
import '../controllers/voice_controller.dart';

class VoiceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VoiceController>(() => VoiceController());
  }
} 