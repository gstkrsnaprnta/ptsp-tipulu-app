import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ptsp_tipulu_app/webview_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const  WebViewScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Atur warna latar belakang sesuai tema Anda
      backgroundColor: Colors.white,
      body: Center(
        // Tampilkan logo Anda di tengah layar
        child: Image.asset(
          'assets/images/logo.png', // Pastikan path logo ini benar
          width: 150, // Sesuaikan ukuran logo
        ),
      ),
    );
  }
}