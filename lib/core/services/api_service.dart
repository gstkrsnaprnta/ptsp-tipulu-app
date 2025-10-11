import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:ptsp_tipulu_ap/core/config/app_config.dart';

class ApiService {
  final Dio _dio = Dio();

  /// Mengirim FCM token ke server untuk registrasi perangkat.
  Future<void> registerDeviceToServer(String userId) async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) {
      print("❌ Gagal mendapatkan FCM Token");
      return;
    }

    print("📤 Registrasi FCM - User ID: $userId");
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/fcm/save-token'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: json.encode({'user_id': int.parse(userId), 'fcm_token': fcmToken}),
      );
      print("📥 Respons Registrasi Token: ${response.statusCode}");
      if (response.statusCode == 200) {
        print("✅ Token berhasil didaftarkan di server.");
      }
    } catch (e) {
      print("❌ Error registrasi token: $e");
    }
  }

  Future<String?> downloadAndProcessFile({
    required String url,
    required String cookies,
    Map<String, dynamic>? formData,
  }) async {
    final headers = {'Cookie': cookies};
    print("📤 Memproses file dari: $url");
    
    Response response;
    if (formData != null) {
      response = await _dio.post(url, data: formData, options: Options(responseType: ResponseType.bytes, contentType: Headers.formUrlEncodedContentType, headers: headers));
    } else {
      response = await _dio.get(url, options: Options(responseType: ResponseType.bytes, headers: headers));
    }

    final contentType = response.headers.value(Headers.contentTypeHeader) ?? '';
    if (!contentType.contains('application/pdf')) {
      throw Exception('Server tidak merespon dengan file PDF. Respon: $contentType');
    }

    final dir = await getTemporaryDirectory();
    final fileName = 'dokumen_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final savePath = "${dir.path}/$fileName";
    
    final file = File(savePath);
    await file.writeAsBytes(response.data);
    print("✅ File berhasil disimpan: $savePath");
    return savePath;
  }
}
