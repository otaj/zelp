import 'package:flutter/material.dart';

import 'screens/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZelpApp());
}

class ZelpApp extends StatelessWidget {
  const ZelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zelp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B6B4A),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(filled: true),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B6B4A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(filled: true),
      ),
      home: const MainShell(),
    );
  }
}
