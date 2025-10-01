import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io' as io;
import 'package:http/http.dart' as http;

class AddressHelper {
  // Mengurai string aneh seperti '{latitude: -6.123, longitude: 106.456}'
  static Map<String, double>? parseLocationString(String? locationString) {
    if (locationString == null || locationString.isEmpty) {
      return null;
    }
    try {
      // Menghapus kurung kurawal dan spasi
      final cleanedString =
          locationString.replaceAll(RegExp(r'[{}]'), '').trim();
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

  static Future<String> getAddressFromCoordinates(
      double latitude, double longitude) async {
    // Cek jika platform adalah Desktop (Windows, Linux, macOS)
    if (!kIsWeb &&
        (io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS)) {
      // ======== GUNAKAN API UNTUK DESKTOP ========
      try {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude');

        final response =
            await http.get(url, headers: {'User-Agent': 'MerallinApp/1.0'});

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['display_name'] ?? 'Alamat tidak dapat diurai';
        } else {
          return 'Gagal memuat alamat (Status: ${response.statusCode})';
        }
      } catch (e) {
        debugPrint("Gagal mendapatkan alamat via API: $e");
        return "Gagal terhubung ke server alamat";
      }
    } else {
      // ======== GUNAKAN GEOCODING UNTUK MOBILE & WEB (KODE LAMA ANDA) ========
      try {
        List<Placemark> placemarks =
            await placemarkFromCoordinates(latitude, longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          return [p.street, p.subLocality, p.locality, p.subAdministrativeArea]
              .where((s) => s != null && s.isNotEmpty)
              .join(', ');
        }
        return "Alamat tidak ditemukan";
      } catch (e) {
        debugPrint("Error getting address via geocoding: $e");
        return "Gagal mendapatkan alamat";
      }
    }
  }
}
