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

  /// Chip label for a stanza: uses its [Chorus]/[Verse] tag when present
  /// (numbered per occurrence), otherwise "Stanza N".

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
            headerActions: _emergencyActions(),
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

        return PresenterScaffold(
          leading: _backBtn(context),
          title: song?['title'] as String? ?? 'Song',
          subtitle: '${stanzas.length} slides',
          tvState: widget.tvState,
          headerActions: _emergencyActions(),
          headerStrip: _StanzaChips(
            labels: labels,
            activeIndex: index,
            onTap: widget.onSelectStanza,
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: _onSwipe,
            child: SingleChildScrollView(
              controller: _stageScroll,
              physics: const BouncingScrollPhysics(),
              child: Container(
                constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 220),
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Text(
                  lyrics,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kText,
                    fontSize: 26,
                    height: 1.75,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    shadows: [
                      Shadow(
                          color: Colors.black.withOpacity(0.6), blurRadius: 18)
                    ],
                  ),
                ),
              ),
            ),
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

  List<Widget> _emergencyActions() => [
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
        return DockCounter(
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
