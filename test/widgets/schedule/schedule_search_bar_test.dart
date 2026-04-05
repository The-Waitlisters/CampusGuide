import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/widgets/schedule/schedule_search_bar.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders text field and forwards change and submit callbacks', (tester) async {
    final controller = TextEditingController();
    String? changedValue;
    String? submittedValue;

    await tester.pumpWidget(
      wrap(
        ScheduleSearchBar(
          controller: controller,
          onChanged: (value) {
            changedValue = value;
          },
          onSubmitted: (value) {
            submittedValue = value;
          },
        ),
      ),
    );

    expect(find.text('Enter Course Name'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'SOEN 363');
    await tester.pump();

    expect(controller.text, 'SOEN 363');
    expect(changedValue, 'SOEN 363');

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(submittedValue, 'SOEN 363');
  });
}