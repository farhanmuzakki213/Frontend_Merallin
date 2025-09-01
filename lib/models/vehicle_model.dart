// lib/models/vehicle_model.dart

class Vehicle {
  final int id;
  final String licensePlate;
  final String model;
  final String type;

  Vehicle({
    required this.id,
    required this.licensePlate,
    required this.model,
    required this.type,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      licensePlate: json['license_plate'] ?? 'N/A',
      model: json['model'] ?? 'N/A',
      type: json['type'] ?? 'N/A',
    );
  }

  // Untuk perbandingan di dropdown
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vehicle && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}