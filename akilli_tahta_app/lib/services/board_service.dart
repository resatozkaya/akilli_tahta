// lib/services/board_service.dart
// Hem BLE hem WebSocket bağlantısını yöneten servis

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnMode { none, ble, wifi }

class BoardService extends ChangeNotifier {
  // ── BLE UUID'leri ──────────────────────────────────────────
  static const String _serviceUuid    = "12345678-1234-1234-1234-123456789abc";
  static const String _cmdCharUuid    = "12345678-1234-1234-1234-123456789ab0";
  static const String _statusCharUuid = "12345678-1234-1234-1234-123456789ab1";

  ConnMode connMode = ConnMode.none;

  // BLE
  BluetoothDevice? _bleDevice;
  BluetoothCharacteristic? _cmdChar;
  BluetoothCharacteristic? _statusChar;
  StreamSubscription? _bleScanSub;
  StreamSubscription? _bleNotifySub;
  bool _bleScanning = false;
  List<ScanResult> bleDevices = [];

  // WiFi / WebSocket
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  String wsIp = "";

  // Board durumu
  Map<String, dynamic> boardStatus = {};
  bool get isConnected => connMode != ConnMode.none;
  bool get isBleConnected => connMode == ConnMode.ble;
  bool get isWifiConnected => connMode == ConnMode.wifi;

  // ── BLE TARA ────────────────────────────────────────────────
  Future<void> startBleScan() async {
    if (_bleScanning) return;
    bleDevices.clear();
    _bleScanning = true;
    notifyListeners();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    _bleScanSub = FlutterBluePlus.scanResults.listen((results) {
      bleDevices = results
          .where((r) => r.device.platformName.isNotEmpty)
          .toList();
      notifyListeners();
    });
    await Future.delayed(const Duration(seconds: 8));
    await FlutterBluePlus.stopScan();
    _bleScanning = false;
    notifyListeners();
  }

  bool get isScanning => _bleScanning;

  // ── BLE BAĞLAN ──────────────────────────────────────────────
  Future<bool> connectBle(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 8));
      _bleDevice = device;

      List<BluetoothService> services = await device.discoverServices();
      for (var svc in services) {
        if (svc.uuid.toString().toLowerCase().contains("12345678-1234-1234-1234-123456789abc")) {
          for (var ch in svc.characteristics) {
            String u = ch.uuid.toString().toLowerCase();
            if (u.contains("ab0")) _cmdChar = ch;
            if (u.contains("ab1")) _statusChar = ch;
          }
        }
      }

      if (_statusChar != null) {
        await _statusChar!.setNotifyValue(true);
        _bleNotifySub = _statusChar!.onValueReceived.listen((value) {
          _parseStatus(utf8.decode(value));
        });
        // İlk durumu oku
        List<int> val = await _statusChar!.read();
        _parseStatus(utf8.decode(val));
      }

      connMode = ConnMode.ble;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("[BLE] Bağlantı hatası: $e");
      return false;
    }
  }

  // ── BLE KOMUTU GÖNDER ───────────────────────────────────────
  Future<void> sendBleMtu(String json) async {
    if (_cmdChar == null) return;
    // MTU sınırı için parçalara böl
    const int chunkSize = 512;
    Uint8List bytes = Uint8List.fromList(utf8.encode(json));
    for (int i = 0; i < bytes.length; i += chunkSize) {
      int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      await _cmdChar!.write(bytes.sublist(i, end), withoutResponse: true);
    }
  }

  // ── WiFi / WebSocket BAĞLAN ──────────────────────────────────
  Future<bool> connectWifi(String ip) async {
    try {
      wsIp = ip;
      _ws = WebSocketChannel.connect(Uri.parse("ws://$ip:81"));
      _wsSub = _ws!.stream.listen(
        (data) => _parseStatus(data.toString()),
        onError: (_) { _disconnectWifi(); },
        onDone:  ()  { _disconnectWifi(); },
      );
      connMode = ConnMode.wifi;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("[WS] Bağlantı hatası: $e");
      return false;
    }
  }

  void _disconnectWifi() {
    connMode = ConnMode.none;
    notifyListeners();
  }

  // ── KOMUT GÖNDER (ortak) ─────────────────────────────────────
  void send(Map<String, dynamic> cmd) {
    String json = jsonEncode(cmd);
    if (connMode == ConnMode.ble) {
      sendBleMtu(json);
    } else if (connMode == ConnMode.wifi) {
      _ws?.sink.add(json);
    }
  }

  // ── STATUS PARSE ─────────────────────────────────────────────
  void _parseStatus(String raw) {
    try {
      boardStatus = Map<String, dynamic>.from(jsonDecode(raw));
      notifyListeners();
    } catch (_) {}
  }

  // ── BAĞLANTIYI KES ───────────────────────────────────────────
  Future<void> disconnect() async {
    _bleNotifySub?.cancel();
    _wsSub?.cancel();
    _bleScanSub?.cancel();
    await _bleDevice?.disconnect();
    _ws?.sink.close();
    _bleDevice  = null;
    _cmdChar    = null;
    _statusChar = null;
    _ws         = null;
    connMode    = ConnMode.none;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
