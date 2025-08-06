import 'package:flutter/foundation.dart';

class User {
  final int id;
  final String name;
  final String email;
  final String address;
  final String phoneNumber;
  final String? awsFaceId; // Tambahkan properti ini

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.address,
    required this.phoneNumber,
    this.awsFaceId, // Tambahkan di constructor
  });

  // Factory constructor untuk membuat instance User dari JSON
  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        address: json['alamat'],
        phoneNumber: json['no_telepon'],
        awsFaceId: json['azure_person_id'], // Ambil data dari JSON
      );
    } catch (e) {
      debugPrint('Error parsing User from JSON: $e');
      rethrow;
    }
  }

  // Method untuk mengubah User menjadi JSON (berguna untuk penyimpanan lokal)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'alamat': address,
      'no_telepon': phoneNumber,
      'azure_person_id': awsFaceId,
    };
  }
}
