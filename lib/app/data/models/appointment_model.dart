import 'service_model.dart';

class AppointmentDetails {
  final int appointmentId;
  final DateTime slotStart;
  final DateTime slotEnd;
  final String notes;
  final double price;
  final Service service;

  AppointmentDetails({
    required this.appointmentId,
    required this.slotStart,
    required this.slotEnd,
    required this.notes,
    required this.price,
    required this.service,
  });

  factory AppointmentDetails.fromJson(Map<String, dynamic> json) {
    return AppointmentDetails(
      appointmentId: json['appointment_id'],
      slotStart: DateTime.parse(json['slot_start']),
      slotEnd: DateTime.parse(json['slot_end']),
      notes: json['notes'],
      price: json['price'].toDouble(),
      service: Service.fromJson(json['service']),
    );
  }
}

class AppointmentResponse {
  final String appointmentStatus;
  final AppointmentDetails appointmentDetails;

  AppointmentResponse({
    required this.appointmentStatus,
    required this.appointmentDetails,
  });

  factory AppointmentResponse.fromJson(Map<String, dynamic> json) {
    return AppointmentResponse(
      appointmentStatus: json['appointment_status'],
      appointmentDetails: AppointmentDetails.fromJson(json['appointment_details']),
    );
  }
}

class AvailableSlotsResponse {
  final String userPreferredDate;
  final String userPreferredTime;
  final Service userPreferredService;
  final List<List<String>> slotsAvailable;

  AvailableSlotsResponse({
    required this.userPreferredDate,
    required this.userPreferredTime,
    required this.userPreferredService,
    required this.slotsAvailable,
  });

  factory AvailableSlotsResponse.fromJson(Map<String, dynamic> json) {
    return AvailableSlotsResponse(
      userPreferredDate: json['user_preffered_date'],
      userPreferredTime: json['user_preffered_time'],
      userPreferredService: Service.fromJson(json['user_preffered_service']),
      slotsAvailable: (json['slots_available'] as List)
          .map((slot) => (slot as List).map((time) => time.toString()).toList())
          .toList(),
    );
  }
} 