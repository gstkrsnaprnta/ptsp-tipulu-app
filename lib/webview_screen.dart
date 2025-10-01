import 'dart:convert';

import 'package:dio/dio.dart'; // Untuk download file
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart'; // Untuk path direktori
import 'package:share_plus/share_plus.dart'; // Untuk share/print
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isDownloading = false; // State untuk melacak status download

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.parse(request.url);

            // 2. Handle link WhatsApp (tidak berubah)
            if (uri.host == 'wa.me' || uri.host == 'api.whatsapp.com') {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }

            // 3. Handle link untuk CETAK atau LIHAT DOKUMEN (logika baru)
            if (request.url.contains('/list-pengajuan/cetak/') ||
                request.url.contains('/list-pengajuan/stream')) {
              print('Mencegat link file, akan diunduh: ${request.url}');
              _downloadAndOpenFile(request.url); // Panggil fungsi download
              return NavigationDecision.prevent; // Hentikan navigasi WebView
            }

            // Izinkan semua navigasi lainnya
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'flutterApp',
        onMessageReceived: (JavaScriptMessage message) {
          print("Login berhasil! Menerima User ID dari web: ${message.message}");
          String adminUserId = message.message;
          _registerDeviceToServer(adminUserId);
        },
      )
      ..loadRequest(Uri.parse('http://10.17.107.210:8000/login'));
  }

  // 4. FUNGSI BARU untuk download dan buka file
  Future<void> _downloadAndOpenFile(String url) async {
    setState(() {
      _isDownloading = true; // Tampilkan loading
    });

    try {
      final dir = await getTemporaryDirectory();
      // Buat nama file yang unik atau ambil dari header server jika memungkinkan
      final fileName = 'dokumen_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final savePath = "${dir.path}/$fileName";

      print("Mengunduh file dari: $url");
      await Dio().download(url, savePath);
      print("File berhasil disimpan di: $savePath");

      // Gunakan share_plus untuk membuka share sheet native
      // Dari sini, admin bisa memilih "Print", "Save to Drive", dll.
      final xfile = XFile(savePath);
      await Share.shareXFiles([xfile], text: 'Dokumen surat dari aplikasi PTSP.');

    } catch (e) {
      print("❌ Error saat mengunduh atau membuka file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memproses dokumen.')),
      );
    } finally {
      setState(() {
        _isDownloading = false; // Sembunyikan loading
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return false;
        } else {
          return true;
        }
      },
      child: Scaffold(
        body: SafeArea(
          // 5. Gunakan Stack untuk menumpuk loading indicator di atas WebView
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),

              // Tampilkan overlay loading saat proses download
              if (_isDownloading)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 20),
                        Text(
                          'Memproses dokumen...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  

  Future<void> _registerDeviceToServer(String userId) async {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    
    if (fcmToken == null) {
      print("❌ Gagal mendapatkan FCM Token.");
      return;
    }

    print("📤 Mengirim User ID ($userId) dan FCM Token ($fcmToken) ke server...");

    try {
      final response = await http.post(
        Uri.parse('http://10.17.107.210:8000/api/fcm/save-token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'user_id': int.parse(userId),
          'fcm_token': fcmToken,
        }),
      );

      print("📥 Response status: ${response.statusCode}");
      print("📥 Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print("✅ Token berhasil didaftarkan di server.");
        } else {
          print("❌ Token gagal didaftarkan: ${data['message']}");
        }
      } else {
        print("❌ Gagal mendaftarkan token. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Terjadi error saat mengirim token ke server: $e");
    }
  }
}