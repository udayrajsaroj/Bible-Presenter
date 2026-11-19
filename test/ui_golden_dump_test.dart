import 'dart:io';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:biblepresenter/screens/v2/bible_hub_screen.dart';
import 'package:biblepresenter/screens/v2/files_hub_screen.dart';
import 'package:biblepresenter/screens/v2/home_screen.dart';
import 'package:biblepresenter/screens/v2/settings_hub_screen.dart';
import 'package:biblepresenter/screens/v2/slides_hub_screen.dart';
import 'package:biblepresenter/screens/v2/songs_hub_screen.dart';
import 'package:biblepresenter/state/bible_state.dart';
import 'package:biblepresenter/theme/app_theme.dart';

/// Dumps golden PNGs of the six redesigned screens so the dark-neon
/// glassmorphism design can be reviewed without a device.
///
/// Run: flutter test test/ui_golden_dump_test.dart --update-goldens
void main() {
  final fontsAvailable =
      Directory('/tmp/flutter/bin/cache/artifacts/material_fonts')
          .existsSync();

  testWidgets('dump screen goldens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    SharedPreferences.setMockInitialValues({});

    final bible = BibleState();

    // Real fonts: test glyphs (Ahem) are far wider/taller than Roboto and
    // trigger layout overflows that never happen on devices.
    await tester.runAsync(() async {
      final dir = Directory('/tmp/flutter/bin/cache/artifacts/material_fonts');
      final loader = FontLoader('Roboto');
      for (final f in dir.listSync().whereType<File>()) {
        if (f.path.endsWith('.ttf')) {
          loader.addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
        }
      }
      await loader.load();
    });

    Widget host(Widget child) => MultiProvider(
          providers: [ChangeNotifierProvider<BibleState>.value(value: bible)],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(body: child),
          ),
        );
    // Real asset bible load (runAsync: real I/O).
    await tester.runAsync(() async {
      for (var i = 0; i < 150 && !bible.bibleLoaded; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });

    // Precache bundled art + icon font: asset decode is real I/O and the
    // first frames would otherwise capture black tiles.
    await tester.pumpWidget(host(const SizedBox.shrink()));
    final ctx = tester.state(find.byType(Scaffold)).context;
    await tester.runAsync(() async {
      await precacheImage(const AssetImage(AppAssets.heroVerse), ctx);
      for (final item in kSlideLibrary) {
        await precacheImage(AssetImage(item.asset), ctx);
      }
      await precacheImage(
          const AssetImage('assets/icon/app_icon.png'), ctx);
    });

    final outDir = Directory('goldens');
    if (!outDir.existsSync()) outDir.createSync();

    Future<void> snap(String name, Widget screen) async {
      await tester.pumpWidget(host(screen));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'));
    }

    await snap('01_home', HomeScreen(
      tvState: ValueNotifier<Map<String, dynamic>>({'type': 'idle'}),
      onOpenSlides: () {},
      onOpenSongs: () {},
      onOpenBible: () {},
      onOpenFiles: () {},
      onOpenSettings: () {},
      onCastLogo: () {},
      onCastBlackout: () {},
      onCastToTV: () {},
    ));

    await snap('02_slides', SlidesHubScreen(
      activeBackgroundAsset: '',
      onPickBackground: (_) {},
      onAddCustomSlide: () {},
      onOpenCustomSlides: () {},
    ));

    final songs = [
      {'title': 'Praise You Jehovah', 'stanzas': ['Hallelujah', 'Praise the Lord']},
      {'title': '10000 Reasons', 'stanzas': ['Bless the Lord oh my soul']},
      {'title': 'Aaja Din Yahova Ne', 'stanzas': ['आज दिन यहोवा ने', 'बनाया है']},
      {'title': 'Aatma Mandarata', 'stanzas': ['आत्मा मंडराता']},
      {'title': 'Hallelujah', 'stanzas': ['Hallelujah']},
    ];
    await snap('03_songs', SongsHubScreen(
      allSongs: songs,
      songsLoaded: true,
      searchCtrl: TextEditingController(),
      selectedSongIndex: 0,
      onAddSong: () {},
      onImportWord: () {},
      onFilterSongs: (_) {},
      onSelectSong: (_) {},
      onPlaySong: (_) {},
      onEditSong: (_) {},
      onDeleteSong: (_) {},
      onBack: () {},
    ));

    await snap('04_bible', BibleHubScreen(
      onPrevVerse: () {},
      onNextVerse: () {},
      onCastVerse: () {},
      onImportLanguage: () {},
    ));

    await snap('05_files', FilesHubScreen(
      uploadedFiles: [
        {'name': 'Worship_Background.mp4', 'type': 'video', 'size': 13100000},
        {'name': 'Sunday_Service.pdf', 'type': 'pdf', 'size': 890000},
      ],
      isUploading: false,
      activeFileIndex: -1,
      ytUrlCtrl: TextEditingController(),
      onPickAndUploadFile: () {},
      onCastFile: (_) {},
      onDeleteFile: (_) {},
      onCastYouTubeUrl: () {},
      onBack: () {},
    ));

    await snap('06_settings', SettingsHubScreen(
      serverStarted: true,
      connected: false,
      deviceIp: '192.168.1.24',
      onCopyUrl: () {},
      onCastToTV: () {},
      onClassicUI: () {},
      onBack: () {},
    ));
  },
      skip: !fontsAvailable,
      timeout: const Timeout(Duration(minutes: 3)));
}
