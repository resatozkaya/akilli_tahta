import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/board_service.dart';

class OrientationScreen extends StatelessWidget {
  const OrientationScreen({super.key});

  // Asılı yön + kaydırma yönü kombinasyonları
  static const _configs = [
    // [rotSteps, orient, dirLR, label, desc]
    [0, 0, -1, '→ Yatay Sola',    'Tabela normal, yazı sola kayar'],
    [0, 0,  1, '→ Yatay Sağa',    'Tabela normal, yazı sağa kayar'],
    [2, 0, -1, '← Ters Yatay',    'Tabela baş aşağı asılı, yazı sola'],
    [2, 0,  1, '← Ters Sağa',     'Tabela baş aşağı asılı, yazı sağa'],
    [1, 1, -1, '↑ Dikey Sol Kenar','Sol kenarı alta, yazı yukarı kayar'],
    [1, 1,  1, '↑ Dikey Sol Alt', 'Sol kenarı alta, yazı aşağı kayar'],
    [3, 2, -1, '↓ Dikey Sağ Kenar','Sağ kenarı alta, yazı yukarı kayar'],
    [3, 2,  1, '↓ Dikey Sağ Alt', 'Sağ kenarı alta, yazı aşağı kayar'],
  ];

  static const _icons = [
    Icons.keyboard_arrow_left,
    Icons.keyboard_arrow_right,
    Icons.keyboard_arrow_left,
    Icons.keyboard_arrow_right,
    Icons.keyboard_arrow_up,
    Icons.keyboard_arrow_down,
    Icons.keyboard_arrow_up,
    Icons.keyboard_arrow_down,
  ];

  static const _rotLabels = ['0°', '90°', '180°', '270°'];

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();
    final s = svc.boardStatus;
    final curRot   = (s['rotSteps'] ?? 0) as int;
    final curOrient= (s['orient']   ?? 0) as int;
    final curDir   = (s['dirLR']    ?? -1) as int;

    return Scaffold(
      appBar: AppBar(title: const Text('Tabela Yönü')),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // Görsel önizleme
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF12121F),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            const Text('Mevcut Durum', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Tabela önizleme
            _buildPreview(curRot, curOrient, curDir),
            const SizedBox(height: 12),
            Text(
              'Döndürme: ${_rotLabels[curRot.clamp(0,3)]}  |  '
              'Yön: ${curOrient==0?"Yatay":curOrient==1?"Dikey↑":"Dikey↓"}  |  '
              'Kaydırma: ${curDir<0?"←":"→"}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ]),
        ),

        // Hızlı döndürme
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF12121F), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🔄 Hızlı Döndürme', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: List.generate(4, (i) => Expanded(child: Padding(
              padding: EdgeInsets.only(right: i<3 ? 8 : 0),
              child: _RotBtn(
                label: _rotLabels[i],
                isActive: curRot == i,
                onTap: () => svc.send({'rotSteps': i}),
              ),
            )))),
          ]),
        ),
        const SizedBox(height: 12),

        // Hazır konfigürasyonlar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF12121F), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('📌 Asılı Yön Presetleri', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('Tabelayı nasıl astığınıza göre seçin:', style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 12),
            ..._configs.asMap().entries.map((e) {
              final i = e.key;
              final cfg = e.value;
              final isActive = curRot  == cfg[0] &&
                               curOrient == cfg[1] &&
                               (curDir < 0 ? -1 : 1) == cfg[2];
              return _PresetTile(
                icon: _icons[i],
                label: cfg[3] as String,
                desc: cfg[4] as String,
                isActive: isActive,
                onTap: () => svc.send({
                  'rotSteps': cfg[0],
                  'orient':   cfg[1],
                  'dirLR':    cfg[2],
                }),
              );
            }),
          ]),
        ),
        const SizedBox(height: 12),

        // Manuel ince ayar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF12121F), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('⚙️ Manuel Ayar', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            // Kaydırma yönü
            const Text('Kaydırma Yönü:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _ToggleBtn(label: '← Sol / Yukarı', isActive: curDir < 0, onTap: () => svc.send({'dirLR': -1}))),
              const SizedBox(width: 8),
              Expanded(child: _ToggleBtn(label: '→ Sağ / Aşağı', isActive: curDir >= 0, onTap: () => svc.send({'dirLR': 1}))),
            ]),
            const SizedBox(height: 10),
            const Text('Dikey Mod:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _ToggleBtn(label: 'Yatay', isActive: curOrient==0, onTap: () => svc.send({'orient': 0}))),
              const SizedBox(width: 6),
              Expanded(child: _ToggleBtn(label: 'Dikey ↑', isActive: curOrient==1, onTap: () => svc.send({'orient': 1}))),
              const SizedBox(width: 6),
              Expanded(child: _ToggleBtn(label: 'Dikey ↓', isActive: curOrient==2, onTap: () => svc.send({'orient': 2}))),
            ]),
          ]),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildPreview(int rot, int orient, int dir) {
    // Basit görsel: tabela dikdörtgeni + ok
    return Container(
      width: 200, height: 130,
      child: Stack(alignment: Alignment.center, children: [
        // Tabela gövdesi
        Transform.rotate(
          angle: rot * 3.14159 / 2,
          child: Container(
            width: orient == 0 ? 140 : 90,
            height: orient == 0 ? 90 : 140,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF00E5FF), width: 2),
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFF001A2E),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                dir < 0 ? Icons.arrow_back : Icons.arrow_forward,
                color: const Color(0xFF00E5FF), size: 24,
              ),
              const SizedBox(height: 4),
              const Text('LED', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 10)),
            ]),
          ),
        ),
        // Asma noktası
        Positioned(
          top: 0,
          child: Container(
            width: 12, height: 12,
            decoration: const BoxDecoration(color: Colors.amberAccent, shape: BoxShape.circle),
          ),
        ),
        const Positioned(
          top: 6,
          child: Text('▲ Duvara asılan kenar', style: TextStyle(color: Colors.amberAccent, fontSize: 8)),
        ),
      ]),
    );
  }
}

class _RotBtn extends StatelessWidget {
  final String label; final bool isActive; final VoidCallback onTap;
  const _RotBtn({required this.label, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF00E5FF).withOpacity(0.2) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? const Color(0xFF00E5FF) : Colors.transparent, width: 2),
      ),
      child: Text(label,
        style: TextStyle(color: isActive ? const Color(0xFF00E5FF) : Colors.grey,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 13),
        textAlign: TextAlign.center),
    ),
  );
}

class _ToggleBtn extends StatelessWidget {
  final String label; final bool isActive; final VoidCallback onTap;
  const _ToggleBtn({required this.label, required this.isActive, required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? Colors.purple.withOpacity(0.25) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? Colors.purple : Colors.transparent, width: 2),
      ),
      child: Text(label,
        style: TextStyle(color: isActive ? Colors.purpleAccent : Colors.grey, fontSize: 12),
        textAlign: TextAlign.center),
    ),
  );
}

class _PresetTile extends StatelessWidget {
  final IconData icon; final String label, desc;
  final bool isActive; final VoidCallback onTap;
  const _PresetTile({required this.icon,required this.label,required this.desc,
    required this.isActive,required this.onTap});
  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF00E5FF).withOpacity(0.15) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isActive ? const Color(0xFF00E5FF) : Colors.transparent),
      ),
      child: Row(children: [
        Icon(icon, color: isActive ? const Color(0xFF00E5FF) : Colors.grey, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(
            color: isActive ? const Color(0xFF00E5FF) : Colors.white,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
          Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ])),
        if (isActive) const Icon(Icons.check_circle, color: Color(0xFF00E5FF), size: 18),
      ]),
    ),
  );
}
