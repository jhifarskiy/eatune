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

  // ИЗМЕНЕНИЕ: Добавлен Notifier для хранения реального времени трека
  final ValueNotifier<Duration> currentTrackProgress = ValueNotifier(
    Duration.zero,
  );

  List<Track> get queue => _queue;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected && _channel != null) return;

    final venueId = await VenueSessionManager.getActiveVenueId();
    if (venueId == null) {
      print("QueueManager: No active venue session, can't connect.");
      return;
    }

    final wsUrl = Uri.parse('wss://eatune-api.onrender.com?venueId=$venueId');

    try {
      _channel = WebSocketChannel.connect(wsUrl);
      _isConnected = true;
      print("QueueManager: Connecting to $wsUrl");
      notifyListeners();

      _channel!.stream.listen(
        (message) {
          final data = json.decode(message);

          // Обработка обновления всей очереди
          if (data['type'] == 'queue_update') {
            final List<dynamic> trackData = data['queue'] ?? [];
            _queue = trackData.map((json) => Track.fromJson(json)).toList();
            // При обновлении очереди сбрасываем прогресс
            currentTrackProgress.value = Duration.zero;
            print("QueueManager: Queue updated with ${_queue.length} tracks.");
            notifyListeners();
          }

          // ИЗМЕНЕНИЕ: Обработка сообщения о прогрессе
          if (data['type'] == 'current_track_progress') {
            final double currentTimeSeconds =
                (data['currentTime'] as num?)?.toDouble() ?? 0.0;
            currentTrackProgress.value = Duration(
              milliseconds: (currentTimeSeconds * 1000).round(),
            );
          }
        },
        onDone: () {
          _isConnected = false;
          currentTrackProgress.value = Duration.zero;
          print("QueueManager: WebSocket disconnected.");
          notifyListeners();
        },
        onError: (error) {
          _isConnected = false;
          currentTrackProgress.value = Duration.zero;
          print("QueueManager: WebSocket error: $error");
          notifyListeners();
        },
      );
    } catch (e) {
      print("QueueManager: Failed to connect: $e");
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    _queue = [];
    currentTrackProgress.value = Duration.zero;
    print("QueueManager: Disconnected manually.");
    notifyListeners();
  }
}
