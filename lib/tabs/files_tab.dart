import 'dart:io';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';

class FilesTab extends StatelessWidget {
  final List<Map<String, dynamic>> uploadedFiles;
  final bool isUploading;
  final int activeFileIndex;
  final Map<String, dynamic> tvState;
  final int pdfCurrentPage;
  final int pdfTotalPages;
  final VoidCallback onPickAndUploadFile;
  final void Function(int idx) onCastFile;
  final void Function(int idx) onDeleteFile;
  final VoidCallback onPdfPrevPage;
  final VoidCallback onPdfNextPage;
  final VoidCallback onOpenFullscreen;

  const FilesTab({
    super.key,
    required this.uploadedFiles,
    required this.isUploading,
    required this.activeFileIndex,
    required this.tvState,
    required this.pdfCurrentPage,
    required this.pdfTotalPages,
    required this.onPickAndUploadFile,
    required this.onCastFile,
    required this.onDeleteFile,
    required this.onPdfPrevPage,
    required this.onPdfNextPage,
    required this.onOpenFullscreen,
  });

  Widget _buildFilePreview(String fileType, String localPath, bool isActive) {
    if (fileType == 'pdf' && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Container(
          width: 52, height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isActive ? kAccent.withOpacity(0.5) : kBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(children: [
              Center(child: Image.asset('assets/icon/app_icon.png', width: 24, height: 24,
                errorBuilder: (_, __, ___) => const Icon(Icons.picture_as_pdf, size: 24, color: Colors.red))),
              Positioned(bottom: 0, left: 0, right: 0, child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                color: Colors.red.shade700,
                child: const Text('PDF', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              )),
            ]),
          ),
        );
      }
    }
    if (fileType == 'pptx') {
      return Container(
        width: 52, height: 68,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD04423), Color(0xFFF07030)]),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isActive ? kAccent.withOpacity(0.5) : kBorder),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.slideshow, size: 22, color: Colors.white),
          SizedBox(height: 2),
          Text('PPT', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ]),
      );
    }
    return Container(
      width: 52, height: 68,
      decoration: BoxDecoration(
        color: kBg2, borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isActive ? kAccent.withOpacity(0.5) : kBorder),
      ),
      child: const Icon(Icons.insert_drive_file, size: 22, color: kMuted),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        // Upload button
        appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          label('UPLOAD PDF / PPT'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: isUploading ? null : onPickAndUploadFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isUploading ? kAccent.withOpacity(0.3) : kBorder, width: 1.5, strokeAlign: BorderSide.strokeAlignOutside),
              ),
              child: isUploading
                  ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: kAccent, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Uploading...', style: TextStyle(color: kAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                    ])
                  : const Column(children: [
                      Icon(Icons.cloud_upload_outlined, size: 32, color: kAccent),
                      SizedBox(height: 8),
                      Text('Tap to Upload PDF / PPT', style: TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('PDF, PPT, PPTX files supported', style: TextStyle(color: kMuted, fontSize: 10)),
                    ]),
            ),
          ),
        ])),

        const SizedBox(height: 12),

        // PDF page navigation
        if (tvState['type'] == 'pdf') appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          label('PDF PAGE CONTROL'),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kAccent.withOpacity(0.3))),
            child: Column(children: [
              Text('Page $pdfCurrentPage ${pdfTotalPages > 0 ? "/ $pdfTotalPages" : ""}',
                style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: secondaryBtn('Prev Page', pdfCurrentPage > 1 ? onPdfPrevPage : null)),
                const SizedBox(width: 8),
                Expanded(child: secondaryBtn('Next Page', (pdfTotalPages > 0 && pdfCurrentPage >= pdfTotalPages) ? null : onPdfNextPage)),
              ]),
            ]),
          ),
        ])),

        const SizedBox(height: 12),

        // Uploaded files list
        appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            label('UPLOADED FILES'),
            if (uploadedFiles.isNotEmpty) Text('$uploadedFiles.length', style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 10)),
          ]),
          const SizedBox(height: 10),

          if (uploadedFiles.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const Column(children: [
                Icon(Icons.folder_open, size: 28, color: Color(0xFF1a2d45)),
                SizedBox(height: 8),
                Text('No files uploaded yet', style: TextStyle(color: kMuted, fontSize: 11)),
                Text('Upload PDF or PPT to display on TV', style: TextStyle(color: Color(0xFF1a2d45), fontSize: 9)),
              ]),
            )
          else
            ...uploadedFiles.asMap().entries.map((entry) {
              final idx = entry.key;
              final f = entry.value;
              final isActive = idx == activeFileIndex && tvState['type'] != 'idle';
              final fileType = f['type'] as String? ?? 'other';
              final fileName = f['name'] as String? ?? 'Unknown';
              final fileSize = f['size'] as int? ?? 0;
              final localPath = f['localPath'] as String? ?? '';
              final isPdf = fileType == 'pdf';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF0c1f3a) : kBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isActive ? kAccent.withOpacity(0.7) : kBorder),
                ),
                child: Column(children: [
                  Row(children: [
                    _buildFilePreview(fileType, localPath, isActive),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(fileName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? kText : kMuted), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: fileColor(fileType).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                          child: Text(isPdf ? 'PDF' : 'PPT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: fileColor(fileType), letterSpacing: 0.5)),
                        ),
                        const SizedBox(width: 8),
                        Text(formatFileSize(fileSize), style: const TextStyle(fontSize: 9, color: kMuted, fontFamily: 'monospace')),
                      ]),
                    ])),
                    if (isActive) const Icon(Icons.cast, size: 16, color: kAccent)
                    else GestureDetector(
                      onTap: () => onCastFile(idx),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: kAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: kAccent.withOpacity(0.3))),
                        child: const Icon(Icons.cast, size: 16, color: kAccent),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => onDeleteFile(idx),
                      child: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade400),
                    ),
                  ]),
                  if (!isActive) Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(width: double.infinity, child: castFileBtn(isPdf ? 'Cast PDF to TV' : 'Cast PPT to TV', () => onCastFile(idx))),
                  ),
                ]),
              );
            }),
        ])),

        const SizedBox(height: 10),

        // Fullscreen button for PDF/PPT
        if (tvState['type'] == 'pdf' || tvState['type'] == 'pptx')
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: onOpenFullscreen,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kAccent.withOpacity(0.4)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.fullscreen, color: kAccent, size: 20),
                  SizedBox(width: 8),
                  Text('Full Screen', style: TextStyle(color: kAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
