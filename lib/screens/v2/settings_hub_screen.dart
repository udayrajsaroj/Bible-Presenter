import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Screen 6 — Settings & profile: violet profile card, settings groups with
/// vibrant icon badges, connection info, and the gradient Log Out pill.
class SettingsHubScreen extends StatelessWidget {
  final bool serverStarted;
  final bool connected;
  final String deviceIp;
  final VoidCallback onCopyUrl;
  final VoidCallback onCastToTV;
  final VoidCallback onClassicUI;
  final VoidCallback onBack;

  const SettingsHubScreen({
    super.key,
    required this.serverStarted,
    required this.connected,
    required this.deviceIp,
    required this.onCopyUrl,
    required this.onCastToTV,
    required this.onClassicUI,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.settings_rounded,
                  size: 24, color: AppColors.cyan),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Settings',
                    style: TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ),
              Stack(children: [
                const IconButton(
                  onPressed: null,
                  icon: Icon(Icons.notifications_outlined,
                      color: AppColors.textMuted, size: 24),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.red.withOpacity(0.7),
                            blurRadius: 6)
                      ],
                    ),
                  ),
                ),
              ]),
            ]),
            const SizedBox(height: 8),

            // ── Profile card ──
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppGradients.profile,
                borderRadius: BorderRadius.circular(AppRadii.cardLg),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.purple.withOpacity(0.4),
                      blurRadius: 22,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.92),
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 32, color: AppColors.purple),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BiblePresenter',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 3),
                        Text('Blessed to serve',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12.5)),
                      ]),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white70, size: 24),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Connection group ──
            _group('CONNECTION'),
            _ConnectionTile(
              connected: connected,
              serverStarted: serverStarted,
              deviceIp: deviceIp,
              onCopyUrl: onCopyUrl,
              onCastToTV: onCastToTV,
            ),
            const SizedBox(height: 14),

            // ── Settings groups ──
            _group('PREFERENCES'),
            _SettingsTile(
              iconColor: AppColors.cyan,
              icon: Icons.tv_rounded,
              title: 'Display Settings',
              subtitle: 'Font, Theme, Layout',
              onTap: () => _infoDialog(context, 'Display Settings',
                  'Font size lives in the Bible hub slider (A- … A+). '
                  'The dark neon theme is applied app-wide.'),
            ),
            _SettingsTile(
              iconColor: AppColors.purple,
              icon: Icons.translate_rounded,
              title: 'Language',
              subtitle: 'English / Hindi',
              onTap: () => _infoDialog(context, 'Language',
                  'Primary and secondary bible languages are managed in the '
                  'Bible hub — open the language pill to switch or import.'),
            ),
            _SettingsTile(
              iconColor: AppColors.emerald,
              icon: Icons.auto_awesome_motion_rounded,
              title: 'Background Motion',
              subtitle: 'Pan & Zoom / Video',
              onTap: () => _infoDialog(context, 'Background Motion',
                  'Pick a backdrop from the Slides hub; animated themes '
                  '(Pan & Zoom) render live on the TV.'),
            ),
            _SettingsTile(
              iconColor: const Color(0xFF6366F1),
              icon: Icons.info_rounded,
              title: 'About App',
              subtitle: 'Version 1.0.0',
              onTap: () => _aboutDialog(context),
            ),
            _SettingsTile(
              iconColor: const Color(0xFFA16207),
              icon: Icons.help_outline_rounded,
              title: 'Help & Support',
              subtitle: 'Get help',
              onTap: () => _infoDialog(context, 'Help & Support',
                  'Cast steps: start a TV Direct (DLNA) device, or open '
                  'tv.html in the TV browser via Browser Connect. '
                  'Slides change about a second later on TV Direct.'),
            ),
            _SettingsTile(
              iconColor: AppColors.orange,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: '',
              onTap: () => _infoDialog(context, 'Privacy Policy',
                  'BiblePresenter runs entirely on your local network. '
                  'No presentation data leaves your device or your Wi-Fi.'),
            ),
            _SettingsTile(
              iconColor: AppColors.goldSoft,
              icon: Icons.history_rounded,
              title: 'Classic Interface',
              subtitle: 'Advanced video / YouTube remotes',
              onTap: onClassicUI,
            ),
            const SizedBox(height: 18),

            // ── Log out ──
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _confirmLogout(context),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppGradients.logout,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.red.withOpacity(0.35),
                          blurRadius: 18),
                    ],
                  ),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text('Log Out',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                      ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4)),
      );

  void _infoDialog(BuildContext ctx, String title, String body) {
    showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceSolid,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card)),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textHigh,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: Text(body,
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK',
                style: TextStyle(color: AppColors.cyan)),
          ),
        ],
      ),
    );
  }

  void _aboutDialog(BuildContext ctx) {
    showAboutDialog(
      context: ctx,
      applicationName: 'BiblePresenter',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.menu_book_rounded,
          color: AppColors.cyan, size: 36),
      children: const [
        Text('Present • Worship • Share',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        Text(
            'Local-network presentation casting: TV Direct (DLNA), '
            'Browser Connect, Chromecast and YouTube hand-off.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }

  void _confirmLogout(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceSolid,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card)),
        title: const Text('Log Out',
            style: TextStyle(
                color: AppColors.textHigh,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        content: const Text('Close BiblePresenter?',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SystemNavigator.pop();
            },
            child: const Text('Log Out',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Connection tile ─────────────────────────────────────────────────────────

class _ConnectionTile extends StatelessWidget {
  final bool connected;
  final bool serverStarted;
  final String deviceIp;
  final VoidCallback onCopyUrl;
  final VoidCallback onCastToTV;

  const _ConnectionTile({
    required this.connected,
    required this.serverStarted,
    required this.deviceIp,
    required this.onCopyUrl,
    required this.onCastToTV,
  });

  @override
  Widget build(BuildContext context) {
    final url = serverStarted && deviceIp != '...'
        ? 'http://$deviceIp:3000/tv.html'
        : 'Server starting…';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glass(
        radius: AppRadii.card,
        opacity: 0.55,
        borderColor: AppColors.borderGlow,
        shadow: const [],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? AppColors.emerald : AppColors.orange,
              boxShadow: [
                BoxShadow(
                    color: (connected
                            ? AppColors.emerald
                            : AppColors.orange)
                        .withOpacity(0.7),
                    blurRadius: 6)
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(connected ? 'TV connected' : 'No TV connected',
              style: const TextStyle(
                  color: AppColors.textHigh,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(serverStarted ? 'Server on :3000' : 'Server off',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 10.5)),
        ]),
        const SizedBox(height: 10),
        Text(url,
            style: const TextStyle(
                color: AppColors.cyan,
                fontSize: 12,
                fontFamily: 'monospace')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _miniBtn(Icons.copy_rounded, 'Copy URL', onCopyUrl),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _miniBtn(Icons.cast_rounded, 'Cast to TV', onCastToTV),
          ),
        ]),
      ]),
    );
  }

  Widget _miniBtn(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.cyan.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(color: AppColors.cyan.withOpacity(0.45)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: AppColors.cyan),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: AppColors.cyan,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }
}

// ── Settings tile ───────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: glass(
          radius: AppRadii.card,
          opacity: 0.45,
          shadow: const []),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card)),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.card)),
          leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: iconColor.withOpacity(0.55)),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textHigh,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        subtitle: subtitle.isEmpty
            ? null
            : Text(subtitle,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 22),
        ),
      ),
    );
  }
}
