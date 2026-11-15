import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'shared_widgets.dart';

/// Schedule presentation full-screen with ALWAYS-VISIBLE controllers.
/// BUG FIX: Removed the Positioned.fill GestureDetector that was catching all taps
/// and making controllers disappear. Controllers now stay visible permanently.
class ScheduleFullscreen extends StatefulWidget {
  final String scheduleName;
  final String scheduleDate;
  final List songs;
  final int currentSongIndex;
  final int currentStanzaIndex;
  final int fontSize;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onCast;
  final void Function(int songIdx) onJumpToSong;
  final VoidCallback onExit;
  final Map<String, int> Function() getState;

  const ScheduleFullscreen({
    super.key,
    required this.scheduleName,
    required this.scheduleDate,
    required this.songs,
    required this.currentSongIndex,
    required this.currentStanzaIndex,
    required this.fontSize,
    required this.onPrev,
    required this.onNext,
    required this.onCast,
    required this.onJumpToSong,
    required this.onExit,
    required this.getState,
  });

  @override
  State<ScheduleFullscreen> createState() => _ScheduleFullscreenState();
}

class _ScheduleFullscreenState extends State<ScheduleFullscreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Enter immersive landscape mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Periodic refresh to sync state from parent
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    // Restore portrait mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.getState();
    final songIdx = state['songIndex'] ?? 0;
    final stanzaIdx = state['stanzaIndex'] ?? 0;
    final songs = widget.songs;
    final currentSong = songIdx < songs.length ? songs[songIdx] : null;
    final stanzas = currentSong != null ? List<String>.from(currentSong['stanzas'] ?? []) : <String>[];
    final currentStanza = stanzaIdx < stanzas.length ? stanzas[stanzaIdx] : '';
    final totalSongs = songs.length;

    return Scaffold(
      backgroundColor: const Color(0xFF060c18),
      body: Stack(children: [
        // ── Background gradient ──
        Positioned.fill(child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0a0520), Color(0xFF0c0a2a), Color(0xFF060c18)],
            ),
          ),
        )),

        // ── Current stanza preview (center content) ──
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 60, bottom: 140, left: 24, right: 24),
              child: Center(child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (currentSong != null) ...[
                    Text(currentSong['title'] ?? '',
                      style: const TextStyle(color: kGold, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text('Stanza ${stanzaIdx + 1} / ${stanzas.length}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: AutoFitText(
                      currentStanza.isEmpty ? 'No content' : currentStanza,
                      maxFontSize: (widget.fontSize * 0.55).clamp(14, 22).toDouble(),
                      minFontSize: 12,
                      // Scroll view gives unbounded height — cap the fit box
                      // so long stanzas shrink instead of pushing a scroll.
                      maxHeightOverride:
                          MediaQuery.of(context).size.height - 300,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: (widget.fontSize * 0.55).clamp(14, 22).toDouble(),
                        height: 1.8,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ]),
              )),
            ),
          ),
        ),

        // ── Top bar: schedule info + exit ──
        // NOTE: NO tap-to-toggle here. Controls are ALWAYS visible.
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(children: [
                // Schedule badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade900.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade500),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.purple),
                    const SizedBox(width: 6),
                    Text(widget.scheduleName,
                      style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  ]),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${songIdx + 1}/$totalSongs  •  ${currentSong?['title'] ?? ''}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                    overflow: TextOverflow.ellipsis),
                ])),

                // Exit button
                GestureDetector(
                  onTap: widget.onExit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade700.withOpacity(0.5)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.close, size: 16, color: Colors.red),
                      SizedBox(width: 6),
                      Text('Exit', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── Bottom controls: ALWAYS VISIBLE ──
        // BUG FIX: Removed the old Positioned.fill GestureDetector that was
        // intercepting all taps and toggling _showControls. Controllers now
        // stay visible permanently — no auto-hide behavior.
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            child: Container(
              padding: EdgeInsets.fromLTRB(14, 12, 14, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, const Color(0xFF060c18).withOpacity(0.95)],
                ),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── Song list (horizontal scrollable) ──
                if (songs.length > 1) SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: songs.length,
                    itemBuilder: (ctx, i) {
                      final isActive = i == songIdx;
                      return GestureDetector(
                        onTap: () => widget.onJumpToSong(i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.purple.shade700.withOpacity(0.4) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isActive ? Colors.purple.shade500 : Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('${i + 1}',
                              style: TextStyle(fontSize: 10, color: isActive ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            Text(songs[i]['title'] ?? '',
                              style: TextStyle(fontSize: 11, color: isActive ? Colors.white : Colors.white54, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                if (songs.length > 1) const SizedBox(height: 10),

                // ── Main navigation: Prev / Cast / Next ──
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: widget.onPrev,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      alignment: Alignment.center,
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.skip_previous, color: Colors.white54, size: 20),
                        SizedBox(width: 4),
                        Text('Prev', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: GestureDetector(
                    onTap: widget.onCast,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.purple, Color(0xFF7C3AED)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.cast, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('Cast to TV', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: GestureDetector(
                    onTap: widget.onNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      alignment: Alignment.center,
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Next', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.skip_next, color: Colors.white54, size: 20),
                      ]),
                    ),
                  )),
                ]),
              ]),
            ),
          ),
        ),

        // NOTE: NO Positioned.fill GestureDetector here!
        // The old code had a tap-anywhere-to-toggle-controls gesture detector
        // that was on TOP of all other widgets, causing buttons to not work
        // and controls to disappear on every tap. That has been removed.
      ]),
    );
  }
}
