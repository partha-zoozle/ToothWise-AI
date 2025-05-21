import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../controllers/voice_controller.dart';

class SlotList extends StatelessWidget {
  final VoiceController controller;

  const SlotList({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.availableSlots.value == null) {
        return const SizedBox.shrink();
      }

      final slots = controller.availableSlots.value!.slotsAvailable;
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Available Slots',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: slots.length,
              itemBuilder: (context, index) {
                final slot = slots[index];
                return SlotCard(
                  startTime: slot[0],
                  endTime: slot[1],
                  controller: controller,
                );
              },
            ),
          ),
          if (controller.isAnimating.value)
            Center(
              child: Lottie.asset(
                controller.currentAnimation.value,
                height: 200,
                width: 200,
                fit: BoxFit.contain,
              ),
            ),
        ],
      );
    });
  }
}

class SlotCard extends StatelessWidget {
  final String startTime;
  final String endTime;
  final VoiceController controller;

  const SlotCard({
    Key? key,
    required this.startTime,
    required this.endTime,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(startTime);
    final end = DateTime.parse(endTime);

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text('to'),
            Text(
              '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 