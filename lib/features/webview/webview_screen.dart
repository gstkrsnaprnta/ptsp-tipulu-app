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
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

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
  bool _isRefreshing = false; // indikator swipe refresh

  @override
  void initState() {
    super.initState();

    late final PlatformWebViewControllerCreationParams params;

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() {
              _isPageLoading = true;
              _loadingMessage = 'Memuat halaman...';
            });
          },
          onPageFinished: (_) async {
            setState(() => _isPageLoading = false);
            _injectFileUploadHandler();
          },
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);

            if (uri.host == 'wa.me' || uri.host == 'api.whatsapp.com') {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }

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

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
  }

  // ================== FILE UPLOAD HANDLER ==================
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
              return false;
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

  void _handleFileUpload(JavaScriptMessage message) async {
    if (message.message != 'selectFile') return;

    final source = await _showImageSourceDialog();
    if (source == null) return;

    if (!await _requestPermission(source)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Izin diperlukan untuk kamera/galeri')),
      );
      return;
    }

    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile == null) return;
    await _uploadFileToWebView(File(pickedFile.path));
  }

  Future<bool> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      return (await Permission.camera.request()).isGranted;
    } else {
      if (Platform.isAndroid) {
        final photos = await Permission.photos.request();
        if (photos.isGranted) return true;
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
        })();
      ''');
    } catch (e) {
      debugPrint('❌ Upload error: $e');
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
      default:
        return 'application/octet-stream';
    }
  }

  // ================== CETAK & LOGIN ==================
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
      debugPrint("❌ Error parsing cetak: $e");
    }
  }

  Future<void> _processFileRequest(String url, String message,
      [Map<String, dynamic>? formData]) async {
    if (!mounted) return;
    setState(() {
      _loadingMessage = message;
      _isFileProcessing = true;
    });

    try {
      final cookieObject =
          await _controller.runJavaScriptReturningResult('document.cookie');
      final cookies =
          cookieObject is String ? cookieObject.replaceAll('"', '') : '';

      final savePath = await _apiService.downloadAndProcessFile(
        url: url,
        cookies: cookies,
        formData: formData,
      );

      if (savePath != null && mounted) {
        if (url.contains('download')) {
          await Share.shareXFiles([XFile(savePath)], subject: 'Dokumen PTSP');
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
      debugPrint('❌ Gagal download file: $e');
    } finally {
      if (mounted) setState(() => _isFileProcessing = false);
    }
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    double dragDistance = 0;
    const double refreshThreshold = 120;

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
              Listener(
                onPointerMove: (event) {
                  // Swipe ke bawah dari atas untuk refresh
                  if (event.delta.dy > 0 && dragDistance < refreshThreshold) {
                    dragDistance += event.delta.dy;
                    if (dragDistance > 50 && !_isRefreshing) {
                      setState(() => _isRefreshing = true);
                    }
                  }
                },
                onPointerUp: (_) async {
                  if (dragDistance > refreshThreshold) {
                    await _controller.reload();
                  }
                  dragDistance = 0;
                  setState(() => _isRefreshing = false);
                },
                child: WebViewWidget(controller: _controller),
              ),

              // Pull refresh indicator
              if (_isRefreshing)
                Positioned(
                  top: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      children: const [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 8),
                        Text("Menyegarkan halaman...",
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),

              if (_isPageLoading)
                LoadingOverlay(message: _loadingMessage),
              if (_isFileProcessing)
                LoadingOverlay(message: _loadingMessage),
            ],
          ),
        ),
      ),
    );
  }

  Future<ImageSource?> _showImageSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text('Pilih Sumber Foto',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
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
}
