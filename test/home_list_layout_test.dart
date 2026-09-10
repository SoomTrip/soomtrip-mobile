import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soomtrip/home_screen.dart';

void main() {
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

  testWidgets('shared destinations show a person icon instead of a bookmark', (tester) async {
    tester.view.physicalSize = const Size(390, 744);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'soomtrip_access_token': 'test'});
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.bookmark_border).hitTestable(), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded).hitTestable(), findsOneWidget);

      await tester.tap(find.byIcon(Icons.person_rounded));
      await tester.pump();
      expect(find.text('세영'), findsOneWidget);
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
