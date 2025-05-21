import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:voice_to_text/app/modules/login/views/widgets/user_profile.dart';
import '../controllers/voice_controller.dart';
import 'package:figma_squircle/figma_squircle.dart';
import '../widgets/service_list.dart';
import '../widgets/slot_list.dart';
import '../widgets/appointment_status.dart';

class VoiceScreen extends GetView<VoiceController> {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();
    ever(controller.chatMessages, (_) {
      // Using ever for better lifecycle management with GetX
      if (scrollController.hasClients && controller.chatMessages.isNotEmpty) {
        // Check if chatMessages is not empty ensures ListView is likely being built
        Future.delayed(const Duration(milliseconds: 100), () {
          // Additional check inside delayed callback as state might change again
          if (scrollController.hasClients &&
              controller.chatMessages.isNotEmpty) {
            scrollController.animateTo(
              scrollController.position.minScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    // Futuristic AI Design Palette
    const Color bgColor = Color(0xFF0A0A23); // Dark space blue
    const Color chatButtonColor = Color(0xFF00F0FF); // Neon cyan for primary FAB
    const Color fabIconColor = Colors.white; // For icons on FABs
    const Color stopButtonColor = Color(0xFFFF00FF); // Neon magenta for stop button
    const Color userBubbleColor = Color(0xFF1C2A4F); // Updated User Bubble Color - Muted Dark Blue
    // const Color botBubbleColor = Color(0xFF2A2A50); // Old bot color
    const Color textColor = Colors.white;

    // Define Bot Bubble Gradient
    const LinearGradient botBubbleGradient = LinearGradient(
      colors: [Color(0xFF0D1B4E), Color(0xFF254A80)], // Dark Sapphire to Celestial Blue
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'ToothWise AI Assistant',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        centerTitle: true,
        actions: [const UserProfileIcon()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Service List Section
            SizedBox(
              height: 200,
              child: ServiceList(controller: controller),
            ),
            
            // Appointment Status Section
            Obx(() {
              if (controller.currentAppointment.value != null) {
                return AppointmentStatus(
                  controller: controller,
                );
              }
              return const SizedBox.shrink();
            }),
            
            // Available Slots Section
            SlotList(controller: controller),
            
            // Animation Section with Loading State
            Obx(() {
              if (controller.isAnimating.value) {
                return Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Main Animation
                      AnimatedOpacity(
                        opacity: controller.isLoading.value ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Lottie.asset(
                          controller.currentAnimation.value,
                          height: 200,
                          width: 200,
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Loading Animation
                      AnimatedOpacity(
                        opacity: controller.isLoading.value ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Lottie.asset(
                          'assets/animations/loading.json',
                          height: 100,
                          width: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            
            // Chat Messages Section
            Expanded(
              child: Obx(() {
                var displayMessages = List<Map<String, dynamic>>.from(controller.chatMessages);
                if (controller.isWaitingForBot.value && displayMessages.isNotEmpty && displayMessages.last['sender'] == 'user') {
                  displayMessages.add({'sender': 'bot_typing', 'timestamp': DateTime.now()});
                }

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 140.0),
                  reverse: true,
                  itemCount: displayMessages.length,
                  itemBuilder: (context, index) {
                    final message = displayMessages[displayMessages.length - 1 - index];
                    final bool isUserMessage = message['sender'] == 'user';
                    final bool isBotTyping = message['sender'] == 'bot_typing';

                    if (isBotTyping) {
                      return _buildBotTypingIndicator(botBubbleGradient, chatButtonColor, textColor);
                    }

                    // Chat bubble styling with specific corner rounding for "talk bubble" look
                    // Using SmoothRectangleBorder for squircle corners
                    final ShapeBorder bubbleShape = SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                        cornerRadius: 20,
                        cornerSmoothing:1, // Adjust for desired smoothness
                      ),
                      side: isUserMessage 
                            ? BorderSide.none 
                            : BorderSide(color: chatButtonColor.withOpacity(0.7), width: 1.5), // Border for bot messages
                    );
                    
                    // The old BorderRadius logic might be partially replicable if figma_squircle supports different radii per corner,
                    // or by nesting/clipping. For now, a uniform squircle will be applied.
                    // BorderRadius messageBorderRadius = isUserMessage
                    //     ? const BorderRadius.only(
                    //         topLeft: Radius.circular(20.0),
                    //         topRight: Radius.circular(20.0),
                    //         bottomLeft: Radius.circular(20.0),
                    //         bottomRight: Radius.circular(5.0), // Less rounded on one corner
                    //       )
                    //     : const BorderRadius.only(
                    //         topLeft: Radius.circular(20.0),
                    //         topRight: Radius.circular(20.0),
                    //         bottomLeft: Radius.circular(5.0), // Less rounded on one corner
                    //         bottomRight: Radius.circular(20.0),
                    //       );

                    return Align(
                      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                        decoration: ShapeDecoration( 
                          gradient: isUserMessage ? null : botBubbleGradient, // Apply gradient for bot
                          color: isUserMessage ? userBubbleColor : null, // Use flat color for user, null for bot if gradient is used
                          shape: bubbleShape, 
                          shadows: [ 
                            BoxShadow(
                              color: chatButtonColor.withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        child: Column(
                          crossAxisAlignment: isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['text'].toString(),
                              style: GoogleFonts.inter(
                                color: textColor,
                                fontWeight: FontWeight.w400,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('hh:mm a').format(message['timestamp'] as DateTime),
                              style: GoogleFonts.inter(
                                color: textColor.withOpacity(0.6),
                                fontWeight: FontWeight.w300,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Obx(() {
          // Renamed variable for clarity
          bool isCurrentlyListening = controller.isListening.value;
          bool botBusy = controller.isWaitingForBot.value || controller.isBotAudioPlaying.value;
          bool canStartListening = !isCurrentlyListening && !botBusy;

          // Define the main microphone button widget once
          Widget mainMicButton = FloatingActionButton(
            heroTag: 'mainFab',
            onPressed: canStartListening ? controller.startListening : null,
            backgroundColor: canStartListening ? chatButtonColor : Colors.grey.shade700,
            elevation: canStartListening ? 6.0 : 2.0,
            shape: const CircleBorder(),
            child: Icon(
                isCurrentlyListening ? Icons.mic_off : Icons.mic,
                color: fabIconColor,
                size: 28,
            ),
          ).animate(
            target: canStartListening ? 1 : 0,
            effects: canStartListening ? 
              [
                ScaleEffect(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut, begin: const Offset(0.8, 0.8), end: const Offset(1,1)),
                ShimmerEffect(delay: 800.ms, duration: 1500.ms, color: chatButtonColor.withOpacity(0.5), blendMode: BlendMode.srcATop)
              ]
              : [],
          );

          if (isCurrentlyListening) {
            // Listening state: Show main mic (disabled) and stop button side-by-side
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                mainMicButton, // Will appear disabled due to onPressed: null from canStartListening logic
                const SizedBox(width: 16),
                FloatingActionButton(
                  heroTag: 'stopFab',
                  onPressed: controller.stopListening,
                  backgroundColor: stopButtonColor,
                  elevation: 4,
                  mini: false, // Make it normal size for balance in the Row
                  shape: const CircleBorder(),
                  child: const Icon(Icons.close, color: fabIconColor, size: 24),
                )
                .animate()
                .fadeIn(duration: 200.ms)
                .slideX(begin: 0.5, end: 0, curve: Curves.easeInOutCubic),
              ],
            );
          } else {
            // Not listening state: Show main mic button and "Tap to speak" text below it
            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                mainMicButton,
                if (!botBusy) // Only show "Tap to speak" if not busy and not listening
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, right: 4.0),
                    child: Text(
                      "Tap to speak",
                      style: GoogleFonts.inter(
                        color: chatButtonColor.withOpacity(0.8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms),
              ],
            );
          }
        }),
      ),
    );
  }

  Widget _buildBotTypingIndicator(Gradient botGradient, Color accentColor, Color textColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: ShapeDecoration( 
          gradient: botGradient,
          shape: SmoothRectangleBorder( 
            borderRadius: SmoothBorderRadius(
              cornerRadius: 20,
              cornerSmoothing:1,
            ),
            side: BorderSide(color: accentColor.withOpacity(0.7), width: 1.5), // Use accentColor
          ),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(Get.context!).size.width * 0.35),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor.withOpacity(0.7)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Typing...',
              style: GoogleFonts.inter(
                color: textColor.withOpacity(0.7),
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
