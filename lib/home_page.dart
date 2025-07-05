import 'package:eatune/managers/queue_manager.dart';
import 'package:eatune/widgets/album_browser_widget.dart';
import 'package:eatune/widgets/genre_selector_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'track_list_widget.dart';
import 'queue_page.dart';
import 'favorites_screen.dart';
import 'search_page.dart';

class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});
  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final List<String> _genres = const [
    'Popular',
    'R&B',
    'Hip-Hop',
    'Electronic',
    'Rock',
    'Soul',
    'All Tracks',
  ];

  late String _selectedGenre;
  String? _selectedArtist;
  String _trackListTitle = 'Popular';

  @override
  void initState() {
    super.initState();
    _selectedGenre = _genres.first;
    _trackListTitle = _genres.first;
  }

  @override
  Widget build(BuildContext context) {
    // ИЗМЕНЕНИЕ: Скрываем блок с подборками только для "All Tracks"
    final bool showPicks = _selectedGenre != 'All Tracks';

    return ScrollConfiguration(
      behavior: NoGlowScrollBehavior(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GenreSelectorWidget(
            genres: _genres,
            onGenreSelected: (genre) {
              setState(() {
                _selectedGenre = genre;
                _selectedArtist = null;
                _trackListTitle = genre;
              });
            },
          ),

          // ИЗМЕНЕНИЕ: Возвращаем AnimatedSwitcher для правильной анимации
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.0, -0.3),
                end: Offset.zero,
              ).animate(animation);

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slideAnimation, child: child),
              );
            },
            child: showPicks
                ? Column(
                    key: const ValueKey('picks-visible'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          'PICKS IN $_selectedGenre'.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AlbumBrowserWidget(
                        key: ValueKey<String>(_selectedGenre),
                        genreFilter: _selectedGenre,
                        onArtistTapped: (artistName) {
                          setState(() {
                            _selectedArtist = artistName;
                            _trackListTitle = artistName;
                          });
                        },
                      ),
                    ],
                  )
                : const SizedBox(key: ValueKey('picks-hidden')),
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              _trackListTitle.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: TrackListWidget(
                  key: ValueKey('$_selectedGenre/$_selectedArtist'),
                  genreFilter: _selectedGenre,
                  artistFilter: _selectedArtist,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),
    const QueuePage(),
    const FavoritesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print("App resumed, attempting to reconnect WebSocket...");
      context.read<QueueManager>().connect();
    }
  }

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
                            width: 24,
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
                            width: 24,
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
      bottomNavigationBar: Container(
        height: 65,
        color: const Color(0xFF0D325F),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(index: 0, asset: 'assets/icons/home.svg'),
            _buildNavItem(index: 1, asset: 'assets/icons/playlist.svg'),
            _buildNavItem(index: 2, asset: 'assets/icons/heart.svg'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({required int index, required String asset}) {
    final bool isSelected = _currentIndex == index;
    const double iconSize = 26.0;

    return GestureDetector(
      onTap: () {
        if (index == 1) {
          context.read<QueueManager>().connect();
        }
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        height: 65,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              asset,
              width: iconSize,
              height: iconSize,
              color: Colors.white,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: 3,
              width: isSelected ? iconSize : 0,
              decoration: BoxDecoration(
                color: const Color(0xFF1CA4FF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
