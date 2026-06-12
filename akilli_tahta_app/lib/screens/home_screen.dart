import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/board_service.dart';
import 'scan_screen.dart';
import 'control_screen.dart';
import 'text_screen.dart';
import 'effects_screen.dart';
import 'orientation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width:8,height:8,decoration:BoxDecoration(
            color: svc.isConnected ? Colors.greenAccent : Colors.redAccent,
            shape: BoxShape.circle)),
          const SizedBox(width:8),
          const Text('Akıllı Tabela', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
            icon: Icon(svc.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: svc.isConnected ? Colors.greenAccent : Colors.grey),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
          ),
          if (svc.isConnected)
            IconButton(
              icon: const Icon(Icons.screen_rotation, color: Color(0xFF00E5FF)),
              tooltip: 'Tabela Yönü',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrientationScreen())),
            ),
        ],
      ),
      body: svc.isConnected ? _pages()[_tab] : _buildDisconnected(context),
      bottomNavigationBar: svc.isConnected ? NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: const Color(0xFF12121F),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.tune), label: 'Kontrol'),
          NavigationDestination(icon: Icon(Icons.text_fields), label: 'Yazılar'),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Efektler'),
        ],
      ) : null,
    );
  }

  List<Widget> _pages() => const [ControlScreen(), TextScreen(), EffectsScreen()];

  Widget _buildDisconnected(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF12121F),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.display_settings, size: 80, color: Color(0xFF00E5FF)),
      ),
      const SizedBox(height: 24),
      const Text('Tahtaya Bağlı Değilsiniz', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Bluetooth ile bağlanın', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 32),
      ElevatedButton.icon(
        icon: const Icon(Icons.bluetooth_searching),
        label: const Text('Cihaz Tara ve Bağlan'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
      ),
    ]));
  }
}
