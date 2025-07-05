import 'package:eatune/managers/track_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../api.dart';

class AlbumBrowserWidget extends StatefulWidget {
  final String genreFilter;
  final Function(String artistName) onArtistTapped;

  const AlbumBrowserWidget({
    super.key,
    required this.genreFilter,
    required this.onArtistTapped,
  });

  @override
  State<AlbumBrowserWidget> createState() => _AlbumBrowserWidgetState();
}

class _AlbumBrowserWidgetState extends State<AlbumBrowserWidget> {
  late Future<List<Track>> _artistsFuture;

  @override
  void initState() {
    super.initState();
    _artistsFuture = _loadAndFilterArtists();
  }

  @override
  void didUpdateWidget(covariant AlbumBrowserWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.genreFilter != oldWidget.genreFilter) {
      setState(() {
        _artistsFuture = _loadAndFilterArtists();
      });
    }
  }

  Future<List<Track>> _loadAndFilterArtists() async {
    final allTracks = await TrackCacheManager.getAllTracks();

    final Map<String, Track> allUniqueArtists = {};
    for (var track in allTracks) {
      if (!allUniqueArtists.containsKey(track.artist)) {
        allUniqueArtists[track.artist] = track;
      }
    }

    // Если жанр - "Popular", показываем всех
    if (widget.genreFilter == 'Popular') {
      return allUniqueArtists.values.toList();
    }

    // Иначе, фильтруем по жанру
    final genreTracks = allTracks
        .where((track) => track.genre == widget.genreFilter)
        .toList();

    final Map<String, Track> uniqueArtistsInGenre = {};
    for (var track in genreTracks) {
      if (!uniqueArtistsInGenre.containsKey(track.artist)) {
        uniqueArtistsInGenre[track.artist] = track;
      }
    }

    // ИЗМЕНЕНИЕ: Если в жанре нет артистов, показываем всех (как в Popular)
    if (uniqueArtistsInGenre.isEmpty) {
      return allUniqueArtists.values.toList();
    }

    return uniqueArtistsInGenre.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: FutureBuilder<List<Track>>(
        future: _artistsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildPlaceholder();
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return _buildPlaceholder();
          }

          final artists = snapshot.data!;

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artistTrack = artists[index];
              return GestureDetector(
                onTap: () => widget.onArtistTapped(artistTrack.artist),
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: Image.network(
                      artistTrack.coverUrl ?? 'invalid',
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 120,
                        width: 120,
                        color: Colors.grey[800],
                        child: Center(
                          child: Text(
                            artistTrack.artist,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[850]!,
      highlightColor: Colors.grey[800]!,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        itemCount: 5,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (_, __) => Container(
          width: 120,
          height: 120,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
          ),
        ),
      ),
    );
  }
}
