// lib/screens/connect_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/board_service.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  final _ipCtrl = TextEditingController(text: '192.168.1.');

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tc.dispose(); _ipCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bağlantı'),
        bottom: TabBar(
          controller: _tc,
          tabs: const [
            Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth'),
            Tab(icon: Icon(Icons.wifi), text: 'WiFi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tc,
        children: [
          _buildBleTab(svc),
          _buildWifiTab(svc),
        ],
      ),
    );
  }

  Widget _buildBleTab(BoardService svc) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: Text(
              svc.isScanning ? 'Taranıyor...' : '${svc.bleDevices.length} cihaz bulundu',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            icon: Icon(svc.isScanning ? Icons.stop : Icons.search),
            label: Text(svc.isScanning ? 'Durdur' : 'Tara'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            onPressed: svc.isScanning ? null : () => svc.startBleScan(),
          ),
        ]),
      ),
      Expanded(
        child: svc.bleDevices.isEmpty
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bluetooth_disabled, size: 60, color: Colors.grey),
                SizedBox(height: 12),
                Text('Cihaz bulunamadı', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 4),
                Text('"Tara" butonuna basın', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ))
          : ListView.builder(
              itemCount: svc.bleDevices.length,
              itemBuilder: (ctx, i) {
                final r = svc.bleDevices[i];
                bool isTarget = r.device.platformName.contains('AkilliTahta') ||
                                r.device.platformName.contains('Akilli');
                return Card(
                  color: isTarget ? const Color(0xFF0D2840) : const Color(0xFF1A1A2E),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Icon(Icons.bluetooth,
                      color: isTarget ? const Color(0xFF00E5FF) : Colors.grey),
                    title: Text(r.device.platformName.isEmpty
                      ? r.device.remoteId.str : r.device.platformName),
                    subtitle: Text('RSSI: ${r.rssi} dBm'),
                    trailing: isTarget
                      ? const Icon(Icons.star, color: Color(0xFF00E5FF), size: 16)
                      : null,
                    onTap: () => _connectBle(svc, r.device),
                  ),
                );
              },
            ),
      ),
    ]);
  }

  void _connectBle(BoardService svc, BluetoothDevice device) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Bağlanıyor...'),
        ]),
      ),
    );
    bool ok = await svc.connectBle(device);
    if (mounted) {
      Navigator.pop(context); // dialog kapat
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Bluetooth bağlantısı kuruldu!'),
            backgroundColor: Colors.green));
        Navigator.pop(context); // connect screen kapat
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Bağlantı başarısız'),
            backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildWifiTab(BoardService svc) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tahta IP Adresi', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ipCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: '192.168.1.100',
                prefixIcon: const Icon(Icons.wifi, color: Color(0xFF00E5FF)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Bağlan'),
            onPressed: () => _connectWifi(svc),
          ),
        ]),
        const SizedBox(height: 24),
        const Card(
          color: Color(0xFF1A1A2E),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('💡 IP Adresini Nasıl Bulursunuz?',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF))),
              SizedBox(height: 8),
              Text('1. Tahtayı ilk kez açın', style: TextStyle(fontSize: 13)),
              Text('2. "AkilliTahta-Setup" WiFi\'a telefondan bağlanın', style: TextStyle(fontSize: 13)),
              Text('3. Ev WiFi\'ınızı ve şifresini girin', style: TextStyle(fontSize: 13)),
              Text('4. Tahta bağlandıktan sonra router admin panelinden veya Serial Monitor\'dan IP\'yi öğrenin', style: TextStyle(fontSize: 13)),
            ]),
          ),
        ),
        if (svc.isWifiConnected) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2A0A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent),
              const SizedBox(width: 8),
              Text('Bağlı: ${svc.wsIp}',
                style: const TextStyle(color: Colors.greenAccent)),
            ]),
          ),
        ],
      ]),
    );
  }

  void _connectWifi(BoardService svc) async {
    String ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Bağlanıyor...'),
        ]),
      ),
    );
    bool ok = await svc.connectWifi(ip);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ WiFi bağlantısı kuruldu!' : '❌ Bağlantı başarısız'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) Navigator.pop(context);
    }
  }
}
