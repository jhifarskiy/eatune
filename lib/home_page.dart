import 'package:eatune/settings_page.dart';
import 'package:eatune/api.dart';
import 'package:eatune/helpers/genre_helper.dart';
import 'package:eatune/managers/my_orders_manager.dart';
import 'package:eatune/managers/track_cache_manager.dart';
import 'package:eatune/managers/venue_session_manager.dart';
import 'package:eatune/widgets/cooldown_dialog.dart';
import 'package:eatune/widgets/pressable_animated_widget.dart';
import 'package:eatune/widgets/track_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'track_list_widget.dart';
import 'queue_page.dart';
import 'favorites_screen.dart';
import 'search_page.dart';
import 'managers/queue_manager.dart';

void showTrackConfirmationModal(BuildContext context, Track track) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black.withOpacity(0.5),
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, _, __) {
      return TrackConfirmationDialog(
        track: track,
        onConfirm: () async {
          Navigator.of(context).pop();
          final venueId = await VenueSessionManager.getActiveVenueId();
          if (venueId == null) {
            if (!context.mounted) return;
            _showCustomSnackBar(
              context,
              'Ошибка сессии. Отсканируйте QR-код заново.',
            );
            return;
          }
          final ApiResponse response = await ApiService.addToQueue(
            trackId: track.id,
            venueId: venueId,
          );
          if (!context.mounted) return;
          if (response.success) {
            MyOrdersManager.add(track.id);
            _showCustomSnackBar(context, response.message);
          } else {
            if (response.cooldownType != null &&
                response.timeLeftSeconds != null) {
              showDialog(
                context: context,
                builder: (context) => CooldownDialog(
                  initialCooldownSeconds: response.timeLeftSeconds!,
                ),
              );
            } else {
              _showCustomSnackBar(context, response.message);
            }
          }
        },
      );
    },
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutQuart),
          child: child,
        ),
      );
    },
  );
}

void _showCustomSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: const Color(0xFF1885D3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.0)),
      margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      duration: const Duration(milliseconds: 1500),
    ),
  );
}

class FeaturedTracksWidget extends StatefulWidget {
  const FeaturedTracksWidget({super.key});

  @override
  State<FeaturedTracksWidget> createState() => _FeaturedTracksWidgetState();
}

class _FeaturedTracksWidgetState extends State<FeaturedTracksWidget> {
  Future<List<Track>>? _featuredTracksFuture;

  @override
  void initState() {
    super.initState();
    _featuredTracksFuture = _loadFeaturedTracks();
  }

  Future<List<Track>> _loadFeaturedTracks() async {
    List<Track> allTracks = await TrackCacheManager.getAllTracks();
    List<Track> tracksWithCovers = allTracks.where((t) => t.hasCover).toList();
    tracksWithCovers.shuffle();
    return tracksWithCovers.take(7).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Track>>(
      future: _featuredTracksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildPlaceholder();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final tracks = snapshot.data!;
        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return PressableAnimatedWidget(
                onTap: () => showTrackConfirmationModal(context, track),
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: Image.network(
                      track.coverUrl!,
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return SizedBox(
      height: 120,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[850]!,
        highlightColor: Colors.grey[800]!,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          itemCount: 7,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Container(height: 120, width: 120, color: Colors.black),
              ),
            );
          },
        ),
      ),
    );
  }
}

class GenreSelectorWidget extends StatelessWidget {
  final List<String> genres;
  final String? selectedGenre;
  final ValueChanged<String> onGenreSelected;

  GenreSelectorWidget({
    super.key,
    required this.genres,
    this.selectedGenre,
    required this.onGenreSelected,
  });

  final Map<String, String> genreCovers = {
    'Jazz':
        'https://images.pexels.com/photos/1649691/pexels-photo-1649691.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
    'Rock':
        'https://images.pexels.com/photos/167636/pexels-photo-167636.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
    'Pop':
        'https://images.pexels.com/photos/1190297/pexels-photo-1190297.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
    'Hip-Hop/R&B':
        'https://images.pexels.com/photos/894156/pexels-photo-894156.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
    'Dance':
        'https://images.pexels.com/photos/2240763/pexels-photo-2240763.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
    'Chillout':
        'https://images.pexels.com/photos/311039/pexels-photo-311039.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
    'default':
        'https://images.pexels.com/photos/3783471/pexels-photo-3783471.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        itemCount: genres.length,
        itemBuilder: (context, index) {
          final genre = genres[index];
          final isSelected = genre == selectedGenre;
          final coverUrl = genreCovers[genre] ?? genreCovers['default']!;

          return PressableAnimatedWidget(
            onTap: () => onGenreSelected(genre),
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  image: DecorationImage(
                    image: NetworkImage(coverUrl),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1CA4FF)
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13.0),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        genre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [
                            Shadow(blurRadius: 2, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ByGenreTabContent extends StatelessWidget {
  final bool isLoading;
  final List<String> genres;
  final String? selectedGenre;
  final ValueChanged<String> onGenreSelected;

  const _ByGenreTabContent({
    required this.isLoading,
    required this.genres,
    required this.selectedGenre,
    required this.onGenreSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Column(
      children: [
        GenreSelectorWidget(
          genres: genres,
          selectedGenre: selectedGenre,
          onGenreSelected: onGenreSelected,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: selectedGenre == null
                  ? const Center(
                      key: ValueKey('genre_placeholder'),
                      child: Text(
                        "Выберите жанр из списка выше",
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : TrackListWidget(
                      mode: 'genre',
                      filterValue: selectedGenre!,
                      key: ValueKey(selectedGenre!),
                    ),
            ),
          ),
        ),
      ],
    );
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
  final List<String> _tabs = const ['Popular', 'All Tracks', 'By Genre'];
  List<String> _allGenres = [];
  String? _selectedGenre;
  bool _isLoadingGenres = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadGenres();
    _tabController.addListener(() {
      if (_tabController.index != 2 && _selectedGenre != null) {
        setState(() {
          _selectedGenre = null;
        });
      }
    });
  }

  Future<void> _loadGenres() async {
    final allTracks = await TrackCacheManager.getAllTracks();
    final genres = <String>{};
    for (var track in allTracks) {
      if (track.genre != null && track.genre!.isNotEmpty) {
        genres.add(GenreHelper.getStandardizedGenre(track.genre!));
      }
    }
    final sortedGenres = genres.toList()..sort();
    if (mounted) {
      setState(() {
        _allGenres = sortedGenres;
        _isLoadingGenres = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Container(
          height: 40,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: TabBar(
            controller: _tabController,
            tabs: _tabs.map((label) => Tab(text: label.toUpperCase())).toList(),
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
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: _tabController,
            children: [
              Column(
                children: [
                  const FeaturedTracksWidget(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: TrackListWidget(
                        mode: 'popular',
                        key: const ValueKey('popular'),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: TrackListWidget(mode: 'all', key: const ValueKey('all')),
              ),
              _ByGenreTabContent(
                isLoading: _isLoadingGenres,
                genres: _allGenres,
                selectedGenre: _selectedGenre,
                onGenreSelected: (genre) {
                  setState(() {
                    if (_selectedGenre == genre) {
                      _selectedGenre = null;
                    } else {
                      _selectedGenre = genre;
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ],
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
    _checkAndClearCache();
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
    }
  }

  Future<void> _checkAndClearCache() async {
    if (mounted) {
      try {
        final currentVenueId = await VenueSessionManager.getActiveVenueId();
        final prefs = await SharedPreferences.getInstance();
        final lastVenueId = prefs.getString('last_venue_id');

        if (currentVenueId != lastVenueId) {
          TrackCacheManager.clearCache();
          await prefs.remove('cachedGenres');

          if (currentVenueId != null) {
            await prefs.setString('last_venue_id', currentVenueId);
          } else {
            await prefs.remove('last_venue_id');
          }
          if (mounted) setState(() {});
        }
      } catch (e) {
        // ...
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
        // ИЗМЕНЕНИЕ: Используем jumpToPage для мгновенного переключения
        _pageController.jumpToPage(index);
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
