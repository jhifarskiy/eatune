import 'package:eatune/managers/device_id_manager.dart';
import 'package:eatune/managers/venue_session_manager.dart';
import 'package:eatune/venue_scan_page.dart';
import 'package:eatune/widgets/pressable_animated_widget.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'about_page.dart';
import 'legal_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _activeVenueId;
  String _appVersion = '';
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final venueId = await VenueSessionManager.getActiveVenueId();
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceId = DeviceIdManager.id ?? '...';
    if (mounted) {
      setState(() {
        _activeVenueId = venueId;
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
        _deviceId = deviceId;
      });
    }
  }

  void _navigateToPage(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  void _showSignOutDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A3A6D).withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Выйти из заведения?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Текущая сессия будет завершена.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await VenueSessionManager.clearSession();
                      await navigator.pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const VenueScanPage(),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Выйти',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF010A15),
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: const Color(0xFF010A15),
        elevation: 0,
      ),
      body: ListView(
        // ИЗМЕНЕНИЕ: Добавлен отступ сверху
        padding: const EdgeInsets.only(top: 16.0),
        children: [
          if (_activeVenueId != null) ...[
            _buildSectionTitle('Текущая сессия'),
            _buildListTile(
              icon: Icons.store_mall_directory_outlined,
              title: 'Заведение',
              subtitle: _activeVenueId,
            ),
            _buildListTile(
              icon: Icons.exit_to_app,
              title: 'Выйти из заведения',
              onTap: _showSignOutDialog,
              isDestructive: true,
            ),
          ],
          const SizedBox(height: 24),
          _buildSectionTitle('Приложение'),
          _buildListTile(
            icon: Icons.star_outline,
            title: 'Оценить приложение',
            onTap: () {},
          ),
          _buildListTile(
            icon: Icons.support_agent,
            title: 'Связаться с поддержкой',
            onTap: () {},
          ),
          _buildListTile(
            icon: Icons.info_outline,
            title: 'О приложении',
            onTap: () => _navigateToPage(const AboutPage()),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Правовая информация'),
          _buildListTile(
            icon: Icons.description_outlined,
            title: 'Условия использования',
            onTap: () =>
                _navigateToPage(const LegalPage(type: LegalPageType.terms)),
          ),
          _buildListTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Политика конфиденциальности',
            onTap: () =>
                _navigateToPage(const LegalPage(type: LegalPageType.privacy)),
          ),
          const SizedBox(height: 40),
          _buildFooterInfo(
            'Версия приложения: $_appVersion\nID устройства: $_deviceId',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.redAccent : Colors.white;
    Widget tile = ListTile(
      leading: Icon(icon, color: color.withOpacity(0.8)),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            )
          : null,
      trailing: onTap != null
          ? Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.white.withOpacity(0.5),
            )
          : null,
    );

    return onTap != null
        ? PressableAnimatedWidget(onTap: onTap, child: tile)
        : tile;
  }

  Widget _buildFooterInfo(String text) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
      ),
    );
  }
}
