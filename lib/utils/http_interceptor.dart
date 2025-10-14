// lib/utils/http_interceptor.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend_merallin/providers/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class HttpInterceptor {
  final BuildContext context;
  late final AuthProvider _authProvider;

  HttpInterceptor(this.context) {
    // Dapatkan instance AuthProvider tanpa perlu listen perubahan
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
  }

  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    final response = await http.post(url, headers: headers, body: body);
    _handleResponse(response);
    return response;
  }

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final response = await http.get(url, headers: headers);
    _handleResponse(response);
    return response;
  }
  

  void _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      _authProvider.handleInvalidSession();
      throw Exception('Sesi tidak valid atau telah berakhir.');
    }
  }
}