import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';

class WristLinkApp extends StatelessWidget {
  const WristLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WristLink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006B5F),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
