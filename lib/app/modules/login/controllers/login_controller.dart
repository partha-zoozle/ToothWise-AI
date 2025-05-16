import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voice_to_text/routes/app_pages.dart';
final supabase = Supabase.instance.client;

class LoginController extends GetxController {
  final RxBool isLoading = false.obs;
  static const String webClientId = '695830795380-cdd0prekslfjph5ptdbs404d9b4tlj4j.apps.googleusercontent.com';


  @override
  void onInit() {
    super.onInit();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        if (kDebugMode) {
          print("User signed in. Navigating to voice screen.");
        }
        Get.offAllNamed(AppRoutes.VOICE);
      } else if (event == AuthChangeEvent.signedOut) {
        if (kDebugMode) {
          print("User signed out. Navigating to login screen.");
        }
      }
    });
  }

  Future<void> signInWithGoogleSupabase() async {
    isLoading.value = true;
    try {
      if (kDebugMode) {
        print("Initiating Supabase Google Sign-In...");
        print("Web Client ID: $webClientId");
      }

      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: webClientId, // Essential for idToken verification by Supabase
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        if (kDebugMode) {
          print("Google Sign-In cancelled by user.");
        }
        isLoading.value = false;
        return;
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'Google Sign-In failed: No ID Token found.';
      }
      if (accessToken == null) {
        // While the article includes accessToken in signInWithIdToken,
        // Supabase typically primarily needs the idToken for Google Auth.
        // The accessToken might be required by Supabase for other providers or specific setups.
        // For safety, we check, but usually, the idToken is the key.
        if (kDebugMode) {
          print('Warning: No Access Token found from Google, but proceeding with ID Token.');
        }
      }
      
      if (kDebugMode) {
        print("Google ID Token: $idToken");
        // print("Google Access Token: $accessToken"); // Uncomment if needed for debugging
      }

      final AuthResponse response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken, // Supabase might use this for some providers or future enhancements
      );

      if (response.user == null) {
        throw 'Supabase Sign-In failed: No user returned.';
      }

      if (kDebugMode) {
        print("Supabase Sign-In successful: ${response.user?.email}");
      }
      // Navigation is handled by the auth state listener (_setupAuthListener)

    } catch (e) {
      if (kDebugMode) {
        print('Error during Supabase Google Sign-In: $e');
      }
      Get.snackbar(
        'Login Error',
        'Failed to sign in with Google: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    isLoading.value = true;
    try {
      await supabase.auth.signOut();
      if (kDebugMode) {
        print("User signed out successfully.");
      }
      // Navigation is handled by the auth state listener
      // Ensure user is redirected to login screen if not handled by listener properly.
      Get.offAllNamed(AppRoutes.LOGIN);
    } catch (e) {
      if (kDebugMode) {
        print('Error during sign out: $e');
      }
      Get.snackbar(
        'Error',
        'Failed to sign out: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }
} 