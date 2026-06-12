import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/board_service.dart';

class EffectsScreen extends StatelessWidget {
  const EffectsScreen({super.key});

  static const _textAnims = [
    {'id':0,'name':'Normal Kayış','icon':Icons.text_fields,'color':0xFF00E5FF},
    {'id':1,'name':'Yanıp Sönen','icon':Icons.flash_on,'color':0xFFFFEB3B},
    {'id':2,'name':'Renk Dalgası','icon':Icons.waves,'color':0xFF2196F3},
    {'id':3,'name':'Gökkuşağı','icon':Icons.colorize,'color':0xFFE91E63},
    {'id':4,'name':'Parlaklık Nabzı','icon':Icons.brightness_auto,'color':0xFFFF9800},
    {'id':5,'name':'Yazılıyor...','icon':Icons.keyboard,'color':0xFF4CAF50},
  ];

  static const _borderAnims = [
    {'id':0,'name':'Yok','icon':Icons.border_clear,'color':0xFF444444},
    {'id':1,'name':'Tek Renk','icon':Icons.border_all,'color':0xFF00E5FF},
    {'id':2,'name':'Dönen Nokta','icon':Icons.rotate_right,'color':0xFFFFEB3B},
    {'id':3,'name':'Gökkuşağı','icon':Icons.palette,'color':0xFFE91E63},
    {'id':4,'name':'Nabız','icon':Icons.favorite,'color':0xFFFF5722},
    {'id':5,'name':'Yılan','icon':Icons.gesture,'color':0xFF4CAF50},
    {'id':6,'name':'Kıvılcım','icon':Icons.auto_awesome,'color':0xFFFFD700},
    {'id':7,'name':'Gradyan','icon':Icons.gradient,'color':0xFF9C27B0},
  ];

  static const _bgFills = [
    {'id':0,'name':'Yok','icon':Icons.block,'color':0xFF444444},
    {'id':1,'name':'Tek Renk','icon':Icons.square,'color':0xFF00E5FF},
    {'id':2,'name':'Gökkuşağı','icon':Icons.view_column,'color':0xFFE91E63},
    {'id':3,'name':'Twinkle','icon':Icons.star,'color':0xFFFFEB3B},
    {'id':4,'name':'Matrix','icon':Icons.code,'color':0xFF00FF41},
    {'id':5,'name':'Ateş','icon':Icons.local_fire_department,'color':0xFFFF5722},
    {'id':6,'name':'Dalga','icon':Icons.water,'color':0xFF2196F3},
    {'id':7,'name':'Yıldızlar','icon':Icons.nights_stay,'color':0xFF9C27B0},
  ];

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();
    final s = svc.boardStatus;
    final curTA = (s['textAnim'] ?? 0) as int;
    final curBA = (s['borderAnim'] ?? 0) as int;
    final curBG = (s['bgFill'] ?? 0) as int;
    final borderHue = ((s['borderHue'] ?? 0) as num).toDouble();
    final borderWidth = ((s['borderWidth'] ?? 1) as num).toInt();

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Yazı Animasyonu
      _sectionTitle('✍️ Yazı Animasyonu'),
      const SizedBox(height: 8),
      _grid(_textAnims, curTA, (id) => svc.send({'textAnim': id})),
      const SizedBox(height: 16),

      // Çerçeve
      _sectionTitle('🖼️ Çerçeve Animasyonu'),
      const SizedBox(height: 8),
      _grid(_borderAnims, curBA, (id) => svc.send({'borderAnim': id})),
      const SizedBox(height: 12),
      if (curBA > 0) ...[
        _Card(title: 'Çerçeve Rengi & Kalınlığı', child: Column(children: [
          Row(children: [
            const Icon(Icons.palette, color: Color(0xFF00E5FF), size: 18),
            const SizedBox(width: 8),
            const SizedBox(width: 50, child: Text('Renk', style: TextStyle(fontSize: 12))),
            Expanded(child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: HSVColor.fromAHSV(1, borderHue/255*360, 1, 1).toColor(),
                thumbColor: HSVColor.fromAHSV(1, borderHue/255*360, 1, 1).toColor(),
              ),
              child: Slider(value: borderHue, min: 0, max: 255,
                onChanged: (v) => svc.send({'borderHue': v.round()})),
            )),
          ]),
          Row(children: [
            const Icon(Icons.border_all, color: Color(0xFF00E5FF), size: 18),
            const SizedBox(width: 8),
            const SizedBox(width: 50, child: Text('Kalınlık', style: TextStyle(fontSize: 12))),
            Expanded(child: SliderTheme(
              data: SliderTheme.of(context).copyWith(activeTrackColor: Colors.purple, thumbColor: Colors.purple),
              child: Slider(value: borderWidth.toDouble(), min: 0, max: 4, divisions: 4,
                onChanged: (v) => svc.send({'borderWidth': v.round()})),
            )),
            Text('$borderWidth px', style: const TextStyle(fontSize: 12)),
          ]),
        ])),
        const SizedBox(height: 16),
      ],

      // Arkaplan
      _sectionTitle('🌈 Arkaplan'),
      const SizedBox(height: 8),
      _grid(_bgFills, curBG, (id) => svc.send({'bgFill': id})),
      const SizedBox(height: 80),
    ]);
  }

  Widget _sectionTitle(String t) => Text(t,
    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 14, fontWeight: FontWeight.bold));

  Widget _grid(List<Map<String,dynamic>> items, int cur, Function(int) onTap) {
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, childAspectRatio: 0.85, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final isActive = cur == item['id'];
        final color = Color(item['color'] as int);
        return GestureDetector(
          onTap: () => onTap(item['id'] as int),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.2) : const Color(0xFF12121F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isActive ? color : Colors.transparent, width: 2),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(item['icon'] as IconData, color: isActive ? color : Colors.grey, size: 26),
              const SizedBox(height: 4),
              Text(item['name'] as String,
                style: TextStyle(fontSize: 9, color: isActive ? color : Colors.grey),
                textAlign: TextAlign.center, maxLines: 2),
            ]),
          ),
        );
      },
    );
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
      Text(title, style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10), child,
    ]),
  );
}
