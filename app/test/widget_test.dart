import 'package:guitar_vibe/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Library screen loads title', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GuitarVibeApp()));
    await tester.pump();

    expect(find.text('GuitarVibe'), findsOneWidget);
  });
}
