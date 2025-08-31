// lib/models/vehicle_model.dart

class Vehicle {
  final int id;
  final String licensePlate;
  final String? model;
  final String? type;

  Vehicle({
    required this.id,
    required this.licensePlate,
    this.model,
    this.type,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      licensePlate: json['license_plate'] ?? 'N/A',
      model: json['model'],
      type: json['type'],
    );
  }
}