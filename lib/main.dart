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
      home: const HomePage(),
    );
  }
}
