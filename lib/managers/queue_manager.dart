// lib/managers/queue_manager.dart

import 'dart:convert';
import 'package:eatune/api.dart';
import 'package:eatune/managers/venue_session_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class QueueManager extends ChangeNotifier {
  static final QueueManager _instance = QueueManager._internal();
  factory QueueManager() => _instance;
  QueueManager._internal();

  WebSocketChannel? _channel;
  List<Track> _queue = [];
  bool _isConnected = false;
  bool _isConnecting = false;

  List<Track> get queue => _queue;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;

    final venueId = await VenueSessionManager.getActiveVenueId();
    if (venueId == null) {
      print("QueueManager: Нет активной сессии, подключение невозможно.");
      return;
    }

    final wsUrl = Uri.parse('wss://eatune-api.onrender.com?venueId=$venueId');

    try {
      _isConnecting = true;
      notifyListeners();

      _channel = WebSocketChannel.connect(wsUrl);
      print("QueueManager: Подключение к $wsUrl");

      await _channel!.ready;

      _isConnected = true;
      _isConnecting = false;
      print("QueueManager: WebSocket подключен.");
      notifyListeners();

      _channel!.stream.listen(
        (message) {
          final data = json.decode(message);
          if (data['type'] == 'queue_update') {
            final List<dynamic> trackData = data['queue'] ?? [];
            _queue = trackData.map((json) => Track.fromJson(json)).toList();
            notifyListeners();
          }
        },
        onDone: () {
          _isConnected = false;
          _isConnecting = false;
          notifyListeners();
        },
        onError: (error) {
          _isConnected = false;
          _isConnecting = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
    _queue = [];
    notifyListeners();
  }
}
