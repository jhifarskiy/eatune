// lib/managers/track_cache_manager.dart

import '../api.dart';

class TrackCacheManager {
  // Статическое поле для хранения кеша
  static List<Track>? _allTracksCache;

  // Флаг, чтобы избежать повторных запросов во время первой загрузки
  static Future<List<Track>>? _fetchFuture;

  /// Получает список всех треков.
  /// Если треки уже в кеше, возвращает их мгновенно.
  /// Если нет, загружает из сети, сохраняет в кеш и возвращает.
  static Future<List<Track>> getAllTracks() {
    if (_allTracksCache != null) {
      return Future.value(_allTracksCache);
    }

    if (_fetchFuture != null) {
      return _fetchFuture!;
    }

    _fetchFuture = ApiService.getAllTracks()
        .then((tracks) {
          _allTracksCache = tracks;
          _fetchFuture = null;
          return tracks;
        })
        .catchError((error) {
          _fetchFuture = null;
          throw error;
        });

    return _fetchFuture!;
  }

  /// Очищает кеш треков
  static void clearCache() {
    _allTracksCache = null;
    _fetchFuture = null;
  }
}
