import 'dart:async';

import 'package:flutter/material.dart';
// The package also exports a DlnaService class — keep the app's one.
import 'package:media_cast_dlna/media_cast_dlna.dart' hide DlnaService;

import '../dlna_service.dart';
import '../theme.dart';
import 'top_notification.dart';

/// Device picker bottom sheet (plan 9.2) — the only screen where the user
/// chooses a TV. Opens with discovery already running (pre-warmed at cast
/// dialog open), appends TVs live as SSDP answers arrive during the 10 s
/// window, and after 5 s of silence shows the troubleshooting empty state
/// instead of an endless spinner.
class DlnaPickerSheet extends StatefulWidget {
  final VoidCallback onUseBrowserConnect;

  /// Called after a device is chosen and stored; the controller casts its
  /// current content over the new TV Direct channel.
  final void Function(DlnaDevice device) onDeviceSelected;

  const DlnaPickerSheet({
    super.key,
    required this.onUseBrowserConnect,
    required this.onDeviceSelected,
  });

  @override
  State<DlnaPickerSheet> createState() => _DlnaPickerSheetState();
}

class _DlnaPickerSheetState extends State<DlnaPickerSheet> {
  final DlnaService _dlna = DlnaService.instance;
  ({String udn, String name})? _remembered;
  DlnaDevice? _rememberedAlive;
  bool _showEmptyState = false;
  Timer? _emptyTimer;

  @override
  void initState() {
    super.initState();
    _warmReconnectPing();
    // Empty state only after five seconds of silence (plan Table 7).
    _emptyTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _dlna.devices.isEmpty) {
        setState(() => _showEmptyState = true);
      }
    });
    _dlna.addListener(_onDevicesChanged);
    // Discovery is expected to be running already; restart it defensively.
    _dlna.scan();
  }

  @override
  void dispose() {
    _emptyTimer?.cancel();
    _dlna.removeListener(_onDevicesChanged);
    // Battery (risk R8): end the discovery window when the sheet closes.
    _dlna.stopScan();
    super.dispose();
  }

  void _onDevicesChanged() {
    if (!mounted) return;
    // The remembered TV answering the warm-up ping unlocks the banner even
    // before it shows up in the general list.
    if (_remembered != null && !_rememberedAliveFound) {
      for (final d in _dlna.devices) {
        if (d.udn.value == _remembered!.udn) {
          setState(() => _rememberedAlive = d);
          break;
        }
      }
    }
    setState(() {});
  }

  bool get _rememberedAliveFound =>
      _rememberedAlive != null &&
      _dlna.devices.any((d) => d.udn.value == _rememberedAlive!.udn.value);

  /// One-tap reconnect: ping the stored UDN instead of waiting for a full
  /// scan (TVs in deep standby never answer — risk R9 — so no false offer).
  Future<void> _warmReconnectPing() async {
    final last = await DlnaService.lastTv();
    if (last == null || !mounted) return;
    setState(() => _remembered = last);
    final alive = await _dlna.pingStored(last.udn);
    if (mounted && alive != null) {
      setState(() => _rememberedAlive = alive);
    }
  }

  Future<void> _connectAndCast(
      BuildContext sheetContext, DlnaDevice device) async {
    Navigator.of(sheetContext).pop();
    await _dlna.connect(device);
    // "Connected ✓" confirmation for ~2 s (plan Table 7), then the
    // controller pushes whatever is currently on the presentation screen.
    if (mounted) {
      TopNotification.show(this.context, 'Connected ✓  ${device.friendlyName}');
    }
    await Future.delayed(const Duration(seconds: 2));
    widget.onDeviceSelected(device);
  }

  void _rescan() {
    setState(() => _showEmptyState = false);
    _emptyTimer?.cancel();
    _emptyTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _dlna.devices.isEmpty) {
        setState(() => _showEmptyState = true);
      }
    });
    _dlna.scan();
  }

  @override
  Widget build(BuildContext context) {
    final devices = _dlna.devices;
    final rememberedAlive = _rememberedAlive;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TV Direct — pick your TV',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, color: kText)),
              IconButton(
                icon: const Icon(Icons.close, color: kMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reconnect banner (one tap = connect + cast).
          if (rememberedAlive != null && _remembered != null) ...[
            _ReconnectCard(
              name: rememberedAlive.friendlyName,
              onTap: () => _connectAndCast(context, rememberedAlive),
            ),
            const SizedBox(height: 8),
          ],

          if (devices.isEmpty && !_showEmptyState) ...[
            Row(
              children: [
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kAccent)),
                const SizedBox(width: 10),
                Text('Scanning…',
                    style: TextStyle(color: kMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
          ],

          if (devices.isEmpty && _showEmptyState)
            _EmptyState(
              onRescan: _rescan,
              onUseBrowserConnect: () {
                Navigator.pop(context);
                widget.onUseBrowserConnect();
              },
            )
          else
            ...devices.map(
              (d) => _DeviceRow(
                device: d,
                selected: _dlna.connectedDevice?.udn.value == d.udn.value,
                onTap: () => _connectAndCast(context, d),
              ),
            ),

          if (devices.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kMuted)),
                const SizedBox(width: 8),
                Text('Scanning — more TVs may still answer…',
                    style: TextStyle(color: kMuted, fontSize: 10)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReconnectCard extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _ReconnectCard({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.shade900.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade700.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.history, size: 20, color: Colors.green.shade400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cast to $name — tap to connect',
                style: const TextStyle(
                    color: kText, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right, color: kMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final DlnaDevice device;
  final bool selected;
  final VoidCallback onTap;
  const _DeviceRow(
      {required this.device, required this.selected, required this.onTap});

  IconData get _brandIcon {
    final m = device.manufacturerDetails.manufacturer.toLowerCase();
    if (m.contains('kodi')) return Icons.computer;
    return Icons.tv;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0c1f3a) : kBg,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: selected ? kAccent.withOpacity(0.7) : kBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_brandIcon, size: 18, color: kAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.friendlyName,
                      style: const TextStyle(
                          color: kText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${device.manufacturerDetails.manufacturer} · ${device.ipAddress.value}',
                    style: const TextStyle(color: kMuted, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? kAccent : kMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Troubleshooting empty state — final copy from plan Table 9.
class _EmptyState extends StatelessWidget {
  final VoidCallback onRescan;
  final VoidCallback onUseBrowserConnect;
  const _EmptyState(
      {required this.onRescan, required this.onUseBrowserConnect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.tv_off, size: 30, color: kMuted.withOpacity(0.6)),
          const SizedBox(height: 10),
          const Text('No TV found',
              style: TextStyle(
                  color: kText, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Make sure the TV is turned on and connected to the same Wi-Fi as this phone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 6),
          const Text(
            'Some office and guest networks block casting between devices (AP isolation). Try your phone\'s hotspot.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 10, height: 1.5),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onRescan,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kAccent.withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh, size: 15, color: kAccent),
                  SizedBox(width: 6),
                  Text('Re-scan',
                      style: TextStyle(
                          color: kAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onUseBrowserConnect,
            child: Text('Use Browser Connect instead',
                style: TextStyle(
                    color: kAccent.withOpacity(0.75),
                    fontSize: 11,
                    decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}
