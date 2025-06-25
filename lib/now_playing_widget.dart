import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart'; // Наш ApiService

class NowPlayingWidget extends StatefulWidget {
  const NowPlayingWidget({super.key});

  @override
  State<NowPlayingWidget> createState() => _NowPlayingWidgetState();
}

class _NowPlayingWidgetState extends State<NowPlayingWidget> {
  Track? _currentTrack;
  Timer? _pollingTimer;
  Timer? _progressTimer;
  double _currentProgress = 0.0; // От 0.0 до 1.0
  Duration _trackDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;

  // Переменная, чтобы избежать многократного запуска таймера
  bool _isProgressTimerRunning = false;

  @override
  void initState() {
    super.initState();
    fetchCurrentTrack();
    // Опрашиваем сервер на предмет смены трека
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      fetchCurrentTrack();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  // Запрашиваем данные о текущем треке с сервера
  Future<void> fetchCurrentTrack() async {
    try {
      final track = await ApiService.getCurrentTrack();
      if (mounted && track?.id != _currentTrack?.id) {
        setState(() {
          _currentTrack = track;
          // Сбрасываем прогресс при смене трека
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

  // Запускаем таймер для обновления прогресс-бара
  void _startProgressTimer() {
    _progressTimer?.cancel(); // Отменяем старый таймер, если он был

    // Этот таймер будет имитировать проигрывание
    // В реальном приложении данные о прогрессе будут приходить от аудио-плеера
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentPosition < _trackDuration) {
        setState(() {
          _currentPosition += const Duration(seconds: 1);
          _currentProgress =
              _currentPosition.inSeconds / _trackDuration.inSeconds;
        });
      } else {
        timer.cancel(); // Останавливаем, когда трек "закончился"
      }
    });
  }

  // Сброс прогресса
  void _resetProgress() {
    _progressTimer?.cancel();
    setState(() {
      _currentPosition = Duration.zero;
      _currentProgress = 0.0;
      _trackDuration = Duration.zero;
    });
  }

  // Вспомогательная функция для парсинга времени из строки "M:SS"
  Duration _parseDuration(String d) {
    try {
      final parts = d.split(':');
      final minutes = int.parse(parts[0]);
      final seconds = int.parse(parts[1]);
      return Duration(minutes: minutes, seconds: seconds);
    } catch (e) {
      return Duration.zero;
    }
  }

  // Вспомогательная функция для форматирования Duration в "M:SS"
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
        const Text(
          'NOW PLAYING',
          style: TextStyle(
            color: Color(0xB2FFFFFF), // Белый с 70% прозрачности
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            // --- Стилизованная обложка ---
            Transform.rotate(
              angle: -0.05, // Легкий наклон
              child: Container(
                width: 70,
                height: 70,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    _currentTrack?.coverUrl ??
                        'https://placehold.co/100x100/1F2937/FFFFFF?text=?',
                    fit: BoxFit.cover,
                    // Заглушка на случай ошибки загрузки
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.music_note, color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),

            // --- Название и Артист ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentTrack?.title ?? 'Ничего не играет',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _currentTrack?.artist ?? 'Выберите трек',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),

        // --- Кастомный прогресс-бар ---
        Column(
          children: [
            CustomProgressBar(
              progress: _currentProgress,
              // Передаем функцию для обработки перемотки
              onSeek: (newProgress) {
                setState(() {
                  _currentProgress = newProgress;
                  _currentPosition = Duration(
                    seconds: (_trackDuration.inSeconds * newProgress).round(),
                  );
                  // Перезапускаем таймер с новой позиции
                  _startProgressTimer();
                });
              },
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_currentPosition),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatDuration(_trackDuration),
                  style: TextStyle(
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

// --- Отдельный виджет для кастомного прогресс-бара ---
class CustomProgressBar extends StatelessWidget {
  final double progress;
  final ValueChanged<double> onSeek;

  const CustomProgressBar({
    super.key,
    required this.progress,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final position = details.localPosition.dx;
        final newProgress = (position / box.size.width).clamp(0.0, 1.0);
        onSeek(newProgress);
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final position = details.localPosition.dx;
        final newProgress = (position / box.size.width).clamp(0.0, 1.0);
        onSeek(newProgress);
      },
      child: Container(
        height: 20, // Увеличиваем высоту для удобства нажатия
        color: Colors.transparent, // Прозрачный фон для захвата касаний
        alignment: Alignment.centerLeft,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Задний фон полосы
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Заполненная часть полосы
            LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: constraints.maxWidth * progress,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
            // "Капелька"-бегунок
            LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: constraints.maxWidth * progress,
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
    );
  }
}
