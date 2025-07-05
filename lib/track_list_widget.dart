import 'package:eatune/managers/my_orders_manager.dart';
import 'package:eatune/managers/track_cache_manager.dart';
import 'package:eatune/managers/venue_session_manager.dart';
import 'package:eatune/widgets/cooldown_dialog.dart';
import 'package:eatune/widgets/track_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'api.dart';

class TrackListWidget extends StatefulWidget {
  final String? genreFilter;
  final String? artistFilter;

  const TrackListWidget({super.key, this.genreFilter, this.artistFilter});

  @override
  State<TrackListWidget> createState() => _TrackListWidgetState();
}

class _TrackListWidgetState extends State<TrackListWidget> {
  late Future<List<Track>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _tracksFuture = _loadAndFilterTracks();
  }

  Future<List<Track>> _loadAndFilterTracks() async {
    var tracks = await TrackCacheManager.getAllTracks();

    // Показываем все треки, если выбран "Popular" или "All Tracks" И не выбран артист
    if ((widget.genreFilter == 'Popular' ||
            widget.genreFilter == 'All Tracks') &&
        widget.artistFilter == null) {
      return tracks;
    }

    // Фильтруем по жанру (если это не Popular/All Tracks)
    if (widget.genreFilter != null &&
        widget.genreFilter != 'Popular' &&
        widget.genreFilter != 'All Tracks') {
      tracks = tracks
          .where((track) => track.genre == widget.genreFilter)
          .toList();
    }

    // Фильтруем по артисту, если он выбран
    if (widget.artistFilter != null) {
      tracks = tracks
          .where((track) => track.artist == widget.artistFilter)
          .toList();
    }
    // Если артист НЕ выбран, но жанр - конкретный, возвращаем пустой список, чтобы сработала заглушка
    else if (widget.genreFilter != 'Popular' &&
        widget.genreFilter != 'All Tracks') {
      return [];
    }

    return tracks;
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

        // ИЗМЕНЕНИЕ: Показываем заглушку, если список пуст
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          bool isSpecificGenre =
              widget.genreFilter != 'Popular' &&
              widget.genreFilter != 'All Tracks';
          // Показываем инструкцию, если выбран конкретный жанр, но не артист
          if (isSpecificGenre && widget.artistFilter == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Выберите подборку выше',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ),
            );
          }
          // В остальных случаях (например, у артиста нет треков) - показываем шиммер
          return const _TrackListPlaceholder();
        }

        final tracks = snapshot.data!;
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
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
    return InkWell(
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
            const SizedBox(width: 16),
            Text(
              track.duration,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
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
        itemBuilder: (context, index) => const _TrackItemPlaceholder(),
      ),
    );
  }
}

class _TrackItemPlaceholder extends StatelessWidget {
  const _TrackItemPlaceholder();

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
