import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/bible_state.dart';
import '../../theme/app_theme.dart';

/// Screen 6 — Settings & profile. Everything here is functional:
///  • Connection tile: live server / TV status, copy URL, cast dialog.
///  • My TV tile: one-tap reconnect to the remembered TV + forget.
///  • Display Settings: working font-size slider bound to BibleState.
///  • Language: primary / secondary bible language switcher.
///  • Welcome & Logo: welcome-message editor + custom logo upload / remove.
///  • About / Help / Privacy dialogs, Classic Interface switch, Log Out.
class SettingsHubScreen extends StatelessWidget {
  final bool serverStarted;
  final bool connected;
  final String deviceIp;
  final VoidCallback onCopyUrl;
  final VoidCallback onCastToTV;
  final VoidCallback onClassicUI;
  final VoidCallback onBack;

  // Optional functional hooks — when null the related controls hide/disable,
  // keeping older call sites (tests) compiling.
  final String storedTvName;
  final VoidCallback? onReconnectTv;
  final VoidCallback? onForgetTv;
  final TextEditingController? welcomeMsgCtrl;
  final ValueChanged<String>? onWelcomeMessageChanged;
  final String customLogoPath;
  final VoidCallback? onUploadLogo;
  final VoidCallback? onRemoveLogo;

  const SettingsHubScreen({
    super.key,
    required this.serverStarted,
    required this.connected,
    required this.deviceIp,
    required this.onCopyUrl,
    required this.onCastToTV,
    required this.onClassicUI,
    required this.onBack,
    this.storedTvName = '',
    this.onReconnectTv,
    this.onForgetTv,
    this.welcomeMsgCtrl,
    this.onWelcomeMessageChanged,
    this.customLogoPath = '',
    this.onUploadLogo,
    this.onRemoveLogo,
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
            ]),
            const SizedBox(height: 8),

            // ── Profile card (tap → About) ──
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _aboutDialog(context),
                borderRadius: BorderRadius.circular(AppRadii.cardLg),
                child: Container(
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
              ),
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
            const SizedBox(height: 10),
            _MyTvTile(
              storedTvName: storedTvName,
              onReconnect: onReconnectTv,
              onForget: onForgetTv,
            ),
            const SizedBox(height: 14),

            // ── Preferences group (all tiles open working editors) ──
            _group('PREFERENCES'),
            _SettingsTile(
              iconColor: AppColors.cyan,
              icon: Icons.tv_rounded,
              title: 'Display Settings',
              subtitle: 'TV slide font size',
              onTap: () => _openDisplaySheet(context),
            ),
            _SettingsTile(
              iconColor: AppColors.purple,
              icon: Icons.translate_rounded,
              title: 'Language',
              subtitle: 'Primary & secondary bible languages',
              onTap: () => _openLanguageSheet(context),
            ),
            _SettingsTile(
              iconColor: AppColors.emerald,
              icon: Icons.wb_sunny_rounded,
              title: 'Welcome Screen & Logo',
              subtitle: 'Welcome message, custom church logo',
              onTap: () => _openWelcomeLogoSheet(context),
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
              subtitle: 'How to cast, troubleshooting',
              onTap: () => _infoDialog(context, 'Help & Support',
                  'TV Direct (DLNA): both devices on the same Wi-Fi, then '
                  'Cast to TV and pick your TV — slides appear about a '
                  'second later and pre-rendered verses change instantly.\n\n'
                  'Browser Connect: open http://<phone-ip>:3000/tv.html in '
                  'the TV browser (Copy URL above shares the address).\n\n'
                  'Tips: keep the phone screen on while presenting; verses '
                  'and stanzas are pre-rendered ahead of time for instant '
                  'switching; Blackout and Logo stay one tap away in every '
                  'presenter header.'),
            ),
            _SettingsTile(
              iconColor: AppColors.orange,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'Your data never leaves your network',
              onTap: () => _infoDialog(context, 'Privacy Policy',
                  'BiblePresenter runs entirely on your local network. '
                  'Bibles, songs, slides and the custom logo are stored only '
                  'on this device. No presentation data, analytics or '
                  'personal information is ever sent to any server.'),
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

  // ══════════════════ DISPLAY: working font-size editor ══════════════════

  void _openDisplaySheet(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => Consumer<BibleState>(
        builder: (context, bible, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.tv_rounded,
                  size: 20, color: AppColors.cyan),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('TV Slide Font Size',
                    style: TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
              Text('${bible.fontSize} pt',
                  style: const TextStyle(
                      color: AppColors.cyan,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 14),
            // Live preview at the real TV size.
            Container(
              height: 150,
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.borderGlow),
              ),
              child: Text(
                'Fear none of those things which thou shalt suffer',
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: bible.fontSize * 0.55,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              _fontStepBtn(Icons.remove_rounded,
                  () => bible.fontSize = bible.fontSize - 4),
              Expanded(
                child: Slider(
                  value: bible.fontSize.toDouble(),
                  min: 24,
                  max: 120,
                  divisions: 48,
                  activeColor: AppColors.cyan,
                  label: '${bible.fontSize}',
                  onChanged: (v) => bible.fontSize = v.round(),
                ),
              ),
              _fontStepBtn(Icons.add_rounded,
                  () => bible.fontSize = bible.fontSize + 4),
            ]),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Applies to verses, songs and slides cast to the TV.',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _fontStepBtn(IconData icon, VoidCallback onTap) => Material(
        color: AppColors.cyan.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 20, color: AppColors.cyan),
          ),
        ),
      );

  // ══════════════════ LANGUAGE: primary / secondary switcher ═════════════

  void _openLanguageSheet(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => Consumer<BibleState>(
        builder: (context, bible, _) {
          final langs = bible.languages.entries.toList();
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.translate_rounded,
                    size: 20, color: AppColors.purple),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Bible Languages',
                      style: TextStyle(
                          color: AppColors.textHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
                Text('${langs.length} installed',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('PRIMARY — big on TV',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              ),
              const SizedBox(height: 4),
              ...langs.map((e) => _langRow(
                    context,
                    name: e.value,
                    selected: bible.primaryLang == e.key,
                    color: AppColors.cyan,
                    onTap: () => bible.primaryLang = e.key,
                  )),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('SECONDARY — small under primary',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              ),
              const SizedBox(height: 4),
              _langRow(
                context,
                name: 'None (single language)',
                selected: bible.secondaryLang.isEmpty,
                color: AppColors.purple,
                onTap: () => bible.secondaryLang = '',
              ),
              ...langs.map((e) => e.key == bible.primaryLang
                  ? const SizedBox.shrink()
                  : _langRow(
                      context,
                      name: e.value,
                      selected: bible.secondaryLang == e.key,
                      color: AppColors.purple,
                      onTap: () => bible.secondaryLang = e.key,
                    )),
              const SizedBox(height: 10),
              const Text(
                  'Import more languages from the Bible hub (VerseVIEW XML).',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ]),
          );
        },
      ),
    );
  }

  Widget _langRow(
    BuildContext ctx, {
    required String name,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? color.withOpacity(0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? color.withOpacity(0.55) : Colors.transparent),
          ),
          child: Row(children: [
            Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 18,
                color: selected ? color : AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  style: TextStyle(
                      color:
                          selected ? AppColors.textHigh : AppColors.textMuted,
                      fontSize: 13.5,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal)),
            ),
          ]),
        ),
      ),
    );
  }

  // ══════════════════ WELCOME & LOGO editor ══════════════════════════════

  void _openWelcomeLogoSheet(BuildContext ctx) {
    final hasCtrl = welcomeMsgCtrl != null;
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 28 + MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.wb_sunny_rounded,
                size: 20, color: AppColors.emerald),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Welcome Screen & Logo',
                  style: TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 14),

          // ── Welcome message ──
          if (hasCtrl && onWelcomeMessageChanged != null) ...[
            TextField(
              controller: welcomeMsgCtrl,
              maxLines: 2,
              style: const TextStyle(
                  color: AppColors.textHigh, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Welcome to Grace Community Church',
                hintStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: Colors.black.withOpacity(0.3),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: AppColors.borderGlow, width: 1)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: AppColors.borderGlow, width: 1)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.cyan, width: 1.4)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              width: double.infinity,
              child: Material(
                color: AppColors.emerald.withOpacity(0.16),
                borderRadius: BorderRadius.circular(AppRadii.button),
                child: InkWell(
                  onTap: () {
                    onWelcomeMessageChanged!(welcomeMsgCtrl!.text);
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Welcome message saved'),
                        backgroundColor: AppColors.emerald));
                  },
                  borderRadius: BorderRadius.circular(AppRadii.button),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_rounded,
                            size: 18, color: AppColors.emerald),
                        SizedBox(width: 8),
                        Text('Save Message',
                            style: TextStyle(
                                color: AppColors.emerald,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold)),
                      ]),
                ),
              ),
            ),
          ] else ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'The welcome message is edited in the Classic Interface '
                  '(More → Settings) in this build.',
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ),
          ],
          const SizedBox(height: 16),

          // ── Custom logo ──
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('CHURCH LOGO — used by Logo & Welcome cast',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.borderGlow),
              ),
              child: customLogoPath.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      child: _logoPreview())
                  : const Icon(Icons.church_rounded,
                      size: 34, color: AppColors.goldSoft),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(children: [
                if (onUploadLogo != null)
                  _sheetBtn(
                    icon: Icons.upload_rounded,
                    label: 'Upload PNG / JPG',
                    color: AppColors.cyan,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onUploadLogo!();
                    },
                  ),
                if (onUploadLogo != null && onRemoveLogo != null)
                  const SizedBox(height: 8),
                if (onRemoveLogo != null && customLogoPath.isNotEmpty)
                  _sheetBtn(
                    icon: Icons.delete_outline_rounded,
                    label: 'Remove Logo',
                    color: AppColors.red,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onRemoveLogo!();
                    },
                  ),
                if (onUploadLogo == null || onRemoveLogo == null)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Logo management lives in the Classic '
                        'Interface in this build.',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11.5)),
                  ),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
              customLogoPath.isEmpty
                  ? 'No custom logo — the built-in church logo is cast.'
                  : 'Custom logo active — it is used by every Logo cast.',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11.5)),
        ]),
      ),
    );
  }

  /// Decodes the stored base64 logo; falls back to a placeholder glyph if the
  /// data is corrupt so the sheet can never crash.
  Widget _logoPreview() {
    try {
      final bytes = base64Decode(customLogoPath);
      return Image.memory(bytes, fit: BoxFit.contain);
    } catch (_) {
      return const Icon(Icons.church_rounded,
          size: 34, color: AppColors.goldSoft);
    }
  }

  Widget _sheetBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 42,
      child: Material(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.button),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ══════════════════ Dialogs ════════════════════════════════════════════

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
                const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
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
            onPressed: () => Navigator.pop(_),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(_);
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

// ── My TV tile (one-tap reconnect / forget) ─────────────────────────────────

class _MyTvTile extends StatelessWidget {
  final String storedTvName;
  final VoidCallback? onReconnect;
  final VoidCallback? onForget;

  const _MyTvTile({
    required this.storedTvName,
    this.onReconnect,
    this.onForget,
  });

  @override
  Widget build(BuildContext context) {
    final hasTv = storedTvName.isNotEmpty;
    final canAct = hasTv && (onReconnect != null || onForget != null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: glass(
          radius: AppRadii.card,
          opacity: 0.45,
          shadow: const []),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (hasTv ? AppColors.emerald : AppColors.textMuted)
                .withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: (hasTv ? AppColors.emerald : AppColors.textMuted)
                    .withOpacity(0.5)),
          ),
          child: Icon(Icons.connected_tv_rounded,
              size: 20,
              color: hasTv ? AppColors.emerald : AppColors.textMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hasTv ? storedTvName : 'No TV remembered yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                    hasTv
                        ? 'Your last TV Direct device — reconnect in one tap'
                        : 'Cast to a TV once and it will be remembered here',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ]),
        ),
        if (canAct) ...[
          if (onReconnect != null)
            _tvActionBtn(
              icon: Icons.refresh_rounded,
              label: 'Reconnect',
              color: AppColors.emerald,
              onTap: onReconnect!,
            ),
          if (onReconnect != null && onForget != null)
            const SizedBox(width: 8),
          if (onForget != null)
            _tvActionBtn(
              icon: Icons.link_off_rounded,
              label: 'Forget',
              color: AppColors.red,
              onTap: onForget!,
            ),
        ],
      ]),
    );
  }

  Widget _tvActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.14),
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11.5,
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
