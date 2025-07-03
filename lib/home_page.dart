import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'widgets/horizontal_tracks_widget.dart';
import 'track_list_widget.dart';
import 'queue_page.dart';
import 'favorites_screen.dart';
import 'search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SizedBox(height: 10),
              HorizontalTracksWidget(),
              SizedBox(height: 10), // Было 32 — уменьшили
              Text(
                'ALL TRACKS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 8), // Было 16 — уменьшили
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TrackListWidget(),
          ),
        ),
      ],
    );
  }
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),
    const QueuePage(),
    const FavoritesScreen(),
  ];

  void _openSearchPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SearchPage(),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.linear,
          );

          return FadeTransition(opacity: curvedAnimation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF010A15), Color(0xFF0D325F)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SizedBox(
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: SvgPicture.asset(
                            'assets/icons/search.svg',
                            color: Colors.white,
                            width: 28,
                          ),
                          onPressed: _openSearchPage,
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
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey<int>(_currentIndex),
                    child: _screens[_currentIndex],
                  ),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SizedBox(
        height: 80,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Color(0xFF0D325F), // нижняя часть градиента с экрана
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final double itemWidth = width / 3;
                final double bubbleWidth = 64;
                final double bubbleHeight = 52;
                final double bubbleLeft =
                    _currentIndex * itemWidth + (itemWidth - bubbleWidth) / 2;
                final double bubbleTop = (80 - bubbleHeight) / 2;

                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      left: bubbleLeft,
                      top: bubbleTop,
                      child: Container(
                        width: bubbleWidth,
                        height: bubbleHeight,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1CA4FF),
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    SizedBox.expand(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Center(
                              child: _buildNavItem(0, 'assets/icons/home.svg'),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: _buildNavItem(
                                1,
                                'assets/icons/playlist.svg',
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: _buildNavItem(2, 'assets/icons/heart.svg'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String asset) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: SvgPicture.asset(
            asset,
            width: 30,
            height: 30,
            color: Colors.white,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
