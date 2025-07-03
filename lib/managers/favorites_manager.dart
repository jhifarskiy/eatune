// lib/managers/favorites_manager.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatune/models/track_model.dart'; // <-- ИЗМЕНЕНИЕ ЗДЕСЬ

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

  static Future<void> _save() async {
    notifier.value = List.from(_favoriteTracks);

    try {
      final prefs = await SharedPreferences.getInstance();
      final favoriteTracksJson = _favoriteTracks
          .map((track) => json.encode(track.toJson()))
          .toList();
      await prefs.setStringList(_key, favoriteTracksJson);
    } catch (e) {
      print("Error saving favorites: $e");
    }
  }

  static List<Track> get favorites => _favoriteTracks;

  static bool isFavorite(String trackId) {
    return _favoriteTracks.any((track) => track.id == trackId);
  }

  static void addFavorite(Track track) {
    if (!isFavorite(track.id)) {
      _favoriteTracks.add(track);
      _save();
    }
  }

  static void removeFavorite(String trackId) {
    _favoriteTracks.removeWhere((track) => track.id == trackId);
    _save();
  }

  static void toggleFavorite(Track track) {
    if (isFavorite(track.id)) {
      removeFavorite(track.id);
    } else {
      addFavorite(track);
    }
  }
}
