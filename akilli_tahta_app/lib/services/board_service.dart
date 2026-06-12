import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

const _svcUuid = "12345678-1234-1234-1234-123456789abc";
const _cmdUuid = "12345678-1234-1234-1234-123456789ab0";
const _stsUuid = "12345678-1234-1234-1234-123456789ab1";

class BoardService extends ChangeNotifier {
  final List<ScanResult> bleDevices = [];
  bool isScanning = false;
  bool isConnected = false;
  Map<String, dynamic> boardStatus = {};
  List<String> textList = [];

  BluetoothDevice? _device;
  BluetoothCharacteristic? _cmdChar;
  BluetoothCharacteristic? _stsChar;
  StreamSubscription? _notifySub;
  StreamSubscription? _scanSub;

  Future<void> startScan() async {
    await _requestPermissions();
    bleDevices.clear();
    isScanning = true;
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        bleDevices.clear();
        bleDevices.addAll(results.where((r) => r.device.platformName.isNotEmpty));
        notifyListeners();
      });
      await Future.delayed(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[SCAN] $e');
    }
    await FlutterBluePlus.stopScan();
    isScanning = false;
    notifyListeners();
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    isScanning = false;
    notifyListeners();
  }

  Future<bool> connect(String deviceId) async {
    try {
      final results = bleDevices.where((r) => r.device.remoteId.str == deviceId);
      if (results.isEmpty) return false;
      _device = results.first.device;

      await _device!.connect(timeout: const Duration(seconds: 10));
      final services = await _device!.discoverServices();

      for (var svc in services) {
        if (svc.uuid.toString().toLowerCase().contains("12345678-1234-1234-1234-123456789abc")) {
          for (var ch in svc.characteristics) {
            final u = ch.uuid.toString().toLowerCase();
            if (u.contains("ab0")) _cmdChar = ch;
            if (u.contains("ab1")) _stsChar = ch;
          }
        }
      }

      if (_stsChar != null) {
        await _stsChar!.setNotifyValue(true);
        _notifySub?.cancel();
        _notifySub = _stsChar!.onValueReceived.listen((data) {
          try {
            final json = utf8.decode(data);
            boardStatus = Map<String, dynamic>.from(jsonDecode(json));
            if (boardStatus.containsKey('texts')) {
              textList = List<String>.from(boardStatus['texts']);
            }
            notifyListeners();
          } catch (_) {}
        });
        // İlk durum oku
        try {
          final val = await _stsChar!.read();
          final json = utf8.decode(val);
          boardStatus = Map<String, dynamic>.from(jsonDecode(json));
          if (boardStatus.containsKey('texts')) {
            textList = List<String>.from(boardStatus['texts']);
          }
          notifyListeners();
        } catch (_) {}
      }

      isConnected = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[CONNECT] $e');
      isConnected = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> send(Map<String, dynamic> cmd) async {
    if (_cmdChar == null || !isConnected) return;
    try {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(cmd)));
      const chunk = 500;
      for (int i = 0; i < bytes.length; i += chunk) {
        final end = (i + chunk < bytes.length) ? i + chunk : bytes.length;
        await _cmdChar!.write(bytes.sublist(i, end), withoutResponse: true);
        if (bytes.length > chunk) await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      debugPrint('[SEND] $e');
    }
  }

  Future<void> disconnect() async {
    _notifySub?.cancel();
    _scanSub?.cancel();
    await _device?.disconnect();
    _device = null;
    _cmdChar = null;
    _stsChar = null;
    isConnected = false;
    boardStatus = {};
    textList = [];
    notifyListeners();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.locationWhenInUse,
    ].request();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
