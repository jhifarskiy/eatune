import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart'; // Убедитесь, что путь к api.dart верный

class FavoritesManager {
  FavoritesManager._();

  static const _key = 'favoriteTracks';
  static List<Track> _favoriteTracks = [];

  static final ValueNotifier<List<Track>> notifier = ValueNotifier(
    _favoriteTracks,
  );

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteTracksJson = prefs.getStringList(_key) ?? [];
    _favoriteTracks = favoriteTracksJson
        .map((jsonString) => Track.fromJson(json.decode(jsonString)))
        .toList();
    notifier.value = List.from(_favoriteTracks);
  }

  // ИЗМЕНЕНО: Логика сохранения
  static Future<void> _save() async {
    // 1. Сначала НЕМЕДЛЕННО обновляем UI, отправив уведомление
    notifier.value = List.from(_favoriteTracks);

    // 2. Затем в фоне, незаметно для пользователя, сохраняем данные
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoriteTracksJson = _favoriteTracks
          .map((track) => json.encode(track.toJson()))
          .toList();
      await prefs.setStringList(_key, favoriteTracksJson);
    } catch (e) {
      // В случае ошибки можно добавить логирование
      print("Error saving favorites: $e");
    }
  }

  static List<Track> get favorites => _favoriteTracks;

  static bool isFavorite(String trackId) {
    return _favoriteTracks.any((track) => track.id == trackId);
  }

  // ИЗМЕНЕНО: Функции теперь просто меняют список и вызывают _save
  static void addFavorite(Track track) {
    if (!isFavorite(track.id)) {
      _favoriteTracks.add(track);
      _save(); // _save теперь сам обновит UI и сохранит данные
    }
  }

  static void removeFavorite(String trackId) {
    _favoriteTracks.removeWhere((track) => track.id == trackId);
    _save(); // _save теперь сам обновит UI и сохранит данные
  }

  static void toggleFavorite(Track track) {
    if (isFavorite(track.id)) {
      removeFavorite(track.id);
    } else {
      addFavorite(track);
    }
  }
}
