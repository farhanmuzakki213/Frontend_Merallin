import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../models/attendance_history_model.dart';

class HistoryService {
  final String _baseUrl = dotenv.env['API_BASE_URL']!;

  Future<List<AttendanceHistory>> fetchHistory(String token, DateTime date) async {
    final String formattedDate = DateFormat('y-MM-dd').format(date);
    final url = Uri.parse('$_baseUrl/attendance/history?date=$formattedDate');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = json.decode(response.body);
      return body.map((dynamic item) => AttendanceHistory.fromJson(item)).toList();
    } else {
      throw Exception('Gagal memuat riwayat absensi');
    }
  }
}