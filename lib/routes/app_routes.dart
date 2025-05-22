part of 'app_pages.dart';

abstract class AppRoutes {
  AppRoutes._();
  static const SPLASH = _Paths.SPLASH;
  static const LOGIN = _Paths.LOGIN;
  static const VOICE = _Paths.VOICE; // Assuming this exists
  // Add other routes here if they follow the same pattern
}

abstract class _Paths {
  _Paths._();
  static const SPLASH = '/splash';
  static const LOGIN = '/login';
  static const VOICE = '/voice'; // Assuming this exists
  // Define paths for other routes
} 