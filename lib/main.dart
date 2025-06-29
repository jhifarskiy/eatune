import 'package:eatune/managers/favorites_manager.dart';
import 'package:flutter/material.dart';
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FavoritesManager.init();
  runApp(const EatOneApp());
}

class EatOneApp extends StatelessWidget {
  const EatOneApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Получаем базовую тему, чтобы не переопределить размеры и жирность
    final baseTextTheme = ThemeData.light().textTheme;

    return MaterialApp(
      title: 'EatOne',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Montserrat',
        scaffoldBackgroundColor: const Color(0xFF010A15),

        // ИЗМЕНЕНИЕ: Задаем кастомную тему для текста
        textTheme: baseTextTheme
            .copyWith(
              // Для обычного текста
              bodyLarge: baseTextTheme.bodyLarge?.copyWith(letterSpacing: -0.3),
              bodyMedium: baseTextTheme.bodyMedium?.copyWith(
                letterSpacing: -0.3,
              ),
              bodySmall: baseTextTheme.bodySmall?.copyWith(letterSpacing: -0.3),

              // Для заголовков
              titleLarge: baseTextTheme.titleLarge?.copyWith(
                letterSpacing: -0.4,
              ),
              titleMedium: baseTextTheme.titleMedium?.copyWith(
                letterSpacing: -0.4,
              ),
              titleSmall: baseTextTheme.titleSmall?.copyWith(
                letterSpacing: -0.4,
              ),

              // Для надписей на кнопках и т.д.
              labelLarge: baseTextTheme.labelLarge?.copyWith(
                letterSpacing: -0.4,
              ),
              labelMedium: baseTextTheme.labelMedium?.copyWith(
                letterSpacing: -0.4,
              ),
              labelSmall: baseTextTheme.labelSmall?.copyWith(
                letterSpacing: -0.4,
              ),

              // Для крупных заголовков
              headlineLarge: baseTextTheme.headlineLarge?.copyWith(
                letterSpacing: -0.4,
              ),
              headlineMedium: baseTextTheme.headlineMedium?.copyWith(
                letterSpacing: -0.4,
              ),
              headlineSmall: baseTextTheme.headlineSmall?.copyWith(
                letterSpacing: -0.4,
              ),
            )
            .apply(
              // Применяем основной цвет ко всем стилям
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
      ),
      home: const HomePage(),
    );
  }
}
