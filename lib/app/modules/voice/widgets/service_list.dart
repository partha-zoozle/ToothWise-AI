import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:voice_to_text/app/data/models/service_model.dart';
import '../controllers/voice_controller.dart';

class ServiceList extends StatelessWidget {
  final VoiceController controller;

  const ServiceList({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.services.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: controller.services.length,
        itemBuilder: (context, index) {
          final service = controller.services[index];
          return ServiceCard(service: service, controller: controller);
        },
      );
    });
  }
}

class ServiceCard extends StatelessWidget {
  final Service service;
  final VoiceController controller;

  const ServiceCard({
    Key? key,
    required this.service,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              if (controller.isAnimating.value && 
                  controller.currentAnimation.value == controller.serviceAnimations[service.name]) {
                return Lottie.asset(
                  controller.currentAnimation.value,
                  height: 100,
                  width: 100,
                  fit: BoxFit.contain,
                );
              }
              return Icon(
                _getServiceIcon(service.name),
                size: 50,
                color: Theme.of(context).primaryColor,
              );
            }),
            const SizedBox(height: 8),
            Text(
              service.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${service.price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${service.duration} mins',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getServiceIcon(String serviceName) {
    switch (serviceName) {
      case 'Teeth Cleaning':
        return Icons.cleaning_services;
      case 'Tooth Filling':
        return Icons.medical_services;
      case 'Root Canal':
        return Icons.bluetooth;
      case 'Tooth Extraction':
        return Icons.remove_circle;
      case 'Teeth Whitening':
        return Icons.brightness_high;
      default:
        return Icons.medical_services;
    }
  }
} 