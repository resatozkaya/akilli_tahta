import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/board_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BoardService>().startScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cihaz Tara'),
        actions: [
          if (svc.isScanning)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF))),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => svc.startScan(),
            ),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF001A2E),
          child: Text(
            svc.isScanning
              ? '🔍 Taranıyor... Tahtanın açık olduğundan emin olun'
              : '${svc.bleDevices.length} cihaz bulundu',
            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: svc.bleDevices.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(svc.isScanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
                  size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(svc.isScanning ? 'Aranıyor...' : 'Cihaz bulunamadı',
                  style: const TextStyle(color: Colors.grey, fontSize: 16)),
                if (!svc.isScanning) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Tekrar Tara'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => svc.startScan(),
                  ),
                ],
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: svc.bleDevices.length,
                itemBuilder: (_, i) {
                  final r = svc.bleDevices[i];
                  final name = r.device.platformName;
                  final isTarget = name.contains('AkilliTahta');
                  return Card(
                    color: isTarget ? const Color(0xFF0D2840) : const Color(0xFF12121F),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Icon(Icons.bluetooth,
                        color: isTarget ? const Color(0xFF00E5FF) : Colors.grey, size: 28),
                      title: Text(name.isEmpty ? r.device.remoteId.str : name,
                        style: TextStyle(
                          fontWeight: isTarget ? FontWeight.bold : FontWeight.normal,
                          color: isTarget ? Colors.white : Colors.grey)),
                      subtitle: Text('RSSI: ${r.rssi} dBm • ${r.device.remoteId.str}',
                        style: const TextStyle(fontSize: 11)),
                      trailing: isTarget
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF00E5FF)),
                            ),
                            child: const Text('Tabela', style: TextStyle(fontSize: 11, color: Color(0xFF00E5FF))),
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

  void _connect(BoardService svc, String id) async {
    svc.stopScan();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Color(0xFF12121F),
        content: Row(children: [
          CircularProgressIndicator(color: Color(0xFF00E5FF)),
          SizedBox(width: 16),
          Text('Bağlanıyor...'),
        ]),
      ),
    );
    final ok = await svc.connect(id);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Bağlantı kuruldu!' : '❌ Bağlantı başarısız, tekrar deneyin'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) Navigator.pop(context);
    }
  }
}
