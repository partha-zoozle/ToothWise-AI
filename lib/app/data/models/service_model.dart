class Service {
  final int id;
  final String name;
  final double price;
  final int duration;
  final String description;

  Service({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    required this.description,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'],
      name: json['name'],
      price: json['price'].toDouble(),
      duration: json['duration'],
      description: json['description'],
    );
  }
}

class ServicesResponse {
  final bool success;
  final String message;
  final List<Service> services;

  ServicesResponse({
    required this.success,
    required this.message,
    required this.services,
  });

  factory ServicesResponse.fromJson(Map<String, dynamic> json) {
    return ServicesResponse(
      success: json['success'],
      message: json['message'],
      services: (json['services'] as List)
          .map((service) => Service.fromJson(service))
          .toList(),
    );
  }
} 