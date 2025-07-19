import 'dart:ui';
import 'package:eatune/managers/my_orders_manager.dart';
import 'package:eatune/managers/venue_session_manager.dart';
import 'package:eatune/widgets/cooldown_dialog.dart';
import 'package:eatune/widgets/pressable_animated_widget.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'api.dart';
import 'managers/favorites_manager.dart';

class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

void _showCustomSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
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

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

// ИЗМЕНЕНИЕ: Добавляем AutomaticKeepAliveClientMixin
class _FavoritesScreenState extends State<FavoritesScreen>
    with AutomaticKeepAliveClientMixin {
  // ИЗМЕНЕНИЕ: Указываем, что состояние этого виджета нужно сохранять
  @override
  bool get wantKeepAlive => true;

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
            Navigator.of(context).pop();
            _confirmTrackSelection(track.id);
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
    final venueId = await VenueSessionManager.getActiveVenueId();
    if (venueId == null) {
      if (!mounted) return;
      _showCustomSnackBar(
        context,
        'Ошибка сессии. Отсканируйте QR-код заново.',
      );
      return;
    }

    final ApiResponse response = await ApiService.addToQueue(
      trackId: id,
      venueId: venueId,
    );
    if (!mounted) return;
    if (response.success) {
      MyOrdersManager.add(id);
      _showCustomSnackBar(context, response.message);
    } else {
      if (response.cooldownType != null && response.timeLeftSeconds != null) {
        showDialog(
          context: context,
          builder: (context) =>
              CooldownDialog(initialCooldownSeconds: response.timeLeftSeconds!),
        );
      } else {
        _showCustomSnackBar(context, response.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ИЗМЕНЕНИЕ: Обязательный вызов для AutomaticKeepAliveClientMixin
    super.build(context);
    return ValueListenableBuilder<List<Track>>(
      valueListenable: FavoritesManager.notifier,
      builder: (context, favoriteTracks, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Container(
                height: 40.0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FAVORITE LIST',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (favoriteTracks.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_border,
                          color: Colors.white.withOpacity(0.3),
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your favorite list is empty',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add tracks to see them here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ScrollConfiguration(
                    behavior: NoGlowScrollBehavior(),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: favoriteTracks.length,
                      itemBuilder: (context, index) {
                        final track = favoriteTracks[index];
                        return PressableAnimatedWidget(
                          onTap: () => _showConfirmationModal(track),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                _buildCoverImage(track),
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
                                SizedBox(
                                  width: 45,
                                  child: Text(
                                    track.duration,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PressableAnimatedWidget(
                                  onTap: () {
                                    FavoritesManager.removeFavorite(track.id);
                                    _showCustomSnackBar(
                                      context,
                                      'Удалено из избранного',
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8.0),
                                    child: const Icon(
                                      Icons.favorite,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 85),
            ],
          ),
        );
      },
    );
  }
}

Widget _buildCoverImage(Track track) {
  const double size = 50;
  const double borderRadius = 8;
  final bool hasValidUrl = track.hasCover;

  return ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: hasValidUrl
        ? Image.network(
            track.coverUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: child,
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Shimmer.fromColors(
                baseColor: Colors.grey[850]!,
                highlightColor: Colors.grey[800]!,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) =>
                _buildPlaceholderIcon(size, borderRadius),
          )
        : _buildPlaceholderIcon(size, borderRadius),
  );
}

Widget _buildPlaceholderIcon(double size, double borderRadius) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFF374151),
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    child: Icon(Icons.music_note, color: Colors.grey, size: size * 0.6),
  );
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
    final bool hasCover = track.hasCover;
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
    widget.onConfirm();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isAdded = true;
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
