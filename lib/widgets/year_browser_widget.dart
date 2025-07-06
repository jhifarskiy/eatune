// lib/widgets/year_browser_widget.dart

import 'package:flutter/material.dart';

class YearBrowserWidget extends StatelessWidget {
  final Function(String year) onYearTapped;
  const YearBrowserWidget({super.key, required this.onYearTapped});

  @override
  Widget build(BuildContext context) {
    // Генерируем список годов от 2024 до 2004
    final years = List.generate(21, (index) => (2024 - index).toString());
    const coverBaseUrl =
        'https://Eatune.s3.us-west-004.backblazeb2.com/covers/';

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        itemCount: years.length,
        itemBuilder: (context, index) {
          final year = years[index];
          final coverUrl = '$coverBaseUrl$year.jpg';

          return GestureDetector(
            onTap: () => onYearTapped(year),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Image.network(
                  coverUrl,
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                  // В случае ошибки загрузки, показываем текст с годом
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 120,
                    width: 120,
                    color: Colors.grey[850],
                    child: Center(
                      child: Text(
                        year,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
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
