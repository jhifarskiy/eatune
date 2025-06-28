import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';

class QueuePage extends StatefulWidget {
  const QueuePage({super.key});

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  List<Track> _queue = [];
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQueue();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchQueue(isSilent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchQueue({bool isSilent = false}) async {
    if (!isSilent && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final queue = await ApiService.getQueue();
      if (mounted) {
        setState(() {
          _queue = queue;
        });
      }
    } catch (e) {
      print("Error fetching queue: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowPlaying = _queue.isNotEmpty ? _queue.first : null;
    final upNext = _queue.length > 1 ? _queue.sublist(1) : [];

    // ИЗМЕНЕНО: Scaffold и AppBar удалены. Виджет теперь просто контент.
    return RefreshIndicator(
      onRefresh: _fetchQueue,
      backgroundColor: const Color(0xFF1CA4FF),
      color: Colors.white,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView(
              // Добавляем отступы, чтобы соответствовать другим экранам
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 85),
              children: [
                if (nowPlaying != null) _buildSectionTitle('Сейчас играет'),
                if (nowPlaying != null) _buildNowPlayingCard(nowPlaying),
                if (nowPlaying == null && !_isLoading) _buildEmptyState(),

                if (upNext.isNotEmpty) const SizedBox(height: 24),
                if (upNext.isNotEmpty) _buildSectionTitle('Далее'),
                if (upNext.isNotEmpty)
                  ...List.generate(upNext.length, (index) {
                    return _buildQueueItem(upNext[index], index + 1);
                  }),
              ],
            ),
    );
  }

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
      color: const Color(0xFF173D7A),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            _buildCoverImage(track.coverUrl, 64, 16),
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
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
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
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 16),
          _buildCoverImage(track.coverUrl, 48, 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artist,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
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
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white70,
              size: 28,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.2),
        child: Column(
          children: [
            Icon(
              Icons.queue_music,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Очередь пуста',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.7),
              ),
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
}
