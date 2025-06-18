import 'package:barbar/screens/email_login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BarberClientApp());
}

class BarberClientApp extends StatelessWidget {
  const BarberClientApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Réservation Barbier',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: EmailLoginScreen(),
    );
  }
}
