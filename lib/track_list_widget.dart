import 'package:eatune/managers/my_orders_manager.dart';
import 'package:eatune/managers/venue_session_manager.dart';
import 'package:eatune/widgets/cooldown_dialog.dart';
import 'package:eatune/widgets/track_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'api.dart';

class TrackListWidget extends StatefulWidget {
  const TrackListWidget({super.key});

  @override
  State<TrackListWidget> createState() => _TrackListWidgetState();
}

class _TrackListWidgetState extends State<TrackListWidget> {
  late Future<List<Track>> _allTracksFuture;

  @override
  void initState() {
    super.initState();
    _allTracksFuture = ApiService.getAllTracks();
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
            // Закрываем диалог подтверждения ПЕРЕД отправкой запроса
            Navigator.of(context).pop();
            // Отправляем запрос
            _confirmTrackSelection(context, track.id);
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

  void _confirmTrackSelection(BuildContext context, String id) async {
    final venueId = await VenueSessionManager.getActiveVenueId();
    if (venueId == null) {
      if (mounted) {
        _showCustomSnackBar(
          context,
          'Ошибка сессии. Отсканируйте QR-код заново.',
        );
      }
      return;
    }

    final ApiResponse response = await ApiService.addToQueue(
      trackId: id,
      venueId: venueId,
    );

    if (mounted) {
      if (response.success) {
        MyOrdersManager.add(id);
        _showCustomSnackBar(context, response.message);
      } else {
        // ИЗМЕНЕНИЕ: Улучшенная логика обработки ошибок
        if (response.cooldownType != null && response.timeLeftSeconds != null) {
          // Если сервер вернул информацию о кулдауне, показываем новый диалог
          showDialog(
            context: context,
            builder: (context) => CooldownDialog(
              initialCooldownSeconds: response.timeLeftSeconds!,
            ),
          );
        } else {
          // Для всех остальных ошибок показываем простое сообщение
          _showCustomSnackBar(context, response.message);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Track>>(
      future: _allTracksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: 10,
            itemBuilder: (context, index) => const _TrackItemPlaceholder(),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'Не удалось загрузить список треков.',
              style: TextStyle(color: Colors.white70),
            ),
          );
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

// ... остальной код виджета (_TrackItem, _TrackItemPlaceholder, _showCustomSnackBar) остается без изменений ...

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

class _TrackItemPlaceholder extends StatelessWidget {
  const _TrackItemPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[850]!,
      highlightColor: Colors.grey[800]!,
      child: Padding(
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
