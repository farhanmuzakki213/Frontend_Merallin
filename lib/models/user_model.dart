import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class User {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final String? address;

  @HiveField(4)
  final String? phoneNumber;

  @HiveField(5)
  final List<String> roles;

  @HiveField(6)
  final String profilePhotoUrl;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.address,
    this.phoneNumber,
    required this.roles,
    required this.profilePhotoUrl,
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
        profilePhotoUrl: json['profile_photo_url'] ?? '',
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
      'profile_photo_url': profilePhotoUrl,
    };
  }
}
