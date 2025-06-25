import 'package:flutter/material.dart';

class TabSelectorWidget extends StatefulWidget {
  const TabSelectorWidget({super.key});

  @override
  State<TabSelectorWidget> createState() => _TabSelectorWidgetState();
}

class _TabSelectorWidgetState extends State<TabSelectorWidget> {
  int selectedIndex = 0;
  final List<String> tabs = ['POPULAR', 'BY GENRE', 'BY MOOD'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(tabs.length, (index) {
        final isSelected = index == selectedIndex;
        return Flexible(
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedIndex = index;
              });
            },
            // AnimatedContainer для плавной смены цвета и формы
            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: 300,
              ), // Длительность анимации
              curve: Curves.easeInOut, // Плавность перехода
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                // Устанавливаем цвет: активный с прозрачностью или полностью прозрачный
                color: isSelected
                    ? const Color(0xBD1CA4FF)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    // Текст тоже анимируется по цвету
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
