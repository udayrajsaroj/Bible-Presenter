import 'package:flutter_test/flutter_test.dart';
import 'package:biblepresenter/services/youtube_parser.dart';
import 'package:biblepresenter/dlna_service.dart';

void main() {
  group('YouTube URL Parsing Tests', () {
    test('extracts from standard watch?v= URL', () {
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      expect(YouTubeParser.extractId(url), equals('dQw4w9WgXcQ'));
    });

    test('extracts from youtu.be short URL with query params', () {
      const url = 'https://youtu.be/dQw4w9WgXcQ?si=rX890abcd';
      expect(YouTubeParser.extractId(url), equals('dQw4w9WgXcQ'));
    });

    test('extracts from shorts/ URL', () {
      const url = 'https://www.youtube.com/shorts/dQw4w9WgXcQ';
      expect(YouTubeParser.extractId(url), equals('dQw4w9WgXcQ'));
    });

    test('extracts from live/ URL', () {
      const url = 'https://www.youtube.com/live/dQw4w9WgXcQ?feature=share';
      expect(YouTubeParser.extractId(url), equals('dQw4w9WgXcQ'));
    });

    test('extracts from embed/ URL', () {
      const url = 'https://www.youtube.com/embed/dQw4w9WgXcQ';
      expect(YouTubeParser.extractId(url), equals('dQw4w9WgXcQ'));
    });

    test('accepts raw 11-character video ID', () {
      const id = 'dQw4w9WgXcQ';
      expect(YouTubeParser.extractId(id), equals('dQw4w9WgXcQ'));
    });

    test('returns null for invalid non-YouTube URL', () {
      const url = 'https://google.com/search?q=video';
      expect(YouTubeParser.extractId(url), isNull);
    });
  });

  group('Kodi / DLNA Video & YouTube Helpers', () {
    test('DlnaService instance is available', () {
      final dlna = DlnaService.instance;
      expect(dlna, isNotNull);
      expect(dlna.isConnected, isFalse);
    });
  });
}
