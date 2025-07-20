// lib/helpers/genre_helper.dart

class GenreHelper {
  // Основная функция, которая преобразует "сырой" жанр в стандартную категорию
  static String getStandardizedGenre(String rawGenre) {
    final lowerGenre = rawGenre.toLowerCase();

    // Группируем все виды рока
    if (lowerGenre.contains('rock')) {
      return 'Rock';
    }
    // Группируем хип-хоп, рэп и R&B
    if (lowerGenre.contains('hip-hop') ||
        lowerGenre.contains('r&b') ||
        lowerGenre.contains('rap')) {
      return 'Hip-Hop/R&B';
    }
    // Группируем танцевальную музыку
    if (lowerGenre.contains('dance') ||
        lowerGenre.contains('house') ||
        lowerGenre.contains('electro')) {
      return 'Dance';
    }
    // Группируем чиллаут
    if (lowerGenre.contains('chill') ||
        lowerGenre.contains('lounge') ||
        lowerGenre.contains('downtempo')) {
      return 'Chillout';
    }
    // Группируем поп-музыку
    if (lowerGenre.contains('pop')) {
      return 'Pop';
    }
    // Группируем джаз
    if (lowerGenre.contains('jazz')) {
      return 'Jazz';
    }

    // Если совпадений не найдено, возвращаем исходный жанр с заглавной буквы
    return rawGenre.capitalize();
  }
}

// Вспомогательное расширение для форматирования строки (первая буква заглавная)
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return "";
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
