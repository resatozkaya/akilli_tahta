// lib/screens/connect_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/board_service.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  final _ipCtrl = TextEditingController(text: '192.168.');
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _wifiSent = false;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tc.dispose(); _ipCtrl.dispose(); _ssidCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bağlantı'),
        bottom: TabBar(
          controller: _tc,
          tabs: const [
            Tab(icon: Icon(Icons.wifi), text: 'WiFi ile Bağlan'),
            Tab(icon: Icon(Icons.settings), text: 'WiFi Ayarla'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tc,
        children: [
          _buildWifiTab(svc),
          _buildWifiSetupTab(svc),
        ],
      ),
    );
  }

  // TAB 1: IP girerek bağlan
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: '192.168.1.100',
                prefixIcon: const Icon(Icons.wifi, color: Color(0xFF00E5FF)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: const Color(0xFF1A1A2E),
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
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('💡 IP Adresini Bulmak İçin:',
              style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('1. ESP32\'yi bilgisayara bağlayın', style: TextStyle(fontSize: 13)),
            Text('2. Arduino IDE → Araçlar → Seri Monitör', style: TextStyle(fontSize: 13)),
            Text('3. "[WiFi] Baglandi: 192.168.X.X" satırına bakın', style: TextStyle(fontSize: 13)),
            SizedBox(height: 8),
            Text('veya: akilli-tahta.local yazın (mDNS)',
              style: TextStyle(fontSize: 13, color: Colors.greenAccent)),
          ]),
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
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ]),
    );
  }

  // TAB 2: WiFi şifresini tahtaya gönder
  Widget _buildWifiSetupTab(BoardService svc) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.greenAccent, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Önce WiFi ile bağlanın (Tab 1), sonra buradan ev WiFi şifrenizi gönderin. Tahta bir dahaki açılışta otomatik bağlanır.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _ssidCtrl,
          decoration: InputDecoration(
            hintText: 'WiFi Adı (SSID)',
            prefixIcon: const Icon(Icons.wifi, color: Color(0xFF00E5FF), size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true, fillColor: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'WiFi Şifresi',
            prefixIcon: const Icon(Icons.lock, color: Color(0xFF00E5FF), size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true, fillColor: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: Text(_wifiSent ? '✅ Gönderildi! Tahta bağlanıyor...' : 'Tahtaya WiFi Bilgisi Gönder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _wifiSent ? Colors.green : const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: !svc.isConnected ? null : () {
              if (_ssidCtrl.text.isEmpty) return;
              svc.send({'wifiSSID': _ssidCtrl.text, 'wifiPass': _passCtrl.text});
              setState(() => _wifiSent = true);
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted) setState(() => _wifiSent = false);
              });
            },
          ),
        ),
        if (!svc.isConnected)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('⚠️ Önce Tab 1\'den bağlantı kurun',
              style: TextStyle(color: Colors.orange, fontSize: 12)),
          ),
      ]),
    );
  }

  void _connectWifi(BoardService svc) async {
    String ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(), SizedBox(width: 16), Text('Bağlanıyor...'),
        ]),
      ),
    );
    bool ok = await svc.connectWifi(ip);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Bağlantı kuruldu!' : '❌ Bağlantı başarısız — IP doğru mu?'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) Navigator.pop(context);
    }
  }
}
