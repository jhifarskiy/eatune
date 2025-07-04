import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

class CooldownDialog extends StatefulWidget {
  // ИСПРАВЛЕНИЕ: Принимаем точное время в секундах
  final int initialCooldownSeconds;

  const CooldownDialog({super.key, required this.initialCooldownSeconds});

  @override
  State<CooldownDialog> createState() => _CooldownDialogState();
}

class _CooldownDialogState extends State<CooldownDialog> {
  late Timer _timer;
  late Duration _remainingTime;

  @override
  void initState() {
    super.initState();
    // ИСПРАВЛЕНИЕ: Инициализируем таймер из полученного значения
    _remainingTime = Duration(seconds: widget.initialCooldownSeconds);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        // Автоматически закрываем диалог, когда время вышло
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A6D).withOpacity(0.9),
            borderRadius: BorderRadius.circular(24.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Другие тоже хотят послушать 😊',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Следующий трек можно будет заказать через:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _formatDuration(_remainingTime),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Понятно',
                  style: TextStyle(
                    color: Color(0xFF1CA4FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
