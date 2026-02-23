import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CampusGuideApp builds MaterialApp with correct configuration',
          (WidgetTester tester) async {
        const injectedHome = SizedBox(key: Key('test-home'));

        await tester.pumpWidget(const CampusGuideApp(home: injectedHome));

        final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));

        expect(materialApp.title, 'Campus Guide');
        expect(materialApp.debugShowCheckedModeBanner, false);
        expect(materialApp.theme?.useMaterial3, true);

        // Assert the MaterialApp is configured with our injected home
        expect(materialApp.home, isA<SizedBox>());

        // And also confirm it is in the widget tree
        await tester.pump(); // give it one more frame
        expect(find.byKey(const Key('test-home')), findsOneWidget);
      });

  test('isE2EMode default is false', () {
    expect(isE2EMode, false);
  });
}