import 'package:flutter/material.dart';

class TabSelectorWidget extends StatefulWidget {
  const TabSelectorWidget({super.key});

  @override
  State<TabSelectorWidget> createState() => _TabSelectorWidgetState();
}

class _TabSelectorWidgetState extends State<TabSelectorWidget> {
  int selectedIndex = 0;

  final List<String> tabs = ['Popular', 'By Genre', 'By Mood'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(tabs.length, (index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedIndex = index;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tabs[index],
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
