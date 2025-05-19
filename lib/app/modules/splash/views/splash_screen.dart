import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
// import 'package:google_fonts/google_fonts.dart'; // No longer needed for main text
import '../controllers/splash_controller.dart';

class SplashScreen extends GetView<SplashController> {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure controller is initialized by accessing it.
    // Get.find<SplashController>(); 
    // This is usually handled by GetX if routes and bindings are set up correctly.

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A2E), // Dark blue-black background
      body: Stack(
        children: [
          // Top-left abstract shape
          Positioned(
            top: -screenHeight * 0.1,
            left: -screenWidth * 0.2,
            child: _buildAbstractShape(screenHeight, Colors.blueAccent.withOpacity(0.5), 300.ms)
          ),
          Positioned(
            top: -screenHeight * 0.05,
            left: -screenWidth * 0.3,
            child: _buildAbstractShape(screenHeight, Colors.cyanAccent.withOpacity(0.4), 400.ms, sizeFactor: 0.8)
          ),

          // Bottom-right abstract shape
          Positioned(
            bottom: -screenHeight * 0.15,
            right: -screenWidth * 0.25,
            child: _buildAbstractShape(screenHeight, Colors.purpleAccent.withOpacity(0.5), 500.ms, rotate: true)
          ),
          Positioned(
            bottom: -screenHeight * 0.1,
            right: -screenWidth * 0.35,
            child: _buildAbstractShape(screenHeight, Colors.pinkAccent.withOpacity(0.4), 600.ms, sizeFactor: 0.7, rotate: true)
          ),

          // Center App Logo
                    // Center App Name
          Center(
            child: Text(
              'TOOTHWISE AI', // Updated App Name
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            )
            .animate()
            .fadeIn(delay: 700.ms, duration: 800.ms)
            .scaleXY(begin: 0.8, end: 1.0, duration: 800.ms, curve: Curves.easeOutBack),
          ),

        ],
      ),
    );
  }

  Widget _buildAbstractShape(double screenHeight, Color color, Duration delay, {double sizeFactor = 1.0, bool rotate = false}) {
    return Transform.rotate(
      angle: rotate ? 0.5 : 0, // Slight rotation for visual interest
      child: Container(
        width: screenHeight * 0.5 * sizeFactor,
        height: screenHeight * 0.5 * sizeFactor,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [color.withOpacity(0.6), color.withOpacity(0.01)],
            stops: const [0.3, 1.0]
          ),
          shape: BoxShape.circle,
        ),
      )
      .animate()
      .fadeIn(delay: delay, duration: 800.ms)
      .slide(begin: rotate ? const Offset(0.5, 0.5) : const Offset(-0.5, -0.5), duration: 1000.ms, curve: Curves.easeOutCubic),
    );
  }
} 