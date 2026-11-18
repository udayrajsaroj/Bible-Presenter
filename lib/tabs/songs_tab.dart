import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';

class SongsTab extends StatelessWidget {
  final List<Map<String, dynamic>> allSongs;
  final List<Map<String, dynamic>> filteredSongs;
  final bool songsLoaded;
  final String songSearchQuery;
  final int selectedSongIndex;
  final int selectedStanzaIndex;
  final TextEditingController songSearchCtrl;
  final bool importingWord;
  final void Function(String query) onFilterSongs;
  final VoidCallback onShowAddSongModal;
  final VoidCallback onShowCreateScheduleModal;
  final VoidCallback onImportWord;
  final VoidCallback onExportWord;
  final VoidCallback onEditSlides;
  final void Function(int idx) onDeleteSong;
  final void Function(int idx) onSelectSong;
  final void Function(int idx) onSelectStanza;
  final VoidCallback onCastSong;
  final VoidCallback onPrevStanza;
  final VoidCallback onNextStanza;
  final VoidCallback onOpenFullscreen;

  // Schedule related
  final List<Map<String, dynamic>> schedules;
  final bool scheduleMode;
  final int activeScheduleIndex;
  final void Function(int idx) onOpenScheduleDetail;
  final void Function(int idx) onDeleteSchedule;
  final void Function(int idx) onStartSchedulePresentation;

  const SongsTab({
    super.key,
    required this.allSongs,
    required this.filteredSongs,
    required this.songsLoaded,
    required this.songSearchQuery,
    required this.selectedSongIndex,
    required this.selectedStanzaIndex,
    required this.songSearchCtrl,
    required this.importingWord,
    required this.onFilterSongs,
    required this.onShowAddSongModal,
    required this.onShowCreateScheduleModal,
    required this.onImportWord,
    required this.onExportWord,
    required this.onEditSlides,
    required this.onDeleteSong,
    required this.onSelectSong,
    required this.onSelectStanza,
    required this.onCastSong,
    required this.onPrevStanza,
    required this.onNextStanza,
    required this.onOpenFullscreen,
    required this.schedules,
    required this.scheduleMode,
    required this.activeScheduleIndex,
    required this.onOpenScheduleDetail,
    required this.onDeleteSchedule,
    required this.onStartSchedulePresentation,
  });

  @override
  Widget build(BuildContext context) {
    if (!songsLoaded) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: kAccent),
            SizedBox(height: 16),
            Text('Loading songs...',
                style: TextStyle(color: kMuted, fontSize: 13)),
          ],
        ),
      );
    }

    final selectedSong =
        selectedSongIndex >= 0 && selectedSongIndex < filteredSongs.length
            ? filteredSongs[selectedSongIndex]
            : null;
    final stanzas = selectedSong?['stanzas'] as List<String>? ?? [];
    final currentStanza =
        selectedStanzaIndex < stanzas.length ? stanzas[selectedStanzaIndex] : '';

    return Column(
      children: [
        // ── Top pinned controls: Search card + Quick action buttons ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: appCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label('SEARCH SONGS'),
                const SizedBox(height: 8),
                TextField(
                  controller: songSearchCtrl,
                  style: const TextStyle(color: kText, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by title or lyrics...',
                    hintStyle: const TextStyle(color: kMuted, fontSize: 12),
                    prefixIcon:
                        const Icon(Icons.search, size: 18, color: kAccent),
                    filled: true,
                    fillColor: kBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kAccent)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    suffixIcon: songSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                size: 16, color: kMuted),
                            onPressed: () {
                              songSearchCtrl.clear();
                              onFilterSongs('');
                            })
                        : null,
                  ),
                  onChanged: onFilterSongs,
                ),
                if (songSearchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${filteredSongs.length} songs found',
                        style: const TextStyle(color: kMuted, fontSize: 9)),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onShowAddSongModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade900.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.green.shade800.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 16, color: Colors.green),
                        SizedBox(width: 6),
                        Text('Add Song',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onShowCreateScheduleModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade900.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.purple.shade800.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.purple),
                        SizedBox(width: 6),
                        Text('Schedule',
                            style: TextStyle(
                                color: Colors.purple,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: importingWord ? null : onImportWord,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.blue.shade800.withOpacity(0.4)),
                  ),
                  child: importingWord
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.blue, strokeWidth: 2))
                      : const Icon(Icons.upload_file,
                          size: 18, color: Colors.blue),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onOpenFullscreen,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kAccent.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.fullscreen, color: kAccent, size: 20),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── Expanded Scrollable View: fills 100% of remaining screen height (no blank space) ──
        Expanded(
          child: CustomScrollView(
            slivers: [
              // Schedules list (if schedules exist)
              if (!scheduleMode && schedules.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: appCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SCHEDULES',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                  letterSpacing: 1.5)),
                          const SizedBox(height: 8),
                          ...schedules.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final sch = entry.value;
                            final songs = sch['songs'] as List? ?? [];
                            final isActive = idx == activeScheduleIndex;
                            return GestureDetector(
                              onTap: () => onOpenScheduleDetail(idx),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.purple.shade900.withOpacity(0.2)
                                      : kBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: isActive
                                          ? Colors.purple.shade700
                                              .withOpacity(0.5)
                                          : kBorder),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color: Colors.purple.shade900
                                              .withOpacity(0.3),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: const Icon(Icons.calendar_today,
                                          size: 16, color: Colors.purple),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(sch['name'] ?? '',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: kText,
                                                  fontSize: 12),
                                              overflow:
                                                  TextOverflow.ellipsis),
                                          const SizedBox(height: 2),
                                          Text(
                                              '${sch['date'] ?? ''}  •  ${songs.length} song${songs.length != 1 ? 's' : ''}',
                                              style: const TextStyle(
                                                  color: kMuted, fontSize: 9)),
                                        ],
                                      ),
                                    ),
                                    if (songs.isNotEmpty)
                                      GestureDetector(
                                        onTap: () =>
                                            onStartSchedulePresentation(idx),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                              color: Colors.purple.shade700
                                                  .withOpacity(0.3),
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: const Icon(Icons.play_arrow,
                                              size: 20, color: Colors.purple),
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => onDeleteSchedule(idx),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                            color: Colors.red.shade900
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Icon(Icons.delete_outline,
                                            size: 16,
                                            color: Colors.red.shade400),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right,
                                        size: 18, color: kMuted),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),

              // Selected song card (actions + preview + stanza control)
              if (selectedSong != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: appCard(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  selectedSong['title'] as String? ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: kGold,
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${selectedStanzaIndex + 1} / ${stanzas.length}',
                                style: const TextStyle(
                                    color: kAccent,
                                    fontFamily: 'monospace',
                                    fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: kBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: kGold.withOpacity(0.2))),
                            child: Text(
                              currentStanza,
                              style: const TextStyle(
                                  color: kText, fontSize: 12, height: 1.6),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (stanzas.length > 1)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(stanzas.length, (i) {
                                final isActive = i == selectedStanzaIndex;
                                return GestureDetector(
                                  onTap: () => onSelectStanza(i),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    width: isActive ? 20 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isActive ? kGold : kBorder,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          if (stanzas.length > 1) const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                  child: secondaryBtn(
                                      'Prev',
                                      selectedStanzaIndex > 0
                                          ? onPrevStanza
                                          : null)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: primaryBtn('Cast', onCastSong)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: secondaryBtn(
                                      'Next',
                                      selectedStanzaIndex < stanzas.length - 1
                                          ? onNextStanza
                                          : null)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: onEditSlides,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: kAccent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: kAccent.withOpacity(0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.auto_awesome_motion,
                                            size: 14, color: kAccent),
                                        SizedBox(width: 6),
                                        Text('Edit Slides',
                                            style: TextStyle(
                                                color: kAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: onExportWord,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.blue.shade900.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.blue.shade800
                                              .withOpacity(0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.description,
                                            size: 14, color: Colors.blue),
                                        SizedBox(width: 6),
                                        Text('Export Word',
                                            style: TextStyle(
                                                color: Colors.blue,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Songs list header strip
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      label('ALL SONGS'),
                      Text(
                        '${filteredSongs.length} song${filteredSongs.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: kMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Empty state when no songs match
              if (filteredSongs.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.music_off,
                            size: 36, color: Color(0xFF1a2d45)),
                        const SizedBox(height: 10),
                        Text(
                          songSearchQuery.isEmpty
                              ? 'No songs loaded'
                              : 'No songs found',
                          style:
                              const TextStyle(color: kMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Full virtualized song list: expands to entire viewport, smoothly scrollable
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final song = filteredSongs[i];
                        final isSelected = i == selectedSongIndex;
                        final isManual = song['source'] == 'manual';
                        return GestureDetector(
                          onTap: () => onSelectSong(i),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0c1f3a)
                                  : kBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? kAccent.withOpacity(0.7)
                                    : kBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isManual
                                      ? Icons.edit_note
                                      : Icons.library_music,
                                  size: 15,
                                  color: isSelected ? kAccent : kMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    song['title'] as String? ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? kText : kMuted,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle,
                                      size: 14, color: kAccent),
                                if (isManual) ...[
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () =>
                                        onDeleteSong(allSongs.indexOf(song)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(Icons.delete_outline,
                                          size: 15,
                                          color: Colors.red.shade400),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: filteredSongs.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 84),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
