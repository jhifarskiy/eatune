import 'package:flutter/material.dart';

enum LegalPageType { terms, privacy }

class LegalPage extends StatelessWidget {
  final LegalPageType type;
  const LegalPage({super.key, required this.type});

  String get _title => type == LegalPageType.terms
      ? 'Условия использования'
      : 'Политика конфиденциальности';

  String get _content => type == LegalPageType.terms
      ? 'Здесь будет полный текст вашего пользовательского соглашения...'
      : 'Здесь будет полный текст вашей политики обработки персональных данных...';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF010A15),
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: const Color(0xFF0D325F),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _content,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
