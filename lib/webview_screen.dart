import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:ptsp_tipulu_app/pdf_viewer_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isProcessingFile = false; // Ganti nama agar lebih umum

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      // ===================================================================
      // ▼▼▼ NAVIGATION DELEGATE DIKEMBALIKAN UNTUK HANDLE LINK BIASA ▼▼▼
      // ===================================================================
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            print(">>> Navigasi Link Dicegat: ${request.url}");
            final uri = Uri.parse(request.url);

            // Handle link WhatsApp
            if (uri.host == 'wa.me' || uri.host == 'api.whatsapp.com') {
              print(">>> AKSI: Buka WhatsApp");
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }

            // Handle link "Lihat Dokumen" (GET request)
            if (request.url.contains('/list-pengajuan/stream')) {
              print(">>> AKSI: Proses Lihat Dokumen (GET)");
              // Panggil fungsi download dengan data form null
              _downloadAndProcessFile(request.url, null);
              return NavigationDecision.prevent;
            }

            print(">>> AKSI: Izinkan navigasi normal");
            return NavigationDecision.navigate;
          },
        ),
      )
      // ===================================================================
      // ▲▲▲ PERUBAHAN SELESAI ▲▲▲
      // ===================================================================
      ..addJavaScriptChannel(
        'flutterApp', // Channel untuk Login
        onMessageReceived: (JavaScriptMessage message) {
          // ... (logika login tidak berubah)
        },
      )
      ..addJavaScriptChannel(
        'flutterCetak', // Channel untuk Cetak (POST request)
        onMessageReceived: (JavaScriptMessage message) {
          print("📄 Menerima request cetak dari web: ${message.message}");
          try {
            final data = json.decode(message.message);
            if (data['type'] == 'cetakSurat') {
              final String url = data['url'];
              final Map<String, dynamic> formData = Map<String, dynamic>.from(data['formData']);
              _downloadAndProcessFile(url, formData);
            }
          } catch (e) {
            print("❌ Error parsing data cetak: $e");
          }
        },
      )
      ..loadRequest(Uri.parse('http://10.182.81.210:8000/login'));
  }

  // Fungsi ini sekarang lebih generik untuk menangani GET dan POST
  Future<void> _downloadAndProcessFile(String url, Map<String, dynamic>? formData) async {
    if (!mounted) return;
    setState(() { _isProcessingFile = true; });

    try {
      print("📤 Memproses file dari URL: $url");
      Response response;

      // Cerdas memilih metode request
      if (formData != null) {
        print("📦 Metode: POST dengan data: $formData");
        response = await Dio().post(
          url,
          data: formData,
          options: Options(
            responseType: ResponseType.bytes,
            contentType: Headers.formUrlEncodedContentType,
          ),
        );
      } else {
        print("📦 Metode: GET");
        response = await Dio().get(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
      }
      
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final fileName = 'dokumen_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final savePath = "${dir.path}/$fileName";
        
        final file = File(savePath);
        await file.writeAsBytes(response.data);
        print("✅ File berhasil disimpan: $savePath");
        
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              pdfUrl: savePath,       // PERBAIKAN: Menggunakan 'pdfUrl'
              title: 'Pratinjau Dokumen',
              isLocalFile: true,    // PERBAIKAN: Menambahkan 'isLocalFile'
            ),
          ),
        );
      } else {
        throw Exception('Status code: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Error saat memproses file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat dokumen.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isProcessingFile = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isProcessingFile)
                Container(
                  color: Colors.black.withOpacity(0.6),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 20),
                        Text('Memproses dokumen...', style: TextStyle(color: Colors.white)),
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

    print("📤 Mengirim User ID ($userId) dan FCM Token ke server...");

    try {
      final response = await http.post(
        Uri.parse('http://10.17.107.210:8000/api/fcm/save-token'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'user_id': int.parse(userId), // ✅ Parse ke integer
          'fcm_token': fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print("✅ Token berhasil didaftarkan di server.");
        }
      }
    } catch (e) {
      print("❌ Error mengirim token: $e");
    }
  }
}