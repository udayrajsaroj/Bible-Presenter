import 'package:flutter/material.dart';

import '../state/song_state.dart';
import '../theme.dart';
import '../widgets/presenter_shell.dart';

/// Dedicated live-casting screen for songs. Opens when a song is tapped in
/// the Songs tab (or Cast is pressed). The stanza index lives in SongState —
/// this screen listens to it, so chips, stage and dock stay 100% in sync
/// with whatever is on the TV.
class SongPresenterScreen extends StatefulWidget {
  final SongState songState;
  final ValueNotifier<Map<String, dynamic>> tvState;

  /// Selects a stanza in SongState and casts it.
  final void Function(int stanzaIndex) onSelectStanza;
  final VoidCallback onPrevStanza;
  final VoidCallback onNextStanza;
  final VoidCallback onLogo;
  final VoidCallback onBlackout;
  final VoidCallback onClear;
  final VoidCallback? onCastSong;

  const SongPresenterScreen({
    super.key,
    required this.songState,
    required this.tvState,
    required this.onSelectStanza,
    required this.onPrevStanza,
    required this.onNextStanza,
    required this.onLogo,
    required this.onBlackout,
    required this.onClear,
    this.onCastSong,
  });

  static final _labelRe = RegExp(r'^\s*\[([^\]]+)\]\s*$');

  /// Chip label for a stanza: uses its [Chorus]/[Verse] tag when present
  /// (numbered per occurrence), otherwise "Stanza N".
  static List<String> stanzaLabels(List<String> stanzas) {
    final counts = <String, int>{};
    return List.generate(stanzas.length, (i) {
      final m = _labelRe.firstMatch(stanzas[i].split('\n').first);
      if (m == null) return 'Stanza ${i + 1}';
      final base = m.group(1)!.trim();
      final n = (counts[base] ?? 0) + 1;
      counts[base] = n;
      return n == 1 ? base : '$base $n';
    });
  }

  @override
  State<SongPresenterScreen> createState() => _SongPresenterScreenState();
}

class _SongPresenterScreenState extends State<SongPresenterScreen> {
  final _stageScroll = ScrollController();

  /// Drops a leading [Label] line so the stage shows clean lyrics (the same
  /// rule the TV renderer applies).
  String _cleanLyrics(String stanza) =>
      stanza.replaceFirst(RegExp(r'^\s*\[[^\]]*\]\s*\n?'), '');

  @override
  void dispose() {
    _stageScroll.dispose();
    super.dispose();
  }

  void _onSwipe(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx;
    if (v < -120) widget.onNextStanza();
    if (v > 120) widget.onPrevStanza();
  }

  void _recastSong() {
    if (widget.onCastSong != null) {
      widget.onCastSong!();
    } else {
      widget.onSelectStanza(widget.songState.selectedStanzaIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.songState,
      builder: (context, _) {
        final song = widget.songState.selectedSong;
        final stanzas =
            List<String>.from(song?['stanzas'] as List? ?? const []);
        if (stanzas.isEmpty) {
          return PresenterScaffold(
            leading: _backBtn(context),
            title: song?['title'] as String? ?? 'Song',
            tvState: widget.tvState,
            headerActions: _headerActions(),
            body: Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                  Icon(Icons.music_off, size: 40, color: kMuted),
                  SizedBox(height: 12),
                  Text('This song has no slides',
                      style: TextStyle(color: kMuted, fontSize: 13)),
                ])),
          );
        }

        final labels = SongPresenterScreen.stanzaLabels(stanzas);
        final index =
            widget.songState.selectedStanzaIndex.clamp(0, stanzas.length - 1);
        final lyrics = _cleanLyrics(stanzas[index]);

        // Keep the stage scrolled to the top of the new stanza after a
        // stanza change (button, chip or swipe).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_stageScroll.hasClients && _stageScroll.offset != 0) {
            _stageScroll.jumpTo(0);
          }
        });

        final fs = widget.songState.fontSize;
        final previewFontSize = (26.0 * (fs / 44.0)).clamp(16.0, 48.0);

        return PresenterScaffold(
          leading: _backBtn(context),
          title: song?['title'] as String? ?? 'Song',
          subtitle: '${stanzas.length} slides',
          tvState: widget.tvState,
          headerActions: _headerActions(),
          headerStrip: _StanzaChips(
            labels: labels,
            activeIndex: index,
            onTap: widget.onSelectStanza,
          ),
          body: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: _onSwipe,
                  child: SingleChildScrollView(
                    controller: _stageScroll,
                    physics: const BouncingScrollPhysics(),
                    child: Container(
                      constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height - 280),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 24),
                      child: Text(
                        lyrics,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kText,
                          fontSize: previewFontSize,
                          height: 1.75,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 18)
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _SongTextControllerBar(
                fontSize: fs,
                onChanged: (newSize) {
                  widget.songState.fontSize = newSize;
                  _recastSong();
                },
              ),
            ],
          ),
          dockLeft: DockNavButton(
            label: 'PREV',
            icon: Icons.skip_previous,
            iconFirst: true,
            onTap: index > 0 ? widget.onPrevStanza : null,
          ),
          dockCenter: _SongDockCounter(
            tvState: widget.tvState,
            position: 'Stanza ${index + 1} / ${stanzas.length}',
          ),
          dockRight: DockNavButton(
            label: 'NEXT',
            icon: Icons.skip_next,
            onTap: index < stanzas.length - 1 ? widget.onNextStanza : null,
          ),
        );
      },
    );
  }

  Widget _backBtn(BuildContext context) => PresenterIconButton(
        icon: Icons.arrow_back,
        tooltip: 'Back to song library',
        onTap: () => Navigator.of(context).pop(),
      );

  List<Widget> _headerActions() {
    final curFs = widget.songState.fontSize;
    return [
      // Font size popover ("Tt") — identical to BiblePresenterScreen
      PopupMenuButton<int>(
        tooltip: 'Font size',
        icon: const Icon(Icons.format_size, size: 20, color: kText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: kBg2,
        onSelected: (size) {
          widget.songState.fontSize = size;
          _recastSong();
        },
        itemBuilder: (_) => [36, 44, 52, 60, 68, 80, 96, 112]
            .map((s) => PopupMenuItem<int>(
                value: s,
                child: Text('$s sp',
                    style: TextStyle(
                        color: curFs == s ? kGold : kText,
                        fontSize: 13,
                        fontWeight: curFs == s
                            ? FontWeight.bold
                            : FontWeight.normal))))
            .toList(),
      ),
      PresenterIconButton(
          icon: Icons.image_outlined,
          tooltip: 'Show church logo',
          onTap: widget.onLogo),
      PresenterIconButton(
          icon: Icons.dark_mode_outlined,
          tooltip: 'Blackout screen',
          onTap: widget.onBlackout),
      PresenterIconButton(
          icon: Icons.close,
          tooltip: 'Clear screen',
          onTap: widget.onClear),
    ];
  }
}

/// Dedicated phone-screen text controller bar for songs (A- / slider / A+ / size badge).
class _SongTextControllerBar extends StatelessWidget {
  final int fontSize;
  final ValueChanged<int> onChanged;

  const _SongTextControllerBar({
    required this.fontSize,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: kBg2.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder.withOpacity(0.8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // A- button (quick step down)
          IconButton(
            icon: const Text(
              'A-',
              style: TextStyle(
                color: kText,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            splashRadius: 18,
            tooltip: 'Decrease text size',
            onPressed: fontSize > 24
                ? () => onChanged((fontSize - 4).clamp(24, 120))
                : null,
          ),
          const SizedBox(width: 4),
          // Slider
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.5,
                activeTrackColor: kAccent,
                inactiveTrackColor: kBorder,
                thumbColor: kAccent,
                overlayColor: kAccent.withOpacity(0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: fontSize.toDouble().clamp(24.0, 120.0),
                min: 24,
                max: 120,
                onChanged: (val) => onChanged(val.round()),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Current font size display badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAccent.withOpacity(0.4)),
            ),
            child: Text(
              '$fontSize sp',
              style: const TextStyle(
                color: kAccent,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // A+ button (quick step up)
          IconButton(
            icon: const Text(
              'A+',
              style: TextStyle(
                color: kGold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            splashRadius: 18,
            tooltip: 'Increase text size',
            onPressed: fontSize < 120
                ? () => onChanged((fontSize + 4).clamp(24, 120))
                : null,
          ),
        ],
      ),
    );
  }
}

/// Dock center: position + live status from TV state.
class _SongDockCounter extends StatelessWidget {
  final ValueNotifier<Map<String, dynamic>> tvState;
  final String position;
  const _SongDockCounter({required this.tvState, required this.position});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: tvState,
      builder: (context, state, _) {
        final live = state.isNotEmpty && state['type'] == 'song';
        return DockCounterPill(
          primary: position,
          secondary: live ? '● Live on TV' : 'Off air',
          accent: live ? Colors.green : kGold,
        );
      },
    );
  }
}

/// Horizontal chip carousel: "Verse 1", "Chorus", "Bridge"… active chip gold.
class _StanzaChips extends StatelessWidget {
  final List<String> labels;
  final int activeIndex;
  final void Function(int) onTap;

  const _StanzaChips({
    required this.labels,
    required this.activeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: kBg,
        border: Border(
            bottom: BorderSide(color: kBorder, width: 1),
            top: BorderSide(color: kBorder, width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: labels.length,
        itemBuilder: (context, i) {
          final active = i == activeIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: active
                  ? kGold.withOpacity(0.22)
                  : kBg2,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(20),
                splashColor: kGold.withOpacity(0.3),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: active ? kGold : kBorder, width: active ? 1.5 : 1),
                  ),
                  child: Text(labels[i],
                      style: TextStyle(
                          color: active ? kGold : kMuted,
                          fontSize: 11.5,
                          fontWeight:
                              active ? FontWeight.bold : FontWeight.w500)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
