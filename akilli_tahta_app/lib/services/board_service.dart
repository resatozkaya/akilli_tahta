// lib/services/board_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ConnMode { none, wifi }

class BoardService extends ChangeNotifier {
  ConnMode connMode = ConnMode.none;
  String wsIp = "";
  Map<String, dynamic> boardStatus = {};
  Timer? _pollTimer;

  bool get isConnected => connMode != ConnMode.none;
  bool get isWifiConnected => connMode == ConnMode.wifi;
  bool get isBleConnected => false;
  bool get isScanning => false;
  List<dynamic> get bleDevices => [];

  // WiFi bağlan
  Future<bool> connectWifi(String ip) async {
    try {
      wsIp = ip;
      final res = await http.get(Uri.parse('http://$ip/status')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        boardStatus = Map<String, dynamic>.from(jsonDecode(res.body));
        connMode = ConnMode.wifi;
        _startPolling();
        notifyListeners();
        return true;
      }
      // /status yoksa sadece ping dene
      final ping = await http.get(Uri.parse('http://$ip/')).timeout(const Duration(seconds: 5));
      if (ping.statusCode == 200) {
        connMode = ConnMode.wifi;
        _startPolling();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[HTTP] $e');
      return false;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!isConnected) return;
      try {
        final res = await http.get(Uri.parse('http://$wsIp/status')).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          boardStatus = Map<String, dynamic>.from(jsonDecode(res.body));
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  // Komut gönder
  void send(Map<String, dynamic> cmd) {
    if (connMode == ConnMode.wifi) {
      _sendHttp(cmd);
    }
  }

  Future<void> _sendHttp(Map<String, dynamic> cmd) async {
    try {
      await http.post(
        Uri.parse('http://$wsIp/cmd'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(cmd),
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[HTTP CMD] $e');
    }
  }

  Future<void> startBleScan() async {}

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    connMode = ConnMode.none;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
