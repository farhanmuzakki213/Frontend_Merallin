import 'package:flutter/material.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? address;
  final String? profilePhotoPath;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.address,
    this.profilePhotoPath,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
      profilePhotoPath: json['profile_photo_path'] ?? '',
    );
  }

  User copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? address,
    String? profilePhotoPath,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
    );
  }
}

class AuthProvider extends ChangeNotifier {
  User? _user;
  User? get user => _user;

  void setUser(User user) {
    _user = user;
    notifyListeners();
  }

  void updateProfile({
    String? name,
    String? email,
    String? phoneNumber,
    String? address,
    String? profilePhotoPath,
  }) {
    if (_user != null) {
      _user = _user!.copyWith(
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        address: address,
        profilePhotoPath: profilePhotoPath,
      );
      notifyListeners();
    }
  }
}
