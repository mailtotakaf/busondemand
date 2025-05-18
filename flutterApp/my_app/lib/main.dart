import 'package:flutter/material.dart';
import 'screens/request_screen.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GSI Map + ORS + Nominatim',
      home: RequestScreen(),
    );
  }
}