// lib/main.dart

import 'package:eatune/managers/favorites_manager.dart';
import 'package:eatune/managers/venue_session_manager.dart'; // <-- НОВЫЙ ИМПОРТ
import 'package:eatune/venue_scan_page.dart'; // <-- НОВЫЙ ИМПОРТ
import 'package:flutter/material.dart';
import 'home_page.dart';

void main() async {
  // Убеждаемся, что все биндинги инициализированы
  WidgetsFlutterBinding.ensureInitialized();

  // ИЗМЕНЕНИЕ: Инициализируем менеджер избранного
  await FavoritesManager.init();

  // ИЗМЕНЕНИЕ: Проверяем, есть ли активная сессия
  final String? activeVenueId = await VenueSessionManager.getActiveVenueId();

  // ИЗМЕНЕНИЕ: Определяем, какой экран будет стартовым
  final Widget initialScreen = (activeVenueId == null)
      ? const VenueScanPage()
      : const HomePage();

  // Запускаем приложение с нужным стартовым экраном
  runApp(EatOneApp(initialScreen: initialScreen));
}

class EatOneApp extends StatelessWidget {
  // ИЗМЕНЕНИЕ: Добавляем поле для стартового экрана
  final Widget initialScreen;

  const EatOneApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EatOne',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Montserrat',
        scaffoldBackgroundColor: const Color(0xFF010A15),
        textTheme: ThemeData.light().textTheme
            .copyWith(
              bodyLarge: const TextStyle(letterSpacing: -0.4),
              bodyMedium: const TextStyle(letterSpacing: -0.4),
              bodySmall: const TextStyle(letterSpacing: -0.4),
              titleLarge: const TextStyle(letterSpacing: -0.4),
              titleMedium: const TextStyle(letterSpacing: -0.4),
              titleSmall: const TextStyle(letterSpacing: -0.4),
              labelLarge: const TextStyle(letterSpacing: -0.4),
              labelMedium: const TextStyle(letterSpacing: -0.4),
              labelSmall: const TextStyle(letterSpacing: -0.4),
              headlineLarge: const TextStyle(letterSpacing: -0.4),
              headlineMedium: const TextStyle(letterSpacing: -0.4),
              headlineSmall: const TextStyle(letterSpacing: -0.4),
            )
            .apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      // ИЗМЕНЕНИЕ: Используем initialScreen в качестве домашнего экрана
      home: initialScreen,
    );
  }
}
