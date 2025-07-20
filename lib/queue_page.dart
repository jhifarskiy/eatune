import 'package:eatune/managers/my_orders_manager.dart';
import 'package:eatune/managers/queue_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api.dart';

class _NowPlayingCard extends StatefulWidget {
  final Track track;
  const _NowPlayingCard({required this.track});
  @override
  State<_NowPlayingCard> createState() => _NowPlayingCardState();
}

class _NowPlayingCardState extends State<_NowPlayingCard> {
  Duration _trackDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _trackDuration = _parseDuration(widget.track.duration);
  }

  @override
  void didUpdateWidget(covariant _NowPlayingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.track.id != oldWidget.track.id) {
      setState(() {
        _trackDuration = _parseDuration(widget.track.duration);
      });
    }
  }

  Duration _parseDuration(String? d) {
    if (d == null) return Duration.zero;
    try {
      final parts = d.split(':');
      final minutes = int.parse(parts[0]);
      final seconds = int.parse(parts[1]);
      return Duration(minutes: minutes, seconds: seconds);
    } catch (e) {
      return Duration.zero;
    }
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return "0:00";
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final queueManager = context.read<QueueManager>();

    return Card(
      color: const Color(0xFF173D7A).withOpacity(0.5),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                _buildCoverImage(widget.track, 64, 12),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.track.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.track.artist,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<Duration>(
              valueListenable: queueManager.currentTrackProgress,
              builder: (context, currentPosition, child) {
                final double progress = (_trackDuration.inSeconds > 0)
                    ? (currentPosition.inSeconds / _trackDuration.inSeconds)
                          .clamp(0.0, 1.0)
                    : 0.0;
                return Column(
                  children: [
                    SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(currentPosition),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(_trackDuration),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
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
}

class QueuePage extends StatefulWidget {
  const QueuePage({super.key});

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<QueueManager>(
      builder: (context, queueManager, child) {
        if (!queueManager.isConnected) {
          return _buildConnectionErrorState(context, queueManager);
        }

        final queue = queueManager.queue;
        final nowPlaying = queue.isNotEmpty ? queue.first : null;
        final upNext = queue.length > 1 ? queue.sublist(1) : [];

        if (nowPlaying == null) {
          return _buildEmptyState(context);
        }

        // ИЗМЕНЕНИЕ: Убрана обертка ScrollConfiguration, так как она теперь не нужна
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          children: [
            const SizedBox(height: 10),
            Container(
              height: 40.0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_buildSectionTitle('NOW PLAYING')],
              ),
            ),
            const SizedBox(height: 12),
            _NowPlayingCard(track: nowPlaying),
            if (upNext.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionTitle('UP NEXT'),
              const SizedBox(height: 12),
              ...upNext
                  .map(
                    (track) =>
                        _buildQueueItem(track, upNext.indexOf(track) + 1),
                  )
                  .toList(),
            ],
            const SizedBox(height: 85),
          ],
        );
      },
    );
  }
}

Widget _buildSectionTitle(String title) {
  return Text(
    title.toUpperCase(),
    style: const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.5,
    ),
  );
}

Widget _buildQueueItem(Track track, int position) {
  final bool isMyOrder = MyOrdersManager.isMyOrder(track.id);

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      children: [
        Text(
          '$position',
          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5)),
        ),
        const SizedBox(width: 16),
        _buildCoverImage(track, 48, 8),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                track.artist,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (isMyOrder) ...[
          const SizedBox(width: 8),
          const Tooltip(
            message: 'Ваш выбор',
            child: Icon(Icons.check_circle, color: Color(0xFF1CA4FF), size: 20),
          ),
        ],
      ],
    ),
  );
}

Widget _buildCoverImage(Track track, double size, double borderRadius) {
  final bool hasValidUrl = track.hasCover;

  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: hasValidUrl
        ? Image.network(
            track.coverUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholderIcon(size, borderRadius);
            },
          )
        : _buildPlaceholderIcon(size, borderRadius),
  );
}

Widget _buildPlaceholderIcon(double size, double borderRadius) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFF4B5563),
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    child: Icon(
      Icons.music_note_rounded,
      color: Colors.white.withOpacity(0.7),
      size: size * 0.5,
    ),
  );
}

Widget _buildEmptyState(BuildContext context) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 80.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Очередь пуста',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'Закажите песню, чтобы она появилась здесь',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
        ],
      ),
    ),
  );
}

Widget _buildConnectionErrorState(
  BuildContext context,
  QueueManager queueManager,
) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 80.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Нет подключения к плееру',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => queueManager.connect(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1CA4FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text('Переподключиться'),
          ),
        ],
      ),
    ),
  );
}
