import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';

class NowPlayingWidget extends StatefulWidget {
  // Конструктор теперь принимает ключ, который обязателен для StatefulWidget
  const NowPlayingWidget({super.key});

  @override
  State<NowPlayingWidget> createState() => _NowPlayingWidgetState();
}

class _NowPlayingWidgetState extends State<NowPlayingWidget> {
  Track? _currentTrack;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchCurrentTrack();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      fetchCurrentTrack();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Метод теперь публичный, чтобы его можно было вызвать извне через GlobalKey
  Future<void> fetchCurrentTrack() async {
    try {
      final track = await ApiService.getCurrentTrack();
      if (mounted && track?.id != _currentTrack?.id) {
        setState(() {
          _currentTrack = track;
        });
      }
    } catch (e) {
      print("Error fetching now playing: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NOW PLAYING',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
                image: _currentTrack?.coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_currentTrack!.coverUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _currentTrack?.coverUrl == null
                  ? const Icon(Icons.music_note, color: Colors.white, size: 30)
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ИСПРАВЛЕНО: Текст по умолчанию
                  Text(
                    _currentTrack?.title ?? 'Ничего не играет',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // ИСПРАВЛЕНО: Текст по умолчанию
                  Text(
                    _currentTrack?.artist ?? 'Выберите трек из списка',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Text('0:00', style: TextStyle(color: Colors.white54)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: LinearProgressIndicator(
                  value: 0.0,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            Text('0:00', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ],
    );
  }
}
