import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TrackListWidget extends StatefulWidget {
  const TrackListWidget({super.key});

  @override
  State<TrackListWidget> createState() => _TrackListWidgetState();
}

class _TrackListWidgetState extends State<TrackListWidget> {
  int? selectedTrackId;
  final String baseUrl = 'http://192.168.0.102:3000';

  final List<Map<String, String>> tracks = List.generate(15, (index) {
    return {
      'id': '${index + 1}',
      'title': 'Track ${index + 1}',
      'artist': 'Artist ${index + 1}',
      'duration': '3:${index.toString().padLeft(2, '0')}',
      'image': 'assets/cover.jpg',
    };
  });

  Future<void> selectTrack(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/track'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': id}),
    );
    if (response.statusCode == 200) {
      setState(() {
        selectedTrackId = id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
      itemCount: tracks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isSelected = selectedTrackId == int.parse(track['id']!);

        return GestureDetector(
          onTap: () => selectTrack(int.parse(track['id']!)),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.white10 : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: AssetImage(track['image']!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track['title']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track['artist']!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      track['duration']!,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.more_vert, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
