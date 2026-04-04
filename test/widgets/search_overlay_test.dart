import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/widgets/home/search_overlay.dart';

Widget _wrap({
  required TextEditingController controller,
  VoidCallback? onSearch,
  VoidCallback? onClear,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          SearchOverlay(
            controller: controller,
            showResults: false,
            results: const [],
            onChanged: (_) {},
            onClear: onClear ?? () {},
            onSearch: onSearch ?? () {},
            onMenuSelected: (_) {},
            onTapField: () {},
            onSelectResult: (_) {},
          ),
        ],
      ),
    ),
  );
}

void main() {
  group('SearchOverlay search button', () {
    testWidgets('search icon is always present', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(controller: controller));

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('search button calls onSearch when text is non-empty',
        (tester) async {
      final controller = TextEditingController(text: 'Hall');
      addTearDown(controller.dispose);

      var called = false;
      await tester.pumpWidget(
        _wrap(controller: controller, onSearch: () => called = true),
      );

      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('search button does nothing when text is empty', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      var called = false;
      await tester.pumpWidget(
        _wrap(controller: controller, onSearch: () => called = true),
      );

      // The button has onPressed: null when empty — tap is a no-op
      await tester.tap(find.byIcon(Icons.search), warnIfMissed: false);
      await tester.pump();

      expect(called, isFalse);
    });

    testWidgets('clear button only appears when text is non-empty',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrap(controller: controller));
      expect(find.byIcon(Icons.clear), findsNothing);

      controller.text = 'something';
      await tester.pump();
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear button calls onClear', (tester) async {
      final controller = TextEditingController(text: 'Hall');
      addTearDown(controller.dispose);

      var cleared = false;
      await tester.pumpWidget(
        _wrap(controller: controller, onClear: () => cleared = true),
      );

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(cleared, isTrue);
    });
  });
}
