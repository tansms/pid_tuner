import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(PIDTunerApp());
}

class PIDTunerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PID调参助手',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}