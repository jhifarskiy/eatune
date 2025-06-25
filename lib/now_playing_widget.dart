import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api.dart';

class NowPlayingWidget extends StatefulWidget {
  const NowPlayingWidget({super.key});

  @override
  State<NowPlayingWidget> createState() => _NowPlayingWidgetState();
}

class _NowPlayingWidgetState extends State<NowPlayingWidget> {
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
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      fetchCurrentTrack();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchCurrentTrack() async {
    try {
      final track = await ApiService.getCurrentTrack();
      if (mounted && track?.id != _currentTrack?.id) {
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
        if (mounted) {
          setState(() {
            _currentPosition += const Duration(seconds: 1);
            _currentProgress = _trackDuration.inSeconds > 0
                ? _currentPosition.inSeconds / _trackDuration.inSeconds
                : 0.0;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _resetProgress() {
    _progressTimer?.cancel();
    if (mounted) {
      setState(() {
        _currentPosition = Duration.zero;
        _currentProgress = 0.0;
        _trackDuration = Duration.zero;
      });
    }
  }

  Duration _parseDuration(String d) {
    try {
      final parts = d.split(':');
      return Duration(
        minutes: int.parse(parts[0]),
        seconds: int.parse(parts[1]),
      );
    } catch (e) {
      return Duration.zero;
    }
  }

  String _formatDuration(Duration d) {
    return "${d.inMinutes.remainder(60)}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    // Стиль текста Montserrat Semi-Bold
    final semiBoldStyle = GoogleFonts.montserrat(fontWeight: FontWeight.w600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOW PLAYING',
          style: semiBoldStyle.copyWith(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            // --- Обложка без рамки и наклона ---
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF334155), // Цвет-заглушка
                borderRadius: BorderRadius.circular(8),
                image: _currentTrack?.coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_currentTrack!.coverUrl!),
                        fit: BoxFit.cover,
                        onError: (e, s) => print("Failed to load cover: $e"),
                      )
                    : null,
              ),
              child: _currentTrack?.coverUrl == null
                  ? const Icon(Icons.music_note, color: Colors.white54)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentTrack?.title ?? 'Ничего не играет',
                    style: semiBoldStyle.copyWith(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _currentTrack?.artist ?? 'Выберите трек',
                    style: semiBoldStyle.copyWith(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // --- Неинтерактивный прогресс-бар ---
        Column(
          children: [
            SizedBox(
              height: 12, // Высота контейнера
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        width: (constraints.maxWidth * _currentProgress).clamp(
                          0,
                          constraints.maxWidth,
                        ),
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    },
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Padding(
                        padding: EdgeInsets.only(
                          left: (constraints.maxWidth * _currentProgress).clamp(
                            0,
                            constraints.maxWidth - 12,
                          ),
                        ),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_currentPosition),
                  style: semiBoldStyle.copyWith(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatDuration(_trackDuration),
                  style: semiBoldStyle.copyWith(
                    color: Colors.white.withOpacity(0.6),
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
