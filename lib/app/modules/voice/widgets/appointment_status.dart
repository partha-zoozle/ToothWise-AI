import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../controllers/voice_controller.dart';

class AppointmentStatus extends StatelessWidget {
  final VoiceController controller;

  const AppointmentStatus({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.currentAppointment.value == null) {
        return const SizedBox.shrink();
      }

      final appointment = controller.currentAppointment.value!;
      final details = appointment.appointmentDetails;

      return Card(
        margin: const EdgeInsets.all(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Appointment ${appointment.appointmentStatus.toUpperCase()}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (controller.isAnimating.value)
                    Lottie.asset(
                      controller.currentAnimation.value,
                      height: 50,
                      width: 50,
                      fit: BoxFit.contain,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Service', details.service.name),
              _buildInfoRow('Date', _formatDate(details.slotStart)),
              _buildInfoRow('Time', _formatTime(details.slotStart, details.slotEnd)),
              _buildInfoRow('Duration', '${details.service.duration} minutes'),
              _buildInfoRow('Price', '₹${details.price.toStringAsFixed(0)}'),
              if (details.notes.isNotEmpty)
                _buildInfoRow('Notes', details.notes),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime start, DateTime end) {
    return '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - '
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }
} 