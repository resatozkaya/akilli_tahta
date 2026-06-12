// lib/services/board_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

const _svcUuid  = "12345678-1234-1234-1234-123456789abc";
const _cmdUuid  = "12345678-1234-1234-1234-123456789ab0";
const _stsUuid  = "12345678-1234-1234-1234-123456789ab1";

class BoardService extends ChangeNotifier {
  final _ble = FlutterReactiveBle();

  // Scan
  StreamSubscription? _scanSub;
  final List<DiscoveredDevice> bleDevices = [];
  bool isScanning = false;

  // Connection
  StreamSubscription? _connSub;
  StreamSubscription? _notifySub;
  String? _connDevId;
  bool isConnected = false;

  // Board state
  Map<String, dynamic> boardStatus = {};
  List<String> textList = [];

  // BLE characteristics
  QualifiedCharacteristic? _cmdChar;
  QualifiedCharacteristic? _stsChar;

  // Scan
  Future<void> startScan() async {
    await _requestPermissions();
    bleDevices.clear();
    isScanning = true;
    notifyListeners();

    _scanSub?.cancel();
    _scanSub = _ble.scanForDevices(
      withServices: [Uuid.parse(_svcUuid)],
      scanMode: ScanMode.lowLatency,
    ).timeout(const Duration(seconds: 10), onTimeout: (sink) => sink.close())
     .listen((device) {
      if (!bleDevices.any((d) => d.id == device.id)) {
        bleDevices.add(device);
        notifyListeners();
      }
    }, onDone: () {
      isScanning = false;
      notifyListeners();
    }, onError: (_) {
      isScanning = false;
      notifyListeners();
    });
  }

  void stopScan() {
    _scanSub?.cancel();
    isScanning = false;
    notifyListeners();
  }

  // Connect
  Future<bool> connect(String deviceId) async {
    _connSub?.cancel();
    bool success = false;
    final completer = Completer<bool>();

    _connSub = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
    ).listen((state) async {
      if (state.connectionState == DeviceConnectionState.connected) {
        _connDevId = deviceId;
        isConnected = true;
        _setupChars(deviceId);
        _subscribeStatus(deviceId);
        success = true;
        if (!completer.isCompleted) completer.complete(true);
        notifyListeners();
      } else if (state.connectionState == DeviceConnectionState.disconnected) {
        isConnected = false;
        _connDevId = null;
        if (!completer.isCompleted) completer.complete(false);
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('[BLE] Hata: $e');
      if (!completer.isCompleted) completer.complete(false);
    });

    return completer.future.timeout(const Duration(seconds: 12), onTimeout: () => false);
  }

  void _setupChars(String deviceId) {
    _cmdChar = QualifiedCharacteristic(
      serviceId: Uuid.parse(_svcUuid),
      characteristicId: Uuid.parse(_cmdUuid),
      deviceId: deviceId,
    );
    _stsChar = QualifiedCharacteristic(
      serviceId: Uuid.parse(_svcUuid),
      characteristicId: Uuid.parse(_stsUuid),
      deviceId: deviceId,
    );
  }

  void _subscribeStatus(String deviceId) {
    _notifySub?.cancel();
    if (_stsChar == null) return;
    _notifySub = _ble.subscribeToCharacteristic(_stsChar!).listen((data) {
      try {
        final json = utf8.decode(data);
        boardStatus = Map<String, dynamic>.from(jsonDecode(json));
        if (boardStatus.containsKey('texts')) {
          textList = List<String>.from(boardStatus['texts']);
        }
        notifyListeners();
      } catch (e) {
        debugPrint('[BLE] Status parse hatası: $e');
      }
    });
  }

  // Send command
  Future<void> send(Map<String, dynamic> cmd) async {
    if (_cmdChar == null || !isConnected) return;
    try {
      final bytes = utf8.encode(jsonEncode(cmd));
      // MTU chunking
      const chunkSize = 500;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        await _ble.writeCharacteristicWithoutResponse(
          _cmdChar!,
          value: bytes.sublist(i, end),
        );
        if (bytes.length > chunkSize) await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      debugPrint('[BLE] Gönderme hatası: $e');
    }
  }

  Future<void> disconnect() async {
    _notifySub?.cancel();
    _connSub?.cancel();
    isConnected = false;
    _connDevId = null;
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
    _scanSub?.cancel();
    _connSub?.cancel();
    _notifySub?.cancel();
    super.dispose();
  }
}
