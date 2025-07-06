import 'package:eatune/widgets/mode_selector_widget.dart';
import 'package:eatune/widgets/year_browser_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'track_list_widget.dart';
import 'queue_page.dart';
import 'favorites_screen.dart';
import 'search_page.dart';
import 'managers/queue_manager.dart';

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
  final List<String> _modes = const ['Popular', 'By year', 'All Tracks'];
  late String _selectedMode;
  String? _selectedYear;

  // ИЗМЕНЕНИЕ: Добавляем PageController для управления PageView
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _selectedMode = _modes.first;
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: NoGlowScrollBehavior(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          ModeSelectorWidget(
            modes: _modes,
            selectedMode: _selectedMode,
            onModeSelected: (mode) {
              final index = _modes.indexOf(mode);
              // При нажатии на селектор, анимированно переключаем страницу
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            // ИЗМЕНЕНИЕ: Заменяем AnimatedSwitcher на PageView для свайпов
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                // При свайпе, обновляем состояние селектора
                setState(() {
                  _selectedMode = _modes[index];
                  _selectedYear = null; // Сбрасываем год при смене таба
                });
              },
              children: [
                // Страница 1: Popular
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: TrackListWidget(
                    mode: 'popular',
                    limit: 50,
                    key: const ValueKey('popular'),
                  ),
                ),

                // Страница 2: By Year
                Column(
                  key: const ValueKey('by_year'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    YearBrowserWidget(
                      onYearTapped: (year) {
                        setState(() {
                          _selectedYear = year;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        _selectedYear == null
                            ? 'CHOOSE YEAR'
                            : 'HITS OF $_selectedYear',
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
                        child: _selectedYear == null
                            ? const Center(
                                child: Text(
                                  "Выберите год из списка выше",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : TrackListWidget(
                                mode: 'year',
                                filterValue: _selectedYear!,
                                key: ValueKey(_selectedYear),
                              ),
                      ),
                    ),
                  ],
                ),

                // Страница 3: All Tracks
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: TrackListWidget(
                    mode: 'all',
                    key: const ValueKey('all'),
                  ),
                ),
              ],
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
