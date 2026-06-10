// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/board_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();
    final s = svc.boardStatus;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Bağlantı durumu
        _InfoCard(
          title: 'Bağlantı Durumu',
          items: [
            _InfoRow('Mod', svc.isBleConnected ? '📶 Bluetooth' : svc.isWifiConnected ? '📡 WiFi' : '❌ Bağlı Değil'),
            if (svc.isWifiConnected) _InfoRow('Tahta IP', svc.wsIp),
            if (s.containsKey('ip')) _InfoRow('Tahta WiFi IP', s['ip'].toString()),
          ],
        ),
        const SizedBox(height: 12),

        // Tahta bilgileri
        _InfoCard(
          title: 'Tahta Durumu',
          items: [
            _InfoRow('Parlaklık', '${s['brightness'] ?? '-'}'),
            _InfoRow('Hız (ms)', '${s['speed'] ?? '-'}'),
            _InfoRow('Arkaplan', ['Kapalı','Solid','Rainbow','Twinkle'][((s['bgMode'] ?? 0) as int).clamp(0,3)]),
            _InfoRow('Yön', ['Yatay','Dikey↑','Dikey↓'][((s['orient'] ?? 0) as int).clamp(0,2)]),
            _InfoRow('Efekt', ['Normal','Matrix','Ateş','Dalga','Konfeti','Saat','Hava','Çizim'][((s['extraEffect'] ?? 0) as int).clamp(0,7)]),
            _InfoRow('WiFi', s['wifiOk'] == true ? '✅ Bağlı' : '❌ Bağlı Değil'),
          ],
        ),
        const SizedBox(height: 12),

        // Kurulum bilgisi
        _InfoCard(
          title: '📦 Kütüphane Gereksinimleri (Arduino)',
          items: [
            _InfoRow('', 'Adafruit NeoMatrix'),
            _InfoRow('', 'Adafruit NeoPixel'),
            _InfoRow('', 'IRremote (shirriff)'),
            _InfoRow('', 'WiFiManager (tzapu)'),
            _InfoRow('', 'arduinoWebSockets (Links2004)'),
            _InfoRow('', 'ArduinoJson (bblanchon)'),
            _InfoRow('', 'ESP32 BLE Arduino (built-in)'),
          ],
        ),
        const SizedBox(height: 12),

        // Bağlantıyı kes
        ListTile(
          tileColor: const Color(0xFF2A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: const Icon(Icons.link_off, color: Colors.redAccent),
          title: const Text('Bağlantıyı Kes'),
          subtitle: const Text('Tahta ile bağlantıyı sonlandır'),
          onTap: () {
            svc.disconnect();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bağlantı kesildi')));
          },
        ),
        const SizedBox(height: 12),

        // Hakkında
        const ListTile(
          tileColor: Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          leading: Icon(Icons.info_outline, color: Color(0xFF00E5FF)),
          title: Text('Akıllı Tahta v2.0'),
          subtitle: Text('20×30 NeoMatrix LED • ESP32\nBLE + WiFi + IR Kontrol'),
          isThreeLine: true,
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _InfoCard({required this.title, required this.items});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A2E),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
        color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
      const SizedBox(height: 8),
      ...items,
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      if (label.isNotEmpty) ...[
        SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ] else
        Text('• $value', style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ]),
  );
}

// WiFi setup widget - settings ekranına eklenecek
class WifiSetupCard extends StatefulWidget {
  const WifiSetupCard({super.key});
  @override
  State<WifiSetupCard> createState() => _WifiSetupCardState();
}
class _WifiSetupCardState extends State<WifiSetupCard> {
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📡 WiFi Ayarı', style: TextStyle(
          color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _ssidCtrl,
          decoration: InputDecoration(
            hintText: 'WiFi Adı (SSID)',
            prefixIcon: const Icon(Icons.wifi, color: Color(0xFF00E5FF), size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true, fillColor: const Color(0xFF0D0D0D),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'WiFi Şifresi',
            prefixIcon: const Icon(Icons.lock, color: Color(0xFF00E5FF), size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true, fillColor: const Color(0xFF0D0D0D),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 16),
            label: Text(_sent ? 'Gönderildi! Bağlanıyor...' : 'Tahtaya Gönder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _sent ? Colors.green : const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (_ssidCtrl.text.isEmpty) return;
              svc.send({
                'wifiSSID': _ssidCtrl.text,
                'wifiPass': _passCtrl.text,
              });
              setState(() => _sent = true);
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) setState(() => _sent = false);
              });
            },
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tahta WiFi\'a bağlandıktan sonra otomatik olarak hatırlar.\nBir sonraki açılışta direkt bağlanır.',
          style: TextStyle(color: Colors.grey, fontSize: 11)),
      ]),
    );
  }
}
