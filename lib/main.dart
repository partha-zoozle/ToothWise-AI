import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voice_to_text/app/modules/login/controllers/login_controller.dart';
import 'package:voice_to_text/app/modules/splash/controllers/splash_controller.dart';
import 'package:voice_to_text/routes/app_pages.dart';

final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qfforovsnvhgmzylsxzx.supabase.co/',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmZm9yb3ZzbnZoZ216eWxzeHp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDczMjIzMTksImV4cCI6MjA2Mjg5ODMxOX0.xkLdSq4WQQm6HIykzz-Ck_fF7ZNnSnwa3tvXlReaA9M',
  );

  Get.put(SplashController());

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Voice to Text',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
