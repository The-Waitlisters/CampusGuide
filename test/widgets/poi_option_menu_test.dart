import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proj/widgets/home/poi_option_menu.dart';

Widget _wrap(PoiOptionMenu child) =>
    MaterialApp(home: Scaffold(body: child));

PoiOptionMenu _menu({
  bool restaurants = false,
  bool cafes = false,
  bool parks = false,
  bool parking = false,
  bool fastFood = false,
  bool nightClub = false,
  double currentSliderValue = 0,
  double distanceSliderValue = 0,
  String sortBy = '',
  ValueChanged<bool?>? onRestaurantsChanged,
  ValueChanged<bool?>? onCafesChanged,
  ValueChanged<bool?>? onParksChanged,
  ValueChanged<bool?>? onParkingChanged,
  ValueChanged<bool?>? onFastFoodChanged,
  ValueChanged<bool?>? onNightClubChanged,
  ValueChanged<double?>? onNearbyChanged,
  ValueChanged<String?>? onSortByChanged,
  ValueChanged<double?>? onDistanceChanged,
  VoidCallback? onReset,
  VoidCallback? onApply,
  VoidCallback? onClose,
  VoidCallback? onShow,
}) =>
    PoiOptionMenu(
      restaurants: restaurants,
      cafes: cafes,
      parks: parks,
      parking: parking,
      fastFood: fastFood,
      nightClub: nightClub,
      currentSliderValue: currentSliderValue,
      distanceSliderValue: distanceSliderValue,
      sortBy: sortBy,
      onRestaurantsChanged: onRestaurantsChanged ?? (_) {},
      onCafesChanged: onCafesChanged ?? (_) {},
      onParksChanged: onParksChanged ?? (_) {},
      onParkingChanged: onParkingChanged ?? (_) {},
      onFastFoodChanged: onFastFoodChanged ?? (_) {},
      onNightClubChanged: onNightClubChanged ?? (_) {},
      onNearbyChanged: onNearbyChanged ?? (_) {},
      onSortByChanged: onSortByChanged ?? (_) {},
      onDistanceChanged: onDistanceChanged ?? (_) {},
      onReset: onReset ?? () {},
      onApply: onApply ?? () {},
      onClose: onClose ?? () {},
      onShow: onShow ?? () {},
    );

void main() {
  group('PoiOptionMenu', () {
    setUp(() async {});

    Future<void> pumpMenu(WidgetTester tester, PoiOptionMenu menu) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(menu));
      await tester.pumpAndSettle();
    }

    testWidgets('renders title and close button', (tester) async {
      await pumpMenu(tester, _menu());
      expect(find.text('Points of interest filter'), findsOneWidget);
      expect(find.byTooltip('Cancel'), findsOneWidget);
    });

    testWidgets('onClose is called when cancel button tapped', (tester) async {
      var closed = false;
      await pumpMenu(tester, _menu(onClose: () => closed = true));
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('onRestaurantsChanged fires when restaurant checkbox tapped',
        (tester) async {
      bool? changed;
      await pumpMenu(
          tester,
          _menu(
            restaurants: false,
            onRestaurantsChanged: (v) => changed = v,
          ));
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pump();
      expect(changed, isTrue);
    });

    testWidgets('onCafesChanged fires when cafes checkbox tapped',
        (tester) async {
      bool? changed;
      await pumpMenu(
          tester,
          _menu(cafes: false, onCafesChanged: (v) => changed = v));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      expect(changed, isTrue);
    });

    testWidgets('onParksChanged fires when parks checkbox tapped',
        (tester) async {
      bool? changed;
      await pumpMenu(
          tester,
          _menu(parks: false, onParksChanged: (v) => changed = v));
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pump();
      expect(changed, isTrue);
    });

    testWidgets('onParkingChanged fires when parking checkbox tapped',
        (tester) async {
      bool? changed;
      await pumpMenu(
          tester,
          _menu(parking: false, onParkingChanged: (v) => changed = v));
      await tester.tap(find.byType(Checkbox).at(3));
      await tester.pump();
      expect(changed, isTrue);
    });

    testWidgets('onFastFoodChanged fires when fast food checkbox tapped',
        (tester) async {
      bool? changed;
      await pumpMenu(
          tester,
          _menu(fastFood: false, onFastFoodChanged: (v) => changed = v));
      await tester.tap(find.byType(Checkbox).at(4));
      await tester.pump();
      expect(changed, isTrue);
    });

    testWidgets('onNightClubChanged fires when night club checkbox tapped',
        (tester) async {
      bool? changed;
      await pumpMenu(
          tester,
          _menu(nightClub: false, onNightClubChanged: (v) => changed = v));
      await tester.tap(find.byType(Checkbox).at(5));
      await tester.pump();
      expect(changed, isTrue);
    });

    testWidgets('onNearbyChanged fires when nearby slider is dragged',
        (tester) async {
      double? changed;
      await pumpMenu(
          tester,
          _menu(
            currentSliderValue: 0,
            onNearbyChanged: (v) => changed = v,
          ));
      await tester.drag(find.byType(Slider).first, const Offset(50, 0));
      await tester.pump();
      expect(changed, isNotNull);
    });

    testWidgets('onDistanceChanged fires when distance slider is dragged',
        (tester) async {
      double? changed;
      await pumpMenu(
          tester,
          _menu(
            distanceSliderValue: 0,
            onDistanceChanged: (v) => changed = v,
          ));
      await tester.drag(find.byType(Slider).last, const Offset(50, 0));
      await tester.pump();
      expect(changed, isNotNull);
    });

    testWidgets('onReset is called when Reset button tapped', (tester) async {
      var reset = false;
      await pumpMenu(tester, _menu(onReset: () => reset = true));
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(reset, isTrue);
    });

    testWidgets('onApply is called when Apply button tapped', (tester) async {
      var applied = false;
      await pumpMenu(tester, _menu(onApply: () => applied = true));
      await tester.tap(find.text('Apply'));
      await tester.pump();
      expect(applied, isTrue);
    });

    testWidgets('onShow is called when Show results button tapped',
        (tester) async {
      var shown = false;
      await pumpMenu(tester, _menu(onShow: () => shown = true));
      await tester.tap(find.text('Show results'));
      await tester.pump();
      expect(shown, isTrue);
    });
  });
}
