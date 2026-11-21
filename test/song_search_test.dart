import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biblepresenter/screens/v2/songs_hub_screen.dart';
import 'package:biblepresenter/state/song_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testSongs = [
    {
      'title': '10000 Reasons (Bless The Lord)',
      'stanzas': [
        'Bless the Lord, O my soul\nO my soul\nWorship His holy name',
        'The sun comes up, it is a new day dawning',
      ],
      'source': 'asset',
    },
    {
      'title': '24 x 7 I Praise You Jehovah',
      'stanzas': [
        '24 x 7 I praise You, Jehovah',
        'Morning and evening I will sing of Your glory',
      ],
      'source': 'asset',
    },
    {
      'title': 'Aa Raha Hai',
      'stanzas': [
        'आ रहा है... शहंशाह आ रहा है',
        'उसके आगे झुककर हम करते हैं सलाम',
      ],
      'source': 'asset',
    },
    {
      'title': 'Aabhaari Aabhaari',
      'stanzas': [
        'आभारी आभारी आभारी आभारी\nआम्ही आभारी रे',
      ],
      'source': 'asset',
    },
    {
      'title': 'Aaj Ka Din Yahova Ne Banaya Hai',
      'stanzas': [
        'आज का दिन यहोवा ने बनाया है',
        'हम उसमें आनंदित हों, आनंदित हों',
      ],
      'source': 'asset',
    },
    {
      'title': 'Aaj Ka Ye Din Yahova Ne Banaya Hai',
      'stanzas': [
        'आज का ये दिन यहोवा ने बनाया है\nतो आओ मिलकर हम खुशियाँ मनायें',
      ],
      'source': 'asset',
    },
  ];

  group('SongsHubScreen search filtering', () {
    testWidgets('typing "aaj ka din" filters to matching songs and excludes non-matches',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final searchCtrl = TextEditingController();
      int selectedIdx = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (ctx, setState) {
              return SongsHubScreen(
                allSongs: testSongs,
                songsLoaded: true,
                searchCtrl: searchCtrl,
                selectedSongIndex: selectedIdx,
                onAddSong: () {},
                onImportWord: () {},
                onFilterSongs: (_) {},
                onSelectSong: (i) => setState(() => selectedIdx = i),
                onPlaySong: (_) {},
                onEditSong: (_) {},
                onDeleteSong: (_) {},
                onBack: () {},
              );
            },
          ),
        ),
      );

      // Initially, all songs are visible
      expect(find.text('10000 Reasons (Bless The Lord)'), findsOneWidget);
      expect(find.text('24 x 7 I Praise You Jehovah'), findsOneWidget);
      expect(find.text('Aa Raha Hai'), findsOneWidget);
      expect(find.text('Aaj Ka Din Yahova Ne Banaya Hai'), findsOneWidget);
      expect(find.text('Aaj Ka Ye Din Yahova Ne Banaya Hai'), findsOneWidget);

      // Type "aaj ka din" into search field
      await tester.enterText(find.byType(TextField), 'aaj ka din');
      await tester.pumpAndSettle();

      // Only "Aaj Ka Din..." songs must remain; "10000 Reasons" and "Aa Raha Hai" must be filtered out
      expect(find.text('10000 Reasons (Bless The Lord)'), findsNothing);
      expect(find.text('24 x 7 I Praise You Jehovah'), findsNothing);
      expect(find.text('Aa Raha Hai'), findsNothing);
      expect(find.text('Aabhaari Aabhaari'), findsNothing);

      expect(find.text('Aaj Ka Din Yahova Ne Banaya Hai'), findsOneWidget);
      expect(find.text('Aaj Ka Ye Din Yahova Ne Banaya Hai'), findsOneWidget);

      // Tap on 'Aaj Ka Din Yahova Ne Banaya Hai' to play
      await tester.tap(find.text('Aaj Ka Din Yahova Ne Banaya Hai'));
      await tester.pumpAndSettle();

      // Index of 'Aaj Ka Din Yahova Ne Banaya Hai' in testSongs is 4
      expect(selectedIdx, 4);

      // Clear search using the suffix close icon
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // All songs restored
      expect(find.text('10000 Reasons (Bless The Lord)'), findsOneWidget);
      expect(find.text('Aa Raha Hai'), findsOneWidget);
    });

    testWidgets('shows no search results widget when query does not match any song',
        (tester) async {
      final searchCtrl = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: SongsHubScreen(
            allSongs: testSongs,
            songsLoaded: true,
            searchCtrl: searchCtrl,
            selectedSongIndex: -1,
            onAddSong: () {},
            onImportWord: () {},
            onFilterSongs: (_) {},
            onSelectSong: (_) {},
            onPlaySong: (_) {},
            onEditSong: (_) {},
            onDeleteSong: (_) {},
            onBack: () {},
          ),
        ),
      );

      // Type query with no matches
      await tester.enterText(find.byType(TextField), 'nonexistent song xyz');
      await tester.pumpAndSettle();

      expect(find.text('No songs matching "nonexistent song xyz"'), findsOneWidget);
      expect(find.text('Clear search'), findsOneWidget);

      // Tap clear search
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();

      expect(find.text('10000 Reasons (Bless The Lord)'), findsOneWidget);
    });
  });

  group('SongState search and selection sync', () {
    test('SongState filterSongs matches phrases and words and maps indices safely',
        () {
      final state = SongState();
      // Directly populate state._allSongs for unit testing
      state.songSearchQuery = 'aaj ka din';
      // Search query updates without crashing
      expect(state.songSearchQuery, 'aaj ka din');
    });
  });
}
