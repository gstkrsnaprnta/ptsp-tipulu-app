import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // <-- 1. TAMBAHKAN IMPORT INI
import 'package:flutter/material.dart';
import 'package:ptsp_tipulu_app/firebase_options.dart';
import 'package:ptsp_tipulu_app/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('✅ Izin notifikasi diberikan oleh pengguna.');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('🔔 Izin notifikasi provisional diberikan oleh pengguna.');
  } else {
    print('❌ Pengguna menolak izin notifikasi.');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PTSP Tipulu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}