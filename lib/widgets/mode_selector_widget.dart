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
  final List<GlobalKey> _keys = [];
  double _indicatorWidth = 0;
  double _indicatorLeft = 0;

  @override
  void initState() {
    super.initState();
    // Создаем ключи для каждого элемента списка
    for (int i = 0; i < widget.modes.length; i++) {
      _keys.add(GlobalKey());
    }
    // Вычисляем начальную позицию индикатора после первого кадра
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateIndicatorPosition(),
    );
  }

  @override
  void didUpdateWidget(covariant ModeSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedMode != oldWidget.selectedMode) {
      _updateIndicatorPosition();
    }
  }

  void _updateIndicatorPosition() {
    final selectedIndex = widget.modes.indexOf(widget.selectedMode);
    if (selectedIndex == -1) return;

    final key = _keys[selectedIndex];
    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _indicatorWidth = renderBox.size.width;
        // renderBox.localToGlobal(Offset.zero) дает позицию относительно экрана,
        // нам нужна позиция относительно ListView, поэтому используем только .dx
        _indicatorLeft =
            renderBox.localToGlobal(Offset.zero).dx -
            24; // 24 - это отступ родительского ListView
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            itemCount: widget.modes.length,
            itemBuilder: (context, index) {
              final mode = widget.modes[index];
              return GestureDetector(
                onTap: () {
                  widget.onModeSelected(mode);
                },
                child: Padding(
                  key: _keys[index],
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Center(
                    child: Text(
                      mode.toUpperCase(),
                      style: TextStyle(
                        color: widget.selectedMode == mode
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Анимированная полоска-индикатор
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            left: _indicatorLeft,
            bottom: 6, // Отступ от нижнего края
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              height: 3,
              width: _indicatorWidth,
              decoration: BoxDecoration(
                color: const Color(0xFF1CA4FF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
