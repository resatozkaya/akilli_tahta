import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/board_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<ScanResult> _allDevices = [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    // İzinleri iste
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.locationWhenInUse,
    ].request();

    setState(() { _allDevices.clear(); _scanning = true; });

    try {
      // Tüm cihazları tara (UUID filtresi YOK)
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      FlutterBluePlus.scanResults.listen((results) {
        if (mounted) setState(() => _allDevices = results);
      });
      await Future.delayed(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[SCAN] $e');
    }

    if (mounted) setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();

    // Tahtaları üste çıkar
    final sorted = [..._allDevices]..sort((a, b) {
      final aT = _isTabela(a.device.platformName);
      final bT = _isTabela(b.device.platformName);
      if (aT && !bT) return -1;
      if (!aT && bT) return 1;
      return 0;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cihaz Tara'),
        actions: [
          if (_scanning)
            const Padding(padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF))))
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: _startScan),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(10),
          color: const Color(0xFF001A2E),
          child: Text(
            _scanning ? '🔍 Tüm BLE cihazlar taranıyor...' : '${sorted.length} cihaz bulundu — tahtanızı seçin',
            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
            textAlign: TextAlign.center),
        ),
        Expanded(
          child: sorted.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(_scanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
                  size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(_scanning ? 'Aranıyor...' : 'Cihaz bulunamadı',
                  style: const TextStyle(color: Colors.grey, fontSize: 16)),
                if (!_scanning) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Tekrar Tara'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
                    onPressed: _startScan,
                  ),
                ],
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: sorted.length,
                itemBuilder: (_, i) {
                  final r = sorted[i];
                  final name = r.device.platformName;
                  final isTabela = _isTabela(name);
                  return Card(
                    color: isTabela ? const Color(0xFF0D2840) : const Color(0xFF12121F),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    child: ListTile(
                      leading: Icon(Icons.bluetooth,
                        color: isTabela ? const Color(0xFF00E5FF) : Colors.grey),
                      title: Text(
                        name.isEmpty ? '(İsimsiz) ${r.device.remoteId.str}' : name,
                        style: TextStyle(
                          fontWeight: isTabela ? FontWeight.bold : FontWeight.normal,
                          color: isTabela ? Colors.white : Colors.grey70)),
                      subtitle: Text('RSSI: ${r.rssi} dBm',
                        style: const TextStyle(fontSize: 11)),
                      trailing: isTabela
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF00E5FF)),
                            ),
                            child: const Text('⭐ Tabela',
                              style: TextStyle(fontSize: 11, color: Color(0xFF00E5FF))),
                          )
                        : null,
                      onTap: () => _connect(svc, r.device.remoteId.str),
                    ),
                  );
                }),
        ),
      ]),
    );
  }

  bool _isTabela(String name) =>
    name.toLowerCase().contains('akilli') ||
    name.toLowerCase().contains('tahta') ||
    name.toLowerCase().contains('tabela') ||
    name.toLowerCase().contains('esp32') ||
    name.toLowerCase().contains('esp-');

  void _connect(BoardService svc, String id) async {
    await FlutterBluePlus.stopScan();
    setState(() => _scanning = false);

    showDialog(context: context, barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Color(0xFF12121F),
        content: Row(children: [
          CircularProgressIndicator(color: Color(0xFF00E5FF)),
          SizedBox(width: 16), Text('Bağlanıyor...'),
        ]),
      ));

    final ok = await svc.connect(id);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Bağlantı kuruldu!' : '❌ Başarısız, tekrar deneyin'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) Navigator.pop(context);
    }
  }
}
