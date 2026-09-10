import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soomtrip/share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'soomtrip_access_token': 'test'}));
  test('share sends region ID and recipient user ID', () async {
    await http.runWithClient(() => ShareService.create(savedRegionId: 12, friendUserId: 7),
      () => MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/saved-regions/12/share');
        expect(jsonDecode(request.body), {'friend_user_ids': [7]});
        expect(request.headers['Authorization'], 'Bearer test');
        return http.Response('{"created":[{"friend_user_id":7,"share_id":8}],"failed":[]}', 200);
      }));
  });
  test('200 with recipient failure is not reported as success', () async {
    await http.runWithClient(() async {
      await expectLater(ShareService.create(savedRegionId: 12, friendUserId: 7), throwsA(isA<ShareException>()));
    }, () => MockClient((_) async => http.Response('{"created":[],"failed":[{"friend_user_id":7,"reason":"ALREADY_SAVED"}]}', 200)));
  });
  test('already-pending failure surfaces the waiting-for-response message', () async {
    await http.runWithClient(() async {
      try {
        await ShareService.create(savedRegionId: 12, friendUserId: 7);
        fail('expected ShareException');
      } on ShareException catch (error) {
        expect(error.message, '이미 보낸 여행지에요. 친구의 응답을 기다려주세요!');
      }
    }, () => MockClient((_) async => http.Response('{"created":[],"failed":[{"friend_user_id":7,"reason":"SHARE_ALREADY_PENDING"}]}', 200)));
  });
}
