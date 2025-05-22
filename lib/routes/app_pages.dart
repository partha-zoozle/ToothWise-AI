import 'package:get/get.dart';
import 'package:voice_to_text/app/modules/login/views/login_view.dart';

import '../app/modules/login/bindings/login_binding.dart';
import '../app/modules/splash/bindings/splash_binding.dart';
import '../app/modules/splash/views/splash_screen.dart';
import '../app/modules/voice/bindings/voice_binding.dart'; // Assuming this exists
import '../app/modules/voice/views/voice_view.dart'; // Assuming this exists


part 'app_routes.dart';



class AppPages {
  AppPages._();
  static const INITIAL = AppRoutes.SPLASH;

  static final routes = [
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashScreen(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: _Paths.LOGIN,
      page: () => const LoginScreen(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: _Paths.VOICE, // Assuming this is your voice screen
      page: () => const VoiceScreen(),
      binding: VoiceBinding(), // Or whatever binding you use for VoiceScreen
    ),
    // Add other pages here
  ];
} 