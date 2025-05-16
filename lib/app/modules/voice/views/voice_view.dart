import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:voice_to_text/app/modules/login/views/widgets/user_profile.dart';
import '../controllers/voice_controller.dart';

class VoiceScreen extends GetView<VoiceController> {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();

    // Scroll to bottom when messages change
    // Make sure this listener is disposed to prevent memory leaks if VoiceScreen is disposed
    // GetX usually handles controller listeners, but direct listeners on observables might need care.
    // However, since this is in build method, it gets re-evaluated.
    ever(controller.chatMessages, (_) {
      // Using ever for better lifecycle management with GetX
      if (scrollController.hasClients && controller.chatMessages.isNotEmpty) {
        // Check if chatMessages is not empty ensures ListView is likely being built
        Future.delayed(const Duration(milliseconds: 100), () {
          // Additional check inside delayed callback as state might change again
          if (scrollController.hasClients &&
              controller.chatMessages.isNotEmpty) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'ToothWise AI Assistant',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        centerTitle: true,
        actions: [const UserProfileIcon()],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Obx(() {
                if (controller.chatMessages.isEmpty) {
                  // When chat is empty, scrollController is not attached to the ListView
                  return Center(
                    child: Text(
                      'Tap the button and start speaking...',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                // ListView is built only when chatMessages is not empty
                return ListView.builder(
                  controller: scrollController, // controller is attached here
                  padding: const EdgeInsets.only(
                    top: 100,
                    bottom: 180,
                    left: 10,
                    right: 10,
                  ),
                  itemCount: controller.chatMessages.length,
                  itemBuilder: (context, index) {
                    final message = controller.chatMessages[index];
                    final bool isUserMessage = message['sender'] == 'user';
                    final bool isSystemMessage = message['sender'] == 'system';
                    final String formattedTime = DateFormat(
                      'hh:mm a',
                    ).format(message['timestamp']);

                    return Align(
                      alignment:
                          isUserMessage
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 5,
                          horizontal: 8,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 15,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isUserMessage
                                  ? Colors.blueAccent.withOpacity(0.8)
                                  : isSystemMessage
                                  ? Colors.grey.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft:
                                isUserMessage
                                    ? const Radius.circular(16)
                                    : const Radius.circular(4),
                            bottomRight:
                                isUserMessage
                                    ? const Radius.circular(4)
                                    : const Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 3,
                              offset: const Offset(1, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment:
                              isUserMessage
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message['text'],
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                color:
                                    isSystemMessage
                                        ? Colors.white70
                                        : Colors.white,
                                fontWeight:
                                    isSystemMessage
                                        ? FontWeight.w300
                                        : FontWeight.normal,
                                fontStyle:
                                    isSystemMessage
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedTime,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.6),
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
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              height: 50,
              child: Obx(() {
                if (controller.isWaitingForBot.value) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Assistant is replying...",
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(delay: 500.ms, duration: 300.ms).fadeIn(duration: 300.ms);
                } else if (!controller.isListening.value && controller.recognizedText.value.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      "You said: ${controller.recognizedText.value}",
                      style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontSize: 13, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                } else {
                  return const SizedBox(height: 20);
                }
              }),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20.0, right: 0),
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (controller.isListening.value)
                FloatingActionButton(
                      heroTag: 'stopFab',
                      onPressed: controller.stopListening,
                      backgroundColor: Colors.redAccent.withOpacity(0.9),
                      elevation: 2,
                      mini: true,
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 200.ms)
                    .slideX(begin: 0.2, curve: Curves.easeInOutCubic),
              if (controller.isListening.value) const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'mainFab',
                onPressed: (controller.isWaitingForBot.value || controller.isBotAudioPlaying.value)
                    ? null  // Disable button while waiting for bot or bot is speaking
                    : controller.isListening.value
                        ? null
                        : controller.startListening,
                backgroundColor: (controller.isWaitingForBot.value || controller.isBotAudioPlaying.value)
                    ? Colors.grey.withOpacity(0.6)  // Grey out when disabled
                    : controller.isListening.value
                        ? Colors.grey.withOpacity(0.6)
                        : const Color(0xFF00B8D4).withOpacity(0.95),
                elevation: controller.isListening.value ? 2.0 : 6.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      controller.isListening.value ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                      size: controller.isListening.value ? 24 : 28,
                    ),
                    if (controller.isWaitingForBot.value || controller.isBotAudioPlaying.value)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ).animate(
                target: controller.isListening.value ? 0 : 1,
                effects:
                    controller.isListening.value
                        ? []
                        : [
                          ScaleEffect(
                            delay: 400.ms,
                            duration: 400.ms,
                            begin: Offset(0.9, 0.9),
                            end: Offset(1, 1),
                            curve: Curves.elasticOut,
                          ),
                          ShimmerEffect(
                            delay: 800.ms,
                            duration: 1200.ms,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ],
              ),
              if (!controller.isListening.value && !controller.isWaitingForBot.value)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0, right: 4.0),
                  child: Text(
                    "Tip: In noisy places, move closer to your phone's mic or use a headset for best results.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
