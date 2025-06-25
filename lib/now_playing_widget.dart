import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart'; // Наш ApiService

class NowPlayingWidget extends StatefulWidget {
  // Ключ теперь необязателен, так как мы используем GlobalKey в home_page
  const NowPlayingWidget({super.key});

  @override
  State<NowPlayingWidget> createState() => NowPlayingWidgetState();
}

// Переименовываем, чтобы сделать класс публичным для доступа по ключу
class NowPlayingWidgetState extends State<NowPlayingWidget> {
  Track? _currentTrack;
  Timer? _pollingTimer;
  Timer? _progressTimer;
  double _currentProgress = 0.0;
  Duration _trackDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    fetchCurrentTrack();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      fetchCurrentTrack();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  // Делаем метод публичным, чтобы его можно было вызвать из home_page
  Future<void> fetchCurrentTrack() async {
    try {
      final track = await ApiService.getCurrentTrack();
      if (!mounted) return;

      if (track?.id != _currentTrack?.id) {
        setState(() {
          _currentTrack = track;
          _resetProgress();
          if (track != null) {
            _trackDuration = _parseDuration(track.duration);
            _startProgressTimer();
          }
        });
      }
    } catch (e) {
      print("Error fetching now playing: $e");
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentPosition < _trackDuration) {
        setState(() {
          _currentPosition += const Duration(seconds: 1);
          _currentProgress = _trackDuration.inSeconds > 0
              ? _currentPosition.inSeconds / _trackDuration.inSeconds
              : 0.0;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _resetProgress() {
    _progressTimer?.cancel();
    setState(() {
      _currentPosition = Duration.zero;
      _currentProgress = 0.0;
      _trackDuration = Duration.zero;
    });
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
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOW PLAYING',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // --- ИЗМЕНЕНО: ОБЛОЖКА СНОВА КВАДРАТНАЯ ---
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF374151),
                borderRadius: BorderRadius.circular(
                  8,
                ), // Квадрат со скругленными углами
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _currentTrack?.coverUrl ??
                      'https://placehold.co/100x100/374151/FFFFFF?text=?',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.music_note, color: Colors.grey),
                ),
              ),
            ),
            // -----------------------------------------
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentTrack?.title ?? 'Ничего не играет',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentTrack?.artist ?? 'Выберите трек из списка',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: _currentProgress,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_currentPosition),
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
        ),
      ],
    );
  }
}
