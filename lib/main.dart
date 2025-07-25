import 'package:eatune/managers/favorites_manager.dart';
import 'package:eatune/managers/queue_manager.dart';
import 'package:eatune/managers/venue_session_manager.dart';
import 'package:eatune/venue_scan_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_page.dart';
import 'package:eatune/managers/device_id_manager.dart';

// НОВЫЙ КЛАСС: Глобально отключает glow-эффект и включает "пружинку"
class BouncingNoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  // Этот метод заставляет все списки использовать "пружинящую" физику
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceIdManager.init();
  await FavoritesManager.init();

  final String? activeVenueId = await VenueSessionManager.getActiveVenueId();
  final queueManager = QueueManager();
  if (activeVenueId != null) {
    queueManager.connect();
  }

  final Widget initialScreen = (activeVenueId == null)
      ? const VenueScanPage()
      : const HomePage();

  runApp(
    ChangeNotifierProvider(
      create: (context) => queueManager,
      child: EatOneApp(initialScreen: initialScreen),
    ),
  );
}

class EatOneApp extends StatelessWidget {
  final Widget initialScreen;
  const EatOneApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EatOne',
      debugShowCheckedModeBanner: false,
      // ИЗМЕНЕНИЕ: Применяем новое поведение прокрутки ко всему приложению
      scrollBehavior: BouncingNoGlowScrollBehavior(),
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
      home: initialScreen,
    );
  }
}
