import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:biblepresenter/services/song_docx.dart';
import 'package:biblepresenter/state/song_state.dart';

void main() {
  group('SongDocx roundtrip', () {
    const stanzas = [
      '[Chorus]\nBless the Lord, O my soul\nO my soul',
      'The sun comes up, it\'s a new day dawning\nA <new> & "special" day',
    ];

    test('export → parse preserves title, slides and labels', () {
      final bytes = SongDocx.exportSongDocx('10,000 Reasons', stanzas);
      expect(bytes, isNotEmpty);
      final parsed = SongDocx.parseSongDocx(bytes);
      expect(parsed.title, '10,000 Reasons');
      expect(parsed.stanzas.length, 2);
      expect(parsed.stanzas[0], stanzas[0]);
      expect(parsed.stanzas[1], stanzas[1]);
    });

    test('escapes XML special characters safely', () {
      final bytes = SongDocx.exportSongDocx('A <B> & C\'s "D"', ['line 1']);
      final parsed = SongDocx.parseSongDocx(bytes);
      expect(parsed.title, 'A <B> & C\'s "D"');
    });

    test('rejects non-docx bytes', () {
      expect(() => SongDocx.parseSongDocx([1, 2, 3, 4]),
          throwsFormatException);
    });
  });

  group('SongDocx.paragraphsToSong', () {
    test('blank lines split slides, first paragraph is the title', () {
      final song = SongDocx.paragraphsToSong([
        'SONG: Amazing Grace',
        '',
        'Amazing grace how sweet the sound',
        'That saved a wretch like me',
        '',
        'I once was lost, but now am found',
      ]);
      expect(song.title, 'Amazing Grace');
      expect(song.stanzas.length, 2);
      expect(song.stanzas[0],
          'Amazing grace how sweet the sound\nThat saved a wretch like me');
      expect(song.stanzas[1], 'I once was lost, but now am found');
    });

    test('repeated title line inside the body is ignored', () {
      final song = SongDocx.paragraphsToSong([
        'My Song',
        'My Song',
        'verse line',
      ]);
      expect(song.title, 'My Song');
      expect(song.stanzas, ['verse line']);
    });

    test('throws when there are no lyrics', () {
      final bytes = SongDocx.exportSongDocx('Empty Song', []);
      expect(() => SongDocx.parseSongDocx(bytes), throwsFormatException);
    });
  });

  group('SongState edits', () {
    test('importSong adds a manual song and selects it', () async {
      SharedPreferences.setMockInitialValues({});
      final state = SongState();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final ok = await state.importSong(title: 'From Word', stanzas: [
        'slide one',
        'slide two',
      ]);
      expect(ok, isTrue);
      expect(state.allSongs.length, 1);
      expect(state.allSongs.first['source'], 'manual');
      expect(state.selectedSongIndex, 0);
      expect(state.selectedSongStanzas!.length, 2);
    });

    test('saveSongEdits updates a manual song in place', () async {
      SharedPreferences.setMockInitialValues({});
      final state = SongState();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await state.importSong(title: 'Old', stanzas: ['a']);
      final song = state.allSongs.first;

      final result = await state.saveSongEdits(
          song: song, newTitle: 'New', newStanzas: ['b', 'c']);
      expect(result, 'updated');
      expect(state.allSongs.length, 1);
      expect(state.allSongs.first['title'], 'New');
      expect(state.allSongs.first['stanzas'], ['b', 'c']);
    });

    test('saveSongEdits on an asset song creates an editable copy',
        () async {
      SharedPreferences.setMockInitialValues({});
      final state = SongState();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Simulate an asset song (loaded from assets normally).
      state.allSongs.add({
        'title': 'Asset Song',
        'stanzas': ['original'],
        'source': 'asset'
      });

      final result = await state.saveSongEdits(
          song: state.allSongs.first,
          newTitle: 'Asset Song',
          newStanzas: ['edited slide']);
      expect(result, 'copied');
      // Copy added, original asset untouched.
      expect(state.allSongs.length, 2);
      expect(state.allSongs[0]['source'], 'manual');
      expect(state.allSongs[0]['stanzas'], ['edited slide']);
      expect(state.allSongs[1]['stanzas'], ['original']);
      expect(state.allSongs[1]['source'], 'asset');
    });
  });
}
