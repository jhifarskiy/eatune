// lib/venue_scan_page.dart

import 'package:eatune/home_page.dart';
import 'package:eatune/managers/venue_session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class VenueScanPage extends StatefulWidget {
  const VenueScanPage({super.key});

  @override
  State<VenueScanPage> createState() => _VenueScanPageState();
}

class _VenueScanPageState extends State<VenueScanPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onQrCodeDetected(BarcodeCapture capture) {
    // ИЗМЕНЕНИЕ: Добавлен print для отладки
    print("--- QR-КОД ОБНАРУЖЕН! ---");

    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? rawValue = barcodes.first.rawValue;
      print("Содержимое кода: $rawValue"); // Посмотрим, что внутри

      if (rawValue != null && rawValue.startsWith('eatune://venue/')) {
        _scannerController.stop();

        final venueId = rawValue.substring('eatune://venue/'.length);

        _showConfirmationDialog(venueId);
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showConfirmationDialog(String venueId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D325F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Вход в заведение',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Вы хотите войти в заведение с ID: $venueId?',
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Отмена',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _scannerController.start();
                setState(() {
                  _isProcessing = false;
                });
              },
            ),
            TextButton(
              child: const Text(
                'Войти',
                style: TextStyle(
                  color: Color(0xFF1CA4FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                await VenueSessionManager.saveSession(venueId);
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const HomePage()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onQrCodeDetected,
          ),
          Container(color: Colors.black.withOpacity(0.5)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              SvgPicture.asset('assets/icons/logo.svg', width: 180),
              const SizedBox(height: 16),
              const Text(
                'Добро пожаловать в Eatune!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Отсканируйте QR-код на столе,\nчтобы начать',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
              const Spacer(flex: 1),
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.8),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ],
      ),
    );
  }
}
