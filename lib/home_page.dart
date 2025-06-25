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
  // Ключ больше не нужен, NowPlayingWidget сам обновляется по таймеру

  // Эта функция теперь просто существует, чтобы соответствовать контракту виджета,
  // хотя основное обновление происходит по таймеру в NowPlayingWidget.
  // Она также полезна для немедленного обновления при желании.
  void _onTrackSelected() {
    print("Track selection signal received in home_page.");
    // В будущем здесь можно добавить дополнительную логику, если потребуется.
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(
                  height: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: SvgPicture.asset(
                          'assets/icons/menu.svg',
                          color: Colors.white,
                          width: 28,
                        ),
                        onPressed: () {},
                      ),
                      SvgPicture.asset('assets/icons/logo.svg', width: 140),
                      IconButton(
                        icon: SvgPicture.asset(
                          'assets/icons/settings.svg',
                          color: Colors.white,
                          width: 30,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),

                const NowPlayingWidget(),
                const SizedBox(height: 20),
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
