// lib/screens/draw_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/board_service.dart';

class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key});
  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  static const int cols = 30;
  static const int rows = 20;

  // Piksel tamponu (yerel önizleme)
  final List<List<Color>> _pixels =
    List.generate(rows, (_) => List.filled(cols, Colors.black));

  Color _penColor = Colors.cyan;
  double _penSize = 1;
  bool _eraser   = false;

  // Toplu gönderim için kuyruk
  final List<Map<String, dynamic>> _sendQueue = [];
  Timer? _flushTimer;

  @override
  void dispose() { _flushTimer?.cancel(); super.dispose(); }

  void _setPixel(int x, int y) {
    if (x < 0 || x >= cols || y < 0 || y >= rows) return;
    Color c = _eraser ? Colors.black : _penColor;
    if (_pixels[y][x] == c) return;
    setState(() => _pixels[y][x] = c);
    _sendQueue.add({
      'px': x, 'py': y,
      'pr': _eraser ? 0 : c.red,
      'pg': _eraser ? 0 : c.green,
      'pb': _eraser ? 0 : c.blue,
    });
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 50), _flush);
  }

  void _flush() {
    if (_sendQueue.isEmpty) return;
    final svc = context.read<BoardService>();
    // Efekt moduna al
    svc.send({'extraEffect': 7});
    // Toplu piksel gönder (her 10 pikseli tek JSON'da)
    for (int i = 0; i < _sendQueue.length; i++) {
      svc.send(_sendQueue[i]);
    }
    _sendQueue.clear();
  }

  void _onPanUpdate(DragUpdateDetails d, BoxConstraints box) {
    double cellW = box.maxWidth / cols;
    double cellH = box.maxHeight / rows;
    int x = (d.localPosition.dx / cellW).floor();
    int y = (d.localPosition.dy / cellH).floor();
    int r = _penSize.round();
    for (int dy = -r + 1; dy < r; dy++)
      for (int dx = -r + 1; dx < r; dx++)
        _setPixel(x + dx, y + dy);
  }

  void _clearAll() {
    setState(() {
      for (int y = 0; y < rows; y++)
        for (int x = 0; x < cols; x++)
          _pixels[y][x] = Colors.black;
    });
    context.read<BoardService>().send({'clearDraw': true, 'extraEffect': 7});
  }

  // Hazır şekil çiziciler
  void _drawShape(String shape) {
    setState(() {
      for (int y = 0; y < rows; y++)
        for (int x = 0; x < cols; x++)
          _pixels[y][x] = Colors.black;
    });
    if (shape == 'heart') _drawHeart();
    if (shape == 'smiley') _drawSmiley();
    if (shape == 'star') _drawStar();
    if (shape == 'border') _drawBorder();
    // Tümünü gönder
    final svc = context.read<BoardService>();
    svc.send({'clearDraw': true, 'extraEffect': 7});
    for (int y = 0; y < rows; y++)
      for (int x = 0; x < cols; x++) {
        Color c = _pixels[y][x];
        if (c != Colors.black)
          svc.send({'px': x, 'py': y, 'pr': c.red, 'pg': c.green, 'pb': c.blue});
      }
  }

  void _drawHeart() {
    List<List<int>> pts = [
      [3,2],[4,2],[5,2],[6,2],[7,2],[3,2],
      [2,3],[3,3],[4,3],[5,3],[6,3],[7,3],[8,3],
      [2,4],[3,4],[4,4],[5,4],[6,4],[7,4],[8,4],
      [3,5],[4,5],[5,5],[6,5],[7,5],
      [4,6],[5,6],[6,6],
      [5,7],
    ];
    // Offset to center in 30-wide matrix
    for (var p in pts) {
      int x = p[0] + 10, y = p[1] + 6;
      if (x < cols && y < rows) _pixels[y][x] = Colors.redAccent;
    }
  }

  void _drawSmiley() {
    // Simple smiley
    _pixels[4][12] = _pixels[4][17] = Colors.yellow; // eyes
    _pixels[5][12] = _pixels[5][17] = Colors.yellow;
    for (int x = 11; x <= 18; x++) _pixels[8][x] = Colors.yellow; // mouth
    _pixels[7][10] = _pixels[7][19] = Colors.yellow;
    // Face outline
    for (int y = 2; y <= 10; y++) {
      _pixels[y][8]  = Colors.yellow;
      _pixels[y][21] = Colors.yellow;
    }
    for (int x = 9; x <= 20; x++) {
      _pixels[2][x] = Colors.yellow;
      _pixels[10][x] = Colors.yellow;
    }
  }

  double _cos(int deg) => [1,0.866,0.5,0,-0.5,-0.866,-1,-0.866,-0.5,0,0.5,0.866][deg~/30 % 12].toDouble();

  void _drawStar() {
    // 5-pointed star approximation
    List<List<int>> pts = [
      [14,2],[13,5],[10,5],[12,7],[11,10],[14,8],[17,10],[16,7],[18,5],[15,5],
    ];
    for (int i = 0; i < pts.length; i++) {
      int x1 = pts[i][0], y1 = pts[i][1];
      int x2 = pts[(i+1)%pts.length][0], y2 = pts[(i+1)%pts.length][1];
      _line(x1, y1, x2, y2, Colors.yellowAccent);
    }
  }

  void _drawBorder() {
    for (int x = 0; x < cols; x++) {
      _pixels[0][x] = _penColor;
      _pixels[rows-1][x] = _penColor;
    }
    for (int y = 0; y < rows; y++) {
      _pixels[y][0] = _penColor;
      _pixels[y][cols-1] = _penColor;
    }
  }

  void _line(int x0, int y0, int x1, int y1, Color c) {
    int dx = (x1 - x0).abs(), dy = -(y1 - y0).abs();
    int sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, err = dx + dy;
    while (true) {
      if (x0 >= 0 && x0 < cols && y0 >= 0 && y0 < rows) _pixels[y0][x0] = c;
      if (x0 == x1 && y0 == y1) break;
      int e2 = 2 * err;
      if (e2 >= dy) { err += dy; x0 += sx; }
      if (e2 <= dx) { err += dx; y0 += sy; }
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<BoardService>();
    return Column(children: [
      // Araç çubuğu
      Container(
        color: const Color(0xFF1A1A2E),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          // Hazır şekiller
          _ShapeBtn(icon: Icons.favorite, label: 'Kalp', onTap: () => _drawShape('heart')),
          _ShapeBtn(icon: Icons.tag_faces, label: 'Smiley', onTap: () => _drawShape('smiley')),
          _ShapeBtn(icon: Icons.star, label: 'Yıldız', onTap: () => _drawShape('star')),
          _ShapeBtn(icon: Icons.border_outer, label: 'Çerçeve', onTap: () => _drawShape('border')),
          const Spacer(),
          // Silgi
          IconButton(
            icon: Icon(Icons.auto_fix_normal, color: _eraser ? Colors.amberAccent : Colors.grey),
            tooltip: 'Silgi',
            onPressed: () => setState(() => _eraser = !_eraser),
          ),
          // Temizle
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Tümünü Temizle',
            onPressed: _clearAll,
          ),
        ]),
      ),
      // Renk paleti
      Container(
        height: 44,
        color: const Color(0xFF0D0D0D),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Colors.red, Colors.orange, Colors.yellow, Colors.greenAccent,
            Colors.cyan, Colors.blue, Colors.purple, Colors.pink,
            Colors.white, Colors.grey,
          ].map((c) => GestureDetector(
            onTap: () => setState(() { _penColor = c; _eraser = false; }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _penColor == c ? 34 : 28,
              height: _penColor == c ? 34 : 28,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _penColor == c ? Colors.white : Colors.transparent, width: 2),
              ),
            ),
          )).toList(),
        ),
      ),
      // Fırça boyutu
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          const Icon(Icons.brush, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Slider(
            value: _penSize, min: 1, max: 3, divisions: 2,
            activeColor: _penColor,
            onChanged: (v) => setState(() => _penSize = v),
          )),
          Text('${_penSize.round()}px', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
      // Çizim tuvali
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AspectRatio(
            aspectRatio: cols / rows,
            child: LayoutBuilder(builder: (ctx, box) {
              return GestureDetector(
                onPanUpdate: (d) => _onPanUpdate(d, box),
                onTapDown: (d) {
                  double cW = box.maxWidth / cols, cH = box.maxHeight / rows;
                  int x = (d.localPosition.dx / cW).floor();
                  int y = (d.localPosition.dy / cH).floor();
                  _setPixel(x, y);
                },
                child: CustomPaint(
                  painter: _GridPainter(_pixels, cols, rows),
                  size: Size(box.maxWidth, box.maxHeight),
                ),
              );
            }),
          ),
        ),
      ),
      // Gönder butonu
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Tahtaya Gönder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final svc2 = context.read<BoardService>();
              svc2.send({'clearDraw': true, 'extraEffect': 7});
              for (int y = 0; y < rows; y++)
                for (int x = 0; x < cols; x++) {
                  Color c = _pixels[y][x];
                  if (c != Colors.black)
                    svc2.send({'px': x, 'py': y, 'pr': c.red, 'pg': c.green, 'pb': c.blue});
                }
            },
          ),
        ),
      ),
    ]);
  }
}

class _GridPainter extends CustomPainter {
  final List<List<Color>> pixels;
  final int cols, rows;
  _GridPainter(this.pixels, this.cols, this.rows);

  @override
  void paint(Canvas canvas, Size size) {
    double cW = size.width  / cols;
    double cH = size.height / rows;
    final gridPaint = Paint()..color = const Color(0xFF2A2A3E)..strokeWidth = 0.5..style = PaintingStyle.stroke;
    final bgPaint   = Paint()..color = const Color(0xFF0A0A1A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        Color c = pixels[y][x];
        if (c != Colors.black) {
          final paint = Paint()..color = c;
          canvas.drawRect(Rect.fromLTWH(x * cW + 0.5, y * cH + 0.5, cW - 1, cH - 1), paint);
        }
      }
    }
    // Grid çizgileri
    for (int x = 0; x <= cols; x++)
      canvas.drawLine(Offset(x * cW, 0), Offset(x * cW, size.height), gridPaint);
    for (int y = 0; y <= rows; y++)
      canvas.drawLine(Offset(0, y * cH), Offset(size.width, y * cH), gridPaint);
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}

class _ShapeBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ShapeBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(children: [
        Icon(icon, size: 20, color: const Color(0xFF00E5FF)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ]),
    ),
  );
}
