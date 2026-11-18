import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';

class SettingsTab extends StatelessWidget {
  final int fontSize;
  final void Function(int size) onFontSizeChanged;
  final String welcomeMessage;
  final TextEditingController welcomeMsgCtrl;
  final void Function(String msg) onWelcomeMessageChanged;
  final VoidCallback onCastWelcome;
  final VoidCallback onClearScreen;
  final String customLogoPath;
  final VoidCallback onUploadCustomLogo;
  final VoidCallback onRemoveCustomLogo;
  final VoidCallback onCastLogo;
  final String? bgUrl;
  final void Function(String? url) onBgUrlChanged;
  final bool isUploadingBg;
  final VoidCallback onUploadBgImage;
  final List<Map<String, String>> uploadedBgs;
  final void Function(int idx) onDeleteUploadedBg;
  final bool serverStarted;
  final bool connected;
  final String deviceIp;
  final VoidCallback onRefreshIp;
  final VoidCallback onConnectWS;
  final VoidCallback onCopyUrl;

  const SettingsTab({
    super.key,
    required this.fontSize,
    required this.onFontSizeChanged,
    required this.welcomeMessage,
    required this.welcomeMsgCtrl,
    required this.onWelcomeMessageChanged,
    required this.onCastWelcome,
    required this.onClearScreen,
    required this.customLogoPath,
    required this.onUploadCustomLogo,
    required this.onRemoveCustomLogo,
    required this.onCastLogo,
    required this.bgUrl,
    required this.onBgUrlChanged,
    required this.isUploadingBg,
    required this.onUploadBgImage,
    required this.uploadedBgs,
    required this.onDeleteUploadedBg,
    required this.serverStarted,
    required this.connected,
    required this.deviceIp,
    required this.onRefreshIp,
    required this.onConnectWS,
    required this.onCopyUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 84),
      child: Column(children: [
        // DISPLAY section
        appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          sectionHeader(Icons.text_fields, 'DISPLAY', kAccent),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            label('FONT SIZE'),
            Text('$fontSize px', style: const TextStyle(color: kAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kAccent, thumbColor: kAccent,
              inactiveTrackColor: kBorder, overlayColor: kAccent.withOpacity(0.1),
            ),
            child: Slider(min: 24, max: 80, divisions: 56, value: fontSize.toDouble(), onChanged: (v) => onFontSizeChanged(v.round())),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Small', style: TextStyle(fontSize: 9, color: kMuted)),
            const Text('Large', style: TextStyle(fontSize: 9, color: kMuted)),
          ]),
        ])),
        const SizedBox(height: 12),

        // WELCOME SCREEN section
        appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          sectionHeader(Icons.waving_hand, 'WELCOME SCREEN', Colors.green),
          const SizedBox(height: 10),
          TextField(
            controller: welcomeMsgCtrl,
            style: const TextStyle(color: kText, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Welcome message (optional)',
              hintStyle: const TextStyle(color: kMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.message_outlined, size: 18, color: Colors.green),
              filled: true, fillColor: kBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.green)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: onWelcomeMessageChanged,
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: onCastWelcome,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(color: Colors.green.shade900.withOpacity(0.3), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade800.withOpacity(0.5))),
                child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.cast, size: 14, color: Colors.green),
                  SizedBox(width: 6),
                  Text('Cast Welcome', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ])),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: onClearScreen,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade800.withOpacity(0.3))),
                child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.clear, size: 14, color: Colors.red),
                  SizedBox(width: 6),
                  Text('Clear', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                ])),
              ),
            )),
          ]),
        ])),
        const SizedBox(height: 12),

        // CHURCH LOGO section
        appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          sectionHeader(Icons.church, 'CHURCH LOGO', kGold),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onUploadCustomLogo,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kGold.withOpacity(0.3), width: 1.5)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.upload, size: 18, color: kGold),
                SizedBox(width: 8),
                Text('Upload Custom Logo', style: TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          if (customLogoPath.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.check_circle, size: 14, color: Colors.green),
              const SizedBox(width: 6),
              const Expanded(child: Text('Custom logo uploaded', style: TextStyle(color: Colors.green, fontSize: 10))),
              GestureDetector(
                onTap: onRemoveCustomLogo,
                child: Text('Remove', style: TextStyle(color: Colors.red.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: onCastLogo,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: kGold.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: kGold.withOpacity(0.3))),
                child: const Center(child: Text('Cast Logo', style: TextStyle(color: kGold, fontSize: 11, fontWeight: FontWeight.bold))),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: onCastWelcome,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Colors.green.shade900.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade800.withOpacity(0.4))),
                child: const Center(child: Text('Welcome Screen', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold))),
              ),
            )),
          ]),
        ])),
        const SizedBox(height: 12),

        // TV BACKGROUND section
        appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          sectionHeader(Icons.palette, 'TV BACKGROUND', Colors.purple),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: isUploadingBg ? null : onUploadBgImage,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kAccent.withOpacity(0.3), width: 1.5)),
              child: isUploadingBg
                  ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: kAccent, strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Uploading...', style: TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                    ])
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 18, color: kAccent),
                      SizedBox(width: 8),
                      Text('Upload Background Image', style: TextStyle(color: kAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              GestureDetector(
                onTap: () => onBgUrlChanged(null),
                child: Container(
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: bgUrl == null ? kAccent : kBorder, width: bgUrl == null ? 2 : 1),
                  ),
                  alignment: Alignment.center,
                  child: Text('None', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: bgUrl == null ? kAccent : kMuted)),
                ),
              ),
              ...uploadedBgs.asMap().entries.map((entry) {
                final bgIdx = entry.key;
                final bg = entry.value;
                final isSelected = bgUrl == bg['url'];
                return GestureDetector(
                  onTap: () => onBgUrlChanged(bg['url']),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? kAccent : kBorder, width: isSelected ? 2 : 1),
                      image: DecorationImage(image: NetworkImage(bg['url']!), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken)),
                    ),
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [
                      Expanded(child: Text(bg['name']!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis)),
                      if (isSelected) const Icon(Icons.check_circle, size: 12, color: kAccent),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => onDeleteUploadedBg(bgIdx),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.delete_outline, size: 11, color: Color(0xFFFCA5A5)),
                        ),
                      ),
                    ]),
                  ),
                );
              }),
              ...presetBackgrounds.map((bg) => GestureDetector(
                onTap: () => onBgUrlChanged(bg['url']),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: bgUrl == bg['url'] ? kAccent : kBorder, width: bgUrl == bg['url'] ? 2 : 1),
                    image: DecorationImage(image: NetworkImage(bg['url']!), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken)),
                  ),
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    Expanded(child: Text(bg['name']!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))),
                    if (bgUrl == bg['url']) const Icon(Icons.check_circle, size: 12, color: kAccent),
                  ]),
                ),
              )),
              ...animatedBackgrounds.map((bg) => GestureDetector(
                onTap: () => onBgUrlChanged(bg['id']),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: bgUrl == bg['id'] ? kAccent : kBorder, width: bgUrl == bg['id'] ? 2 : 1),
                    gradient: bg['id'] == 'animated:aurora' ? const LinearGradient(colors: [Color(0xFF03030c), Color(0xFF080d24), Color(0xFF150d30)])
                      : bg['id'] == 'animated:divine' ? const LinearGradient(colors: [Color(0xFF14120a), Color(0xFF080704), Color(0xFF030302)])
                      : bg['id'] == 'animated:ocean' ? const LinearGradient(colors: [Color(0xFF020914), Color(0xFF031a2e), Color(0xFF010408)])
                      : bg['id'] == 'animated:fire' ? const LinearGradient(colors: [Color(0xFF060202), Color(0xFF160604), Color(0xFF030101)])
                      : const LinearGradient(colors: [Color(0xFF06020c), Color(0xFF1c0533), Color(0xFF28041a)]),
                  ),
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    const Icon(Icons.motion_photos_on_outlined, size: 11, color: kAccent),
                    const SizedBox(width: 4),
                    Expanded(child: Text(bg['name']!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white))),
                    if (bgUrl == bg['id']) const Icon(Icons.check_circle, size: 12, color: kAccent),
                  ]),
                ),
              )),
            ],
          ),
        ])),
        const SizedBox(height: 12),

        // SERVER section
        appCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          sectionHeader(Icons.dns, 'SERVER', kAccent),
          const SizedBox(height: 10),
          infoRow('Server', serverStarted ? 'Running' : 'Not started', serverStarted ? Colors.green : Colors.red),
          infoRow('WebSocket', connected ? 'Connected' : 'Disconnected', connected ? Colors.green : Colors.red),
          Row(children: [
            SizedBox(width: 80, child: Text('Device IP', style: const TextStyle(fontSize: 10, color: kMuted))),
            Expanded(child: Text(deviceIp, style: const TextStyle(fontSize: 11, color: kAccent, fontWeight: FontWeight.w600))),
            GestureDetector(
              onTap: onRefreshIp,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: kAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.refresh, size: 14, color: kAccent),
              ),
            ),
          ]),
          infoRow('TV URL', 'http://${deviceIp == '...' ? '<IP>' : deviceIp}:3000/tv.html', kAccent),
          const SizedBox(height: 4),
          Text('Tip: If IP changes, set a static IP in your WiFi settings for stability.',
            style: TextStyle(fontSize: 9, color: kGold.withOpacity(0.7), fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: secondaryBtn('Reconnect', onConnectWS)),
            const SizedBox(width: 8),
            Expanded(child: secondaryBtn('Copy URL', onCopyUrl)),
          ]),
        ])),
      ]),
    );
  }
}
