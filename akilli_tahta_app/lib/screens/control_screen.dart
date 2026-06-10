// lib/screens/control_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/board_service.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});
  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  final _textCtrl = TextEditingController();

  static const _bgModes = ['Kapalı', 'Solid', 'Rainbow', 'Twinkle'];
  static const _orientModes = ['Yatay →', 'Dikey ↑', 'Dikey ↓'];

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();
    final s = svc.boardStatus;

    double brightness = ((s['brightness'] ?? 160) as num).toDouble();
    double speed      = ((s['speed']      ?? 40)  as num).toDouble();
    bool   blackout   = s['blackout'] ?? false;
    bool   playlist   = s['playlist'] ?? false;
    int    bgMode     = (s['bgMode']   ?? 0) as int;
    int    orient     = (s['orient']   ?? 0) as int;
    int    hue        = (s['hue']      ?? 0) as int;
    int    activeIdx  = (s['activeIndex'] ?? 0) as int;
    int    textSz     = (s['textSize'] ?? 1) as int;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Açma / Kapama ──────────────────────────────────────
        _SectionCard(
          title: 'Güç',
          child: Row(children: [
            Expanded(
              child: _ActionBtn(
                icon: Icons.power_settings_new,
                label: 'Kapat',
                color: blackout ? Colors.grey : Colors.redAccent,
                onTap: () => svc.send({'blackout': true}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionBtn(
                icon: Icons.power_settings_new,
                label: 'Aç',
                color: blackout ? Colors.greenAccent : Colors.grey,
                onTap: () => svc.send({'blackout': false}),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Özel Metin ─────────────────────────────────────────
        _SectionCard(
          title: 'Özel Metin Gönder',
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Tahtaya yazılacak metin...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: const Color(0xFF0D0D0D),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onPressed: () {
                if (_textCtrl.text.isNotEmpty) {
                  svc.send({'customText': _textCtrl.text.toUpperCase() + '  '});
                }
              },
              child: const Text('Gönder'),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Parlakık & Hız ─────────────────────────────────────
        _SectionCard(
          title: 'Parlaklik & Hiz',
          child: Column(children: [
            _SliderRow(
              icon: Icons.brightness_6,
              label: 'Parlaklık',
              value: brightness,
              min: 0, max: 255,
              color: Colors.amberAccent,
              onChanged: (v) => svc.send({'brightness': v.round()}),
            ),
            const SizedBox(height: 8),
            _SliderRow(
              icon: Icons.speed,
              label: 'Hız',
              value: speed,
              min: 5, max: 200,
              color: const Color(0xFF00E5FF),
              onChanged: (v) => svc.send({'speed': v.round()}),
              reversed: true, // küçük değer = hızlı
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Renk ───────────────────────────────────────────────
        _SectionCard(
          title: 'Yazı Rengi',
          child: Column(children: [
            _SliderRow(
              icon: Icons.palette,
              label: 'Ton (Hue)',
              value: hue.toDouble(),
              min: 0, max: 255,
              color: HSVColor.fromAHSV(1, hue.toDouble() / 255 * 360, 1, 1).toColor(),
              onChanged: (v) => svc.send({'hue': v.round()}),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.color_lens, size: 16),
              label: const Text('Renk Seçici'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A2E),
                foregroundColor: Colors.white,
              ),
              onPressed: () => _showColorPicker(context, svc, hue),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Metin Listesi ──────────────────────────────────────
        _SectionCard(
          title: 'Hazır Metin Listesi',
          child: Column(children: [
            Row(children: [
              Expanded(
                child: DropdownButton<int>(
                  value: activeIdx,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A2E),
                  items: List.generate(14, (i) => DropdownMenuItem(
                    value: i,
                    child: Text(
                      ['TOPRAKSIZ MARKET','HİDROPONİK SET','TOPRAKSIZ TARIM',
                       'BESİN ÇÖZÜMÜ','HOBİ SETLERİ','DİKEY KULE',
                       'BALKONDA ÜRET','MUTFAKTA TÜKET','SERA KURULUMU',
                       'YILIN 365 GÜNÜ HASAT','MAX VERİM MİN ALAN',
                       'A VE B BESİNLERİ','TOHUM FİDE','%90 AZ SU'][i],
                      style: const TextStyle(fontSize: 13),
                    ),
                  )),
                  onChanged: (i) { if (i != null) svc.send({'activeIndex': i}); },
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _ActionBtn(
                icon: Icons.playlist_play,
                label: playlist ? 'Playlist: AÇIK' : 'Playlist: KAPALI',
                color: playlist ? Colors.greenAccent : Colors.grey,
                onTap: () => svc.send({'playlist': !playlist}),
              )),
            ]),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Arkaplan & Yön ─────────────────────────────────────
        Row(children: [
          Expanded(
            child: _SectionCard(
              title: 'Arkaplan',
              child: Column(
                children: List.generate(4, (i) => RadioListTile<int>(
                  title: Text(_bgModes[i], style: const TextStyle(fontSize: 13)),
                  value: i, groupValue: bgMode,
                  dense: true,
                  activeColor: const Color(0xFF00E5FF),
                  onChanged: (v) { if (v != null) svc.send({'bgMode': v}); },
                )),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SectionCard(
              title: 'Yön',
              child: Column(
                children: List.generate(3, (i) => RadioListTile<int>(
                  title: Text(_orientModes[i], style: const TextStyle(fontSize: 13)),
                  value: i, groupValue: orient,
                  dense: true,
                  activeColor: const Color(0xFF00E5FF),
                  onChanged: (v) { if (v != null) svc.send({'orient': v}); },
                )),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Yazı Boyutu ────────────────────────────────────────
        _SectionCard(
          title: 'Yazı Boyutu',
          child: Row(children: [
            Expanded(child: _ActionBtn(
              icon: Icons.text_fields,
              label: '1x (Normal)',
              color: textSz == 1 ? const Color(0xFF00E5FF) : Colors.grey,
              onTap: () => svc.send({'textSize': 1}),
            )),
            const SizedBox(width: 12),
            Expanded(child: _ActionBtn(
              icon: Icons.format_size,
              label: '2x (Büyük)',
              color: textSz == 2 ? const Color(0xFF00E5FF) : Colors.grey,
              onTap: () => svc.send({'textSize': 2}),
            )),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Yön Tuşları ────────────────────────────────────────
        _SectionCard(
          title: 'Kaydırma Yönü',
          child: Row(children: [
            Expanded(child: _ActionBtn(
              icon: Icons.arrow_back,
              label: '← Sola',
              color: const Color(0xFF00E5FF),
              onTap: () => svc.send({'dirLR': -1}),
            )),
            const SizedBox(width: 12),
            Expanded(child: _ActionBtn(
              icon: Icons.arrow_forward,
              label: 'Sağa →',
              color: const Color(0xFF00E5FF),
              onTap: () => svc.send({'dirLR': 1}),
            )),
          ]),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  void _showColorPicker(BuildContext ctx, BoardService svc, int hue) {
    Color current = HSVColor.fromAHSV(1, hue / 255 * 360, 1, 1).toColor();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Renk Seç'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (c) {
              int newHue = (HSVColor.fromColor(c).hue / 360 * 255).round();
              svc.send({'hue': newHue});
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(_), child: const Text('Kapat'))],
      ),
    );
  }
}

// ── Yardımcı Widget'lar ────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(
          color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value, min, max;
  final Color color;
  final ValueChanged<double> onChanged;
  final bool reversed;
  const _SliderRow({
    required this.icon, required this.label, required this.value,
    required this.min, required this.max, required this.color,
    required this.onChanged, this.reversed = false,
  });
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12))),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
          ),
          child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ),
      ),
      SizedBox(
        width: 32,
        child: Text(reversed ? (max - value + min).round().toString() : value.round().toString(),
          style: const TextStyle(fontSize: 12), textAlign: TextAlign.right),
      ),
    ]);
  }
}
