import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voice_to_text/app/modules/login/controllers/login_controller.dart';
final supabase = Supabase.instance.client;

class UserProfileIcon extends GetView<LoginController> {
  const UserProfileIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = supabase.auth.currentUser;
    String displayName = 'User';

    if (currentUser != null) {
      displayName = currentUser.userMetadata?['full_name'] ??
          currentUser.userMetadata?['name'] ??
          currentUser.email ??
          'User';
    }

    return IconButton(
      icon: const Icon(Icons.account_circle),
      onPressed: () {
        Get.dialog(
          AlertDialog(
            title: const Text('Profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi, $displayName!'),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Get.put(LoginController());
                      Get.back();
                      controller.signOut();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text('Logout', style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back(); // Close the dialog
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}
