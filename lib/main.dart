import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:ptsp_tipulu_ap/features/splash/screens/splash_screen.dart';
import 'package:ptsp_tipulu_ap/firebase_options.dart';
import 'package:ptsp_tipulu_ap/notification_service.dart';


/// Instance global untuk notification service (Singleton pattern).
final notificationService = NotificationService();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔔 Menangani notifikasi di background: ${message.messageId}");
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Mendaftarkan handler untuk pesan di background.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Inisialisasi notifikasi lokal dan mulai mendengarkan pesan di foreground.
  await notificationService.init();
  notificationService.listenToForegroundMessages();

  // Meminta izin notifikasi dari pengguna (wajib untuk iOS & Android 13+).
  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  final NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('✅ Izin notifikasi diberikan.');
  } else {
    print('❌ Izin notifikasi ditolak.');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}