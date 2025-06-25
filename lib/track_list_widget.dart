import 'package:flutter/material.dart';
import 'api.dart';
import 'marquee_widget.dart';

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
    futureTracks = ApiService.getAllTracks();
  }

  void _selectTrack(String id) async {
    setState(() {
      selectedTrackId = id;
    });
    bool success = await ApiService.selectTrack(id);
    if (success) {
      widget.onTrackSelected();
    } else {
      setState(() {
        selectedTrackId = null;
      });
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
              snapshot.hasError ? 'Ошибка' : 'Нет треков',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }
        final tracks = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _loadTracks(),
          child: ListView.separated(
            itemCount: tracks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final track = tracks[index];
              final isSelected = selectedTrackId == track.id;

              return InkWell(
                onTap: () => _selectTrack(track.id),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                          image:
                              track.coverUrl != null &&
                                  track.coverUrl!.startsWith('http')
                              ? DecorationImage(
                                  image: NetworkImage(track.coverUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child:
                            (track.coverUrl == null ||
                                !track.coverUrl!.startsWith('http'))
                            ? const Icon(Icons.music_note, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MarqueeWidget(
                              text: track.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            MarqueeWidget(
                              text: track.artist,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        track.duration,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.more_vert, color: Colors.white60),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
