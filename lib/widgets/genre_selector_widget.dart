import 'package:flutter/material.dart';

class GenreSelectorWidget extends StatefulWidget {
  final List<String> genres;
  final Function(String) onGenreSelected;

  const GenreSelectorWidget({
    super.key,
    required this.genres,
    required this.onGenreSelected,
  });

  @override
  State<GenreSelectorWidget> createState() => _GenreSelectorWidgetState();
}

class _GenreSelectorWidgetState extends State<GenreSelectorWidget> {
  int _selectedIndex = 0;

  // Функция для точного вычисления ширины текста
  double _calculateTextWidth(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size.width;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        itemCount: widget.genres.length,
        itemBuilder: (context, index) {
          final genre = widget.genres[index];
          final bool isSelected = _selectedIndex == index;

          final style = TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          );

          // Вычисляем ширину для каждого элемента
          final double textWidth = _calculateTextWidth(
            genre.toUpperCase(),
            style,
          );

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = index;
              });
              widget.onGenreSelected(genre);
            },
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(genre.toUpperCase(), style: style),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: 3,
                    // ИЗМЕНЕНИЕ: Ширина полоски теперь равна ширине текста
                    width: isSelected ? textWidth : 0,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1CA4FF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
