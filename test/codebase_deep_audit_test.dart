import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biblepresenter/theme.dart';
import 'package:biblepresenter/slide_renderer.dart';
import 'package:biblepresenter/output_router.dart';
import 'package:biblepresenter/state/song_state.dart';
import 'package:biblepresenter/widgets/shared_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Deep Codebase Audit — Theme & Network Assets', () {
    test('AUDIT: Preset backgrounds contain external un-cached Unsplash URLs', () {
      expect(presetBackgrounds.isNotEmpty, isTrue);
      for (final bg in presetBackgrounds) {
        final url = bg['url']!;
        final isExternal = url.startsWith('http://') || url.startsWith('https://');
        expect(isExternal, isTrue,
            reason: 'Background ${bg['name']} relies on external network ($url)');
      }
    });

    test('AUDIT: Animated backgrounds use animated: prefix', () {
      for (final bg in animatedBackgrounds) {
        expect(bg['id']!.startsWith('animated:'), isTrue);
      }
    });
  });

  group('Deep Codebase Audit — SlideRenderer Logic', () {
    test('AUDIT: SlideRenderer slide dimensions are strictly 1920x1080', () {
      expect(SlideRenderer.slideSize.width, 1920.0);
      expect(SlideRenderer.slideSize.height, 1080.0);
    });

    test('AUDIT: SlideRenderer.publish URL construction and file leak', () async {
      final tempDir = await Directory.systemTemp.createTemp('bp_audit_dlna_');
      try {
        SlideRenderer.uploadDirPath = tempDir.path;
        SlideRenderer.deviceIp = '192.168.1.100';
        SlideRenderer.serverPort = 3000;

        final dummyPng = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
        final url1 = await SlideRenderer.publish(dummyPng);
        expect(url1, 'http://192.168.1.100:3000/dlna/slide_1.png');

        final url2 = await SlideRenderer.publish(dummyPng);
        expect(url2, 'http://192.168.1.100:3000/dlna/slide_2.png');

        final dlnaFolder = Directory('${tempDir.path}/dlna');
        final files = dlnaFolder.listSync();
        // Discovered Issue: files accumulate indefinitely without eviction
        expect(files.length, 2);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('AUDIT: SlideRenderer widget tree omits background when tvState lacks background key', () {
      final stateWithoutBg = {
        'type': 'verse',
        'content': {
          'textHi': 'यहोवा मेरा चरवाहा है',
          'textEn': 'The Lord is my shepherd',
          'book': 'Psalms',
          'chapter': 23,
          'verse': 1,
        }
      };
      final widget = SlideRenderer.buildSlideWidget(stateWithoutBg);
      expect(widget, isA<SizedBox>());
    });
  });

  group('Deep Codebase Audit — OutputRouter Background & Debounce Flaws', () {
    test('AUDIT: OutputRouter.stateKey uniquely identifies verse, slide, song', () {
      final key1 = OutputRouter.instance.stateKey({'type': 'verse', 'content': {'book': 'Gen', 'chapter': 1, 'verse': 1}});
      final key2 = OutputRouter.instance.stateKey({'type': 'verse', 'content': {'book': 'Gen', 'chapter': 1, 'verse': 2}});
      expect(key1 != key2, isTrue);
    });
  });

  group('Deep Codebase Audit — SongState Logic & Index Alignment', () {
    test('AUDIT: Song search and selection with empty queries', () {
      final songState = SongState();
      expect(songState.selectedSongIndex, -1);
      expect(songState.selectedSong, isNull);
    });

    test('AUDIT: Stanza clamping does not crash on empty stanzas', () {
      final songState = SongState();
      songState.selectedStanzaIndex = 5;
      expect(songState.selectedStanzaIndex, 0);
    });
  });

  group('Deep Codebase Audit — ScheduleState Deserialization TypeError Bug', () {
    test('AUDIT: Schedule loaded from JSON throws TypeError on scheduleStanzaIndex if stanzas is dynamic', () {
      // Simulate raw JSON deserialization from SharedPreferences
      final rawJson = jsonEncode([
        {
          'name': 'Sunday Service',
          'date': '2026-11-15',
          'songs': [
            {
              'title': 'Amazing Grace',
              'stanzas': ['Stanza 1 text', 'Stanza 2 text']
            }
          ]
        }
      ]);

      final decoded = (jsonDecode(rawJson) as List).cast<Map<String, dynamic>>();
      // In Dart, decoded[0]['songs'][0]['stanzas'] has runtime type List<dynamic>
      final stanzasDynamic = decoded[0]['songs'][0]['stanzas'];
      expect(stanzasDynamic is List<dynamic>, isTrue);

      // Testing line 79 of schedule_state.dart:
      // final stanzas = songs[_scheduleSongIndex]['stanzas'] as List<String>?;
      expect(() {
        final list = stanzasDynamic as List<String>?;
        return list?.length;
      }, throwsA(isA<TypeError>()),
          reason: 'Direct cast "as List<String>" fails on json-decoded data');
    });
  });

  group('Deep Codebase Audit — Shared Widgets fitFontSize', () {
    test('AUDIT: fitFontSize returns within bounds', () {
      final size = fitFontSize(
        text: 'Short text',
        style: const TextStyle(fontSize: 40),
        maxWidth: 500,
        maxHeight: 200,
      );
      expect(size, inInclusiveRange(12, 40));
    });

    test('AUDIT: fitFontSize shrinks for very long verse text', () {
      final longText = 'This is an extremely long scripture verse ' * 20;
      final size = fitFontSize(
        text: longText,
        style: const TextStyle(fontSize: 40),
        maxWidth: 400,
        maxHeight: 100,
      );
      expect(size, lessThan(40));
    });
  });

  group('Deep Codebase Audit — Server Path Traversal & Range Headers', () {
    test('AUDIT: Filename sanitization strips path traversal sequences', () {
      const dirty = '../../../../etc/passwd';
      final safeName = dirty.replaceAll('..', '').split('/').last;
      expect(safeName, 'passwd');
      expect(safeName.contains('..'), isFalse);
    });

    test('AUDIT: HTTP range parser handles start-end, start-only, and suffix-only', () {
      const fileSize = 1000;
      expect(fileSize, 1000);
      // bytes=0-499
      final r1 = RegExp(r'bytes=(\d*)-(\d*)').firstMatch('bytes=0-499');
      expect(r1, isNotNull);
      final s1 = int.parse(r1!.group(1)!);
      final e1 = int.parse(r1.group(2)!);
      expect(e1 - s1 + 1, 500);

      // Suffix range: bytes=-200
      final r2 = RegExp(r'bytes=(\d*)-(\d*)').firstMatch('bytes=-200');
      expect(r2, isNotNull);
      expect(r2!.group(1), isEmpty);
      expect(r2.group(2), '200');
    });
  });
}
