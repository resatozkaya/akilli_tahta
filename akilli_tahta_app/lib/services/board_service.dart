import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class BoardService extends ChangeNotifier {
  static const String _ip = '192.168.4.1';

  bool isConnected = false;
  Map<String, dynamic> boardStatus = {};
  List<String> textList = [];
  Timer? _pollTimer;
  String statusMsg = 'Hazır';

  List<dynamic> get bleDevices => [];
  bool get isWifiConnected => isConnected;
  bool get isBleConnected => false;
  bool get isScanning => false;

  Future<bool> autoConnect() => connectWifi(_ip);

  Future<bool> connectWifi(String ip) async {
    try {
      statusMsg = 'Bağlanılıyor...';
      notifyListeners();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse('http://$ip/status'));
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        _parseStatus(body);
        isConnected = true;
        statusMsg = '✅ Bağlı: $ip';
        _startPolling(ip);
        notifyListeners();
        client.close();
        return true;
      }
      client.close();
    } catch (e) {
      debugPrint('[HTTP] $e');
      statusMsg = '❌ $e';
      isConnected = false;
      notifyListeners();
    }
    return false;
  }

  void _startPolling(String ip) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!isConnected) return;
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 3);
        final req = await client.getUrl(Uri.parse('http://$ip/status'));
        final res = await req.close();
        if (res.statusCode == 200) {
          final body = await res.transform(utf8.decoder).join();
          _parseStatus(body);
          notifyListeners();
        }
        client.close();
      } catch (_) {
        isConnected = false;
        notifyListeners();
      }
    });
  }

  void _parseStatus(String body) {
    try {
      boardStatus = Map<String, dynamic>.from(jsonDecode(body));
      if (boardStatus.containsKey('texts')) {
        textList = List<String>.from(boardStatus['texts']);
      }
    } catch (_) {}
  }

  void send(Map<String, dynamic> cmd) => _post(cmd);

  Future<void> _post(Map<String, dynamic> cmd) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final req = await client.postUrl(Uri.parse('http://$_ip/cmd'));
      req.headers.set('Content-Type', 'application/json');
      req.write(jsonEncode(cmd));
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        _parseStatus(body);
        notifyListeners();
      }
      client.close();
    } catch (e) {
      debugPrint('[POST] $e');
    }
  }

  Future<bool> connect(String id) async => false;
  Future<void> startScan() async {}
  void stopScan() {}

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    isConnected = false;
    boardStatus = {};
    textList = [];
    notifyListeners();
  }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }
}
