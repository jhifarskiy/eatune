// lib/widgets/cooldown_dialog.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

class CooldownDialog extends StatefulWidget {
  final String serverMessage;

  const CooldownDialog({super.key, required this.serverMessage});

  @override
  State<CooldownDialog> createState() => _CooldownDialogState();
}

class _CooldownDialogState extends State<CooldownDialog> {
  late Timer _timer;
  late Duration _remainingTime;

  @override
  void initState() {
    super.initState();
    _remainingTime = _parseDurationFromMessage(widget.serverMessage);
    _startTimer();
  }

  Duration _parseDurationFromMessage(String message) {
    // Ищем первое число в строке (например, "5" из "через 5 мин.")
    final regExp = RegExp(r'\d+');
    final match = regExp.firstMatch(message);
    if (match != null) {
      final minutes = int.tryParse(match.group(0) ?? '1') ?? 1;
      return Duration(minutes: minutes);
    }
    // Значение по умолчанию, если не удалось распознать
    return const Duration(minutes: 5);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        // Можно автоматически закрыть диалог, когда время выйдет
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          setState(() {
            _remainingTime = _remainingTime - const Duration(seconds: 1);
          });
        }
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
