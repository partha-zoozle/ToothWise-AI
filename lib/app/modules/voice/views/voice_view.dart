import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:voice_to_text/app/modules/login/views/widgets/user_profile.dart';
import '../controllers/voice_controller.dart';
import 'widgets/voice_waveform.dart';

class VoiceScreen extends GetView<VoiceController> {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'ToothWise AI',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          const UserProfileIcon(),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6D5BFF),
              Color(0xFF2196F3),
              Color(0xFF00B8D4),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Obx(() => AnimatedSwitcher(
                      duration: 400.ms,
                      child: controller.isListening.value
                          ? VoiceWaveform(isListening: true)
                          : const SizedBox(height: 60),
                    )),
                const SizedBox(height: 30),
                Obx(() => Text(
                      controller.recognizedText.value.isEmpty
                          ? 'Your speech will appear here...'
                          : controller.recognizedText.value,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    )),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Obx(() => Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (controller.isListening.value)
                FloatingActionButton(
                  onPressed: controller.stopListening,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.close),
                )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.3, end: 0),
              const SizedBox(width: 16),
              if (!controller.isListening.value)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    'Start Call',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              FloatingActionButton(
                onPressed: controller.isListening.value
                    ? controller.stopListening
                    : controller.startListening,
                backgroundColor: controller.isListening.value
                    ? Colors.purpleAccent
                    : Colors.blueAccent,
                child: Icon(
                  controller.isListening.value ? Icons.mic : Icons.call,
                  color: Colors.white,
                ),
              )
                  .animate()
                  .scale(
                    duration: 300.ms,
                    curve: Curves.easeInOut,
                  ),
            ],
          )),
    );
  }
} 