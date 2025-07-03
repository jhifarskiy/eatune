// lib/api.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/track_model.dart'; // <--- ИЗМЕНЕНИЕм

// НОВЫЙ КЛАСС для ответов от API
class ApiResponse {
  final bool success;
  final String message;

  ApiResponse({required this.success, this.message = ''});
}

class Track {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String? trackUrl;
  final String? coverUrl;
  final double? currentTime;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'duration': duration,
      'trackUrl': trackUrl,
      'coverUrl': coverUrl,
      'currentTime': currentTime,
    };
  }

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

  static Future<List<Track>> getAllTracks() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tracks'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Track.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching tracks: $e');
    }
    return [];
  }

  // ИЗМЕНЕНИЕ: Метод теперь возвращает ApiResponse вместо bool
  static Future<ApiResponse> addToQueue({
    required String trackId,
    required String venueId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/queue'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': trackId, 'venueId': venueId}),
      );

      if (response.statusCode == 201) {
        return ApiResponse(success: true, message: 'Трек добавлен в очередь!');
      } else {
        // Пытаемся извлечь сообщение об ошибке от сервера
        final body = json.decode(response.body);
        final errorMessage = body['error'] ?? 'Не удалось добавить трек';
        return ApiResponse(success: false, message: errorMessage);
      }
    } catch (e) {
      print('Error adding to queue: $e');
      return ApiResponse(success: false, message: 'Ошибка сети');
    }
  }

  static Future<Track?> getCurrentTrack() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/track'));
      if (response.statusCode == 200 &&
          response.body.isNotEmpty &&
          response.body != 'null') {
        final data = jsonDecode(response.body);
        if (data != null && data['id'] != null) {
          return Track.fromJson(data);
        }
      }
    } catch (e) {
      print('Error getting current track: $e');
    }
    return null;
  }

  static Future<List<Track>> getQueue() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/queue'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Track.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error getting queue: $e');
    }
    return [];
  }
}
