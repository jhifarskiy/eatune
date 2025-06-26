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

  void _confirmAndSelectTrack(String id) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Добавить в плейлист?',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: Opacity(
            opacity: anim1.value,
            child: AlertDialog(
              backgroundColor: const Color(0xFF041C3E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Добавить в плейлист?',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Добавить',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF1CA4FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      _selectTrack(id);
    }
  }

  void _selectTrack(String id) async {
    setState(() {
      selectedTrackId = id;
    });

    bool success = await ApiService.selectTrack(id);
    if (success) {
      widget.onTrackSelected();
      showBottomSlideUpMessage(
        context,
        '🎧 Ваш заказ принят!\nМы поставим вашу песню\nсразу, как освободится очередь.',
      );
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
          padding: EdgeInsets.zero,
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];

            return InkWell(
              onTap: () => _confirmAndSelectTrack(track.id),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            track.artist,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      track.duration,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        decoration: TextDecoration.none,
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

// --- Кастомная выезжающая карточка подтверждения ---
void showBottomSlideUpMessage(BuildContext context, String message) {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => _BottomMessagePanel(message: message),
  );
}

class _BottomMessagePanel extends StatefulWidget {
  final String message;

  const _BottomMessagePanel({required this.message});

  @override
  State<_BottomMessagePanel> createState() => _BottomMessagePanelState();
}

class _BottomMessagePanelState extends State<_BottomMessagePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    Future.delayed(const Duration(seconds: 5), () {
      _controller.reverse().then((_) => Navigator.of(context).pop());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SlideTransition(
        position: _offset,
        child: Container(
          height: height * 0.4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: const BoxDecoration(
            color: Color(0xFF1CA4FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Center(
            child: Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
