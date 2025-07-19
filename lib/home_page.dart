import 'package:eatune/settings_page.dart';
import 'package:eatune/widgets/album_placeholders_widget.dart';
import 'package:eatune/widgets/pressable_animated_widget.dart';
import 'package:eatune/widgets/year_browser_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'track_list_widget.dart';
import 'queue_page.dart';
import 'favorites_screen.dart';
import 'search_page.dart';
import 'managers/queue_manager.dart';
import 'managers/venue_session_manager.dart';
import 'managers/track_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _HomeContentState extends State<HomeContent>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _tabController;
  final List<String> _tabs = const [
    'Popular',
    'By year',
    'All Tracks',
    'Jazz',
    'Pop',
    'Chillout',
  ];
  String? _selectedYear;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index != 1) {
          setState(() {
            _selectedYear = null;
          });
          _triggerCacheCheck();
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _triggerCacheCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.findAncestorStateOfType<_HomePageState>();
      if (state != null) {
        state._checkAndClearCache();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScrollConfiguration(
      behavior: NoGlowScrollBehavior(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Container(
            height: 40,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: TabBar(
              controller: _tabController,
              tabs: _tabs
                  .map((label) => Tab(text: label.toUpperCase()))
                  .toList(),
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.5),
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                fontFamily: 'Montserrat',
              ),
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Color(0xFF1CA4FF), width: 4.0),
                borderRadius: BorderRadius.all(Radius.circular(2.0)),
              ),
              indicatorSize: TabBarIndicatorSize.label,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              overlayColor: MaterialStateProperty.all(Colors.transparent),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _PopularTabContent(),
                      _ByYearTabContent(
                        onYearTapped: (year) {
                          setState(() {
                            _selectedYear = year;
                          });
                        },
                        selectedYear: _selectedYear,
                      ),
                      _AllTracksTabContent(),
                      _GenreTabContent(genre: 'jazz'),
                      _GenreTabContent(genre: 'pop'),
                      _GenreTabContent(genre: 'chillout'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PopularTabContent extends StatefulWidget {
  @override
  State<_PopularTabContent> createState() => _PopularTabContentState();
}

class _PopularTabContentState extends State<_PopularTabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        const AlbumPlaceholdersWidget(),
        const SizedBox(height: 24),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TrackListWidget(
              mode: 'popular',
              limit: 20,
              key: const ValueKey('popular'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ByYearTabContent extends StatefulWidget {
  final Function(String year) onYearTapped;
  final String? selectedYear;

  const _ByYearTabContent({required this.onYearTapped, this.selectedYear});

  @override
  State<_ByYearTabContent> createState() => _ByYearTabContentState();
}

class _ByYearTabContentState extends State<_ByYearTabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      key: const ValueKey('by_year'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YearBrowserWidget(onYearTapped: widget.onYearTapped),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            widget.selectedYear == null
                ? 'CHOOSE YEAR'
                : 'HITS OF ${widget.selectedYear}',
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
            child: widget.selectedYear == null
                ? const Center(
                    child: Text(
                      "Выберите год из списка выше",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : TrackListWidget(
                    mode: 'year',
                    filterValue: widget.selectedYear!,
                    limit: 20,
                    key: ValueKey(widget.selectedYear),
                  ),
          ),
        ),
      ],
    );
  }
}

class _AllTracksTabContent extends StatefulWidget {
  @override
  State<_AllTracksTabContent> createState() => _AllTracksTabContentState();
}

class _AllTracksTabContentState extends State<_AllTracksTabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: TrackListWidget(
        mode: 'all',
        limit: 20,
        key: const ValueKey('all'),
      ),
    );
  }
}

class _GenreTabContent extends StatefulWidget {
  final String genre;

  const _GenreTabContent({required this.genre});

  @override
  State<_GenreTabContent> createState() => _GenreTabContentState();
}

class _GenreTabContentState extends State<_GenreTabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: TrackListWidget(
        mode: 'genre',
        filterValue: widget.genre,
        limit: 20,
        key: ValueKey(widget.genre),
      ),
    );
  }
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final PageController _pageController;

  final List<Widget> _screens = [
    const HomeContent(),
    const QueuePage(),
    const FavoritesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      context.read<QueueManager>().connect();
      _checkAndClearCache();
    }
  }

  Future<void> _checkAndClearCache() async {
    if (mounted) {
      try {
        final currentVenueId = await VenueSessionManager.getActiveVenueId();
        final prefs = await SharedPreferences.getInstance();
        final lastVenueId = prefs.getString('last_venue_id');

        if (currentVenueId != lastVenueId) {
          TrackCacheManager.clearCache(); // Убрал await, так как метод синхронный
          if (currentVenueId != null) {
            await prefs.setString('last_venue_id', currentVenueId);
          } else {
            await prefs.remove('last_venue_id');
          }
          if (mounted) setState(() {});
        }
      } catch (e) {
        // Логика для логгера вместо print
      }
    }
  }

  void _openSearchPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SearchPage(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  void _openSettingsPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SettingsPage(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
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
                        child: PressableAnimatedWidget(
                          onTap: _openSearchPage,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/icons/search.svg',
                                color: Colors.white,
                                width: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SvgPicture.asset('assets/icons/logo.svg', width: 140),
                      Align(
                        alignment: Alignment.centerRight,
                        child: PressableAnimatedWidget(
                          onTap: _openSettingsPage,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/icons/settings.svg',
                                color: Colors.white,
                                width: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  children: _screens,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                    _checkAndClearCache();
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
            _buildNavItem(index: 0, asset: 'assets/icons/home.svg', size: 25.0),
            _buildNavItem(
              index: 1,
              asset: 'assets/icons/playlist.svg',
              size: 25.0,
            ),
            _buildNavItem(
              index: 2,
              asset: 'assets/icons/heart.svg',
              size: 25.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String asset,
    required double size,
  }) {
    final bool isSelected = _currentIndex == index;

    return PressableAnimatedWidget(
      onTap: () {
        if (index == 1) {
          context.read<QueueManager>().connect();
        }
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      },
      child: AnimatedScale(
        scale: isSelected ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: 80,
          height: 65,
          child: Center(
            child: SvgPicture.asset(
              asset,
              width: size,
              height: size,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
