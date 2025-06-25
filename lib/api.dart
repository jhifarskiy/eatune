import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl =
      'https://c284-37-110-215-125.ngrok-free.app/api/tracks';

  static Future<Map<String, dynamic>?> getCurrentTrack() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/current'));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final body = jsonDecode(res.body);
        return body.isNotEmpty ? body : null;
      }
    } catch (_) {}
    return null;
  }
}
