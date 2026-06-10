// lib/screens/effects_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/board_service.dart';

class EffectsScreen extends StatefulWidget {
  const EffectsScreen({super.key});
  @override
  State<EffectsScreen> createState() => _EffectsScreenState();
}

class _EffectsScreenState extends State<EffectsScreen> {
  final _cityCtrl   = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  TimeOfDay _onTime  = const TimeOfDay(hour: 8,  minute: 0);
  TimeOfDay _offTime = const TimeOfDay(hour: 22, minute: 0);

  static const _effects = [
    {'id': 0, 'name': 'Normal Kaydır', 'icon': Icons.text_fields,   'color': 0xFF00E5FF},
    {'id': 1, 'name': 'Matrix Yağmur', 'icon': Icons.code,           'color': 0xFF00FF41},
    {'id': 2, 'name': 'Ateş',          'icon': Icons.local_fire_department, 'color': 0xFFFF5722},
    {'id': 3, 'name': 'Dalga',         'icon': Icons.waves,          'color': 0xFF2196F3},
    {'id': 4, 'name': 'Konfeti',       'icon': Icons.celebration,    'color': 0xFFE040FB},
    {'id': 5, 'name': 'Saat (NTP)',    'icon': Icons.access_time,    'color': 0xFFFFEB3B},
    {'id': 6, 'name': 'Hava Durumu',   'icon': Icons.wb_sunny,       'color': 0xFFFF9800},
    {'id': 7, 'name': 'Çizim Modu',    'icon': Icons.draw,           'color': 0xFF4CAF50},
  ];

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();
    final s   = svc.boardStatus;
    int curEffect       = (s['extraEffect'] ?? 0) as int;
    bool weatherEnabled = s['weatherEnabled'] ?? false;
    bool clockEnabled   = s['clockEnabled']   ?? false;
    bool schedEnabled   = s['schedEnabled']   ?? false;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Efekt Seçimi ───────────────────────────────────────
        _header('Efekt Seç'),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, childAspectRatio: 0.8, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: _effects.length,
          itemBuilder: (_, i) {
            final e = _effects[i];
            final isActive = curEffect == e['id'];
            return GestureDetector(
              onTap: () => svc.send({'extraEffect': e['id']}),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isActive
                    ? Color(e['color'] as int).withOpacity(0.25)
                    : const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? Color(e['color'] as int) : Colors.transparent,
                    width: 2),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(e['icon'] as IconData,
                    color: isActive ? Color(e['color'] as int) : Colors.grey,
                    size: 28),
                  const SizedBox(height: 4),
                  Text(e['name'] as String,
                    style: TextStyle(
                      fontSize: 10, textBaseline: TextBaseline.alphabetic,
                      color: isActive ? Color(e['color'] as int) : Colors.grey),
                    textAlign: TextAlign.center, maxLines: 2),
                ]),
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        // ── Hava Durumu ────────────────────────────────────────
        _ExpandableCard(
          title: '🌤 Hava Durumu',
          subtitle: weatherEnabled ? (s['weather'] ?? 'Yükleniyor...').toString() : 'Kapalı',
          color: const Color(0xFFFF9800),
          isEnabled: weatherEnabled,
          onToggle: (v) => svc.send({'weatherEnabled': v}),
          child: Column(children: [
            TextField(
              controller: _cityCtrl,
              decoration: _inputDeco('Şehir', Icons.location_city),
              onChanged: (v) {},
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyCtrl,
              decoration: _inputDeco('OpenWeatherMap API Key', Icons.vpn_key),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Kaydet ve Uygula'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                svc.send({
                  'weatherCity': _cityCtrl.text.isNotEmpty ? _cityCtrl.text : 'Ankara',
                  'weatherApiKey': _apiKeyCtrl.text,
                  'weatherEnabled': true,
                  'extraEffect': 6,
                });
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Not: OpenWeatherMap.org adresinden ücretsiz API anahtarı alabilirsiniz.',
              style: TextStyle(color: Colors.grey, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Saat Gösterimi ─────────────────────────────────────
        _ExpandableCard(
          title: '🕐 Saat Gösterimi (NTP)',
          subtitle: clockEnabled ? 'Açık — WiFi gerektirir' : 'Kapalı',
          color: const Color(0xFFFFEB3B),
          isEnabled: clockEnabled,
          onToggle: (v) => svc.send({'clockEnabled': v, 'extraEffect': v ? 5 : 0}),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Tabta NTP ile senkronize edildikten sonra güncel saat gösterilebilir. WiFi bağlantısı gereklidir.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ),
        const SizedBox(height: 12),

        // ── Zamanlayıcı ────────────────────────────────────────
        _ExpandableCard(
          title: '⏰ Açma/Kapama Zamanlayıcı',
          subtitle: schedEnabled
            ? '${_fmt(_onTime)} – ${_fmt(_offTime)}'
            : 'Kapalı',
          color: const Color(0xFF4CAF50),
          isEnabled: schedEnabled,
          onToggle: (v) => svc.send({'schedEnable': v}),
          child: Column(children: [
            Row(children: [
              Expanded(child: _TimePicker(
                label: 'Açılış Saati',
                time: _onTime,
                color: Colors.greenAccent,
                onPick: (t) async {
                  final picked = await showTimePicker(context: context, initialTime: _onTime);
                  if (picked != null) {
                    setState(() => _onTime = picked);
                    svc.send({'schedOnHour': picked.hour, 'schedOnMin': picked.minute});
                  }
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: _TimePicker(
                label: 'Kapanış Saati',
                time: _offTime,
                color: Colors.redAccent,
                onPick: (t) async {
                  final picked = await showTimePicker(context: context, initialTime: _offTime);
                  if (picked != null) {
                    setState(() => _offTime = picked);
                    svc.send({'schedOffHour': picked.hour, 'schedOffMin': picked.minute});
                  }
                },
              )),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Tahta her 30 saniyede bir zamanı kontrol eder. WiFi + NTP gereklidir.',
              style: TextStyle(color: Colors.grey, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  Widget _header(String text) => Text(text,
    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1));

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: const Color(0xFF00E5FF), size: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    filled: true, fillColor: const Color(0xFF0D0D0D),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

class _ExpandableCard extends StatefulWidget {
  final String title, subtitle;
  final Color color;
  final bool isEnabled;
  final ValueChanged<bool> onToggle;
  final Widget child;
  const _ExpandableCard({
    required this.title, required this.subtitle, required this.color,
    required this.isEnabled, required this.onToggle, required this.child,
  });
  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}
class _ExpandableCardState extends State<_ExpandableCard> {
  bool _exp = false;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isEnabled ? widget.color.withOpacity(0.4) : Colors.transparent),
      ),
      child: Column(children: [
        ListTile(
          leading: Icon(Icons.circle, color: widget.isEnabled ? widget.color : Colors.grey, size: 12),
          title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(widget.subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Switch(
              value: widget.isEnabled,
              activeColor: widget.color,
              onChanged: widget.onToggle,
            ),
            IconButton(
              icon: Icon(_exp ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _exp = !_exp),
            ),
          ]),
        ),
        if (_exp) Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: widget.child,
        ),
      ]),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final Color color;
  final Function(TimeOfDay) onPick;
  const _TimePicker({required this.label, required this.time, required this.color, required this.onPick});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onPick(time),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            '${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }
}
