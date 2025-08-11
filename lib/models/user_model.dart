// lib/models/user_model.dart
import 'package:flutter/foundation.dart';

class User {
  final int id;
  final String name;
  final String email;
  final String address;
  final String phoneNumber;
  final List<String> roles;
  final String profile_photo_url;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.address,
    required this.phoneNumber,
    required this.roles,
    required this.profile_photo_url,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      final rolesData = json['roles'] as List<dynamic>? ?? [];
      List<String> roleNames;
      if (rolesData.isNotEmpty && rolesData.first is Map) {
        roleNames = rolesData.map((role) => role['name'] as String).toList();
      } else {
        roleNames = List<String>.from(rolesData);
      }
      return User(
        id: json['id'] is int
            ? json['id']
            : int.tryParse(json['id'].toString()) ?? 0,
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        address: json['alamat'] ?? 'Alamat tidak tersedia',
        phoneNumber: json['no_telepon'] ?? 'No. telp tidak tersedia',
        profile_photo_url: json['profile_photo_url'] ?? '',
        roles: roleNames,
      );
    } catch (e) {
      debugPrint('Error parsing User from JSON: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'alamat': address,
      'no_telepon': phoneNumber,
      'roles': roles,
      'profile_photo_url': profile_photo_url,
    };
  }
}
