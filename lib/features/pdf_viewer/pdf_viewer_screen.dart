import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';


class PdfViewerScreen extends StatefulWidget {
  final String pdfPath; // Hanya menerima path file lokal
  final String title;

  const PdfViewerScreen({
    Key? key,
    required this.pdfPath, // Parameter utama adalah path file lokal
    this.title = 'Dokumen',
  }) : super(key: key);

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // State disederhanakan, tidak perlu lagi isLoading atau errorMessage dari download.
  int _totalPages = 0;
  int _currentPage = 0;
  String? _renderError;
  
  // ▼▼▼ IMPROVISASI: Tambahkan state untuk melacak status rendering PDF ▼▼▼
  bool _isRendering = true;

  // Fungsi untuk membagikan file PDF yang sedang ditampilkan.
  Future<void> _sharePdf() async {
    final xfile = XFile(widget.pdfPath);
    await Share.shareXFiles(
      [xfile],
      subject: widget.title,
      text: 'Dokumen dari Aplikasi PTSP',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _sharePdf,
            tooltip: 'Bagikan atau Cetak Dokumen',
          ),
        ],
      ),
      // ▼▼▼ IMPROVISASI: Gunakan Stack untuk menumpuk loading overlay di atas PDF view ▼▼▼
      body: Stack(
        children: [
          _renderError != null
              ? _buildErrorWidget(_renderError!)
              : Column(
                  children: [
                    // Tampilkan info halaman jika sudah dirender.
                    if (_totalPages > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Center(
                          child: Text(
                            'Halaman ${_currentPage + 1} dari $_totalPages',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    Expanded(
                      child: PDFView(
                        filePath: widget.pdfPath,
                        onRender: (pages) {
                          // Saat PDF selesai dirender, sembunyikan loading overlay
                          if (mounted) {
                            setState(() {
                              _totalPages = pages ?? 0;
                              _isRendering = false;
                            });
                          }
                        },
                        onPageChanged: (page, total) {
                          if (mounted) setState(() => _currentPage = page ?? 0);
                        },
                        onError: (error) {
                          print("PDFView Error: $error");
                          if (mounted) {
                            setState(() {
                              _renderError = error.toString();
                              _isRendering = false;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
          
          // Tampilkan overlay ini jika PDF sedang dirender
          if (_isRendering)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Mempersiapkan dokumen...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 50),
            const SizedBox(height: 16),
            const Text(
              'Gagal Menampilkan PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'File mungkin rusak atau tidak didukung.\nError: $error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

