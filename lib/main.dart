import 'package:flutter/material.dart';
import 'widgets/realtime_data_display.dart';

void main() {
  runApp(const SubmersibleJetskiApp());
}

class SubmersibleJetskiApp extends StatelessWidget {
  const SubmersibleJetskiApp({super.key});

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
      ),
      home: const RealtimeDataDisplay(),
      debugShowCheckedModeBanner: false,
    );
  }
}
