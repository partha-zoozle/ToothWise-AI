import 'package:get/get.dart';
import 'package:voice_to_text/app/modules/splash/controllers/splash_controller.dart';


class SplashBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SplashController>(() => SplashController());
  }
} 