// lib/managers/venue_session_manager.dart

import 'package:shared_preferences/shared_preferences.dart';

class VenueSessionManager {
  static const _venueKey = 'active_venue_id';
  static const _timestampKey = 'venue_session_timestamp';

  // Сессия будет действительна 8 часов
  static const _sessionDuration = Duration(hours: 8);

  // Сохраняем ID заведения и время входа
  static Future<void> saveSession(String venueId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_venueKey, venueId);
    await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Получаем ID активного заведения, если сессия еще не истекла
  static Future<String?> getActiveVenueId() async {
    final prefs = await SharedPreferences.getInstance();
    final venueId = prefs.getString(_venueKey);
    final timestamp = prefs.getInt(_timestampKey);

    if (venueId == null || timestamp == null) {
      return null;
    }

    final sessionStartTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final currentTime = DateTime.now();

    // Если с момента входа прошло больше 8 часов, сбрасываем сессию
    if (currentTime.difference(sessionStartTime) > _sessionDuration) {
      await clearSession();
      return null;
    }

    return venueId;
  }

  // Очищаем сессию
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_venueKey);
    await prefs.remove(_timestampKey);
  }
}
