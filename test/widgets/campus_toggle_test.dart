import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/widgets/campus_toggle.dart';
import 'package:proj/models/campus.dart';

void main() {
  group('US-1.3 Campus Toggle', () {
    testWidgets('Selecting a campus triggers onChanged with correct value', (
      WidgetTester tester,
    ) async {
      Campus selectedCampus = Campus.sgw;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampusToggle(
              selected: selectedCampus,
              onChanged: (Campus campus) {
                selectedCampus = campus;
              },
            ),
          ),
        ),
      );

      // Verify both campus options are rendered
      expect(find.text('SGW'), findsOneWidget);
      expect(find.text('Loyola'), findsOneWidget);

      // Tap Loyola segment
      await tester.tap(find.text('Loyola'));
      await tester.pump();

      // Verify the selected campus changed
      expect(selectedCampus, Campus.loyola);
    });
  });
}
