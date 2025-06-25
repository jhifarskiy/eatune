import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TabSelectorWidget extends StatefulWidget {
  const TabSelectorWidget({super.key});

  @override
  State<TabSelectorWidget> createState() => _TabSelectorWidgetState();
}

class _TabSelectorWidgetState extends State<TabSelectorWidget> {
  int _selectedIndex = 0;
  final List<String> _tabs = ['POPULAR', 'BY GENRE', 'BY MOOD'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(_tabs.length, (index) {
        final isSelected = index == _selectedIndex;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(right: 12), // Отступ между табами
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              // Используем голубой цвет для активного таба, как в макете
              color: isSelected ? const Color(0xFF38B6FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              _tabs[index],
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600, // Semi-Bold
                fontSize: 14,
                // Белый текст для активного, сероватый для остальных
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.6),
              ),
            ),
          ),
        );
      }),
    );
  }
}
