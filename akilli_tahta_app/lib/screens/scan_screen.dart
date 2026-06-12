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
            const Padding(padding: EdgeInsets.all(12), child: SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)))
          else
            IconButton(icon: const Icon(Icons.refresh), onPressed: () => svc.startScan()),
        ],
      ),
      body: Column(children: [
        if (svc.isScanning)
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            color: const Color(0xFF001A2E),
            child: const Text('Cihazlar taranıyor... (Tahtanın açık ve yakında olduğundan emin olun)',
              style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12), textAlign: TextAlign.center),
          ),
        Expanded(
          child: svc.bleDevices.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(svc.isScanning ? Icons.search : Icons.bluetooth_disabled, size:60, color:Colors.grey),
                const SizedBox(height:12),
                Text(svc.isScanning ? 'Taranıyor...' : 'Cihaz bulunamadı', style: const TextStyle(color:Colors.grey)),
                if (!svc.isScanning) ...[
                  const SizedBox(height:16),
                  ElevatedButton(onPressed: ()=>svc.startScan(), child: const Text('Tekrar Tara')),
                ],
              ]))
            : ListView.builder(
                itemCount: svc.bleDevices.length,
                itemBuilder: (_, i) {
                  final d = svc.bleDevices[i];
                  final isTarget = d.name.contains('AkilliTahta');
                  return Card(
                    color: isTarget ? const Color(0xFF0D2840) : const Color(0xFF12121F),
                    margin: const EdgeInsets.symmetric(horizontal:16, vertical:4),
                    child: ListTile(
                      leading: Icon(Icons.bluetooth, color: isTarget ? const Color(0xFF00E5FF) : Colors.grey),
                      title: Text(d.name.isEmpty ? d.id : d.name,
                        style: TextStyle(fontWeight: isTarget ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text('RSSI: ${d.rssi} dBm'),
                      trailing: isTarget ? const Chip(label: Text('Tabela', style: TextStyle(fontSize:11))) : null,
                      onTap: () => _connect(svc, d.id),
                    ),
                  );
                }),
        ),
      ]),
    );
  }

  void _connect(BoardService svc, String id) async {
    svc.stopScan();
    showDialog(context: context, barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width:16), Text('Bağlanıyor...')]),
      ));
    final ok = await svc.connect(id);
    if (mounted) {
      Navigator.pop(context);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Bağlantı kuruldu!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Bağlantı başarısız'), backgroundColor: Colors.red));
      }
    }
  }
}
