import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/board_service.dart';

class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();
    final s = svc.boardStatus;
    final brightness = ((s['brightness'] ?? 160) as num).toDouble();
    final speed = ((s['speed'] ?? 40) as num).toDouble();
    final blackout = s['blackout'] ?? false;
    final hue = ((s['hue'] ?? 0) as num).toInt();

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Güç
      _Card(title: '⚡ Güç', child: Row(children: [
        Expanded(child: _Btn(
          label: blackout ? '🔴 KAPALI' : '🟢 AÇIK',
          color: blackout ? Colors.redAccent : Colors.greenAccent,
          onTap: () => svc.send({'blackout': !blackout}),
        )),
      ])),
      const SizedBox(height: 12),

      // Parlaklık & Hız
      _Card(title: '🎛️ Kontroller', child: Column(children: [
        _Slider(icon: Icons.brightness_6, label: 'Parlaklık', value: brightness,
          min: 10, max: 255, color: Colors.amberAccent,
          onChanged: (v) => svc.send({'brightness': v.round()})),
        const SizedBox(height: 8),
        _Slider(icon: Icons.speed, label: 'Hız', value: (305 - speed).clamp(5, 300),
          min: 5, max: 300, color: const Color(0xFF00E5FF),
          onChanged: (v) => svc.send({'speed': (305 - v).round()}),
          reversed: true),
      ])),
      const SizedBox(height: 12),

      // Renk
      _Card(title: '🎨 Yazı Rengi', child: Column(children: [
        _Slider(icon: Icons.palette, label: 'Ton',
          value: hue.toDouble(), min: 0, max: 255,
          color: HSVColor.fromAHSV(1, hue / 255 * 360, 1, 1).toColor(),
          onChanged: (v) => svc.send({'hue': v.round()})),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.color_lens, size: 16),
          label: const Text('Renk Seçici Aç'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A2E)),
          onPressed: () => _showColorPicker(context, svc, hue),
        ),
      ])),
      const SizedBox(height: 12),

      // Yön & Boyut
      _Card(title: '↔️ Yön & Kaydırma', child: Column(children: [
        // Orient seçimi
        Row(children: [
          Expanded(child: _Btn(
            label: (s['orient']??0)==0 ? '↔ Yatay ✓' : '↔ Yatay',
            color: (s['orient']??0)==0 ? const Color(0xFF00E5FF) : Colors.grey,
            onTap: () => svc.send({'orient': 0}),
          )),
          const SizedBox(width: 8),
          Expanded(child: _Btn(
            label: (s['orient']??0)==1 ? '↑ Yukarı ✓' : '↑ Yukarı',
            color: (s['orient']??0)==1 ? Colors.greenAccent : Colors.grey,
            onTap: () => svc.send({'orient': 1}),
          )),
          const SizedBox(width: 8),
          Expanded(child: _Btn(
            label: (s['orient']??0)==2 ? '↓ Aşağı ✓' : '↓ Aşağı',
            color: (s['orient']??0)==2 ? Colors.orangeAccent : Colors.grey,
            onTap: () => svc.send({'orient': 2}),
          )),
        ]),
        const SizedBox(height: 8),
        // Yatay modda sola/sağa
        if ((s['orient']??0)==0) Row(children: [
          Expanded(child: _Btn(label: '← Sola', color: const Color(0xFF00E5FF), onTap: () => svc.send({'dirLR': -1}))),
          const SizedBox(width: 8),
          Expanded(child: _Btn(label: 'Sağa →', color: const Color(0xFF00E5FF), onTap: () => svc.send({'dirLR': 1}))),
        ]),
        const SizedBox(height: 8),
        // Döndür & Boyut
        Row(children: [
          Expanded(child: _Btn(
            label: '🔄 Döndür (${(s['rotSteps']??0)*90}°)',
            color: Colors.purple,
            onTap: () => svc.send({'rotSteps': (((s['rotSteps']??0) as int)+1)%4}),
          )),
          const SizedBox(width: 8),
          Expanded(child: _Btn(
            label: (s['textSize'] ?? 1) == 1 ? '🔤 1x Boyut' : '🔠 2x Boyut',
            color: Colors.deepPurple,
            onTap: () => svc.send({'textSize': (s['textSize'] ?? 1) == 1 ? 2 : 1}),
          )),
        ]),
      ])),
      const SizedBox(height: 12),

      // Playlist
      _Card(title: '📋 Playlist', child: Row(children: [
        Expanded(child: _Btn(
          label: (s['playlist'] ?? false) ? '▶ Playlist AÇIK' : '⏸ Playlist KAPALI',
          color: (s['playlist'] ?? false) ? Colors.greenAccent : Colors.grey,
          onTap: () => svc.send({'playlist': !(s['playlist'] ?? false)}),
        )),
      ])),
      const SizedBox(height: 80),
    ]);
  }

  void _showColorPicker(BuildContext ctx, BoardService svc, int hue) {
    Color c = HSVColor.fromAHSV(1, hue / 255 * 360, 1, 1).toColor();
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: const Text('Renk Seç'),
      content: SingleChildScrollView(child: ColorPicker(
        pickerColor: c,
        onColorChanged: (nc) {
          int nh = (HSVColor.fromColor(nc).hue / 360 * 255).round();
          svc.send({'hue': nh});
        },
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(_), child: const Text('Tamam'))],
    ));
  }
}

class _Card extends StatelessWidget {
  final String title; final Widget child;
  const _Card({required this.title, required this.child});
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF12121F), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      const SizedBox(height: 10), child,
    ]),
  );
}

class _Btn extends StatelessWidget {
  final String label; final Color color; final VoidCallback onTap;
  const _Btn({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext ctx) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.4)), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    ),
  );
}

class _Slider extends StatelessWidget {
  final IconData icon; final String label; final double value, min, max;
  final Color color; final ValueChanged<double> onChanged; final bool reversed;
  const _Slider({required this.icon,required this.label,required this.value,
    required this.min,required this.max,required this.color,required this.onChanged,this.reversed=false});
  @override
  Widget build(BuildContext ctx) => Row(children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(width: 8),
    SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12))),
    Expanded(child: SliderTheme(
      data: SliderTheme.of(ctx).copyWith(activeTrackColor: color, thumbColor: color, inactiveTrackColor: color.withOpacity(0.2)),
      child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
    )),
    SizedBox(width: 32, child: Text(value.round().toString(), style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
  ]);
}
