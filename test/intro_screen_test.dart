import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soomtrip/intro_screen.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    testWidgets('intro stays readable and advances through four pages at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'CustomFont'),
        home: const IntroScreen(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      final title = find.textContaining('TRAVEL GACHA', findRichText: true);
      final body = find.textContaining('취향 월드컵을 진행하면서');
      expect(
          tester.getBottomLeft(title).dy, lessThan(tester.getTopLeft(body).dy));
      for (final heading in ['ROUTE & DIARY', 'STAMP', 'FRIENDS']) {
        expect(find.text('다음'), findsNothing);
        expect(find.text('시작하기'), findsNothing);
        await tester.drag(find.byType(PageView), Offset(-size.width * 0.8, 0));
        await tester.pumpAndSettle();
        expect(
            find.textContaining(heading, findRichText: true), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(find.text('시작하기'), findsOneWidget);
      expect(find.text('다음'), findsNothing);
    });
  }
}
