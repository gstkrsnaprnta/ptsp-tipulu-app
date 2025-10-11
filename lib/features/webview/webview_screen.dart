import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ptsp_tipulu_ap/core/config/app_config.dart';
import 'package:ptsp_tipulu_ap/core/services/api_service.dart';
import 'package:ptsp_tipulu_ap/features/pdf_viewer/pdf_viewer_screen.dart';
import 'package:ptsp_tipulu_ap/features/webview/widgets/loading_overlay.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Halaman utama aplikasi yang menampilkan konten web.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _isPageLoading = true;
  bool _isFileProcessing = false;
  String _loadingMessage = 'Memuat halaman...';

  @override
  void initState() {
    super.initState();

    // =====================================================================
    // ✅ 1. Aktifkan hybrid composition untuk Android
    // =====================================================================
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);

    // =====================================================================
    // ✅ 2. Konfigurasi dasar controller
    // =====================================================================
    _controller = controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() {
            _loadingMessage = 'Memuat halaman...';
            _isPageLoading = true;
          }),
          onPageFinished: (url) {
            setState(() => _isPageLoading = false);
            _injectFileUploadHandler();
          },
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);

            // Buka link eksternal (WhatsApp, dsb)
            if (uri.host == 'wa.me' || uri.host == 'api.whatsapp.com') {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }

            // Tangani file PDF
            if (request.url.contains('/list-pengajuan/stream')) {
              _processFileRequest(request.url, "Membuka dokumen...");
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel('flutterApp', onMessageReceived: _handleLoginMessage)
      ..addJavaScriptChannel('flutterCetak', onMessageReceived: _handleCetakMessage)
      ..addJavaScriptChannel('flutterFileUpload', onMessageReceived: _handleFileUpload)
      ..loadRequest(Uri.parse('${AppConfig.baseUrl}/login'));

    // =====================================================================
    // ✅ 3. Konfigurasi tambahan Android
    // =====================================================================
    if (controller.platform is AndroidWebViewController) {
      final AndroidWebViewController androidController =
          controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }
  }

 // =====================================================================
// 🧩 Fungsi JavaScript Injection untuk intercept input file (versi fix)
// =====================================================================
void _injectFileUploadHandler() {
  _controller.runJavaScript('''
    (function() {
      function setupFileInputs() {
        const fileInputs = document.querySelectorAll('input[type="file"]');
        fileInputs.forEach((input) => {
          if (input.hasListenerAttached) return;
          input.hasListenerAttached = true;

          input.addEventListener('click', function(e) {
            e.preventDefault();
            window.currentFileInput = input;
            try {
              flutterFileUpload.postMessage('selectFile');
            } catch (err) {
              console.error('Flutter bridge error:', err);
            }
            return false; // jangan freeze
          });
        });
      }

      setupFileInputs();

      const observer = new MutationObserver(setupFileInputs);
      observer.observe(document.body, { childList: true, subtree: true });

      console.log('✅ File upload handler aktif tanpa freeze');
    })();
  ''');
}



  // =====================================================================
  // 📸 Handle file upload
  // =====================================================================
  void _handleFileUpload(JavaScriptMessage message) async {
    if (message.message == 'selectFile') {
      print('📂 Flutter menerima request pilih file');
      try {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;

        final source = await _showImageSourceDialog();
        if (source == null) return;

        bool granted = await _requestPermission(source);
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                source == ImageSource.camera
                    ? 'Izin kamera diperlukan'
                    : 'Izin galeri diperlukan',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        print('📱 Membuka ${source == ImageSource.camera ? "kamera" : "galeri"}...');
        final XFile? pickedFile = await _picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (pickedFile == null) {
          print('⚠️ Tidak ada file dipilih');
          return;
        }

        print('✅ File dipilih: ${pickedFile.path}');
        await _uploadFileToWebView(File(pickedFile.path));
      } catch (e) {
        print('❌ Error upload: $e');
      }
    }
  }

  Future<bool> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      return status.isGranted;
    } else {
      if (Platform.isAndroid) {
        final status = await Permission.photos.request();
        if (status.isGranted) return true;
        return (await Permission.storage.request()).isGranted;
      }
      return true;
    }
  }

  Future<void> _uploadFileToWebView(File file) async {
    setState(() {
      _loadingMessage = 'Mengunggah foto...';
      _isFileProcessing = true;
    });

    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final fileName = file.path.split('/').last;
      final mimeType = _getMimeType(fileName);

      await _controller.runJavaScript('''
        (function() {
          const input = window.currentFileInput;
          if (!input) return;
          const dataTransfer = new DataTransfer();
          const binary = atob('$base64Image');
          const array = new Uint8Array(binary.length);
          for (let i = 0; i < binary.length; i++) array[i] = binary.charCodeAt(i);
          const blob = new Blob([array], { type: '$mimeType' });
          const file = new File([blob], '$fileName', { type: '$mimeType' });
          dataTransfer.items.add(file);
          input.files = dataTransfer.files;
          input.dispatchEvent(new Event('change', { bubbles: true }));
          console.log('✅ File set ke input: $fileName');
        })();
      ''');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Foto berhasil dipilih'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error upload ke WebView: $e');
    } finally {
      setState(() => _isFileProcessing = false);
    }
  }

  String _getMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  // =====================================================================
  // 🧾 Fungsi-fungsi pendukung login & cetak
  // =====================================================================
  void _handleLoginMessage(JavaScriptMessage message) {
    final userId = message.message.trim();
    if (RegExp(r'^\d+$').hasMatch(userId)) {
      _apiService.registerDeviceToServer(userId);
    }
  }

  void _handleCetakMessage(JavaScriptMessage message) {
    try {
      final data = json.decode(message.message);
      if (data['type'] == 'cetakSurat') {
        _processFileRequest(
          data['url'],
          "Memproses dokumen...",
          Map<String, dynamic>.from(data['formData']),
        );
      }
    } catch (e) {
      print("❌ Error parsing cetak: $e");
    }
  }

  Future<void> _processFileRequest(String url, String message,
      [Map<String, dynamic>? formData]) async {
    if (!mounted || _isFileProcessing) return;
    setState(() {
      _loadingMessage = message;
      _isFileProcessing = true;
    });

    try {
      final cookieObject =
          await _controller.runJavaScriptReturningResult('document.cookie');
      final cookies = cookieObject is String
          ? cookieObject.replaceAll('"', '')
          : '';

      final savePath = await _apiService.downloadAndProcessFile(
        url: url,
        cookies: cookies,
        formData: formData,
      );

      if (savePath != null && mounted) {
        if (url.contains('download')) {
          final xfile = XFile(savePath);
          await Share.shareXFiles(
            [xfile],
            subject: 'Dokumen PTSP',
            text: 'Berikut dokumen dari aplikasi PTSP.',
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                pdfPath: savePath,
                title: 'Pratinjau Dokumen',
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Gagal download file: $e');
    } finally {
      if (mounted) setState(() => _isFileProcessing = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text('Pilih Sumber Foto',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              ListTile(
                leading:
                    const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
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
        body: RefreshIndicator(
          onRefresh: () async => await _controller.reload(),
          child: SafeArea(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isPageLoading)
                  LoadingOverlay(message: _loadingMessage),
                if (_isFileProcessing)
                  LoadingOverlay(message: _loadingMessage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
