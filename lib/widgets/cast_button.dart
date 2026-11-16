import 'dart:io';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/cast_service.dart';
import '../services/cast_api.g.dart';

// ══════════════════════════════════════════════════════════════
// CastButton — Shows cast icon, opens device picker on tap
// ══════════════════════════════════════════════════════════════

class CastButton extends StatelessWidget {
  final CastService castService;
  final String? tvUrl; // The TV URL to auto-cast after connecting

  const CastButton({
    super.key,
    required this.castService,
    this.tvUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: castService,
      builder: (context, _) {
        final isConnected = castService.isConnected;
        final isDiscovering = castService.isDiscovering;
        final deviceCount = castService.discoveredDevices.length;

        // Determine icon and color based on state
        IconData icon;
        Color color;
        if (isConnected) {
          icon = Icons.cast_connected;
          color = kAccent;
        } else if (isDiscovering) {
          icon = Icons.cast;
          color = kGold;
        } else {
          icon = Icons.cast;
          color = kMuted;
        }

        return GestureDetector(
          onTap: () => _showCastSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isConnected
                  ? kAccent.withOpacity(0.15)
                  : kBg2.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isConnected
                    ? kAccent.withOpacity(0.5)
                    : kBorder.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDiscovering && !isConnected)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kGold,
                    ),
                  )
                else
                  Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  isConnected ? castService.connectedDeviceName : 'Chromecast',
                  style: TextStyle(
                    color: isConnected ? kAccent : kMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isConnected && deviceCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$deviceCount',
                      style: const TextStyle(
                        color: kAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCastSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => CastSheet(
        castService: castService,
        tvUrl: tvUrl,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CastSheet — Bottom sheet with device list + controls
// ══════════════════════════════════════════════════════════════

class CastSheet extends StatelessWidget {
  final CastService castService;
  final String? tvUrl;

  const CastSheet({required this.castService, this.tvUrl});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: castService,
      builder: (context, _) {
        final devices = castService.discoveredDevices;
        final isConnected = castService.isConnected;
        final playerState = castService.playerState;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cast to Device',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kText,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: kMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Connected device info ──
              if (isConnected) ...[
                _buildConnectedCard(context),
                const SizedBox(height: 12),

                // ── Playback controls ──
                if (playerState.state != 'idle') _buildPlaybackControls(),
                const SizedBox(height: 12),

                // ── Disconnect button ──
                GestureDetector(
                  onTap: () {
                    castService.disconnect();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.red.shade800.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cast_connected, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Disconnect',
                            style: TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── AirPlay (iOS only) ──
              if (Platform.isIOS) ...[
                GestureDetector(
                  onTap: () {
                    castService.showAirPlayPicker();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.airplay, size: 22, color: Colors.white70),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AirPlay',
                                style: TextStyle(
                                    color: kText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            SizedBox(height: 2),
                            Text('Show native AirPlay picker',
                                style: TextStyle(color: kMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: kMuted, size: 20),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Discover Chromecast devices ──
              if (!isConnected) ...[
                GestureDetector(
                  onTap: () {
                    if (castService.isDiscovering) {
                      castService.stopDiscovery();
                    } else {
                      castService.startDiscovery();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kAccent.withOpacity(0.4)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cast, size: 22, color: kAccent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              castService.isDiscovering
                                  ? 'Scanning...'
                                  : 'Scan for Chromecast',
                              style: const TextStyle(
                                  color: kText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              castService.isDiscovering
                                  ? '${devices.length} device${devices.length != 1 ? 's' : ''} found'
                                  : 'Find Chromecast devices on your network',
                              style:
                                  const TextStyle(color: kMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      if (castService.isDiscovering)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: kAccent, strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.chevron_right,
                            color: kMuted, size: 20),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Device list ──
              if (devices.isNotEmpty && !isConnected) ...[
                const Text('AVAILABLE DEVICES',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: kMuted,
                        letterSpacing: 1.5)),
                const SizedBox(height: 8),
                ...devices.map((device) => _buildDeviceTile(context, device)),
              ] else if (castService.isDiscovering && devices.isEmpty) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Column(children: [
                      CircularProgressIndicator(color: kAccent),
                      SizedBox(height: 12),
                      Text('Looking for devices...',
                          style: TextStyle(color: kMuted, fontSize: 12)),
                    ]),
                  ),
                ),
              ] else if (!isConnected && !castService.isDiscovering) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: const Column(children: [
                    Icon(Icons.cast_connected,
                        size: 32, color: Color(0xFF1a2d45)),
                    SizedBox(height: 8),
                    Text('No devices found',
                        style: TextStyle(color: kMuted, fontSize: 12)),
                    SizedBox(height: 4),
                    Text('Make sure your TV and phone are on the same WiFi',
                        style:
                            TextStyle(color: Color(0xFF1a2d45), fontSize: 10)),
                  ]),
                ),
              ],

              // ── Error display ──
              if (castService.lastError.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.red.shade800.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline,
                        size: 16, color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(castService.lastError,
                          style: TextStyle(
                              color: Colors.red.shade300, fontSize: 11)),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectedCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withOpacity(0.4)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.cast_connected, size: 22, color: kAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                castService.connectedDeviceName,
                style: const TextStyle(
                    color: kText, fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Connected',
                style: TextStyle(color: kAccent, fontSize: 10),
              ),
            ],
          ),
        ),
        if (tvUrl != null)
          GestureDetector(
            onTap: () {
              castService.castTvUrl(tvUrl!);
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: [kAccent, Color(0xFF0284C7)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.play_arrow, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Cast TV',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _buildPlaybackControls() {
    final ps = castService.playerState;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ps.mediaTitle.isNotEmpty)
            Text(ps.mediaTitle,
                style: const TextStyle(
                    color: kText, fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rewind 10s
              GestureDetector(
                onTap: () => castService
                    .seekTo((ps.position - 10).clamp(0.0, ps.duration)),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.replay_10,
                      color: Colors.white54, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              // Play/Pause
              GestureDetector(
                onTap: () => castService.togglePlayPause(),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: castService.isPlaying
                          ? [Colors.orange.shade700, Colors.orange.shade500]
                          : [kAccent, const Color(0xFF0284C7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    castService.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Forward 10s
              GestureDetector(
                onTap: () => castService
                    .seekTo((ps.position + 10).clamp(0.0, ps.duration)),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.forward_10,
                      color: Colors.white54, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Position bar
          if (ps.duration > 0) ...[
            Row(children: [
              Text(_formatDuration(ps.position),
                  style: const TextStyle(
                      color: kMuted, fontSize: 9, fontFamily: 'monospace')),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: kAccent,
                    thumbColor: kAccent,
                    inactiveTrackColor: kBorder,
                    overlayColor: kAccent.withOpacity(0.1),
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                  ),
                  child: Slider(
                    value: ps.position.clamp(0.0, ps.duration),
                    min: 0,
                    max: ps.duration,
                    onChanged: (v) => castService.seekTo(v),
                  ),
                ),
              ),
              Text(_formatDuration(ps.duration),
                  style: const TextStyle(
                      color: kMuted, fontSize: 9, fontFamily: 'monospace')),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceTile(BuildContext context, CastDevice device) {
    final isChromecast = device.platform == 'chromecast';
    return GestureDetector(
      onTap: () {
        castService.connectToDevice(device.deviceId);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isChromecast ? kAccent : Colors.white).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isChromecast ? Icons.cast : Icons.airplay,
              size: 20,
              color: isChromecast ? kAccent : Colors.white70,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name,
                    style: const TextStyle(
                        color: kText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  isChromecast ? 'Chromecast' : 'AirPlay',
                  style: TextStyle(
                    color: isChromecast ? kAccent : Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kAccent.withOpacity(0.3)),
            ),
            child: const Text('Connect',
                style: TextStyle(
                    color: kAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
