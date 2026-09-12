import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soomtrip/gacha_screen.dart';
import 'package:soomtrip/main_screen.dart';
import 'package:soomtrip/splash_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'soomtrip_access_token': 'test-token',
        'soomtrip_refresh_token': 'test-refresh',
        'soomtrip_intro_completed': true,
      }));

  testWidgets('prefetch failure sends a fresh request on the first handle tap',
      (tester) async {
    final prefetch = Completer<Map<String, dynamic>>();
    var requests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        home:
            GachaScreen(preferenceId: 1, recommendationFuture: prefetch.future),
      ));
      prefetch.completeError(Exception('offline'));
      await tester.pump();
      final handle = find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName.endsWith('gacha_handle.png'));
      tester
          .widget<GestureDetector>(find
              .ancestor(of: handle, matching: find.byType(GestureDetector))
              .first)
          .onTap!();
      await tester.pump();
      expect(requests, 1);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(find.text('여행지 추천 실패'), findsOneWidget);
      tester
          .widget<GestureDetector>(find
              .ancestor(of: handle, matching: find.byType(GestureDetector))
              .first)
          .onTap!();
      await tester.pump();
      expect(requests, 2);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              requests++;
              return http.Response('{}', 500);
            }));
  });

  testWidgets('entry lookup failure stays on splash and can retry',
      (tester) async {
    var requests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(MainScreen), findsNothing);
      expect(find.text('다시 시도'), findsOneWidget);
      await tester.tap(find.text('다시 시도'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.byType(MainScreen), findsNothing);
    },
        () => MockClient((request) async {
              requests++;
              return http.Response('{}', 500);
            }));
  });

  testWidgets('expired session returns to login instead of home',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('카카오 로그인'), findsOneWidget);
      expect(find.byType(MainScreen), findsNothing);
    }, () => MockClient((request) async => http.Response('{}', 401)));
  });

  testWidgets('entry response after splash disposal does not navigate',
      (tester) async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(const MaterialApp(home: Text('다른 화면')));
      response.complete(http.Response('[]', 200));
      await tester.pumpAndSettle();
      expect(find.text('다른 화면'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) => response.future));
  });
}
