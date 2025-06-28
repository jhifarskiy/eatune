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
    return MaterialApp(
      title: 'EatOne',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // ИЗМЕНЕНО: Заменяем 'Inter' на 'Montserrat'
        fontFamily: 'Montserrat',
        scaffoldBackgroundColor: const Color(0xFF010A15),
      ),
      home: const HomePage(),
    );
  }
}
