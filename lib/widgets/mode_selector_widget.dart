// lib/widgets/mode_selector_widget.dart

import 'package:flutter/material.dart';

class ModeSelectorWidget extends StatefulWidget {
  final List<String> modes;
  final String selectedMode;
  final Function(String) onModeSelected;

  const ModeSelectorWidget({
    super.key,
    required this.modes,
    required this.selectedMode,
    required this.onModeSelected,
  });

  @override
  State<ModeSelectorWidget> createState() => _ModeSelectorWidgetState();
}

class _ModeSelectorWidgetState extends State<ModeSelectorWidget> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.modes.indexOf(widget.selectedMode);
  }

  // Обновляем индекс, если меняется выбранный режим извне
  @override
  void didUpdateWidget(covariant ModeSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedMode != oldWidget.selectedMode) {
      setState(() {
        _selectedIndex = widget.modes.indexOf(widget.selectedMode);
      });
    }
  }

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
        itemCount: widget.modes.length,
        itemBuilder: (context, index) {
          final mode = widget.modes[index];
          final bool isSelected = _selectedIndex == index;

          final style = TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          );

          final double textWidth = _calculateTextWidth(
            mode.toUpperCase(),
            style,
          );

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = index;
              });
              widget.onModeSelected(mode);
            },
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(mode.toUpperCase(), style: style),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: 3,
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
