// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/board_service.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => BoardService(),
      child: const AkilliTahtaApp(),
    ),
  );
}

class AkilliTahtaApp extends StatelessWidget {
  const AkilliTahtaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akıllı Tahta',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        cardColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D0D),
          foregroundColor: Color(0xFF00E5FF),
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
