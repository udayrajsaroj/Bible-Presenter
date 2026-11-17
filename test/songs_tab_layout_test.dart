import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biblepresenter/tabs/songs_tab.dart';
import 'package:biblepresenter/widgets/top_notification.dart';

void main() {
  testWidgets('SongsTab fills available height and lists all songs without 250px cap',
      (WidgetTester tester) async {
    final sampleSongs = List.generate(
      25,
      (i) => {
        'title': 'Test Song ${i + 1}',
        'stanzas': ['Line 1 of song ${i + 1}'],
        'source': 'asset',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongsTab(
            allSongs: sampleSongs,
            filteredSongs: sampleSongs,
            songsLoaded: true,
            songSearchQuery: '',
            selectedSongIndex: -1,
            selectedStanzaIndex: 0,
            songSearchCtrl: TextEditingController(),
            importingWord: false,
            onFilterSongs: (_) {},
            onShowAddSongModal: () {},
            onShowCreateScheduleModal: () {},
            onImportWord: () {},
            onExportWord: () {},
            onEditSlides: () {},
            onDeleteSong: (_) {},
            onSelectSong: (_) {},
            onSelectStanza: (_) {},
            onCastSong: () {},
            onPrevStanza: () {},
            onNextStanza: () {},
            onOpenFullscreen: () {},
            schedules: const [],
            scheduleMode: false,
            activeScheduleIndex: -1,
            onOpenScheduleDetail: (_) {},
            onDeleteSchedule: (_) {},
            onStartSchedulePresentation: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify CustomScrollView & SliverList are present
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(SliverList), findsOneWidget);

    // Verify first song is visible
    expect(find.text('Test Song 1'), findsOneWidget);

    // Verify search bar and action buttons are present
    expect(find.text('SEARCH SONGS'), findsOneWidget);
    expect(find.text('Add Song'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);

    // Verify that the songs list is not restricted to 250px BoxConstraints
    final containerFinders = find.byType(Container);
    for (final c in tester.widgetList<Container>(containerFinders)) {
      final constraints = c.constraints;
      if (constraints != null) {
        expect(constraints.maxHeight != 250, true,
            reason: 'SongsTab should not artificially cap song list to 250px');
      }
    }
  });

  testWidgets('TopNotification.show displays at top with white text and dismisses',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  TopNotification.show(context, 'URL copied!');
                },
                child: const Text('Copy'),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap button to show notification
    await tester.tap(find.text('Copy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify notification text is shown
    final notificationFinder = find.text('URL copied!');
    expect(notificationFinder, findsOneWidget);

    // Verify text color is pure white
    final textWidget = tester.widget<Text>(notificationFinder);
    expect(textWidget.style?.color, Colors.white);
    expect(textWidget.style?.fontWeight, FontWeight.w600);

    // Wait for auto dismiss
    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.text('URL copied!'), findsNothing);
  });
}
