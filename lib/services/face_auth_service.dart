import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FaceAuthService {
  final String _endpoint = dotenv.env['AZURE_FACE_API_ENDPOINT']!;
  final String _apiKey = dotenv.env['AZURE_FACE_API_KEY']!;
  final String personGroupId = "merallin-employees";

  Future<String?> detectFace(File image) async {
    final url = Uri.parse('$_endpoint/face/v1.0/detect?returnFaceId=true');
    final bytes = await image.readAsBytes();

    final response = await http.post(
      url,
      headers: {
        'Ocp-Apim-Subscription-Key': _apiKey,
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );

    if (response.statusCode == 200) {
      final List<dynamic> faces = json.decode(response.body);
      if (faces.isNotEmpty) {
        return faces[0]['faceId'];
      }
    }
    debugPrint('Azure Detect Error: ${response.body}');
    return null;
  }

  Future<String?> identifyFace(String faceId) async {
    final url = Uri.parse('$_endpoint/face/v1.0/identify');
    final body = json.encode({
      'personGroupId': personGroupId,
      'faceIds': [faceId],
      'maxNumOfCandidatesReturned': 1,
      'confidenceThreshold': 0.7,
    });

    final response = await http.post(
      url,
      headers: {
        'Ocp-Apim-Subscription-Key': _apiKey,
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final List<dynamic> results = json.decode(response.body);
      if (results.isNotEmpty && results[0]['candidates'].isNotEmpty) {
        return results[0]['candidates'][0]['personId'];
      }
    }
    debugPrint('Azure Identify Error: ${response.body}');
    return null;
  }
}
