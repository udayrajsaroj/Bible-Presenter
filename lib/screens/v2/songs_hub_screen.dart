import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/v2/top_bar.dart';

/// Screen 3 — Songs hub: language filter pills, gradient song list and a
/// floating glass mini-player dock pinned above the bottom bar.
class SongsHubScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allSongs;
  final bool songsLoaded;
  final TextEditingController searchCtrl;
  final int selectedSongIndex;
  final VoidCallback onAddSong;
  final VoidCallback onImportWord;
  final ValueChanged<String> onFilterSongs;
  final ValueChanged<int> onSelectSong;
  final ValueChanged<int> onPlaySong;
  final ValueChanged<int> onEditSong;
  final ValueChanged<int> onDeleteSong;
  final VoidCallback onBack;

  const SongsHubScreen({
    super.key,
    required this.allSongs,
    required this.songsLoaded,
    required this.searchCtrl,
    required this.selectedSongIndex,
    required this.onAddSong,
    required this.onImportWord,
    required this.onFilterSongs,
    required this.onSelectSong,
    required this.onPlaySong,
    required this.onEditSong,
    required this.onDeleteSong,
    required this.onBack,
  });

  @override
  State<SongsHubScreen> createState() => _SongsHubScreenState();
}

class _SongsHubScreenState extends State<SongsHubScreen> {
  String _lang = 'All';
  static const _langs = ['All', 'English', 'Hindi', 'Others'];

  /// Rotating gradient palette for the song icon squircles.
  static const _palettes = [
    [Color(0xFF0284C7), Color(0xFF00D2FF)],
    [Color(0xFFEA580C), Color(0xFFFB923C)],
    [Color(0xFF7E22CE), Color(0xFFA855F7)],
    [Color(0xFFEC4899), Color(0xFFF472B6)],
    [Color(0xFF059669), Color(0xFF34D399)],
    [Color(0xFF4F46E5), Color(0xFF818CF8)],
  ];

  String _songLanguage(Map<String, dynamic> song) {
    final stanzas = song['stanzas'] as List? ?? [];
    final sample =
        '${song['title'] ?? ''} ${stanzas.join(' ')}';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(sample)) return 'Hindi';
    if (RegExp(r'[A-Za-z]').hasMatch(sample)) return 'English';
    return 'Others';
  }

  List<Map<String, dynamic>> get _filtered => widget.allSongs
      .where((s) => _lang == 'All' || _songLanguage(s) == _lang)
      .toList();

  Map<String, dynamic>? get _selectedSong =>
      widget.selectedSongIndex >= 0 &&
              widget.selectedSongIndex < widget.allSongs.length
          ? widget.allSongs[widget.selectedSongIndex]
          : null;

  void _step(int delta) {
    final songs = _filtered;
    if (songs.isEmpty) return;
    final cur = widget.selectedSongIndex;
    // Find current song position within the filtered list.
    final curSong =
        cur >= 0 && cur < widget.allSongs.length ? widget.allSongs[cur] : null;
    var idx = curSong != null ? songs.indexOf(curSong) : -1;
    idx = (idx + delta).clamp(0, songs.length - 1);
    final next = songs[idx];
    final abs = widget.allSongs.indexOf(next);
    widget.onSelectSong(abs);
    widget.onPlaySong(abs);
  }

  @override
  Widget build(BuildContext context) {
    final songs = _filtered;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          TopBarV2(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: widget.onBack,
            ),
            icon: Icons.library_music_rounded,
            title: 'Songs',
            actions: [
              IconButton(
                tooltip: 'Add song',
                onPressed: widget.onAddSong,
                icon:
                    const Icon(Icons.add_circle_outline_rounded,
                        color: AppColors.textMuted),
              ),
              IconButton(
                tooltip: 'Import Word file',
                onPressed: widget.onImportWord,
                icon: const Icon(Icons.upload_file_rounded,
                    color: AppColors.textMuted),
              ),
            ],
          ),
          FilterPills(
            options: _langs,
            selected: _lang,
            onSelect: (v) => setState(() => _lang = v),
          ),
          // Search field.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: TextField(
              controller: widget.searchCtrl,
              onChanged: widget.onFilterSongs,
              style: const TextStyle(
                  color: AppColors.textHigh, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Search songs…',
                hintStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textMuted, size: 20),
                filled: true,
                fillColor: AppColors.surface.withOpacity(0.6),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppRadii.button),
                  borderSide: const BorderSide(color: AppColors.borderWhite),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppRadii.button),
                  borderSide: const BorderSide(color: AppColors.borderWhite),
                ),
              ),
            ),
          ),
          Expanded(
            child: widget.songsLoaded && songs.isEmpty
                ? _EmptySongs(onImport: widget.onImportWord)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: songs.length,
                    itemBuilder: (ctx, i) {
                      final song = songs[i];
                      final abs = widget.allSongs.indexOf(song);
                      final active = abs == widget.selectedSongIndex;
                      final palette =
                          _palettes[abs % _palettes.length];
                      final stanzas = song['stanzas'] as List? ?? [];
                      return _SongTile(
                        title: song['title'] as String? ?? 'Untitled',
                        meta:
                            '${_songLanguage(song)} • ${stanzas.length} stanzas',
                        palette: palette,
                        active: active,
                        onPlay: () => widget.onPlaySong(abs),
                        onSelect: () => widget.onSelectSong(abs),
                        onMore: () => _songMenu(ctx, abs),
                      );
                    },
                  ),
          ),
        ]),
      ),
      // Floating mini player dock.
      bottomNavigationBar: _MiniPlayer(
        song: _selectedSong,
        onPrev: () => _step(-1),
        onPlay: () {
          if (_selectedSong != null) {
            widget.onPlaySong(widget.selectedSongIndex);
          }
        },
        onNext: () => _step(1),
      ),
    );
  }

  void _songMenu(BuildContext ctx, int abs) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppColors.surfaceSolid,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          _menuTile(Icons.play_circle_outline_rounded, 'Play on TV',
              () => widget.onPlaySong(abs)),
          _menuTile(Icons.edit_note_rounded, 'Edit slides',
              () => widget.onEditSong(abs)),
          _menuTile(Icons.delete_outline_rounded, 'Delete song', () {
            Navigator.pop(ctx);
            widget.onDeleteSong(abs);
          }, danger: true),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    return ListTile(
      leading: Icon(icon,
          color: danger ? AppColors.red : AppColors.cyan, size: 22),
      title: Text(label,
          style: TextStyle(
              color: danger ? AppColors.red : AppColors.textHigh,
              fontSize: 14,
              fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

class _SongTile extends StatelessWidget {
  final String title;
  final String meta;
  final List<Color> palette;
  final bool active;
  final VoidCallback onPlay;
  final VoidCallback onSelect;
  final VoidCallback onMore;

  const _SongTile({
    required this.title,
    required this.meta,
    required this.palette,
    required this.active,
    required this.onPlay,
    required this.onSelect,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.surface.withOpacity(0.85)
              : AppColors.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: active
                ? AppColors.cyan.withOpacity(0.7)
                : AppColors.borderWhite,
            width: active ? 1.4 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: AppColors.cyan.withOpacity(0.18), blurRadius: 14)
                ]
              : null,
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: palette),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: palette.last.withOpacity(0.4), blurRadius: 12)
              ],
            ),
            child:
                const Icon(Icons.music_note_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textHigh,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(meta,
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
                color: AppColors.cyan.withOpacity(0.14),
                border: Border.all(color: AppColors.cyan.withOpacity(0.55)),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: AppColors.cyan, size: 24),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onMore,
            child: const SizedBox(
              width: 30,
              height: 38,
              child: Icon(Icons.more_vert_rounded,
                  color: AppColors.textMuted, size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  final Map<String, dynamic>? song;
  final VoidCallback onPrev;
  final VoidCallback onPlay;
  final VoidCallback onNext;

  const _MiniPlayer({
    required this.song,
    required this.onPrev,
    required this.onPlay,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final title = song?['title'] as String? ?? 'No song selected';
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: glass(
            radius: AppRadii.cardLg,
            borderColor: AppColors.borderGlow,
            opacity: 0.75,
            shadow: [
              BoxShadow(
                  color: AppColors.cyan.withOpacity(0.12), blurRadius: 20)
            ],
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Image.asset(AppAssets.heroVerse, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold)),
            ),
            IconButton(
              onPressed: song == null ? null : onPrev,
              icon: const Icon(Icons.skip_previous_rounded,
                  color: AppColors.textHigh, size: 26),
            ),
            GestureDetector(
              onTap: song == null ? null : onPlay,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [
                    Color(0xFF00D2FF),
                    Color(0xFF38BDF8)
                  ]),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.cyan.withOpacity(0.5), blurRadius: 14)
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 26),
              ),
            ),
            IconButton(
              onPressed: song == null ? null : onNext,
              icon: const Icon(Icons.skip_next_rounded,
                  color: AppColors.textHigh, size: 26),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EmptySongs extends StatelessWidget {
  final VoidCallback onImport;
  const _EmptySongs({required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.music_off_rounded,
            size: 42, color: AppColors.textMuted),
        const SizedBox(height: 12),
        const Text('No songs yet',
            style: TextStyle(
                color: AppColors.textHigh,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Import a Word file to build your songbook',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onImport,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.purple,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button)),
          ),
          icon: const Icon(Icons.upload_file_rounded, size: 18),
          label: const Text('Import Word file'),
        ),
      ]),
    );
  }
}
