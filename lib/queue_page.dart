import 'package:eatune/managers/queue_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<QueueManager>(
      builder: (context, queueManager, child) {
        if (queueManager.isConnecting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (!queueManager.isConnected) {
          return _buildConnectionErrorState(context, queueManager);
        }

        final queue = queueManager.queue;
        final nowPlaying = queue.isNotEmpty ? queue.first : null;
        final upNext = queue.length > 1 ? queue.sublist(1) : [];

        if (nowPlaying == null) {
          return _buildEmptyState(context);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 85),
          children: [
            _buildSectionTitle('Сейчас играет'),
            _buildNowPlayingCard(nowPlaying),
            if (upNext.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSectionTitle('Далее'),
              ...upNext
                  .map(
                    (track) =>
                        _buildQueueItem(track, upNext.indexOf(track) + 1),
                  )
                  .toList(),
            ],
          ],
        );
      },
    );
  }
}

// --- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ, ВЫНЕСЕННЫЕ ИЗ КЛАССА ---

Widget _buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12.0, top: 16.0),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        fontSize: 12,
      ),
    ),
  );
}

Widget _buildNowPlayingCard(Track track) {
  return Card(
    color: const Color(0xFF173D7A).withOpacity(0.5),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _buildCoverImage(track.coverUrl, 64, 12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
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
                  track.artist,
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
    ),
  );
}

Widget _buildQueueItem(Track track, int position) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      children: [
        Text(
          '$position',
          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5)),
        ),
        const SizedBox(width: 16),
        _buildCoverImage(track.coverUrl, 48, 8),
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
      ],
    ),
  );
}

Widget _buildCoverImage(String? coverUrl, double size, double borderRadius) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: Image.network(
      coverUrl ?? 'invalid_url',
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
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
      },
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
