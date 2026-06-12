import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BoardService extends ChangeNotifier {
  static const String _apIp = '192.168.4.1';
  static const String _baseUrl = 'http://$_apIp';

  bool isConnected = false;
  bool isScanning = false;
  Map<String, dynamic> boardStatus = {};
  List<String> textList = [];
  Timer? _pollTimer;
  String statusMsg = 'Bağlantı bekleniyor...';

  // flutter_blue_plus uyumluluğu için boş liste
  List<dynamic> get bleDevices => [];
  bool get isWifiConnected => isConnected;
  bool get isBleConnected => false;

  Future<bool> connectWifi(String ip) async {
    return await _tryConnect(ip);
  }

  Future<bool> autoConnect() async {
    return await _tryConnect(_apIp);
  }

  Future<bool> _tryConnect(String ip) async {
    try {
      statusMsg = '$ip\'e bağlanılıyor...';
      notifyListeners();
      final res = await http.get(
        Uri.parse('http://$ip/status'),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        _parseStatus(res.body);
        isConnected = true;
        statusMsg = '✅ Bağlı: $ip';
        _startPolling(ip);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[HTTP] $e');
      statusMsg = '❌ Bağlanamadı: $e';
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
    } catch (e) {
      debugPrint('[PARSE] $e');
    }
  }

  void send(Map<String, dynamic> cmd) {
    _sendHttp(cmd);
  }

  Future<void> _sendHttp(Map<String, dynamic> cmd) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/cmd'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(cmd),
      ).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        _parseStatus(res.body);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[SEND] $e');
    }
  }

  Future<bool> connect(String deviceId) async => false;
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
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
