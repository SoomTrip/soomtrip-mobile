import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soomtrip/destination_detail_screen.dart';
import 'package:soomtrip/saved_region_service.dart';

void main() {
  testWidgets('saved selection requires confirmation only until reset accepted', (tester) async {
    SharedPreferences.setMockInitialValues({'soomtrip_access_token': 'test'});
    final region = SavedRegion(id: 1, regionName: '테스트', spots: [
      for (final id in ['A', 'B']) SavedSpot(id: id == 'A' ? 1 : 2,
        contentId: id, name: '장소$id', categoryLabel: '자연', isAnchor: false,
        latitude: null, longitude: null),
    ]);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: DestinationDetailScreen(destination: region)));
      await tester.pumpAndSettle();
      expect(find.text('경로 확인하기'), findsOneWidget);
      await tester.tap(find.text('장소A'));
      await tester.pumpAndSettle();
      expect(find.text('경로를 재설정하시겠습니까?'), findsOneWidget);
      await tester.tap(find.text('아니요'));
      await tester.pumpAndSettle();
      expect(find.text('경로 확인하기'), findsOneWidget);
      await tester.tap(find.text('장소A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('예'));
      await tester.pumpAndSettle();
      expect(find.text('이대로 경로 작성하기'), findsOneWidget);
      await tester.tap(find.text('장소B'));
      await tester.pumpAndSettle();
      expect(find.text('경로를 재설정하시겠습니까?'), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
      expect(request.method, 'GET');
      return http.Response(jsonEncode({'route_by_day': {'day1': [
        {'content_id': 'A', 'name': '장소A', 'category_label': '자연'}
      ]}}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    }));
  });
}
