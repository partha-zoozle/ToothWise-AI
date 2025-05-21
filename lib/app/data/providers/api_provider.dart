import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/service_model.dart';
import '../models/appointment_model.dart';

class ApiProvider {
  static const String baseUrl = 'https://dockrec.zoozle.dev';

  Future<ServicesResponse> getServices() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/list/services'));
      if (response.statusCode == 200) {
        return ServicesResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load services');
      }
    } catch (e) {
      throw Exception('Error fetching services: $e');
    }
  }

  Future<AppointmentResponse> getAppointmentStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/appointment/status'));
      if (response.statusCode == 200) {
        return AppointmentResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load appointment status');
      }
    } catch (e) {
      throw Exception('Error fetching appointment status: $e');
    }
  }

  Future<AvailableSlotsResponse> getAvailableSlots({
    required String date,
    required String time,
    required int serviceId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/appointment/slots?date=$date&time=$time&service_id=$serviceId'),
      );
      if (response.statusCode == 200) {
        return AvailableSlotsResponse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load available slots');
      }
    } catch (e) {
      throw Exception('Error fetching available slots: $e');
    }
  }
} 