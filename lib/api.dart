import 'package:http/http.dart' as http;
import 'dart:convert';
import 'managers/device_id_manager.dart';

class ApiResponse {
  final bool success;
  final String message;
  final String? cooldownType;
  final int? timeLeftSeconds;

  ApiResponse({
    required this.success,
    this.message = '',
    this.cooldownType,
    this.timeLeftSeconds,
  });
}

class Track {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String? genre;
  final int? year;
  final String? trackUrl;
  final String? coverUrl;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    this.genre,
    this.year,
    this.trackUrl,
    this.coverUrl,
  });

  // НОВЫЙ МЕТОД ДЛЯ ПРОВЕРКИ ОБЛОЖКИ
  bool get hasCover {
    if (coverUrl == null || coverUrl!.isEmpty) return false;
    // Проверяем, что это не наши служебные пометки
    if (coverUrl == 'spotify_not_found' || coverUrl == 'not_found_anywhere') {
      return false;
    }
    // Проверяем, что это похоже на настоящую ссылку
    return coverUrl!.startsWith('http');
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      duration: json['duration'] ?? '0:00',
      genre: json['genre'],
      year: json['year'],
      trackUrl: json['url'] ?? json['trackUrl'],
      coverUrl: json['coverUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'duration': duration,
      'genre': genre,
      'year': year,
      'trackUrl': trackUrl,
      'coverUrl': coverUrl,
    };
  }
}

class ApiService {
  static const String baseUrl = 'https://eatune-api.onrender.com';

  static Future<List<Track>> getTracks({
    String mode = 'all',
    String? value,
    int limit = 0,
  }) async {
    try {
      final queryParams = {
        'mode': mode,
        if (value != null) 'value': value,
        if (limit > 0) 'limit': limit.toString(),
      };

      final uri = Uri.parse(
        '$baseUrl/tracks',
      ).replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Track.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching tracks: $e');
    }
    return [];
  }

  static Future<List<Track>> getAllTracks() async {
    return getTracks(mode: 'all');
  }

  static Future<ApiResponse> addToQueue({
    required String trackId,
    required String venueId,
  }) async {
    final deviceId = DeviceIdManager.id;
    if (deviceId == null) {
      return ApiResponse(
        success: false,
        message: 'Ошибка идентификации устройства.',
      );
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/queue'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': trackId,
          'venueId': venueId,
          'deviceId': deviceId,
        }),
      );

      final body = json.decode(response.body);

      if (response.statusCode == 201) {
        return ApiResponse(success: true, message: 'Трек добавлен в очередь!');
      } else if (response.statusCode == 429) {
        return ApiResponse(
          success: false,
          message: body['error'] ?? 'Достигнут лимит запросов.',
          cooldownType: body['cooldownType'],
          timeLeftSeconds: (body['timeLeftSeconds'] as num?)?.toInt(),
        );
      } else {
        return ApiResponse(
          success: false,
          message: body['error']?.toString() ?? 'Не удалось добавить трек',
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Ошибка сети. Проверьте подключение.',
      );
    }
  }
}
