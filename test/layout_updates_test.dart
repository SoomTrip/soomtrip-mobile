import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soomtrip/worldcup_screen.dart';
import 'package:soomtrip/destination_detail_screen.dart';
import 'package:soomtrip/saved_region_service.dart';

void main() {
  testWidgets('sketchbook size remains identical after completion',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: WorldCupScreen()));
    await tester.pumpAndSettle();
    final sketchbook = find.byWidgetPredicate((widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName ==
            'assets/images/sketchbook.png');
    final before = tester.getRect(sketchbook);
    for (var i = 0; i < 5; i++) {
      tester.widget<Slider>(find.byType(Slider)).onChangeEnd!(0);
      await tester.pumpAndSettle();
    }
    expect(find.text('배경 효과 ON'), findsOneWidget);
    expect(tester.getRect(sketchbook), before);
    expect(tester.takeException(), isNull);
  });

  for (final count in [15, 16]) {
    testWidgets('few spots notice threshold is inclusive at $count',
        (tester) async {
      final region = SavedRegion(id: 1, regionName: '지역', spots: [
        for (var i = 0; i < count; i++)
          SavedSpot(
              id: i,
              contentId: '$i',
              name: '장소$i',
              categoryLabel: '자연',
              isAnchor: false,
              latitude: null,
              longitude: null),
      ]);
      await tester.pumpWidget(
          MaterialApp(home: DestinationDetailScreen(destination: region)));
      await tester.pumpAndSettle();
      final scroll =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('사람이 많지 않은 숨겨진 여행지는 추천 장소가 적을 수 있어요😢'),
          count == 15 ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
