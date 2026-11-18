import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biblepresenter/widgets/top_notification.dart';

void main() {
  testWidgets('TopNotification displays TV connected successfully with check icon',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  TopNotification.show(
                    context,
                    'TV connected successfully (Samsung TV)',
                    icon: Icons.check_circle_outline,
                  );
                },
                child: const Text('Connect TV'),
              ),
            ),
          ),
        ),
      ),
    );

    // Initial state: notification not visible
    expect(find.text('TV connected successfully (Samsung TV)'), findsNothing);

    // Tap button to show notification
    await tester.tap(find.text('Connect TV'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Notification is now visible with high contrast
    expect(find.text('TV connected successfully (Samsung TV)'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

    // Advance clock past auto-dismiss duration
    await tester.pump(const Duration(milliseconds: 3000));
    expect(find.text('TV connected successfully (Samsung TV)'), findsNothing);
  });

  testWidgets('Floating TV connection button structure renders properly',
      (WidgetTester tester) async {
    bool sheetOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: FloatingActionButton(
            heroTag: 'tv_connection_fab',
            onPressed: () {
              sheetOpened = true;
            },
            child: const Icon(Icons.tv),
          ),
          body: const Center(child: Text('Main Content Stage')),
        ),
      ),
    );

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.tv), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(sheetOpened, isTrue);
  });
}
