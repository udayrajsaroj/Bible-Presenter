import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import 'top_notification.dart';

/// Full-screen song slide editor — reorder slides by dragging, duplicate a
/// slide, edit its text, preview any slide on the TV. Works on a local copy;
/// nothing is persisted until Save.
class SongSlideEditorScreen extends StatefulWidget {
  final String title;
  final List<String> stanzas;
  final bool isManualSong;

  /// Emits a cast-song payload for one slide of the edited copy (preview).
  final void Function(int slideIndex, List<String> stanzas, String title)
      onPreviewSlide;

  /// Persists the edit. Returns 'updated' (manual song saved in place) or
  /// 'copied' (asset song saved as an editable copy), null when rejected.
  final Future<String?> Function(String title, List<String> stanzas) onSave;

  const SongSlideEditorScreen({
    super.key,
    required this.title,
    required this.stanzas,
    required this.isManualSong,
    required this.onPreviewSlide,
    required this.onSave,
  });

  @override
  State<SongSlideEditorScreen> createState() => _SongSlideEditorScreenState();
}

class _SongSlideEditorScreenState extends State<SongSlideEditorScreen> {
  late final TextEditingController _titleCtrl;
  late List<String> _stanzas;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.title);
    _stanzas = List.of(widget.stanzas);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _editSlide(int index) {
    final ctrl = TextEditingController(text: _stanzas[index]);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg2,
        title: Text('Slide ${index + 1}', style: const TextStyle(color: kText)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 8,
          minLines: 4,
          style: const TextStyle(color: kText, fontSize: 14, height: 1.6),
          decoration: InputDecoration(
            hintText: 'Slide text — one line per row…\n[Chorus] labels allowed',
            hintStyle: const TextStyle(color: kMuted, fontSize: 12),
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
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: kMuted))),
          TextButton(
            onPressed: () {
              setState(() => _stanzas[index] = ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save Slide',
                style: TextStyle(color: kAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  void _duplicateSlide(int index) {
    setState(() => _stanzas.insert(index + 1, _stanzas[index]));
  }

  void _deleteSlide(int index) {
    if (_stanzas.length <= 1) return; // a song needs at least one slide
    setState(() => _stanzas.removeAt(index));
  }

  void _addSlide() {
    setState(() => _stanzas.add(''));
    _editSlide(_stanzas.length - 1);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_titleCtrl.text.trim().isEmpty) {
      TopNotification.show(context, 'Give the song a title first',
          isError: true);
      return;
    }
    if (_stanzas.every((s) => s.trim().isEmpty)) {
      TopNotification.show(context, 'The song has no slide text',
          isError: true);
      return;
    }
    setState(() => _saving = true);
    final result = await widget.onSave(_titleCtrl.text, _stanzas);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg2,
        iconTheme: const IconThemeData(color: kText),
        title: const Text('Edit Song Slides',
            style: TextStyle(color: kText, fontSize: 16)),
        actions: [
          if (widget.isManualSong)
            const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Center(
                    child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('saves in place',
                            style: TextStyle(color: kMuted, fontSize: 9))))),
          if (!widget.isManualSong)
            const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Center(
                    child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('saves as copy',
                            style: TextStyle(color: kMuted, fontSize: 9))))),
          IconButton(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(color: kAccent, strokeWidth: 2))
                  : const Icon(Icons.check, color: Colors.green)),
        ],
      ),
      body: Column(children: [
        // Song title field
        Container(
          color: kBg2,
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: kText, fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Song title',
              labelStyle: const TextStyle(color: kMuted, fontSize: 11),
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
            ),
          ),
        ),
        // Slide count hint
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 12, color: kMuted),
            const SizedBox(width: 6),
            Expanded(
                child: Text(
                    'Drag ⠿ to reorder • copy duplicates a slide • tap text to edit • ▶ previews on TV',
                    style: const TextStyle(color: kMuted, fontSize: 9.5))),
          ]),
        ),
        // Slides list (drag to reorder)
        Expanded(
          child: _stanzas.isEmpty
              ? const Center(
                  child: Text('No slides — add one below',
                      style: TextStyle(color: kMuted, fontSize: 12)))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  itemCount: _stanzas.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final s = _stanzas.removeAt(oldIndex);
                      _stanzas.insert(newIndex, s);
                    });
                  },
                  itemBuilder: (ctx, i) {
                    final empty = _stanzas[i].trim().isEmpty;
                    return Container(
                      key: ValueKey('slide-$i-${_stanzas[i].hashCode}'),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: kBg2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: empty
                                ? Colors.red.withOpacity(0.4)
                                : kBorder),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Column(children: [
                              const Icon(Icons.drag_indicator,
                                  size: 18, color: kMuted),
                              Text('${i + 1}',
                                  style: const TextStyle(
                                      color: kGold,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _editSlide(i),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _stanzas[i].isEmpty
                                    ? '(empty slide — tap to write)'
                                    : _stanzas[i],
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: empty ? kMuted : kText,
                                  fontSize: 12,
                                  height: 1.5,
                                  fontStyle: empty
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _iconBtn(Icons.slideshow, kAccent,
                            () => widget.onPreviewSlide(i, _stanzas, _titleCtrl.text)),
                        _iconBtn(Icons.edit_outlined, kGold, () => _editSlide(i)),
                        _iconBtn(Icons.copy, Colors.green.shade400,
                            () => _duplicateSlide(i)),
                        _iconBtn(
                            Icons.delete_outline,
                            _stanzas.length > 1
                                ? Colors.red.shade400
                                : kBorder,
                            _stanzas.length > 1 ? () => _deleteSlide(i) : null),
                      ]),
                    );
                  },
                ),
        ),
        // Add slide
        Container(
          color: kBg2,
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Expanded(child: secondaryBtn('+ Add Slide', _addSlide)),
            const SizedBox(width: 8),
            Expanded(child: primaryBtn(_saving ? 'Saving…' : 'Save Song', _saving ? null : _save)),
          ]),
        ),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Icon(icon, size: 17, color: onTap == null ? kBorder : color),
      ),
    );
  }
}
