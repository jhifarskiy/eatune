import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'now_playing_widget.dart';
import 'tab_selector_widget.dart';
import 'track_list_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<NowPlayingWidgetState> _nowPlayingKey =
      GlobalKey<NowPlayingWidgetState>();
  int _currentIndex = 0;

  void _onTrackSelected() {
    _nowPlayingKey.currentState?.fetchCurrentTrack();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Позволяет телу рисоваться под навбаром
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF010A15), Color(0xFF0D325F)],
          ),
        ),
        child: SafeArea(
          bottom: false, // Отключаем нижний отступ, чтобы навбар прилегал
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Верхняя панель (без изменений)
                SizedBox(
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: SvgPicture.asset(
                            'assets/icons/menu.svg',
                            color: Colors.white,
                            width: 28,
                          ),
                          onPressed: () {},
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                      ),
                      SvgPicture.asset('assets/icons/logo.svg', width: 140),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: SvgPicture.asset(
                            'assets/icons/settings.svg',
                            color: Colors.white,
                            width: 30,
                          ),
                          onPressed: () {},
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                NowPlayingWidget(key: _nowPlayingKey),
                const SizedBox(height: 32),
                const TabSelectorWidget(),
                const SizedBox(height: 24),
                Expanded(
                  child: TrackListWidget(onTrackSelected: _onTrackSelected),
                ),
                const SizedBox(height: 85),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        child: Container(
          height: 80 + MediaQuery.of(context).padding.bottom,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildNavItem(0, 'assets/icons/home.svg'),
              _buildNavItem(1, 'assets/icons/headphones.svg'),
              _buildNavItem(2, 'assets/icons/search.svg'),
            ],
          ),
        ),
      ),
    );
  }

  // --- ИЗМЕНЕННЫЙ МЕТОД ДЛЯ ИКОНОК С "ПУЗЫРЬКОМ" ---
  Widget _buildNavItem(int index, String asset) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 1) {
          showOrderModal(context);
        } else {
          setState(() {
            _currentIndex = index;
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72, // Задаем фиксированную область для нажатия
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // "Пузырек", который теперь анимируется через масштаб и прозрачность
            AnimatedScale(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack, // Эффект "выпрыгивания"
              scale: isSelected ? 1.0 : 0.0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isSelected ? 1.0 : 0.0,
                child: Container(
                  width: 64,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1CA4FF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
            // Сама иконка, которая теперь не двигается
            SvgPicture.asset(asset, width: 30, height: 30, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// --- КРАСИВАЯ МОДАЛКА (БЕЗ ИЗМЕНЕНИЙ) ---
void showOrderModal(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Заказ',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (_, animation, __, child) {
      final scaleAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeOutCubic,
      );

      return ScaleTransition(
        scale: scaleAnimation,
        child: FadeTransition(
          opacity: animation,
          child: Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A6D),
                    borderRadius: BorderRadius.circular(50.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Заказ принят!',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Мы поставим вашу песню,\nкак только освободится очередь.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.transparent,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 22,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
