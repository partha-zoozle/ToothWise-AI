import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:voice_to_text/routes/app_pages.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    if (kDebugMode) {
      print("SPLASH_CONTROLLER_DEBUG: onInit fired.");
    }
  }

  @override
  void onReady() {
    super.onReady();
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    await Future.delayed(const Duration(seconds: 3));
    try {
      Get.offNamed(AppRoutes.LOGIN);
    } catch (e) {
      if (kDebugMode) {
        print("SPLASH_CONTROLLER_DEBUG: ERROR during navigation to ${AppRoutes.LOGIN}: $e");
      }
    }
  }

  @override
  void onClose() {
    super.onClose();
  }
} 