// import 'dart:io';

// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_pdfview/flutter_pdfview.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:share_plus/share_plus.dart';


// class PdfViewerScreen extends StatefulWidget {
//   final String pdfUrl;
//   final String title;
//   final bool isLocalFile; // ✅ Tambahkan flag

//   const PdfViewerScreen({
//     Key? key,
//     required this.pdfUrl,
//     this.title = 'Dokumen',
//     this.isLocalFile = false, required String pdfPath, // ✅ Default false
//   }) : super(key: key);

//   @override
//   State<PdfViewerScreen> createState() => _PdfViewerScreenState();
// }

// class _PdfViewerScreenState extends State<PdfViewerScreen> {
//   String? localPath;
//   bool isLoading = true;
//   String? errorMessage;
//   int totalPages = 0;
//   int currentPage = 0;

//   Future<void> _requestPermissions() async {
//     if (Platform.isAndroid) {
//       // Android 13+ tidak perlu storage permission untuk app-scoped storage
//       if (await Permission.storage.isDenied) {
//         await Permission.storage.request();
//       }
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     _requestPermissions();
    
//     // ✅ Jika sudah local file, langsung tampilkan
//     if (widget.isLocalFile) {
//       setState(() {
//         localPath = widget.pdfUrl;
//         isLoading = false;
//       });
//     } else {
//       _downloadAndDisplayPdf();
//     }
//   }

//   Future<void> _downloadAndDisplayPdf() async {
//     try {
//       setState(() {
//         isLoading = true;
//         errorMessage = null;
//       });

//       final dir = await getApplicationDocumentsDirectory();
//       final fileName = 'dokumen_${DateTime.now().millisecondsSinceEpoch}.pdf';
//       final savePath = "${dir.path}/$fileName";

//       print('Downloading PDF from: ${widget.pdfUrl}');
//       await Dio().download(widget.pdfUrl, savePath);
//       print('PDF downloaded to: $savePath');

//       setState(() {
//         localPath = savePath;
//         isLoading = false;
//       });
//     } catch (e) {
//       print('Error downloading PDF: $e');
//       setState(() {
//         errorMessage = 'Gagal memuat dokumen: $e';
//         isLoading = false;
//       });
//     }
//   }

//   Future<void> _sharePdf() async {
//     if (localPath != null) {
//       final xfile = XFile(localPath!);
//       await Share.shareXFiles(
//         [xfile],
//         subject: widget.title,
//         text: 'Dokumen dari PTSP Tipulu',
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.title),
//         actions: [
//           if (localPath != null)
//             IconButton(
//               icon: const Icon(Icons.share),
//               onPressed: _sharePdf,
//               tooltip: 'Bagikan/Print',
//             ),
//         ],
//       ),
//       body: _buildBody(),
//     );
//   }

//   Widget _buildBody() {
//     if (isLoading) {
//       return const Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(),
//             SizedBox(height: 16),
//             Text('Memuat dokumen...'),
//           ],
//         ),
//       );
//     }

//     if (errorMessage != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Icon(Icons.error_outline, size: 64, color: Colors.red),
//             const SizedBox(height: 16),
//             Text(errorMessage!),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: _downloadAndDisplayPdf,
//               child: const Text('Coba Lagi'),
//             ),
//           ],
//         ),
//       );
//     }

//     if (localPath == null) {
//       return const Center(child: Text('File tidak ditemukan'));
//     }

//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(8),
//           color: Colors.grey[200],
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 'Halaman ${currentPage + 1} dari $totalPages',
//                 style: const TextStyle(fontSize: 14),
//               ),
//             ],
//           ),
//         ),
//         Expanded(
//           child: PDFView(
//             filePath: localPath!,
//             enableSwipe: true,
//             swipeHorizontal: false,
//             autoSpacing: true,
//             pageFling: true,
//             onRender: (pages) {
//               setState(() {
//                 totalPages = pages ?? 0;
//               });
//             },
//             onPageChanged: (page, total) {
//               setState(() {
//                 currentPage = page ?? 0;
//               });
//             },
//             onError: (error) {
//               print('PDF Error: $error');
//               setState(() {
//                 errorMessage = 'Error menampilkan PDF: $error';
//               });
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }

