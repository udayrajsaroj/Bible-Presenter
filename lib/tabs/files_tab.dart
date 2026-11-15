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
  // ── Video remote (Feature 2) ──
  final double videoPosition;
  final double videoDuration;
  final bool videoPlaying;
  final bool videoMuted;
  final bool videoFinished;
  final VoidCallback onVideoPlayPause;
  final void Function(double seconds) onVideoSeek;
  final VoidCallback onVideoStop;
  final VoidCallback onVideoUnmute;
  // ── YouTube remote (Feature 3) ──
  final TextEditingController ytUrlCtrl;
  final List<String> ytQueue;
  final int ytQueueIndex;
  final double ytPosition;
  final double ytDuration;
  final double ytVolume;
  final bool ytPlaying;
  final VoidCallback onCastYouTubeUrl;
  final VoidCallback onYtPlayPause;
  final void Function(double seconds) onYtSeek;
  final void Function(double value) onYtVolume;
  final VoidCallback onYtStop;
  final void Function(int idx) onYtRemoveFromQueue;

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
    required this.videoPosition,
    required this.videoDuration,
    required this.videoPlaying,
    required this.videoMuted,
    required this.videoFinished,
    required this.onVideoPlayPause,
    required this.onVideoSeek,
    required this.onVideoStop,
    required this.onVideoUnmute,
    required this.ytUrlCtrl,
    required this.ytQueue,
    required this.ytQueueIndex,
    required this.ytPosition,
    required this.ytDuration,
    required this.ytVolume,
    required this.ytPlaying,
    required this.onCastYouTubeUrl,
    required this.onYtPlayPause,
    required this.onYtSeek,
    required this.onYtVolume,
    required this.onYtStop,
    required this.onYtRemoveFromQueue,
  });

  String _formatTime(double seconds) {
    final s = seconds.floor();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

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
    if (fileType == 'video') {
      return Container(
        width: 52, height: 68,
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF12304f), Color(0xFF0d1a2e)]),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isActive ? kAccent.withOpacity(0.5) : kBorder),
        ),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.smart_display_outlined, size: 22, color: kAccent),
          SizedBox(height: 2),
          Text('VIDEO', style: TextStyle(color: kAccent, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
    final isVideoActive = tvState['type'] == 'video';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        // Upload button
        appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          label('UPLOAD FILES'),
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
                      Text('Tap to Upload PDF / PPT / Video', style: TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('PDF, PPT, PPTX · MP4 (H.264 recommended) · WebM, MOV', style: TextStyle(color: kMuted, fontSize: 10)),
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

        // ── Video remote (Feature 2) ──
        if (isVideoActive) appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            label('VIDEO REMOTE'),
            if (videoMuted)
              GestureDetector(
                onTap: onVideoUnmute,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.orange.shade700)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.volume_off, size: 12, color: Colors.orange.shade400),
                    const SizedBox(width: 5),
                    Text('Unmute', style: TextStyle(color: Colors.orange.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kAccent.withOpacity(0.3))),
            child: Column(children: [
              if (videoFinished)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    SizedBox(width: 6),
                    Text('Finished', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              Slider(
                value: videoDuration > 0
                    ? videoPosition.clamp(0.0, videoDuration)
                    : 0,
                max: videoDuration > 0 ? videoDuration : 1,
                onChanged: videoDuration > 0
                    ? (v) => onVideoSeek(v)
                    : null,
                activeColor: kAccent,
                inactiveColor: kBorder,
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_formatTime(videoPosition),
                    style: const TextStyle(color: kMuted, fontFamily: 'monospace', fontSize: 10)),
                Text(_formatTime(videoDuration),
                    style: const TextStyle(color: kMuted, fontFamily: 'monospace', fontSize: 10)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                // Play / pause toggle
                Expanded(
                  child: GestureDetector(
                    onTap: onVideoPlayPause,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kAccent.withOpacity(0.4))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(videoPlaying ? Icons.pause : Icons.play_arrow,
                            size: 16, color: kAccent),
                        const SizedBox(width: 6),
                        Text(videoPlaying ? 'Pause' : 'Play',
                            style: const TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Stop
                Expanded(
                  child: GestureDetector(
                    onTap: onVideoStop,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade800.withOpacity(0.4))),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.stop, size: 16, color: Colors.red),
                        SizedBox(width: 6),
                        Text('Stop', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ])),

        const SizedBox(height: 12),

        // ── YouTube casting (Feature 3) ──
        appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            label('YOUTUBE'),
            const Row(children: [
              Icon(Icons.wifi, size: 11, color: kMuted),
              SizedBox(width: 4),
              Text('needs internet', style: TextStyle(color: kMuted, fontSize: 9)),
            ]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: ytUrlCtrl,
                onSubmitted: (_) => onCastYouTubeUrl(),
                style: const TextStyle(color: kText, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Paste a YouTube link…',
                  hintStyle: const TextStyle(color: kMuted, fontSize: 11),
                  filled: true,
                  fillColor: kBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onCastYouTubeUrl,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade700.withOpacity(0.6))),
                child: Row(children: [
                  Icon(Icons.play_circle_fill, size: 16, color: Colors.red.shade400),
                  const SizedBox(width: 6),
                  Text('Cast', style: TextStyle(color: Colors.red.shade400, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ]),
          if (ytQueue.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('QUEUE (${ytQueueIndex + 1}/${ytQueue.length})',
                style: const TextStyle(color: kMuted, fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...ytQueue.asMap().entries.map((entry) {
              final idx = entry.key;
              final id = entry.value;
              final isCurrent = idx == ytQueueIndex;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFF0c1f3a) : kBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isCurrent ? kAccent.withOpacity(0.7) : kBorder)),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.network('https://i.ytimg.com/vi/$id/mqdefault.jpg',
                      width: 56, height: 32, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56, height: 32, color: kBg2,
                        child: const Icon(Icons.play_circle_outline, size: 14, color: kMuted))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Video ${idx + 1}  ·  $id',
                        style: TextStyle(fontSize: 10, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400, color: isCurrent ? kText : kMuted),
                        overflow: TextOverflow.ellipsis),
                      if (isCurrent)
                        const Text('Now playing', style: TextStyle(color: kAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () => onYtRemoveFromQueue(idx),
                    child: Icon(Icons.close, size: 14, color: Colors.red.shade400),
                  ),
                ]),
              );
            }),
          ],
        ])),

        const SizedBox(height: 12),

        // ── YouTube remote (Feature 3) ──
        if (tvState['type'] == 'youtube') appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            label('YOUTUBE REMOTE'),
            if (videoMuted)
              GestureDetector(
                onTap: onVideoUnmute,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: Colors.orange.shade700)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.volume_off, size: 12, color: Colors.orange.shade400),
                    const SizedBox(width: 5),
                    Text('Unmute', style: TextStyle(color: Colors.orange.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kAccent.withOpacity(0.3))),
            child: Column(children: [
              Slider(
                value: ytDuration > 0 ? ytPosition.clamp(0.0, ytDuration) : 0,
                max: ytDuration > 0 ? ytDuration : 1,
                onChanged: ytDuration > 0 ? (v) => onYtSeek(v) : null,
                activeColor: kAccent,
                inactiveColor: kBorder,
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_formatTime(ytPosition), style: const TextStyle(color: kMuted, fontFamily: 'monospace', fontSize: 10)),
                Text(_formatTime(ytDuration), style: const TextStyle(color: kMuted, fontFamily: 'monospace', fontSize: 10)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.volume_down, size: 16, color: kMuted),
                Expanded(
                  child: Slider(
                    value: ytVolume,
                    max: 100,
                    onChanged: (v) => onYtVolume(v),
                    activeColor: kGold,
                    inactiveColor: kBorder,
                  ),
                ),
                Icon(Icons.volume_up, size: 16, color: kMuted),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onYtPlayPause,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kAccent.withOpacity(0.4))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(ytPlaying ? Icons.pause : Icons.play_arrow, size: 16, color: kAccent),
                        const SizedBox(width: 6),
                        Text(ytPlaying ? 'Pause' : 'Play',
                            style: const TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: onYtStop,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade800.withOpacity(0.4))),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.stop, size: 16, color: Colors.red),
                        SizedBox(width: 6),
                        Text('Stop', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ])),

        const SizedBox(height: 12),

        // Uploaded files list
        appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            label('UPLOADED FILES'),
            if (uploadedFiles.isNotEmpty) Text('${uploadedFiles.length} files', style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontSize: 10)),
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
                Text('Upload PDF, PPT or a video to display on TV', style: TextStyle(color: Color(0xFF1a2d45), fontSize: 9)),
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
              final isVideo = fileType == 'video';
              final ext = fileName.split('.').last.toUpperCase();

              String castLabel() {
                if (isPdf) return 'Cast PDF to TV';
                if (isVideo) return 'Cast Video to TV';
                return 'Cast PPT to TV';
              }

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
                          child: Text(isPdf ? 'PDF' : (isVideo ? ext : 'PPT'), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: fileColor(fileType), letterSpacing: 0.5)),
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
                    child: SizedBox(width: double.infinity, child: castFileBtn(castLabel(), () => onCastFile(idx))),
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
