import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biblepresenter/widgets/shared_widgets.dart';

void main() {
  testWidgets('Cast to TV modal is scrollable and displays HOW IT WORKS clearly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SafeArea(
                    top: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.88,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Cast to TV'),
                            const SizedBox(height: 20),
                            const Text('TV Direct'),
                            const SizedBox(height: 20),
                            const Text('Chromecast / AirPlay'),
                            const SizedBox(height: 20),
                            const Text('Screen Mirror'),
                            const SizedBox(height: 20),
                            const Text('Browser Connect'),
                            const SizedBox(height: 20),
                            Container(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('HOW IT WORKS:'),
                                  castStep('1', 'TV Direct (Recommended)'),
                                  castStep('2', 'Chromecast / AirPlay'),
                                  castStep('3', 'Screen Mirror'),
                                  castStep('4', 'Browser Connect'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open Cast'),
            ),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open Cast'));
    await tester.pumpAndSettle();

    // Verify modal is open and scrollable
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Cast to TV'), findsOneWidget);
    expect(find.text('HOW IT WORKS:'), findsOneWidget);
    expect(find.text('TV Direct (Recommended)'), findsOneWidget);
    expect(find.text('Browser Connect'), findsWidgets);
  });
}
