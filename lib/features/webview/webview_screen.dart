// import 'dart:convert';
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:ptsp_tipulu_ap/core/config/app_config.dart';
// import 'package:ptsp_tipulu_ap/core/services/api_service.dart';
// import 'package:ptsp_tipulu_ap/features/pdf_viewer/pdf_viewer_screen.dart';
// import 'package:ptsp_tipulu_ap/features/webview/widgets/loading_overlay.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// // Import khusus untuk fungsionalitas upload file di Android
// import 'package:webview_flutter_android/webview_flutter_android.dart';

// /// Halaman utama aplikasi yang menampilkan konten web.
// class WebViewScreen extends StatefulWidget {
//   const WebViewScreen({super.key});

//   @override
//   State<WebViewScreen> createState() => _WebViewScreenState();
// }

// class _WebViewScreenState extends State<WebViewScreen> {
//   late final WebViewController _controller;
//   final ApiService _apiService = ApiService();
//   final ImagePicker _picker = ImagePicker();

//   // State untuk mengelola tampilan indikator loading
//   bool _isPageLoading = true;
//   bool _isFileProcessing = false;
//   String _loadingMessage = 'Memuat halaman...';

//   @override
//   void initState() {
//     super.initState();
    
//     // ===================================================================
//     // ▼▼▼ PERBAIKAN: Gunakan pola inisialisasi modern untuk WebView ▼▼▼
//     // ===================================================================
//     // Siapkan parameter pembuatan controller
//     late final PlatformWebViewControllerCreationParams params;
//     if (WebViewPlatform.instance is AndroidWebViewPlatform) {
//       // Jika platform adalah Android, siapkan parameter dengan handler file picker
//       params = AndroidWebViewControllerCreationParams(
//         onFileSelectorRequest: (FileSelectorParams params) async {
//           // Logika dari _handleFileChooser dipindahkan ke sini
//           final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
//           if (image != null) {
//             print("✅ Gambar dipilih: ${image.path}");
//             return <String>[File(image.path).uri.toString()];
//           }
//           print("⚠️ Pemilihan gambar dibatalkan.");
//           return <String>[];
//         },
//       );
//     } else {
//       // Untuk platform lain, gunakan parameter default
//       params = const PlatformWebViewControllerCreationParams();
//     }

//     final WebViewController controller = WebViewController.fromPlatformCreationParams(params);
//     // ===================================================================
//     // ▲▲▲ PERBAIKAN SELESAI ▲▲▲
//     // ===================================================================
    
//     _controller = controller
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setBackgroundColor(const Color(0x00000000))
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onPageStarted: (url) => setState(() {
//             _loadingMessage = 'Memuat halaman...';
//             _isPageLoading = true;
//           }),
//           onPageFinished: (url) => setState(() => _isPageLoading = false),
//           onNavigationRequest: (request) {
//             final uri = Uri.parse(request.url);

//             // Mencegat link eksternal seperti WhatsApp
//             if (uri.host == 'wa.me' || uri.host == 'api.whatsapp.com') {
//               launchUrl(uri, mode: LaunchMode.externalApplication);
//               return NavigationDecision.prevent;
//             }

//             // Mencegat link "Lihat Dokumen" (GET request)
//             if (request.url.contains('/list-pengajuan/stream')) {
//               _processFileRequest(request.url, "Membuka dokumen...");
//               return NavigationDecision.prevent;
//             }

//             // Izinkan semua navigasi lain di dalam WebView
//             return NavigationDecision.navigate;
//           },
//         ),
//       )
//       ..addJavaScriptChannel('flutterApp', onMessageReceived: _handleLoginMessage)
//       ..addJavaScriptChannel('flutterCetak', onMessageReceived: _handleCetakMessage)
//       ..loadRequest(Uri.parse('${AppConfig.baseUrl}/login'));
//   }
  
//   /// Menangani pesan dari web saat login berhasil.
//   void _handleLoginMessage(JavaScriptMessage message) {
//     final userId = message.message.trim();
//     if (RegExp(r'^\d+$').hasMatch(userId)) {
//       _apiService.registerDeviceToServer(userId);
//     }
//   }

//   /// Menangani pesan dari web untuk aksi cetak/unduh.
//   void _handleCetakMessage(JavaScriptMessage message) {
//     try {
//       final data = json.decode(message.message);
//       if (data['type'] == 'cetakSurat') {
//         _processFileRequest(data['url'], "Memproses dokumen...", Map<String, dynamic>.from(data['formData']));
//       }
//     } catch (e) {
//       print("❌ Error parsing data cetak: $e");
//     }
//   }

//   // Method _handleFileChooser tidak lagi diperlukan karena logikanya sudah dipindahkan
//   // ke dalam AndroidWebViewControllerCreationParams di initState.

//   /// Fungsi terpusat untuk memproses permintaan file (GET atau POST).
//   Future<void> _processFileRequest(String url, String loadingMessage, [Map<String, dynamic>? formData]) async {
//     if (!mounted || _isFileProcessing) return;
//     setState(() {
//       _loadingMessage = loadingMessage;
//       _isFileProcessing = true;
//     });

//     try {
//       final cookieObject = await _controller.runJavaScriptReturningResult('document.cookie');
//       final cookies = cookieObject is String ? cookieObject.replaceAll('"', '') : '';

//       // Delegasikan tugas unduh file ke ApiService
//       final savePath = await _apiService.downloadAndProcessFile(
//         url: url,
//         cookies: cookies,
//         formData: formData,
//       );

//       if (savePath != null && mounted) {
//         if (url.contains('download')) {
//           final xfile = XFile(savePath);
//           await Share.shareXFiles(
//             [xfile],
//             subject: 'Dokumen Surat PTSP',
//             text: 'Berikut adalah dokumen surat dari aplikasi PTSP.',
//           );
//         } else {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => PdfViewerScreen(
//                 pdfPath: savePath,
//                 title: 'Pratinjau Dokumen',
//               ),
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Gagal: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isFileProcessing = false);
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
//         body: RefreshIndicator(
//           onRefresh: () async => await _controller.reload(),
//           child: SafeArea(
//             child: Stack(
//               children: [
//                 WebViewWidget(controller: _controller),
//                 if (_isPageLoading) LoadingOverlay(message: _loadingMessage),
//                 if (_isFileProcessing) LoadingOverlay(message: _loadingMessage),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

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

  // State untuk mengelola tampilan indikator loading
  bool _isPageLoading = true;
  bool _isFileProcessing = false;
  String _loadingMessage = 'Memuat halaman...';

  @override
  void initState() {
    super.initState();
    
    // Setup WebView dengan parameter standar
    late final PlatformWebViewControllerCreationParams params;
    params = const PlatformWebViewControllerCreationParams();

    final WebViewController controller = WebViewController.fromPlatformCreationParams(params);
    
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
            // Inject JavaScript untuk intercept file input
            _injectFileUploadHandler();
          },
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);

            // Mencegat link eksternal seperti WhatsApp
            if (uri.host == 'wa.me' || uri.host == 'api.whatsapp.com') {
              launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }

            // Mencegat link "Lihat Dokumen" (GET request)
            if (request.url.contains('/list-pengajuan/stream')) {
              _processFileRequest(request.url, "Membuka dokumen...");
              return NavigationDecision.prevent;
            }

            // Izinkan semua navigasi lain di dalam WebView
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel('flutterApp', onMessageReceived: _handleLoginMessage)
      ..addJavaScriptChannel('flutterCetak', onMessageReceived: _handleCetakMessage)
      // Channel baru untuk handle file upload
      ..addJavaScriptChannel('flutterFileUpload', onMessageReceived: _handleFileUpload)
      ..loadRequest(Uri.parse('${AppConfig.baseUrl}/login'));

    // Konfigurasi Android WebView
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController androidController = controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  /// Inject JavaScript untuk intercept file input clicks
  void _injectFileUploadHandler() {
    _controller.runJavaScript('''
      (function() {
        // Fungsi untuk handle semua input file
        function setupFileInputs() {
          const fileInputs = document.querySelectorAll('input[type="file"]');
          
          fileInputs.forEach(function(input) {
            // Hapus event listener lama jika ada
            const newInput = input.cloneNode(true);
            input.parentNode.replaceChild(newInput, input);
            
            // Tambahkan event listener baru
            newInput.addEventListener('click', function(e) {
              e.preventDefault();
              e.stopPropagation();
              
              console.log('📂 File input clicked');
              
              // Simpan referensi input untuk nanti
              window.currentFileInput = newInput;
              
              // Panggil Flutter untuk pilih file
              flutterFileUpload.postMessage('selectFile');
            });
          });
        }
        
        // Setup awal
        setupFileInputs();
        
        // Observer untuk mendeteksi perubahan DOM (modal dibuka, dll)
        const observer = new MutationObserver(function(mutations) {
          setupFileInputs();
        });
        
        observer.observe(document.body, {
          childList: true,
          subtree: true
        });
        
        console.log('✅ File upload handler initialized');
      })();
    ''');
  }

  /// Handle pesan file upload dari JavaScript
  void _handleFileUpload(JavaScriptMessage message) async {
    if (message.message == 'selectFile') {
      print('📂 Flutter menerima request pilih file');
      
      try {
        // Tampilkan dialog pilihan sumber dengan delay untuk memastikan context ready
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (!mounted) return;
        
        final ImageSource? source = await _showImageSourceDialog();
        
        if (source == null) {
          print('⚠️ User membatalkan pemilihan');
          return;
        }
        
        print('📱 Membuka ${source == ImageSource.camera ? "kamera" : "galeri"}...');
        
        // Request permission sebelum membuka picker
        bool hasPermission = await _requestPermission(source);
        if (!hasPermission) {
          print('❌ Permission ditolak');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  source == ImageSource.camera
                      ? 'Izin kamera diperlukan untuk mengambil foto'
                      : 'Izin storage diperlukan untuk memilih foto',
                ),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Buka Settings',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        }
        
        // Tambahkan delay sebelum membuka picker
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Pilih gambar dengan error handling
        XFile? pickedFile;
        try {
          pickedFile = await _picker.pickImage(
            source: source,
            maxWidth: 1920,
            maxHeight: 1080,
            imageQuality: 85,
          );
        } catch (e) {
          print('❌ Error saat pickImage: $e');
          // Retry dengan instance baru
          try {
            final newPicker = ImagePicker();
            pickedFile = await newPicker.pickImage(
              source: source,
              maxWidth: 1920,
              maxHeight: 1080,
              imageQuality: 85,
            );
          } catch (retryError) {
            print('❌ Retry juga gagal: $retryError');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Gagal membuka ${source == ImageSource.camera ? "kamera" : "galeri"}. Coba tutup dan buka aplikasi lagi.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }
        
        if (pickedFile != null) {
          print('✅ File dipilih: ${pickedFile.path}');
          
          // Upload file ke server
          await _uploadFileToServer(File(pickedFile.path));
        } else {
          print('⚠️ Tidak ada file yang dipilih');
        }
      } catch (e) {
        print('❌ Error di _handleFileUpload: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Terjadi kesalahan: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Request permission untuk kamera atau storage
  Future<bool> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      return status.isGranted;
    } else {
      // Untuk Android 13+ (API 33+), gunakan photos
      // Untuk Android 12 dan dibawah, gunakan storage
      if (Platform.isAndroid) {
        final androidInfo = await Permission.storage.status;
        if (androidInfo.isPermanentlyDenied) {
          return false;
        }
      }
      
      final status = await Permission.photos.request();
      if (status.isGranted) return true;
      
      // Fallback ke storage permission
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
  }

  /// Upload file ke server dan update form
  Future<void> _uploadFileToServer(File file) async {
    try {
      setState(() {
        _loadingMessage = 'Mengunggah foto...';
        _isFileProcessing = true;
      });

      // Ambil cookies untuk autentikasi
      final cookieObject = await _controller.runJavaScriptReturningResult('document.cookie');
      final cookies = cookieObject is String ? cookieObject.replaceAll('"', '') : '';

      // Baca file sebagai bytes
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final fileName = file.path.split('/').last;
      final mimeType = _getMimeType(fileName);

      // Inject data ke form menggunakan JavaScript
      await _controller.runJavaScript('''
        (function() {
          const input = window.currentFileInput;
          if (input) {
            // Buat DataTransfer object
            const dataTransfer = new DataTransfer();
            
            // Konversi base64 ke File object
            const base64 = '$base64Image';
            const binary = atob(base64);
            const array = new Uint8Array(binary.length);
            for (let i = 0; i < binary.length; i++) {
              array[i] = binary.charCodeAt(i);
            }
            const blob = new Blob([array], { type: '$mimeType' });
            const file = new File([blob], '$fileName', { type: '$mimeType' });
            
            // Tambahkan file ke DataTransfer
            dataTransfer.items.add(file);
            
            // Set files ke input
            input.files = dataTransfer.files;
            
            // Trigger change event
            const event = new Event('change', { bubbles: true });
            input.dispatchEvent(event);
            
            console.log('✅ File set ke input:', '$fileName');
            
            // Tampilkan preview jika ada
            const preview = document.querySelector('img[alt="preview"]');
            if (preview) {
              preview.src = 'data:$mimeType;base64,$base64Image';
            }
          }
        })();
      ''');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Foto berhasil dipilih'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error upload file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFileProcessing = false);
      }
    }
  }

  /// Get MIME type dari ekstensi file
  String _getMimeType(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    switch (extension) {
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

  /// Menampilkan dialog untuk memilih sumber gambar
  Future<ImageSource?> _showImageSourceDialog() async {
    // Gunakan showModalBottomSheet untuk compatibility lebih baik dengan WebView
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pilih Sumber Foto',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.blue, size: 28),
                  ),
                  title: const Text(
                    'Kamera',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library, color: Colors.green, size: 28),
                  ),
                  title: const Text(
                    'Galeri',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Menangani pesan dari web saat login berhasil.
  void _handleLoginMessage(JavaScriptMessage message) {
    final userId = message.message.trim();
    if (RegExp(r'^\d+$').hasMatch(userId)) {
      _apiService.registerDeviceToServer(userId);
    }
  }

  /// Menangani pesan dari web untuk aksi cetak/unduh.
  void _handleCetakMessage(JavaScriptMessage message) {
    try {
      final data = json.decode(message.message);
      if (data['type'] == 'cetakSurat') {
        _processFileRequest(data['url'], "Memproses dokumen...", Map<String, dynamic>.from(data['formData']));
      }
    } catch (e) {
      print("❌ Error parsing data cetak: $e");
    }
  }

  /// Fungsi terpusat untuk memproses permintaan file (GET atau POST).
  Future<void> _processFileRequest(String url, String loadingMessage, [Map<String, dynamic>? formData]) async {
    if (!mounted || _isFileProcessing) return;
    setState(() {
      _loadingMessage = loadingMessage;
      _isFileProcessing = true;
    });

    try {
      final cookieObject = await _controller.runJavaScriptReturningResult('document.cookie');
      final cookies = cookieObject is String ? cookieObject.replaceAll('"', '') : '';

      // Delegasikan tugas unduh file ke ApiService
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
            subject: 'Dokumen Surat PTSP',
            text: 'Berikut adalah dokumen surat dari aplikasi PTSP.',
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerScreen(
                pdfPath: savePath,
                title: 'Pratinjau Dokumen',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: ${e.toString().replaceAll("Exception: ", "")}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isFileProcessing = false);
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
        body: RefreshIndicator(
          onRefresh: () async => await _controller.reload(),
          child: SafeArea(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isPageLoading) LoadingOverlay(message: _loadingMessage),
                if (_isFileProcessing) LoadingOverlay(message: _loadingMessage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}