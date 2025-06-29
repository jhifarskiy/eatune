import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'api.dart';
import 'managers/favorites_manager.dart';

// Функция для отображения кастомного SnackBar
void _showCustomSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFF1885D3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.0)),
      margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      duration: const Duration(milliseconds: 1500),
    ),
  );
}

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

  void _showConfirmationModal(BuildContext context, Track track) {
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
      widget.onTrackSelected();
    } else {
      _showCustomSnackBar(context, 'Не удалось добавить трек');
    }
  }

  Widget _buildPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              // ИЗМЕНЕНИЕ: Углы обложки снова менее круглые
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    // ИЗМЕНЕНИЕ: Углы текста более круглые
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    // ИЗМЕНЕНИЕ: Углы текста более круглые
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 35,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              // ИЗМЕНЕНИЕ: Углы текста более круглые
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Track>>(
      future: futureTracks,
      builder: (context, snapshot) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: (snapshot.connectionState == ConnectionState.waiting)
              ? Shimmer.fromColors(
                  key: const ValueKey('shimmer_vertical'),
                  baseColor: Colors.grey[850]!,
                  highlightColor: Colors.grey[800]!,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: 10,
                    itemBuilder: (context, index) => _buildPlaceholder(),
                  ),
                )
              : (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty)
              ? Center(
                  key: const ValueKey('error_vertical'),
                  child: Text(
                    'Нет доступных треков',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                )
              : ListView.builder(
                  key: const ValueKey('data_vertical'),
                  padding: EdgeInsets.zero,
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final track = snapshot.data![index];
                    return ValueListenableBuilder<List<Track>>(
                      valueListenable: FavoritesManager.notifier,
                      builder: (context, favoriteTracks, _) {
                        final isFavorite = FavoritesManager.isFavorite(
                          track.id,
                        );

                        return _AnimatedTrackItem(
                          onTap: () => _showConfirmationModal(context, track),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                ClipRRect(
                                  // ИЗМЕНЕНИЕ: Углы обложки снова менее круглые
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.network(
                                    track.coverUrl ?? '',
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF374151),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                IconButton(
                                  icon: Icon(
                                    isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: isFavorite
                                        ? Colors.redAccent
                                        : Colors.white.withOpacity(0.5),
                                  ),
                                  onPressed: () {
                                    FavoritesManager.toggleFavorite(track);
                                    if (isFavorite) {
                                      _showCustomSnackBar(
                                        context,
                                        'Удалено из избранного',
                                      );
                                    } else {
                                      _showCustomSnackBar(
                                        context,
                                        'Добавлено в избранное',
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
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
