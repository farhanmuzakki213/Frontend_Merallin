import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';


/*
 * Helper Fubction untuk mengubah latitude dan longitude menjadi alamat lengkap
 * Menggunakan Reverse Geocoding
 */

class AddressHelper {
  // Mengurai string aneh seperti '{latitude: -6.123, longitude: 106.456}'
  static Map<String, double>? parseLocationString(String? locationString) {
    if (locationString == null || locationString.isEmpty) {
      return null;
    }
    try {
      // Menghapus kurung kurawal dan spasi
      final cleanedString = locationString.replaceAll(RegExp(r'[{}]'), '').trim();
      final parts = cleanedString.split(',');
      
      if (parts.length != 2) return null;

      final latPart = parts[0].split(':');
      final lonPart = parts[1].split(':');

      if (latPart.length != 2 || lonPart.length != 2) return null;

      final latitude = double.tryParse(latPart[1].trim());
      final longitude = double.tryParse(lonPart[1].trim());

      if (latitude != null && longitude != null) {
        return {'latitude': latitude, 'longitude': longitude};
      }
      return null;
    } catch (e) {
      debugPrint("Error parsing location string: $e");
      return null;
    }
  }

  static Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        // Menggabungkan alamat menjadi format yang lebih rapi dan mudah dibaca
        return [p.street, p.subLocality, p.locality, p.subAdministrativeArea]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ');
      }
      return "Alamat tidak ditemukan";
    } catch (e) {
      debugPrint("Error getting address: $e");
      return "Gagal mendapatkan alamat";
    }
  }
}
