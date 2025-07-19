import 'package:eatune/widgets/pressable_animated_widget.dart';
import 'package:flutter/material.dart';

class AlbumPlaceholdersWidget extends StatelessWidget {
  const AlbumPlaceholdersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        itemCount: 7,
        itemBuilder: (context, index) {
          return PressableAnimatedWidget(
            onTap: () {
              // Пока что нажатие ничего не делает, но анимация будет
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1CA4FF).withOpacity(0.8),
                        const Color(0xFF0D325F),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
