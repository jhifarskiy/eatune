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
          bottom: false, // Отключаем отступ снизу у SafeArea
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Верхняя панель по макету ---
                SizedBox(
                  height: 120, // Задаем высоту для позиционирования
                  child: Stack(
                    children: [
                      Positioned(
                        top: 20,
                        left: 0,
                        child: IconButton(
                          icon: SvgPicture.asset(
                            'assets/icons/menu.svg',
                            width: 24,
                          ),
                          onPressed: () {},
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          'assets/icons/logo.svg',
                          width: 150,
                        ),
                      ),
                      Positioned(
                        top: 20,
                        right: 0,
                        child: IconButton(
                          icon: SvgPicture.asset(
                            'assets/icons/settings.svg',
                            width: 24,
                          ),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),

                NowPlayingWidget(key: _nowPlayingKey),
                const SizedBox(height: 30),
                const TabSelectorWidget(),
                const SizedBox(height: 20),

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
        unselectedItemColor: Colors.white54,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: ''),
        ],
      ),
    );
  }
}
