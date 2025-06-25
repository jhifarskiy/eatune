import 'package:http/http.dart' as http;
import 'dart:convert';

class Track {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String? trackUrl;
  final String? coverUrl;
  final double? currentTime;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    this.trackUrl,
    this.coverUrl,
    this.currentTime,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      duration: json['duration'] ?? '0:00',
      trackUrl: json['trackUrl'],
      coverUrl: json['coverUrl'],
      currentTime: (json['currentTime'] as num?)?.toDouble(),
    );
  }
}

class ApiService {
  static const String baseUrl = 'https://eatune-api.onrender.com';

  static Future<Track?> getCurrentTrack() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/track'));
      if (response.statusCode == 200 &&
          response.body.isNotEmpty &&
          response.body != 'null') {
        final data = jsonDecode(response.body);
        if (data != null && data['id'] != null) return Track.fromJson(data);
      }
    } catch (e) {
      print('Error fetching current track: $e');
    }
    return null;
  }

  // --- ИСПРАВЛЕНО: Полная реализация функции ---
  static Future<List<Track>> getAllTracks() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tracks'));
      if (response.statusCode == 200) {
        final List<dynamic> trackList = jsonDecode(response.body);
        return trackList.map((json) => Track.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching all tracks: $e');
    }
    return [];
  }

  // --- ИСПРАВЛЕНО: Полная реализация функции ---
  static Future<bool> selectTrack(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/track'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error selecting track: $e');
      return false;
    }
  }
}
