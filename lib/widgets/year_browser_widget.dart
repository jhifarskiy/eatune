// lib/widgets/year_browser_widget.dart

import 'package:flutter/material.dart';

class YearBrowserWidget extends StatelessWidget {
  final Function(String year) onYearTapped;
  const YearBrowserWidget({super.key, required this.onYearTapped});

  @override
  Widget build(BuildContext context) {
    // Генерируем список годов от 2024 до 2004
    final years = List.generate(21, (index) => (2024 - index).toString());

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        itemCount: years.length,
        itemBuilder: (context, index) {
          final year = years[index];

          return GestureDetector(
            onTap: () => onYearTapped(year),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              // ИЗМЕНЕНО: Заменяем логику отображения картинки на кастомный контейнер
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1CA4FF).withOpacity(0.8),
                        const Color(0xFF0D325F),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      year,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
