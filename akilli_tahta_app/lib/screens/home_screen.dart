// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/board_service.dart';
import 'connect_screen.dart';
import 'control_screen.dart';
import 'effects_screen.dart';
import 'draw_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _tabs = [
    NavigationDestination(icon: Icon(Icons.tune), label: 'Kontrol'),
    NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Efektler'),
    NavigationDestination(icon: Icon(Icons.draw), label: 'Çizim'),
    NavigationDestination(icon: Icon(Icons.settings), label: 'Ayarlar'),
  ];

  final _pages = const [
    ControlScreen(),
    EffectsScreen(),
    DrawScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.grid_on, color: Color(0xFF00E5FF), size: 20),
          SizedBox(width: 8),
          Text('Akıllı Tahta', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          // Bağlantı durumu rozeti
          GestureDetector(
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ConnectScreen())),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: svc.isConnected
                  ? (svc.isBleConnected ? const Color(0xFF1E3A5F) : const Color(0xFF1A3A1A))
                  : const Color(0xFF3A1A1A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Icon(
                  svc.isBleConnected ? Icons.bluetooth_connected
                    : svc.isWifiConnected ? Icons.wifi
                    : Icons.link_off,
                  size: 14,
                  color: svc.isConnected
                    ? (svc.isBleConnected ? Colors.blueAccent : Colors.greenAccent)
                    : Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  svc.isConnected
                    ? (svc.isBleConnected ? 'BLE' : 'WiFi')
                    : 'Bağlı Değil',
                  style: const TextStyle(fontSize: 12),
                ),
              ]),
            ),
          ),
        ],
      ),
      body: !svc.isConnected
        ? _buildNotConnected(context)
        : _pages[_tab],
      bottomNavigationBar: svc.isConnected
        ? NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            backgroundColor: const Color(0xFF1A1A2E),
            destinations: _tabs,
          )
        : null,
    );
  }

  Widget _buildNotConnected(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.grid_off, size: 80, color: Color(0xFF444444)),
        const SizedBox(height: 20),
        const Text('Tahtaya Bağlı Değilsiniz',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('BLE veya WiFi ile bağlanın',
          style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          icon: const Icon(Icons.bluetooth_searching),
          label: const Text('Bağlantı Kur'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ConnectScreen())),
        ),
      ]),
    );
  }
}
