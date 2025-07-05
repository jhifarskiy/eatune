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
      // Если кеш есть, возвращаем его как успешный Future
      return Future.value(_allTracksCache);
    }

    if (_fetchFuture != null) {
      // Если загрузка уже идет, возвращаем тот же самый Future
      return _fetchFuture!;
    }

    // Если кеша нет и загрузка не идет, запускаем ее
    _fetchFuture = ApiService.getAllTracks()
        .then((tracks) {
          _allTracksCache = tracks; // Сохраняем в кеш
          _fetchFuture =
              null; // Сбрасываем future, чтобы можно было обновить кеш позже при необходимости
          return tracks;
        })
        .catchError((error) {
          _fetchFuture = null; // Сбрасываем future в случае ошибки
          throw error; // Пробрасываем ошибку дальше
        });

    return _fetchFuture!;
  }
}
