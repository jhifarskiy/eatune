import 'package:flutter/material.dart';
import 'api.dart';

class TrackListWidget extends StatefulWidget {
  final Function onTrackSelected;

  const TrackListWidget({super.key, required this.onTrackSelected});

  @override
  State<TrackListWidget> createState() => _TrackListWidgetState();
}

class _TrackListWidgetState extends State<TrackListWidget> {
  late Future<List<Track>> futureTracks;
  String? selectedTrackId;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  void _loadTracks() {
    setState(() {
      futureTracks = ApiService.getAllTracks();
    });
  }

  void _selectTrack(String id) async {
    setState(() {
      selectedTrackId = id;
    });
    bool success = await ApiService.selectTrack(id);
    if (success) {
      widget.onTrackSelected();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Track>>(
      future: futureTracks,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'Нет доступных треков',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          );
        }

        final tracks = snapshot.data!;
        return ListView.builder(
          padding: EdgeInsets.zero, // Убираем отступы по умолчанию
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isSelected = selectedTrackId == track.id;

            return InkWell(
              onTap: () => _selectTrack(track.id),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    // Обложка
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        track.coverUrl ??
                            'https://placehold.co/100x100/374151/FFFFFF?text=?',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 50,
                          height: 50,
                          color: const Color(0xFF374151),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.grey,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Название и артист (ИСПРАВЛЕНО: обернуто в Expanded)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600, // SemiBold
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.artist,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                              fontWeight: FontWeight.w400, // Regular
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Длительность и иконка (ИСПРАВЛЕНО: без переполнения)
                    Text(
                      track.duration,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.more_vert, color: Colors.white.withOpacity(0.5)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
