import 'dart:convert';
import 'package:http/http.dart' as http;

class Track {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String? coverUrl;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    this.coverUrl,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      duration: json['duration'],
      coverUrl: json['coverUrl'],
    );
  }
}

class ApiService {
  static const String baseUrl = 'https://eatune-api.onrender.com';

  static Future<List<Track>> getAllTracks() async {
    final response = await http.get(Uri.parse('$baseUrl/tracks'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Track.fromJson(json)).toList();
    } else {
      throw Exception('Не удалось загрузить треки');
    }
  }

  static Future<bool> selectTrack(String id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/playlist/add'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'trackId': id}),
    );
    return response.statusCode == 200;
  }

  static Future<Track?> getCurrentTrack() async {
    final response = await http.get(Uri.parse('$baseUrl/playlist/current'));
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return Track.fromJson(jsonData);
    }
    return null;
  }

  static Future<int> getQueueLength() async {
    final response = await http.get(Uri.parse('$baseUrl/playlist/length'));
    if (response.statusCode == 200) {
      return int.tryParse(response.body) ?? 0;
    }
    return 0;
  }
}
