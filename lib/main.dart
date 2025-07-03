import 'package:flutter/material.dart';
import 'views/navigation/main_navigation.dart';

void main() {
  runApp(const SubmersibleJetskiApp());
}

class SubmersibleJetskiApp extends StatelessWidget {
  const SubmersibleJetskiApp({super.key, this.autoStartMonitor = true});

  final bool autoStartMonitor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Submersible Jetski Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontWeight: FontWeight.w300),
          bodyMedium: TextStyle(fontWeight: FontWeight.w300),
          bodySmall: TextStyle(fontWeight: FontWeight.w300),
        ),
      ),
      home: MainNavigation(autoStartMonitor: autoStartMonitor),
      debugShowCheckedModeBanner: false,
    );
  }
}
