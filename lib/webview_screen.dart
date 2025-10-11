// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';

// import 'package:dio/dio.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';
// import 'package:ptsp_tipulu_ap/pdf_viewer_screen.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// class WebViewScreen extends StatefulWidget {
//   const WebViewScreen({super.key});

//   @override
//   State<WebViewScreen> createState() => _WebViewScreenState();
// }

// class _WebViewScreenState extends State<WebViewScreen> {
//   late final WebViewController _controller;
//   bool _isProcessingFile = false;

//   final String baseUrl = "https://meambo.id";

//   @override
//   void initState() {
//     super.initState();

//     _controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setBackgroundColor(const Color(0x00000000))
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onNavigationRequest: (NavigationRequest request) {
//             final uri = Uri.parse(request.url);

//             // ✅ Buka WhatsApp di luar WebView
//             if (uri.host == 'wa.me' || uri.host == 'api.whatsapp.com') {
//               launchUrl(uri, mode: LaunchMode.externalApplication);
//               return NavigationDecision.prevent;
//             }

//             // ✅ Tangani dokumen lampiran (PDF)
//             if (request.url.contains('/list-pengajuan/stream')) {
//               final fullUrl = request.url.startsWith('http')
//                   ? request.url
//                   : '$baseUrl${request.url}';
//               print("🔗 Membuka dokumen lampiran: $fullUrl");
//               _downloadAndProcessFile(fullUrl, null);
//               return NavigationDecision.prevent;
//             }

//             return NavigationDecision.navigate;
//           },
//         ),
//       )
//       ..addJavaScriptChannel('flutterApp', onMessageReceived: _handleLoginMessage)
//       ..addJavaScriptChannel('flutterCetak', onMessageReceived: _handleCetakMessage)
//       ..addJavaScriptChannel('flutterPdfReceiver', onMessageReceived: _handlePdfData)
//       ..loadRequest(Uri.parse('$baseUrl/login'));
//   }

//   // 🔹 Pesan login dari web (untuk register FCM)
//   void _handleLoginMessage(JavaScriptMessage message) {
//     print("✅ Pesan login diterima: ${message.message}");
//     final userId = message.message.trim();
//     if (RegExp(r'^\d+$').hasMatch(userId)) {
//       _registerDeviceToServer(userId);
//     } else {
//       print("⚠️ Format user_id tidak valid: $userId");
//     }
//   }

//   // 🔹 Pesan cetak dari web
//   void _handleCetakMessage(JavaScriptMessage message) {
//     print("📄 Request cetak diterima: ${message.message}");
//     try {
//       final data = json.decode(message.message);
//       if (data['type'] == 'cetakSurat') {
//         final String url = data['url'];
//         final fullUrl = url.startsWith('http') ? url : '$baseUrl$url';
//         final Map<String, dynamic> formData =
//             Map<String, dynamic>.from(data['formData']);

//         print("📤 Mengirim request cetak ke: $fullUrl");
//         print("📋 Form data: $formData");

//         _downloadAndProcessFile(fullUrl, formData);
//       }
//     } catch (e) {
//       print("❌ Error parsing data cetak: $e");
//     }
//   }

//   // 🔹 Menerima data PDF base64 dari web
//   Future<void> _handlePdfData(JavaScriptMessage message) async {
//     if (!mounted || _isProcessingFile) return;
//     setState(() => _isProcessingFile = true);

//     try {
//       print("📄 Menerima data PDF Base64 dari web...");
//       final data = json.decode(message.message);
//       final String base64String = data['base64'];
//       final String fileName =
//           data['fileName'] ?? 'dokumen_${DateTime.now().millisecondsSinceEpoch}.pdf';

//       final Uint8List bytes = base64Decode(base64String);

//       final dir = await getTemporaryDirectory();
//       final savePath = "${dir.path}/$fileName";

//       final file = File(savePath);
//       await file.writeAsBytes(bytes);
//       print("✅ File dari Base64 berhasil disimpan: $savePath");

//       if (!mounted) return;

//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => PdfViewerScreen(
//             pdfUrl: savePath,
//             isLocalFile: true,
//             title: 'Pratinjau Dokumen',
//           ),
//         ),
//       );
//     } catch (e) {
//       print("❌ Error memproses data Base64: $e");
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Gagal memproses dokumen dari web.')),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isProcessingFile = false);
//     }
//   }

//   /// ✅ AMBIL COOKIE DARI WEBVIEW (TERMASUK HttpOnly)
//   Future<String> _getAllCookies() async {
//   try {
//     final result = await _controller.runJavaScriptReturningResult('document.cookie');
//     final rawCookies = result.toString();
//     print('--- 🍪 COOKIES DARI JAVASCRIPT ---');
//     print(rawCookies.isNotEmpty ? rawCookies : '⚠️ Tidak ada cookie ditemukan.');
//     return rawCookies;
//   } catch (e) {
//     print('❌ Gagal mengambil cookies via JS: $e');
//     return '';
//   }
// }


//   /// 🔹 Download atau stream file dari server Laravel
//   Future<void> _downloadAndProcessFile(String url, Map<String, dynamic>? formData) async {
//     if (!mounted || _isProcessingFile) return;
//     setState(() => _isProcessingFile = true);

//     try {
//       final cookies = await _getAllCookies();
//       if (cookies.isEmpty) {
//         throw Exception('Tidak dapat mengambil session. Silakan login ulang.');
//       }

//       final headers = {
//         'Cookie': cookies,
//         'Accept': 'application/pdf,text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
//         'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 MEAMBO-Mobile-App',
//         'X-Requested-With': 'XMLHttpRequest',
//         'Referer': baseUrl,
//       };

//       print("📤 Memproses file dari: $url");
//       print("📋 Method: ${formData != null ? 'POST' : 'GET'}");

//       final dio = Dio(BaseOptions(
//         connectTimeout: const Duration(seconds: 30),
//         receiveTimeout: const Duration(seconds: 30),
//         followRedirects: true,
//         maxRedirects: 5,
//         validateStatus: (status) => status != null && status < 500,
//       ));

//       Response response;

//       if (formData != null) {
//         response = await dio.post(
//           url,
//           data: FormData.fromMap(formData),
//           options: Options(
//             responseType: ResponseType.bytes,
//             headers: headers,
//             contentType: Headers.formUrlEncodedContentType,
//           ),
//         );
//       } else {
//         response = await dio.get(
//           url,
//           options: Options(
//             responseType: ResponseType.bytes,
//             headers: headers,
//           ),
//         );
//       }

//       if (response.statusCode == 302 ||
//           response.realUri.toString().contains('/login') ||
//           response.headers.value('location')?.contains('/login') == true) {
//         throw Exception('Sesi berakhir. Silakan login ulang di aplikasi.');
//       }

//       if (response.statusCode == 401 || response.statusCode == 403) {
//         throw Exception('Tidak memiliki akses. Silakan login ulang.');
//       }

//       if (response.statusCode != 200) {
//         throw Exception('Server error: ${response.statusCode}');
//       }

//       final contentType = response.headers.value(Headers.contentTypeHeader) ?? '';
//       print("📄 Final Content-Type: $contentType");

//       if (!contentType.contains('application/pdf')) {
//         throw Exception('Server tidak mengembalikan PDF (Content-Type: $contentType)');
//       }

//       final dir = await getTemporaryDirectory();
//       final fileName = 'dokumen_${DateTime.now().millisecondsSinceEpoch}.pdf';
//       final savePath = "${dir.path}/$fileName";

//       final file = File(savePath);
//       await file.writeAsBytes(response.data);
//       print("✅ File berhasil disimpan: $savePath");

//       if (!mounted) return;

//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => PdfViewerScreen(
//             pdfUrl: savePath,
//             isLocalFile: true,
//             title: formData != null ? 'Pratinjau Surat' : 'Dokumen Lampiran',
//           ),
//         ),
//       );
//     } catch (e) {
//       print("❌ Error detail: $e");
//       if (mounted) {
//         String msg = 'Gagal memuat dokumen.';
//         if (e.toString().contains('Sesi berakhir')) {
//           msg = 'Sesi berakhir. Silakan refresh halaman atau login ulang.';
//           _controller.reload();
//         }
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isProcessingFile = false);
//     }
//   }

//   /// 🔹 Kirim FCM token ke server Laravel
//   Future<void> _registerDeviceToServer(String userId) async {
//     String? fcmToken = await FirebaseMessaging.instance.getToken();
//     if (fcmToken == null) {
//       print("❌ Gagal mendapatkan FCM Token");
//       return;
//     }

//     print("📤 Registrasi FCM - User ID: $userId");

//     try {
//       final response = await http.post(
//         Uri.parse('$baseUrl/api/fcm/save-token'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Accept': 'application/json',
//         },
//         body: json.encode({
//           'user_id': int.parse(userId),
//           'fcm_token': fcmToken,
//         }),
//       );

//       print("📥 Respons Registrasi Token: ${response.statusCode}");
//       if (response.statusCode == 200) {
//         print("✅ Token berhasil didaftarkan di server.");
//       }
//     } catch (e) {
//       print("❌ Error registrasi token: $e");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: () async {
//         if (await _controller.canGoBack()) {
//           _controller.goBack();
//           return false;
//         }
//         return true;
//       },
//       child: Scaffold(
//         body: SafeArea(
//           child: Stack(
//             children: [
//               WebViewWidget(controller: _controller),
//               if (_isProcessingFile)
//                 Container(
//                   color: Colors.black.withOpacity(0.6),
//                   child: const Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         CircularProgressIndicator(color: Colors.white),
//                         SizedBox(height: 20),
//                         Text(
//                           'Memproses dokumen...',
//                           style: TextStyle(color: Colors.white, fontSize: 16),
//                         ),
//                         SizedBox(height: 10),
//                         Text(
//                           'Mohon tunggu',
//                           style: TextStyle(color: Colors.white70, fontSize: 14),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
