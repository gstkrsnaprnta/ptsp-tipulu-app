import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  // Buat instance dari plugin
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Fungsi untuk inisialisasi semua yang dibutuhkan
  Future<void> init() async {
    // Pengaturan inisialisasi untuk Android
    // Menggunakan ikon launcher default dari folder mipmap
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); 

    // Pengaturan inisialisasi untuk iOS (gunakan Darwin... untuk versi 17+)
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    // Gabungkan pengaturan
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // Inisialisasi plugin
    await _localNotificationsPlugin.initialize(initializationSettings);

    // Buat Channel Notifikasi untuk Android (wajib untuk Android 8.0+)
    await _createNotificationChannel();
  }

  // Fungsi internal untuk membuat channel notifikasi
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // ID unik channel
      'Notifikasi Penting',      // Nama channel yang terlihat oleh pengguna
      description: 'Channel ini digunakan untuk notifikasi penting dari aplikasi.',
      importance: Importance.max, // Atur ke 'max' agar muncul sebagai pop-up (heads-up)
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Menampilkan notifikasi dari pesan FCM yang masuk saat app di foreground
  void showNotificationFromFcm(RemoteMessage message) {
    // Ambil judul dan isi dari payload 'data' yang dikirim server
    final String? title = message.data['title'];
    final String? body = message.data['body'];

    if (title != null && body != null) {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel', // ID channel harus sama dengan yang dibuat
        'Notifikasi Penting',
        channelDescription: 'Channel ini digunakan untuk notifikasi penting dari aplikasi.',
        importance: Importance.max,
        priority: Priority.high,
      );
      const NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      _localNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.toSigned(31), // ID notifikasi harus unik
        title,
        body,
        notificationDetails,
      );
    }
  }

  /// Mulai mendengarkan pesan FCM yang masuk saat aplikasi di foreground
  void listenToForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Pesan FCM diterima saat aplikasi di FOREGROUND!');
      print('Data Pesan: ${message.data}');

      // Panggil fungsi untuk menampilkannya secara manual
      showNotificationFromFcm(message);
    });
  }
}

