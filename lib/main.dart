import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
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
        // ИЗМЕНИТЕ ЭТУ СТРОКУ
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFF010A15),
      ),
      home: const HomePage(),
    );
  }
}
