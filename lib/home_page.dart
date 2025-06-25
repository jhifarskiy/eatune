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
  // Используем GlobalKey для связи между виджетами
  final GlobalKey<NowPlayingWidgetState> _nowPlayingKey =
      GlobalKey<NowPlayingWidgetState>();

  // Эта функция будет вызвана из списка треков для обновления плеера
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
                          // ИСПРАВЛЕНО: colorFilter заменен на color
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
                          // ИСПРАВЛЕНО: colorFilter заменен на color
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
        unselectedItemColor: const Color(
          0xBD1CA4FF,
        ), // #1CA4FF с 74% прозрачности
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        currentIndex: 0, // можно будет сделать управление текущей вкладкой
        onTap: (index) {
          // пока без действий
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
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/icons/playlist.svg',
              width: 33,
              height: 33,
              color: const Color(0xBD1CA4FF),
            ),
            activeIcon: SvgPicture.asset(
              'assets/icons/playlist.svg',
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
