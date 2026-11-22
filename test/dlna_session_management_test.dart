import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:biblepresenter/dlna_service.dart';
import 'package:biblepresenter/slide_renderer.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DLNA Session Management & Connection Reuse', () {
    test('initial session state is clean and idle', () {
      final dlna = DlnaService.instance;
      expect(dlna.currentMediaType, equals(DlnaMediaType.none));
      expect(dlna.currentMediaUri, isNull);
      expect(dlna.isSessionActive, isFalse);
    });

    test('DlnaMediaType enum values are properly defined', () {
      expect(DlnaMediaType.values, containsAll([
        DlnaMediaType.none,
        DlnaMediaType.slide,
        DlnaMediaType.video,
        DlnaMediaType.image,
      ]));
    });

    test('SlideRenderer.publish with stable: true produces consistent URL for session reuse', () async {
      final tempDir = await Directory.systemTemp.createTemp('bp_dlna_stable_test_');
      try {
        SlideRenderer.uploadDirPath = tempDir.path;
        SlideRenderer.deviceIp = '192.168.1.50';
        SlideRenderer.serverPort = 3000;

        // Dummy JPEG header: 0xFF, 0xD8
        final slide1Bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02]);
        final slide2Bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x03, 0x04]);

        // Publish first slide with stable: true
        final url1 = await SlideRenderer.publish(slide1Bytes, stable: true);
        expect(url1, equals('http://192.168.1.50:3000/dlna/current_slide.jpg'));

        // Memory cache has current_slide.jpg with slide1 bytes
        expect(SlideRenderer.memorySlides['current_slide.jpg'], equals(slide1Bytes));

        // Publish second slide with stable: true
        final url2 = await SlideRenderer.publish(slide2Bytes, stable: true);
        // The URL MUST remain identical across slide changes to avoid "device connected" on TV
        expect(url2, equals('http://192.168.1.50:3000/dlna/current_slide.jpg'));
        expect(url1, equals(url2));

        // Memory cache is updated with slide2 bytes at the exact same URL
        expect(SlideRenderer.memorySlides['current_slide.jpg'], equals(slide2Bytes));

        // Disk file current_slide.jpg is also updated
        final currentFile = File('${tempDir.path}/dlna/current_slide.jpg');
        expect(currentFile.existsSync(), isTrue);
        expect(await currentFile.readAsBytes(), equals(slide2Bytes));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('SlideRenderer.publish with stable: false maintains backward compatibility', () async {
      final tempDir = await Directory.systemTemp.createTemp('bp_dlna_legacy_test_');
      try {
        SlideRenderer.uploadDirPath = tempDir.path;
        SlideRenderer.deviceIp = '192.168.1.50';
        SlideRenderer.serverPort = 3000;
        SlideRenderer.resetSlideCounter();

        final dummy = Uint8List.fromList([0xFF, 0xD8, 0x00]);
        final url = await SlideRenderer.publish(dummy, stable: false);
        expect(url, equals('http://192.168.1.50:3000/dlna/slide_1.jpg'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('DlnaService disconnect resets session state', () async {
      final dlna = DlnaService.instance;
      dlna.currentMediaType = DlnaMediaType.slide;
      dlna.currentMediaUri = 'http://192.168.1.50:3000/dlna/current_slide.jpg';
      dlna.isSessionActive = true;

      await dlna.disconnect();

      expect(dlna.currentMediaType, equals(DlnaMediaType.none));
      expect(dlna.currentMediaUri, isNull);
      expect(dlna.isSessionActive, isFalse);
      expect(dlna.connectedDevice, isNull);
    });
  });
}
