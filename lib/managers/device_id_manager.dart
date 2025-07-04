// lib/managers/device_id_manager.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdManager {
  static const _key = 'device_unique_id';
  static String? _deviceId;

  // Инициализация при старте приложения
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString(_key);

    if (storedId == null) {
      // Если ID нет, создаем новый и сохраняем
      final newId = const Uuid().v4();
      await prefs.setString(_key, newId);
      _deviceId = newId;
      print('--- DeviceIdManager: New ID generated and saved: $newId');
    } else {
      // Если ID есть, просто загружаем его
      _deviceId = storedId;
      print('--- DeviceIdManager: Existing ID loaded: $storedId');
    }
  }

  // Метод для получения ID
  static String? get id {
    if (_deviceId == null) {
      print('--- DeviceIdManager: WARNING - Device ID was not initialized!');
    }
    return _deviceId;
  }
}
