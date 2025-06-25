import 'dart:async';
import 'package:flutter/material.dart';

/// Виджет, который создает эффект "бегущей строки" для текста,
/// который не помещается в одну строку.
class MarqueeWidget extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Axis scrollAxis;
  final Duration pauseDuration;
  final int animationSpeed; // в миллисекундах на символ

  const MarqueeWidget({
    super.key,
    required this.text,
    required this.style,
    this.scrollAxis = Axis.horizontal,
    this.pauseDuration = const Duration(seconds: 2),
    this.animationSpeed = 150, // Более медленная скорость для читаемости
  });

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Запускаем анимацию после того, как первый кадр был отрисован
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startScrolling();
      }
    });
  }

  void _startScrolling() async {
    // Небольшая задержка, чтобы убедиться, что все размеры рассчитаны
    await Future.delayed(const Duration(milliseconds: 500));

    while (mounted) {
      // Пауза перед началом движения
      await Future.delayed(widget.pauseDuration);
      if (!mounted) break;

      // Проверяем, нужно ли вообще скроллить
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        // Анимированно скроллим до конца
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(
            milliseconds: (widget.text.length * widget.animationSpeed),
          ),
          curve: Curves.linear,
        );
        if (!mounted) break;

        // Пауза в конце
        await Future.delayed(widget.pauseDuration);
        if (!mounted) break;

        // Мгновенно возвращаемся в начало
        _scrollController.jumpTo(0.0);
      } else {
        // Если скроллить не нужно, просто ждем перед следующей проверкой
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Используем LayoutBuilder, чтобы включать прокрутку, только если текст не помещается
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(text: widget.text, style: widget.style);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 1,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        // Если текст помещается в доступную ширину, просто показываем Text
        if (textPainter.width <= constraints.maxWidth) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        // В противном случае используем наш виджет с прокруткой
        return ClipRRect(
          borderRadius: BorderRadius.circular(
            4,
          ), // Чтобы текст не выходил за границы
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: widget.scrollAxis,
            child: Text(widget.text, style: widget.style, maxLines: 1),
          ),
        );
      },
    );
  }
}
