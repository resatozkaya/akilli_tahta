import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BoardService extends ChangeNotifier {
  static const String _ip = '192.168.4.1';

  bool isConnected = false;
  Map<String, dynamic> boardStatus = {};
  List<String> textList = [];
  Timer? _pollTimer;
  String statusMsg = 'Hazır';
  String lastError = '';

  List<dynamic> get bleDevices => [];
  bool get isWifiConnected => isConnected;
  bool get isBleConnected => false;
  bool get isScanning => false;

  Future<bool> autoConnect() => connectWifi(_ip);

  Future<bool> connectWifi(String ip) async {
    try {
      statusMsg = 'Bağlanılıyor...';
      lastError = '';
      notifyListeners();

      final res = await http.get(
        Uri.parse('http://$ip/status'),
        headers: {'Connection': 'close'},
      ).timeout(const Duration(seconds: 8));

      debugPrint('[HTTP] ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 100))}');

      if (res.statusCode == 200) {
        _parseStatus(res.body);
        isConnected = true;
        statusMsg = '✅ Bağlı!';
        _startPolling(ip);
        notifyListeners();
        return true;
      }
      lastError = 'HTTP ${res.statusCode}';
    } catch (e) {
      lastError = e.toString();
      debugPrint('[HTTP ERROR] $e');
      statusMsg = '❌ $lastError';
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
        final res = await http.get(
          Uri.parse('http://$ip/status'),
        ).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          _parseStatus(res.body);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[POLL] $e');
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
    } catch (e) {
      debugPrint('[PARSE] $e');
    }
  }

  void send(Map<String, dynamic> cmd) => _post(cmd);

  Future<void> _post(Map<String, dynamic> cmd) async {
    try {
      final res = await http.post(
        Uri.parse('http://$_ip/cmd'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(cmd),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        _parseStatus(res.body);
        notifyListeners();
      }
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
    statusMsg = 'Bağlantı kesildi';
    notifyListeners();
  }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }
}
