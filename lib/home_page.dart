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

class _HomePageState extends State<HomePage> {
  final GlobalKey<NowPlayingWidgetState> _nowPlayingKey =
      GlobalKey<NowPlayingWidgetState>();
  int _currentIndex = 0;

  void _onTrackSelected() {
    _nowPlayingKey.currentState?.fetchCurrentTrack();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF010A15), Color(0xFF0D325F)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Верхняя панель
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF041C3E),
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xBD1CA4FF),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            showOrderModal(context);
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/home.svg',
              width: 33,
              height: 33,
              color: const Color(0xBD1CA4FF),
            ),
            activeIcon: SvgPicture.asset(
              'assets/icons/home.svg',
              width: 33,
              height: 33,
              color: Colors.white,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/headphones.svg',
              width: 33,
              height: 33,
              color: const Color(0xBD1CA4FF),
            ),
            activeIcon: SvgPicture.asset(
              'assets/icons/headphones.svg',
              width: 33,
              height: 33,
              color: Colors.white,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/search.svg',
              width: 33,
              height: 33,
              color: const Color(0xBD1CA4FF),
            ),
            activeIcon: SvgPicture.asset(
              'assets/icons/search.svg',
              width: 33,
              height: 33,
              color: Colors.white,
            ),
            label: '',
          ),
        ],
      ),
    );
  }
}

void showOrderModal(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Заказ',
    barrierColor: Colors.black.withOpacity(0.4),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (_, animation, __, ___) {
      final curved = Curves.easeOut.transform(animation.value);
      return Stack(
        children: [
          Opacity(
            opacity: curved,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Transform.translate(
              offset: Offset(0, 100 * (1 - curved)),
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 36,
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF041C3E),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const DefaultTextStyle(
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.5,
                      ),
                      child: Text(
                        '🎧 Ваш заказ принят!\n'
                        'Мы поставим вашу песню,\nкак только освободится очередь.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
