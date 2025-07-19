import 'package:eatune/managers/favorites_manager.dart';
import 'package:eatune/managers/my_orders_manager.dart';
import 'package:eatune/managers/track_cache_manager.dart';
import 'package:eatune/managers/venue_session_manager.dart';
import 'package:eatune/widgets/cooldown_dialog.dart';
import 'package:eatune/widgets/pressable_animated_widget.dart';
import 'package:eatune/widgets/track_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'api.dart';

class TrackListWidget extends StatefulWidget {
  final String mode;
  final String? filterValue;
  final int limit;

  const TrackListWidget({
    super.key,
    required this.mode,
    this.filterValue,
    this.limit = 0,
  });

  @override
  State<TrackListWidget> createState() => _TrackListWidgetState();
}

class _TrackListWidgetState extends State<TrackListWidget>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Track>> _tracksFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tracksFuture = TrackCacheManager.getAllTracks();
  }

  @override
  void didUpdateWidget(covariant TrackListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filterValue != oldWidget.filterValue ||
        widget.mode != oldWidget.mode) {
      setState(() {
        _tracksFuture = TrackCacheManager.getAllTracks();
      });
    }
  }

  void _showConfirmationModal(BuildContext context, Track track) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, _, __) {
        return TrackConfirmationDialog(
          track: track,
          onConfirm: () {
            Navigator.of(context).pop();
            _confirmTrackSelection(track.id);
          },
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _confirmTrackSelection(String id) async {
    final venueId = await VenueSessionManager.getActiveVenueId();
    if (venueId == null) {
      if (!mounted) return;
      _showCustomSnackBar(
        context,
        'Ошибка сессии. Отсканируйте QR-код заново.',
      );
      return;
    }

    final ApiResponse response = await ApiService.addToQueue(
      trackId: id,
      venueId: venueId,
    );

    if (!mounted) return;

    if (response.success) {
      MyOrdersManager.add(id);
      _showCustomSnackBar(context, response.message);
    } else {
      if (response.cooldownType != null && response.timeLeftSeconds != null) {
        showDialog(
          context: context,
          builder: (context) =>
              CooldownDialog(initialCooldownSeconds: response.timeLeftSeconds!),
        );
      } else {
        _showCustomSnackBar(context, response.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Track>>(
      future: _tracksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _TrackListPlaceholder();
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Не удалось загрузить список треков.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'Треков не найдено.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        List<Track> displayedTracks = List.from(snapshot.data!);

        if (widget.mode == 'year' && widget.filterValue != null) {
          final yearNum = int.tryParse(widget.filterValue!);
          if (yearNum != null) {
            displayedTracks = displayedTracks
                .where((t) => t.year == yearNum)
                .toList();
          }
        } else if (widget.mode == 'genre' && widget.filterValue != null) {
          displayedTracks = displayedTracks
              .where(
                (t) =>
                    t.genre?.toLowerCase() == widget.filterValue!.toLowerCase(),
              )
              .toList();
        }

        if (widget.limit > 0 && displayedTracks.length > widget.limit) {
          displayedTracks = displayedTracks.sublist(0, widget.limit);
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: displayedTracks.length,
          itemBuilder: (context, index) {
            final track = displayedTracks[index];
            return _TrackItem(
              track: track,
              onTap: () => _showConfirmationModal(context, track),
            );
          },
        );
      },
    );
  }
}

class _TrackItem extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const _TrackItem({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Track>>(
      valueListenable: FavoritesManager.notifier,
      builder: (context, favoriteTracks, _) {
        final isFavorite = FavoritesManager.isFavorite(track.id);
        return PressableAnimatedWidget(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    track.coverUrl ?? '',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF374151),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.artist,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 45,
                  child: Text(
                    track.duration,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
                _FavoriteButton(
                  isFavorite: isFavorite,
                  onPressed: () {
                    final message = isFavorite
                        ? 'Удалено из избранного'
                        : 'Добавлено в избранное';
                    FavoritesManager.toggleFavorite(track);
                    _showCustomSnackBar(context, message);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FavoriteButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onPressed;

  const _FavoriteButton({required this.isFavorite, required this.onPressed});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation =
        TweenSequence([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.3),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.3, end: 1.0),
            weight: 50,
          ),
        ]).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    if (widget.isFavorite) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite != oldWidget.isFavorite) {
      if (widget.isFavorite) {
        _animationController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PressableAnimatedWidget(
      onTap: widget.onPressed,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Icon(
            widget.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: widget.isFavorite ? Colors.redAccent : Colors.white54,
          ),
        ),
      ),
    );
  }
}

class _TrackListPlaceholder extends StatelessWidget {
  const _TrackListPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[850]!,
      highlightColor: Colors.grey[800]!,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: 10,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) => const _TrackItemPlaceholderItem(),
      ),
    );
  }
}

class _TrackItemPlaceholderItem extends StatelessWidget {
  const _TrackItemPlaceholderItem();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 40,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ],
      ),
    );
  }
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
