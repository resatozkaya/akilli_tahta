import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/board_service.dart';

class TextScreen extends StatefulWidget {
  const TextScreen({super.key});
  @override
  State<TextScreen> createState() => _TextScreenState();
}

class _TextScreenState extends State<TextScreen> {
  final _ctrl = TextEditingController();
  int _editIdx = -1;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();
    final s = svc.boardStatus;
    final texts = svc.textList;
    final activeIdx = (s['activeIdx'] ?? 0) as int;

    return Column(children: [
      // Hızlı metin gönder
      Container(
        color: const Color(0xFF0D0D1A),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Tahtaya yazılacak metin...',
              filled: true, fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          )),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (_ctrl.text.isNotEmpty) {
                String txt = _ctrl.text.toUpperCase();
                if (!txt.endsWith(' ')) txt += ' ';
                if (_editIdx >= 0) {
                  svc.send({'setText': {'idx': _editIdx, 'text': txt}});
                  setState(() => _editIdx = -1);
                } else {
                  svc.send({'addText': txt});
                }
                _ctrl.clear();
              }
            },
            child: Text(_editIdx >= 0 ? 'Güncelle' : 'Ekle'),
          ),
        ]),
      ),

      // Metin listesi
      Expanded(
        child: texts.isEmpty
          ? const Center(child: Text('Metin listesi yükleniyor...', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: texts.length,
              itemBuilder: (_, i) {
                final isActive = i == activeIdx;
                return Card(
                  color: isActive ? const Color(0xFF0D2840) : const Color(0xFF12121F),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive ? const Color(0xFF00E5FF) : const Color(0xFF2A2A3E),
                      child: Text('${i+1}', style: TextStyle(color: isActive ? Colors.black : Colors.white, fontSize: 12)),
                    ),
                    title: Text(texts[i], style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () { setState(() { _editIdx = i; _ctrl.text = texts[i].trim(); }); },
                      ),
                      IconButton(
                        icon: Icon(Icons.play_arrow, color: isActive ? const Color(0xFF00E5FF) : Colors.grey, size: 20),
                        onPressed: () => svc.send({'activeIdx': i}),
                      ),
                    ]),
                    onTap: () => svc.send({'activeIdx': i}),
                  ),
                );
              }),
      ),
    ]);
  }
}
