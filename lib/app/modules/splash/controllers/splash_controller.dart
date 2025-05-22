import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voice_to_text/routes/app_pages.dart';

class SplashController extends GetxController {
  final supabase = Supabase.instance.client;

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
    if (kDebugMode) {
      print("SPLASH_CONTROLLER_DEBUG: onReady fired. Checking auth state.");
    }
    _checkAuthStateAndNavigate();
  }

  Future<void> _checkAuthStateAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));

    final currentUser = supabase.auth.currentUser;

    if (currentUser != null) {
      if (kDebugMode) {
        print("SPLASH_CONTROLLER_DEBUG: User found (${currentUser.id}). Navigating to VOICE screen.");
      }
      try {
        Get.offAllNamed(AppRoutes.VOICE);
      } catch (e) {
        if (kDebugMode) {
          print("SPLASH_CONTROLLER_DEBUG: ERROR during navigation to ${AppRoutes.VOICE}: $e");
          Get.offAllNamed(AppRoutes.LOGIN);
        }
      }
    } else {
      if (kDebugMode) {
        print("SPLASH_CONTROLLER_DEBUG: No user found. Navigating to LOGIN screen.");
      }
      try {
        Get.offAllNamed(AppRoutes.LOGIN);
      } catch (e) {
        if (kDebugMode) {
          print("SPLASH_CONTROLLER_DEBUG: ERROR during navigation to ${AppRoutes.LOGIN}: $e");
        }
      }
    }
  }

  @override
  void onClose() {
    super.onClose();
  }
} 