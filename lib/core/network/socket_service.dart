import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class SocketService {
  // Singleton pattern
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  
  // Local backend URL depending on the platform
  final String _serverUrl = !kIsWeb && Platform.isAndroid 
      ? 'http://10.0.2.2:5000' 
      : 'http://localhost:5000';

  io.Socket? get socket => _socket;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    _socket = io.io(_serverUrl, io.OptionBuilder()
      .setTransports(['websocket']) // Force websockets for performance
      .disableAutoConnect()
      .setAuth({'token': token}) // Pass token to socket handshake if backend expects it
      .build()
    );

    _socket?.connect();

    _socket?.onConnect((_) {
      debugPrint('Socket connected: ${_socket?.id}');
    });

    _socket?.onDisconnect((_) {
      debugPrint('Socket disconnected');
    });

    _socket?.onConnectError((err) {
      debugPrint('Socket connect error: $err');
    });

    _socket?.onError((err) {
      debugPrint('Socket error: $err');
    });
  }

  void disconnect() {
    if (_socket != null) {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
    }
  }

  // Helper method to emit events
  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  // Helper method to listen to events
  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  // Helper method to remove event listeners
  void off(String event) {
    _socket?.off(event);
  }
}
