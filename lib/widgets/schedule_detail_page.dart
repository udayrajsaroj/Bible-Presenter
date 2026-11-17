import 'package:flutter/material.dart';
import '../theme.dart';
import 'top_notification.dart';

class ScheduleDetailPage extends StatefulWidget {
  final Map<String, dynamic> schedule;
  final int scheduleIndex;
  final List<Map<String, dynamic>> allSongs;
  final void Function(int songIdx) onAddSong;
  final void Function(int pos) onRemoveSong;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final void Function(int oldPos, int newPos) onSongReorder;

  const ScheduleDetailPage({
    super.key,
    required this.schedule,
    required this.scheduleIndex,
    required this.allSongs,
    required this.onAddSong,
    required this.onRemoveSong,
    required this.onPlay,
    required this.onDelete,
    required this.onSongReorder,
  });

  @override
  State<ScheduleDetailPage> createState() => _ScheduleDetailPageState();
}

class _ScheduleDetailPageState extends State<ScheduleDetailPage> {
  bool _showAddSong = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final songs = widget.schedule['songs'] as List? ?? [];
    final name = widget.schedule['name'] ?? '';
    final date = widget.schedule['date'] ?? '';

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg2,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.close, color: Colors.red, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: kText)),
          Text('$date  •  ${songs.length} song${songs.length != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 10, color: kMuted)),
        ]),
        actions: [
          GestureDetector(
            onTap: () => setState(() => _showAddSong = !_showAddSong),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kAccent.withOpacity(0.3))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 14, color: kAccent),
                SizedBox(width: 4),
                Text('Add Song',
                    style: TextStyle(
                        color: kAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          GestureDetector(
            onTap: widget.onDelete,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.delete_outline,
                  size: 18, color: Colors.red.shade400),
            ),
          ),
        ],
      ),
      body: Column(children: [
        if (_showAddSong) _buildAddSongPanel(),
        Expanded(
          child: songs.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const Icon(Icons.music_off,
                          size: 48, color: Color(0xFF1a2d45)),
                      const SizedBox(height: 12),
                      const Text('No songs yet',
                          style: TextStyle(color: kMuted, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Tap "Add Song" to add songs to this schedule',
                          style:
                              TextStyle(color: Colors.white24, fontSize: 11)),
                    ]))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: songs.length,
                  onReorder: (old, new_) {
                    widget.onSongReorder(old, new_ > old ? new_ - 1 : new_);
                    setState(() {});
                  },
                  itemBuilder: (ctx, i) {
                    final s = songs[i];
                    final stanzas = List<String>.from(s['stanzas'] ?? []);
                    return Container(
                      key: ValueKey('song_$i'),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: kBg3,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorder)),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: kBorder,
                              borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.drag_indicator,
                              size: 16, color: kMuted),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: Colors.purple.shade900.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8)),
                          child: Center(
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      color: Colors.purple,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(s['title'] ?? '',
                                  style: const TextStyle(
                                      color: kText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(
                                  '${stanzas.length} stanza${stanzas.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                      color: kMuted, fontSize: 10)),
                            ])),
                        GestureDetector(
                          onTap: () {
                            widget.onRemoveSong(i);
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: Colors.red.shade900.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.close,
                                size: 14, color: Colors.red.shade400),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
        ),
        if (songs.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            decoration: const BoxDecoration(
                color: kBg2, border: Border(top: BorderSide(color: kBorder))),
            child: Row(children: [
              Expanded(
                  child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  widget.onPlay();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Colors.purple, Color(0xFF7C3AED)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Start Presentation',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5)),
                      ]),
                ),
              )),
            ]),
          ),
      ]),
    );
  }

  Widget _buildAddSongPanel() {
    final filteredList = _searchQuery.isEmpty
        ? widget.allSongs
        : widget.allSongs.where((song) {
            final title = (song['title'] as String? ?? '').toLowerCase();
            return title.contains(_searchQuery.toLowerCase());
          }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      color: kBg2,
      child: Column(children: [
        TextField(
          style: const TextStyle(color: kText, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search song to add...',
            hintStyle: const TextStyle(color: kMuted, fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 18, color: kAccent),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16, color: kMuted),
                    onPressed: () => setState(() => _searchQuery = ''))
                : null,
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filteredList.length > 20 ? 20 : filteredList.length,
            itemBuilder: (ctx, i) {
              final song = filteredList[i];
              final actualIdx = widget.allSongs.indexOf(song);
              return GestureDetector(
                onTap: () {
                  widget.onAddSong(actualIdx);
                  setState(() {});
                  TopNotification.show(context, '${song['title'] ?? ''} added!');
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorder)),
                  child: Row(children: [
                    const Icon(Icons.music_note, size: 14, color: kGold),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(song['title'] as String? ?? '',
                            style: const TextStyle(
                                color: kText,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.add_circle_outline,
                        size: 16, color: kAccent),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}
