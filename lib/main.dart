import 'package:MEAMBO/firebase_options.dart';
import 'package:MEAMBO/notification_service.dart';
import 'package:MEAMBO/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';


// Buat instance service agar bisa diakses dari mana saja (jika perlu)
final notificationService = NotificationService();

// Fungsi ini harus berada di luar class (top-level) untuk menangani notifikasi di background
// Anotasi @pragma('vm:entry-point') penting agar kode ini tidak dihapus saat kompilasi rilis
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Jika Anda menggunakan package lain di sini, pastikan untuk menginisialisasinya
  // seperti Firebase.initializeApp()
  print("🔔 Menangani notifikasi di background: ${message.messageId}");
}


void main() async {
  // Pastikan semua binding Flutter siap sebelum menjalankan kode async
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Atur handler untuk notifikasi background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Inisialisasi dan jalankan semua layanan notifikasi
  await notificationService.init();       // Inisialisasi plugin notifikasi lokal
  notificationService.listenToForegroundMessages(); // Mulai mendengarkan pesan di foreground

  // Minta izin notifikasi kepada pengguna (wajib untuk iOS & Android 13+)
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('✅ Izin notifikasi diberikan oleh pengguna.');
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