import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Screen 5 — Files & media hub: dashed upload dropzone, type filter badges
/// and the "Your Files" grid/list of uploaded documents and videos.
class FilesHubScreen extends StatefulWidget {
  final List<Map<String, dynamic>> uploadedFiles;
  final bool isUploading;
  final int activeFileIndex;
  final TextEditingController ytUrlCtrl;
  final bool isVideoPlaying;
  final String? activeVideoTitle;
  final VoidCallback? onOpenVideoController;
  final VoidCallback? onVideoPlayPause;
  final VoidCallback? onVideoStop;
  final VoidCallback onPickAndUploadFile;
  final ValueChanged<int> onCastFile;
  final ValueChanged<int> onDeleteFile;
  final VoidCallback onCastYouTubeUrl;
  final VoidCallback onBack;

  const FilesHubScreen({
    super.key,
    required this.uploadedFiles,
    required this.isUploading,
    required this.activeFileIndex,
    required this.ytUrlCtrl,
    this.isVideoPlaying = false,
    this.activeVideoTitle,
    this.onOpenVideoController,
    this.onVideoPlayPause,
    this.onVideoStop,
    required this.onPickAndUploadFile,
    required this.onCastFile,
    required this.onDeleteFile,
    required this.onCastYouTubeUrl,
    required this.onBack,
  });

  @override
  State<FilesHubScreen> createState() => _FilesHubScreenState();
}

class _FilesHubScreenState extends State<FilesHubScreen> {
  String _filter = 'All';
  static const _badges = [
    (label: 'PDF', type: 'pdf', color: Color(0xFFEF4444), icon: Icons.picture_as_pdf_rounded),
    (label: 'PPT', type: 'pptx', color: Color(0xFFF97316), icon: Icons.co_present_rounded),
    (label: 'Video', type: 'video', color: Color(0xFF8B5CF6), icon: Icons.play_circle_fill_rounded),
    (label: 'Image', type: 'image', color: Color(0xFF10B981), icon: Icons.image_rounded),
  ];

  String _typeOf(Map<String, dynamic> f) => f['type'] as String? ?? 'other';

  ({String label, Color color, IconData icon}) _badgeFor(String type) {
    final hit = _badges.where((b) => b.type == type).toList();
    if (hit.isNotEmpty) {
      return (
        label: hit.first.label,
        color: hit.first.color,
        icon: hit.first.icon
      );
    }
    return (label: 'File', color: AppColors.textMuted, icon: Icons.insert_drive_file_rounded);
  }

  String _sizeOf(Map<String, dynamic> f) {
    final bytes = (f['size'] as num?)?.toInt() ?? 0;
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.uploadedFiles
        .where((f) => _filter == 'All' || _typeOf(f) == _filter)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.folder_rounded,
                  size: 24, color: AppColors.cyan),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Files',
                    style: TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ),
              IconButton(
                tooltip: 'Upload',
                onPressed: widget.onPickAndUploadFile,
                icon: const Icon(Icons.search, color: AppColors.textMuted),
              ),
              IconButton(
                tooltip: 'List view',
                onPressed: () {},
                icon: const Icon(Icons.format_list_bulleted_rounded,
                    color: AppColors.textMuted),
              ),
            ]),
            const SizedBox(height: 8),

            // ── Dashed upload dropzone ──
            _Dropzone(
              isUploading: widget.isUploading,
              onTap: widget.onPickAndUploadFile,
            ),
            const SizedBox(height: 16),

            // ── Type filter badges (4 columns) ──
            Row(
              children: [
                for (final b in _badges) ...[
                  Expanded(child: _TypeBadge(badge: b, selected: _filter == b.type, onTap: () {
                    setState(() => _filter = _filter == b.type ? 'All' : b.type);
                  })),
                  if (b != _badges.last) const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Quick YouTube cast ──
            _YouTubeRow(ctrl: widget.ytUrlCtrl, onCast: widget.onCastYouTubeUrl),
            const SizedBox(height: 18),

            // ── Your files ──
            Row(children: [
              const Text('Your Files',
                  style: TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (widget.uploadedFiles.isNotEmpty && _filter != 'All')
                GestureDetector(
                  onTap: () => setState(() => _filter = 'All'),
                  child: const Text('Clear filter',
                      style: TextStyle(color: AppColors.cyan, fontSize: 12)),
                ),
            ]),
            const SizedBox(height: 10),
            if (files.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                alignment: Alignment.center,
                child: const Text(
                    'No files here yet — tap the dropzone to upload',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12)),
              )
            else
              ...files.asMap().entries.map((e) {
                final abs = widget.uploadedFiles.indexOf(e.value);
                final badge = _badgeFor(_typeOf(e.value));
                final active = abs == widget.activeFileIndex;
                return _FileCard(
                  name: e.value['name'] as String? ?? 'File',
                  size: _sizeOf(e.value),
                  badge: badge,
                  active: active,
                  onPlay: () => widget.onCastFile(abs),
                  onDelete: () => widget.onDeleteFile(abs),
                );
              }),
          ]),
        ),
      ),
      bottomNavigationBar: widget.activeVideoTitle != null &&
              widget.activeVideoTitle!.isNotEmpty
          ? Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceSolid,
                borderRadius: BorderRadius.circular(AppRadii.cardMd),
                border: Border.all(color: AppColors.cyan.withOpacity(0.5), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withOpacity(0.18),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.play_circle_fill_rounded,
                        color: AppColors.cyan, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.onOpenVideoController,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.activeVideoTitle!,
                              style: const TextStyle(
                                  color: AppColors.textHigh,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          const Row(
                            children: [
                              Icon(Icons.tv_rounded, size: 12, color: AppColors.green),
                              SizedBox(width: 4),
                              Text('Live Video • Tap for Full Controller',
                                  style: TextStyle(
                                      color: AppColors.cyan, fontSize: 10.5)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.onVideoPlayPause != null)
                    IconButton(
                      icon: Icon(
                        widget.isVideoPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: AppColors.cyan,
                        size: 30,
                      ),
                      onPressed: widget.onVideoPlayPause,
                    ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen_rounded,
                        color: AppColors.textHigh, size: 24),
                    onPressed: widget.onOpenVideoController,
                  ),
                  if (widget.onVideoStop != null)
                    IconButton(
                      icon: const Icon(Icons.stop_circle_rounded,
                          color: AppColors.red, size: 22),
                      onPressed: widget.onVideoStop,
                    ),
                ],
              ),
            )
          : null,
    );
  }
}

// ── Dropzone ────────────────────────────────────────────────────────────────

class _Dropzone extends StatelessWidget {
  final bool isUploading;
  final VoidCallback onTap;
  const _Dropzone({required this.isUploading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isUploading ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.cardLg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.45),
            borderRadius: BorderRadius.circular(AppRadii.cardLg),
            border: Border.all(
                color: AppColors.cyan.withOpacity(0.45),
                width: 1.5,
                style: BorderStyle.solid),
            boxShadow: [
              BoxShadow(
                  color: AppColors.cyan.withOpacity(0.10), blurRadius: 18)
            ],
          ),
          child: Column(children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.cyan.withOpacity(0.30),
                  AppColors.cyan.withOpacity(0.0),
                ]),
              ),
              child: isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.cyan))
                  : const Icon(Icons.cloud_upload_rounded,
                      size: 34, color: AppColors.cyan),
            ),
            const SizedBox(height: 10),
            Text(isUploading ? 'Uploading…' : 'Tap to Upload Files',
                style: const TextStyle(
                    color: AppColors.textHigh,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('PDF, PPT, PPTX, MP4, MOV, JSON',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          ]),
        ),
      ),
    );
  }
}

// ── Type badge ──────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final ({String label, String type, Color color, IconData icon}) badge;
  final bool selected;
  final VoidCallback onTap;

  const _TypeBadge({required this.badge, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 86,
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(selected ? 0.85 : 0.5),
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: selected ? badge.color : AppColors.borderWhite,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: badge.color.withOpacity(0.3), blurRadius: 14)]
              : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(badge.icon, size: 24, color: badge.color),
          const SizedBox(height: 6),
          Text(badge.label,
              style: TextStyle(
                  color: selected ? badge.color : AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

// ── YouTube quick cast ──────────────────────────────────────────────────────

class _YouTubeRow extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onCast;
  const _YouTubeRow({required this.ctrl, required this.onCast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: glass(
          radius: AppRadii.card,
          opacity: 0.55,
          shadow: const []),
      child: Row(children: [
        const Icon(Icons.ondemand_video_rounded,
            size: 22, color: AppColors.red),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: AppColors.textHigh, fontSize: 12.5),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Paste a YouTube URL to cast…',
              hintStyle:
                  TextStyle(color: AppColors.textMuted, fontSize: 12),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onCast,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cyan.withOpacity(0.16),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border:
                  Border.all(color: AppColors.cyan.withOpacity(0.55)),
            ),
            child: const Text('Cast',
                style: TextStyle(
                    color: AppColors.cyan,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

// ── File card ───────────────────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  final String name;
  final String size;
  final ({String label, Color color, IconData icon}) badge;
  final bool active;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _FileCard({
    required this.name,
    required this.size,
    required this.badge,
    required this.active,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(active ? 0.85 : 0.5),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
            color: active
                ? AppColors.cyan.withOpacity(0.7)
                : AppColors.borderWhite,
            width: active ? 1.4 : 1),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: badge.color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badge.color.withOpacity(0.6)),
          ),
          child: Icon(badge.icon, size: 24, color: badge.color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(
                    size.isEmpty
                        ? badge.label
                        : '${badge.label} • $size',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11.5)),
              ]),
        ),
        GestureDetector(
          onTap: onPlay,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? AppColors.green.withOpacity(0.2)
                  : AppColors.cyan.withOpacity(0.14),
              border: Border.all(
                  color: active
                      ? AppColors.green
                      : AppColors.cyan.withOpacity(0.55)),
            ),
            child: Icon(
                active ? Icons.tv_rounded : Icons.play_arrow_rounded,
                color: active ? AppColors.green : AppColors.cyan,
                size: 22),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _menu(context),
          child: const SizedBox(
            width: 30,
            height: 38,
            child: Icon(Icons.more_vert_rounded,
                color: AppColors.textMuted, size: 20),
          ),
        ),
      ]),
    );
  }

  void _menu(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppColors.surfaceSolid,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.play_circle_outline_rounded,
                color: AppColors.cyan, size: 22),
            title: const Text('Cast to TV',
                style: TextStyle(
                    color: AppColors.textHigh,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              onPlay();
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_outline_rounded, color: AppColors.red, size: 22),
            title: const Text('Delete',
                style: TextStyle(
                    color: AppColors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              onDelete();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
