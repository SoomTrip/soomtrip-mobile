import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soomtrip/home_screen.dart';
import 'package:soomtrip/my_destination_screen.dart';

void main() {
  testWidgets('shared list includes sent and received and fits four rows', (tester) async {
    SharedPreferences.setMockInitialValues({'soomtrip_access_token': 'test'});
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: MyDestinationsScreen(sharedOnly: true)));
      await tester.pumpAndSettle();
      expect(find.text('개인 여행지'), findsNothing);
      for (var i = 1; i <= 4; i++) {
        expect(find.text('공유$i').hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) async => http.Response(jsonEncode([
      {'id': 10, 'region_name': '개인 여행지', 'spots': []},
      for (var i = 1; i <= 4; i++) {
        'id': i, 'region_name': '공유$i', 'spots': [],
        if (i.isEven) 'shared_from': {'share_id': i, 'user_id': 7, 'nickname': '친구'},
        if (i.isOdd) 'shared_to': [{'share_id': i, 'user_id': 7, 'nickname': '친구'}],
      },
    ]), 200, headers: {'content-type': 'application/json; charset=utf-8'})));
  });

  testWidgets('six home destinations fit and bookmarks sit outside cards', (tester) async {
    tester.view.physicalSize = const Size(390, 744);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'soomtrip_access_token': 'test'});
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();
      expect(find.text('지역6').hitTestable(), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border).hitTestable(), findsNWidgets(6));
      expect(tester.getTopLeft(find.text('지역1')).dy, greaterThan(372));
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) async => http.Response(jsonEncode([
      for (var i = 1; i <= 6; i++) {'id': i, 'region_name': '지역$i', 'spots': []},
    ]), 200, headers: {'content-type': 'application/json; charset=utf-8'})));
  });

  testWidgets('received shared icon selects, starts and shows details after one second', (tester) async {
    tester.view.physicalSize = const Size(390, 744);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'soomtrip_access_token': 'test'});
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.bookmark_border).hitTestable(), findsOneWidget);
      expect(find.byIcon(Icons.people_alt_outlined).hitTestable(), findsOneWidget);

      await tester.tap(find.byIcon(Icons.people_alt_outlined));
      await tester.pump();
      expect(find.text('From\n세영'), findsNothing);
      expect(find.text('start'), findsOneWidget);
      expect(find.byIcon(Icons.people_alt_rounded), findsOneWidget);
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      expect(find.text('받은 여행지'), findsNWidgets(2));
      final button = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'start'));
      expect(button.style!.backgroundColor!.resolve({}), const Color(0xFF4A7C59));
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      expect(find.text('어디로 떠나볼까요?'), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getInt('home_active_trip_id'), isNull);
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.people_alt_rounded)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('From\n세영'), findsNothing);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('From\n세영'), findsOneWidget);
      await gesture.up();
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byIcon(Icons.people_alt_rounded));
      await tester.pumpAndSettle();
      expect(find.text('어디로 떠나볼까요?'), findsOneWidget);
      expect(find.text('start'), findsNothing);
      expect(find.byIcon(Icons.people_alt_outlined), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) async => http.Response(jsonEncode([
      {'id': 1, 'region_name': '내 여행지', 'spots': []},
      {
        'id': 2,
        'region_name': '받은 여행지',
        'spots': [],
        'shared_from': {'share_id': 3, 'user_id': 7, 'nickname': '세영'},
      },
    ]), 200, headers: {'content-type': 'application/json; charset=utf-8'})));
  });
}
