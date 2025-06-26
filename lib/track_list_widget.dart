import 'dart:ui';
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

  void _showConfirmationModal(Track track) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, _, __) {
        return _TrackConfirmationDialog(
          track: track,
          onConfirm: () {
            _confirmTrackSelection(track.id);
            Navigator.of(context).pop();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuart,
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _confirmTrackSelection(String id) async {
    bool success = await ApiService.addToQueue(id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Трек добавлен в очередь!'),
          backgroundColor: Color(0xFF1CA4FF),
          duration: Duration(seconds: 2),
        ),
      );
      widget.onTrackSelected();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось добавить трек'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
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
            return _AnimatedTrackItem(
              onTap: () => _showConfirmationModal(track),
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
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
                              fontWeight: FontWeight.w400,
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

class _AnimatedTrackItem extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _AnimatedTrackItem({required this.onTap, required this.child});

  @override
  __AnimatedTrackItemState createState() => __AnimatedTrackItemState();
}

class __AnimatedTrackItemState extends State<_AnimatedTrackItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _TrackConfirmationDialog extends StatelessWidget {
  final Track track;
  final VoidCallback onConfirm;

  const _TrackConfirmationDialog({
    required this.track,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasCover = track.coverUrl != null && track.coverUrl!.isNotEmpty;
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A6D).withOpacity(0.9),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasCover)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      track.coverUrl!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              Text(
                track.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                track.artist,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Отмена',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _ConfirmAddButton(onConfirm: onConfirm),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmAddButton extends StatefulWidget {
  final VoidCallback onConfirm;

  const _ConfirmAddButton({required this.onConfirm});

  @override
  __ConfirmAddButtonState createState() => __ConfirmAddButtonState();
}

class __ConfirmAddButtonState extends State<_ConfirmAddButton> {
  bool _isAdding = false;
  bool _isAdded = false;

  void _handleAdd() {
    if (_isAdding || _isAdded) return;

    setState(() => _isAdding = true);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isAdded = true;
          widget.onConfirm();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleAdd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 120,
        height: 48,
        decoration: BoxDecoration(
          color: _isAdding ? Colors.transparent : const Color(0xFF1CA4FF),
          border: Border.all(
            color: const Color(0xFF1CA4FF),
            width: _isAdding ? 2 : 0,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: _isAdded
              ? const Icon(Icons.check, color: Color(0xFF1CA4FF))
              : Text(
                  'Добавить',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
