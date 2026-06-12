import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/board_service.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ChangeNotifierProvider(
    create: (_) => BoardService(),
    child: const TabelaApp(),
  ));
}

class TabelaApp extends StatelessWidget {
  const TabelaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akıllı Tabela',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00E5FF), brightness: Brightness.dark),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        cardColor: const Color(0xFF12121F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0A0F),
          foregroundColor: Color(0xFF00E5FF),
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
