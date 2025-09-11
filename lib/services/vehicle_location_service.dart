// lib/services/vehicle_location_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend_merallin/models/trip_model.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import '../models/vehicle_location_model.dart';
import 'trip_service.dart';

class VehicleLocationService {
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? '';
  final TripService _helperService = TripService();

  Future<List<VehicleLocation>> getHistory(String token) async {
    final url = Uri.parse('$_baseUrl/driver/vehicle-locations');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json'
    });
    _helperService.handleResponse(response);
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => VehicleLocation.fromJson(json)).toList();
  }

  Future<VehicleLocation?> getActiveLocation(String token) async {
    try {
      final allLocations = await getHistory(token);
      return allLocations.firstWhere((loc) => loc.derivedStatus != TripDerivedStatus.selesai);
    } catch(e) {
      return null;
    }
  }

  Future<VehicleLocation> getDetails(String token, int locationId) async {
    final url = Uri.parse('$_baseUrl/driver/vehicle-locations/$locationId');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json'
    });
    _helperService.handleResponse(response);
    return VehicleLocation.fromJson(json.decode(response.body));
  }
  
  Future<VehicleLocation> create(String token, int vehicleId, String keterangan) async {
    final url = Uri.parse('$_baseUrl/driver/vehicle-locations');
    final response = await http.post(url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'vehicle_id': vehicleId,
          'keterangan': keterangan,
        }));
    _helperService.handleResponse(response);
    return VehicleLocation.fromJson(json.decode(response.body)['data']);
  }

  Future<VehicleLocation> uploadStandbyAndStartKm({
    required String token,
    required int locationId,
    File? standbyPhoto,
    File? startKmPhoto,
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse('$_baseUrl/driver/vehicle-locations/$locationId/upload-standby-start');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields['latitude'] = latitude.toString()
      ..fields['longitude'] = longitude.toString();

    if (standbyPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'standby_photo', standbyPhoto.path,
          filename: basename(standbyPhoto.path)));
    }
    if (startKmPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'start_km_photo', startKmPhoto.path,
          filename: basename(startKmPhoto.path)));
    }
    
    final response = await _helperService.multipartPostRequest(request);
    return VehicleLocation.fromJson(json.decode(response.body)['data']);
  }

  Future<VehicleLocation> arriveAtLocation({
    required String token,
    required int locationId,
  }) async {
    final url = Uri.parse('$_baseUrl/driver/vehicle-locations/$locationId/arrive');
    final response = await http.post(url, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json'
    });
    _helperService.handleResponse(response);
    return VehicleLocation.fromJson(json.decode(response.body)['data']);
  }

  Future<VehicleLocation> uploadEndKm({
    required String token,
    required int locationId,
    required File endKmPhoto,
    required double latitude,
    required double longitude,
  }) async {
    final url = Uri.parse('$_baseUrl/driver/vehicle-locations/$locationId/upload-end');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields['latitude'] = latitude.toString()
      ..fields['longitude'] = longitude.toString()
      ..files.add(await http.MultipartFile.fromPath(
          'end_km_photo', endKmPhoto.path,
          filename: basename(endKmPhoto.path)));
          
    final response = await _helperService.multipartPostRequest(request);
    return VehicleLocation.fromJson(json.decode(response.body)['data']);
  }
}