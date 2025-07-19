import 'package:flutter/material.dart';

/// Виджет, который добавляет дочернему элементу анимацию
/// плавного "прожимания" при нажатии.
class PressableAnimatedWidget extends StatefulWidget {
  /// Дочерний виджет, к которому применяется анимация.
  final Widget child;

  /// Функция обратного вызова, которая сработает по завершении нажатия.
  final VoidCallback onTap;

  const PressableAnimatedWidget({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<PressableAnimatedWidget> createState() =>
      _PressableAnimatedWidgetState();
}

class _PressableAnimatedWidgetState extends State<PressableAnimatedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120), // Ускоряем анимацию
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.80).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
