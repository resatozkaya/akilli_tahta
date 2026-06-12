import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/board_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _connecting = false;
  String _msg = 'Hazır';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoConnect());
  }

  Future<void> _autoConnect() async {
    setState(() { _connecting = true; _msg = '192.168.4.1\'e bağlanılıyor...'; });
    final ok = await context.read<BoardService>().autoConnect();
    if (mounted) {
      final svc2 = context.read<BoardService>();
      setState(() { 
        _connecting = false; 
        _msg = ok ? '✅ Bağlandı!' : '❌ Hata: \${svc2.lastError}'; 
      });
      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tahtaya Bağlan')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // WiFi talimat kutusu
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF001A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.wifi, color: Color(0xFF00E5FF), size: 20),
                SizedBox(width: 8),
                Text('Bağlantı Talimatı', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 12),
              _step('1', 'Telefonun WiFi ayarlarına gidin'),
              _step('2', '"AkilliTahta-AP" ağına bağlanın'),
              _step('3', 'Şifre: 12345678'),
              _step('4', 'Geri gelip "Bağlan" butonuna basın'),
            ]),
          ),
          const SizedBox(height: 32),

          // Durum göstergesi
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF12121F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              if (_connecting)
                const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)))
              else
                Icon(
                  _msg.contains('✅') ? Icons.check_circle : Icons.info_outline,
                  color: _msg.contains('✅') ? Colors.greenAccent : Colors.grey, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(_msg, style: const TextStyle(fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 24),

          // Bağlan butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _connecting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.wifi),
              label: Text(_connecting ? 'Bağlanıyor...' : 'Bağlan (192.168.4.1)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _connecting ? null : _autoConnect,
            ),
          ),
          const SizedBox(height: 12),

          // Özel IP girişi
          OutlinedButton.icon(
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Farklı IP gir'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              side: const BorderSide(color: Colors.grey),
            ),
            onPressed: () => _showCustomIpDialog(),
          ),
        ]),
      ),
    );
  }

  Widget _step(String num, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Container(
        width: 22, height: 22,
        decoration: const BoxDecoration(color: Color(0xFF00E5FF), shape: BoxShape.circle),
        child: Center(child: Text(num, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );

  void _showCustomIpDialog() {
    final ctrl = TextEditingController(text: '192.168.4.1');
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF12121F),
      title: const Text('IP Adresi Gir'),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: '192.168.4.1'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
          onPressed: () async {
            Navigator.pop(context);
            setState(() { _connecting = true; _msg = '${ctrl.text}\'e bağlanılıyor...'; });
            final ok = await context.read<BoardService>().connectWifi(ctrl.text.trim());
            if (mounted) {
              final svc2 = context.read<BoardService>();
      setState(() { 
        _connecting = false; 
        _msg = ok ? '✅ Bağlandı!' : '❌ Hata: \${svc2.lastError}'; 
      });
              if (ok) Navigator.pop(context);
            }
          },
          child: const Text('Bağlan'),
        ),
      ],
    ));
  }
}
