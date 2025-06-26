import 'package:flutter/material.dart';

class TabSelectorWidget extends StatefulWidget {
  const TabSelectorWidget({super.key});

  @override
  State<TabSelectorWidget> createState() => _TabSelectorWidgetState();
}

class _TabSelectorWidgetState extends State<TabSelectorWidget> {
  int _selectedIndex = 0;
  final List<String> _tabs = ['POPULAR', 'BY GENRE', 'BY MOOD'];

  // Вычисляем выравнивание для "пилюли" на основе индекса
  Alignment _getAlignment() {
    double x;
    switch (_selectedIndex) {
      case 0:
        x = -1.0;
        break;
      case 1:
        x = 0.0;
        break;
      case 2:
        x = 1.0;
        break;
      default:
        x = -1.0;
    }
    return Alignment(x, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44, // Фиксированная высота для контейнера
      // ИСПРАВЛЕНО: Убран BoxDecoration с темным фоном
      child: Stack(
        alignment: Alignment.center,
        children: [
          // "Пилюля", которая будет плавно скользить
          AnimatedAlign(
            alignment: _getAlignment(),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: FractionallySizedBox(
              widthFactor:
                  1 / _tabs.length, // Ширина пилюли равна 1/3 от общей ширины
              child: Container(
                margin: const EdgeInsets.all(4), // Небольшой отступ от краев
                decoration: BoxDecoration(
                  color: const Color(0xBD1CA4FF),
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
            ),
          ),

          // Ряд с текстом поверх "пилюли"
          Row(
            children: List.generate(_tabs.length, (index) {
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  behavior: HitTestBehavior
                      .opaque, // Чтобы вся область была кликабельной
                  child: Center(
                    child: Text(
                      _tabs[index],
                      style: TextStyle(
                        color: Colors.white.withOpacity(
                          _selectedIndex == index ? 1.0 : 0.7,
                        ),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
