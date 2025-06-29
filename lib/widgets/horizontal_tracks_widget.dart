import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../api.dart';

// --- Функции-хелперы ---
void _showCustomSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      backgroundColor: const Color(0xFF1885D3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.0)),
      margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      duration: const Duration(milliseconds: 1500),
    ),
  );
}

class HorizontalTracksWidget extends StatefulWidget {
  const HorizontalTracksWidget({super.key});

  @override
  State<HorizontalTracksWidget> createState() => _HorizontalTracksWidgetState();
}

class _HorizontalTracksWidgetState extends State<HorizontalTracksWidget> {
  late Future<List<Track>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _tracksFuture = ApiService.getAllTracks();
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
      transitionBuilder: (context, animation, _, child) {
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
      _showCustomSnackBar(context, 'Трек добавлен в очередь!');
    } else {
      _showCustomSnackBar(context, 'Не удалось добавить трек');
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              // ИЗМЕНЕНИЕ: Углы обложки снова менее круглые
              borderRadius: BorderRadius.circular(16.0),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 14,
            width: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              // ИЗМЕНЕНИЕ: Углы текста более круглые
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            height: 12,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              // ИЗМЕНЕНИЕ: Углы текста более круглые
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'POPULAR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: FutureBuilder<List<Track>>(
            future: _tracksFuture,
            builder: (context, snapshot) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: (snapshot.connectionState == ConnectionState.waiting)
                    ? Shimmer.fromColors(
                        key: const ValueKey('shimmer_horizontal'),
                        baseColor: Colors.grey[850]!,
                        highlightColor: Colors.grey[800]!,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 5,
                          itemBuilder: (context, index) => _buildPlaceholder(),
                        ),
                      )
                    : (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty)
                    ? const Center(
                        key: ValueKey('error_horizontal'),
                        child: Text(
                          'Popular tracks not available.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        key: const ValueKey('data_horizontal'),
                        scrollDirection: Axis.horizontal,
                        itemCount: snapshot.data!.length > 10
                            ? 10
                            : snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final track = snapshot.data![index];
                          return GestureDetector(
                            onTap: () => _showConfirmationModal(track),
                            child: Container(
                              width: 130,
                              margin: const EdgeInsets.only(right: 20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    // ИЗМЕНЕНИЕ: Углы обложки снова менее круглые
                                    borderRadius: BorderRadius.circular(16.0),
                                    child: Image.network(
                                      track.coverUrl ?? '',
                                      height: 120,
                                      width: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (
                                            context,
                                            error,
                                            stackTrace,
                                          ) => Container(
                                            height: 120,
                                            width: 120,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF374151),
                                              borderRadius:
                                                  BorderRadius.circular(16.0),
                                            ),
                                            child: const Icon(
                                              Icons.music_note,
                                              color: Colors.grey,
                                              size: 40,
                                            ),
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    track.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    track.artist,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              );
            },
          ),
        ),
      ],
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
            borderRadius: BorderRadius.circular(50.0),
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
              : const Text(
                  'Добавить',
                  style: TextStyle(
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
