// lib/api.dart
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

  bool get hasCover {
    if (coverUrl == null || coverUrl!.isEmpty) return false;
    if (coverUrl == 'spotify_not_found' || coverUrl == 'not_found_anywhere') {
      return false;
    }
    return coverUrl!.startsWith('http');
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      // ИЗМЕНЕНИЕ: Используем '_id' если 'id' отсутствует для совместимости
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      duration: json['duration'] ?? '0:00',
      genre: json['genre'],
      year: json['year'],
      // ИЗМЕНЕНИЕ: Используем 'url' как запасной вариант для 'trackUrl'
      trackUrl: json['trackUrl'] ?? json['url'],
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

  // Получение всех треков для медиатеки
  static Future<List<Track>> getAllTracks() async {
    try {
      // ИЗМЕНЕНИЕ: Указываем новый, правильный адрес /api/tracks
      final uri = Uri.parse('$baseUrl/api/tracks');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Track.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error fetching all tracks: $e');
    }
    return [];
  }

  // Добавление трека в очередь
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
      // ИЗМЕНЕНИЕ: Указываем новый, правильный адрес /api/queue/add
      final response = await http.post(
        Uri.parse('$baseUrl/api/queue/add'),
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
