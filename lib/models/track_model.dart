// lib/models/track_model.dart

class Track {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String? trackUrl;
  final String? coverUrl;
  final bool isBackgroundTrack;
  final bool isPlaying;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    this.trackUrl,
    this.coverUrl,
    this.isBackgroundTrack = false,
    this.isPlaying = false,
  });

  // Этот метод нужен для сохранения в SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'duration': duration,
      'trackUrl': trackUrl,
      'coverUrl': coverUrl,
      'isBackgroundTrack': isBackgroundTrack,
    };
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      duration: json['duration'] ?? '0:00',
      trackUrl: json['trackUrl'],
      coverUrl: json['coverUrl'],
      isBackgroundTrack: json['isBackgroundTrack'] ?? false,
    );
  }
}
