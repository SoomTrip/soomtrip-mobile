import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soomtrip/share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'soomtrip_access_token': 'test'}));

  const sampleShareJson = '''
  [{
    "share_id": 8, "saved_region_id": 21, "region_name": "제주 서귀포", "status": "PENDING",
    "created_at": "2026-09-11T10:30:00Z", "responded_at": null,
    "sender_id": 8, "sender_nickname": "세영", "sender_profile_image": null,
    "receiver_id": 12, "receiver_nickname": "민지", "receiver_profile_image": null
  }]''';

  test('getSent hits /saved-regions/shares/sent and parses the list', () async {
    await http.runWithClient(() async {
      final shares = await ShareService.getSent();
      expect(shares, hasLength(1));
      expect(shares.single.regionName, '제주 서귀포');
      expect(shares.single.senderNickname, '세영');
      expect(shares.single.status, 'PENDING');
    }, () => MockClient((request) async {
      expect(request.url.path, '/saved-regions/shares/sent');
      return http.Response(sampleShareJson, 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
  });

  test('getReceived hits /saved-regions/shares/received and parses the list', () async {
    await http.runWithClient(() async {
      final shares = await ShareService.getReceived();
      expect(shares.single.receiverNickname, '민지');
    }, () => MockClient((request) async {
      expect(request.url.path, '/saved-regions/shares/received');
      return http.Response(sampleShareJson, 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
  });

  test('accept PATCHes /accept and returns the cloned saved region id', () async {
    await http.runWithClient(() async {
      final clonedId = await ShareService.accept(8);
      expect(clonedId, 34);
    }, () => MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/saved-regions/shares/8/accept');
      return http.Response('{"share_id":8,"status":"ACCEPTED","cloned_saved_region_id":34}', 200);
    }));
  });

  test('accept surfaces a friendly message on 409 already-saved conflict', () async {
    await http.runWithClient(() async {
      await expectLater(ShareService.accept(8), throwsException);
    }, () => MockClient((_) async => http.Response('{"detail":"conflict"}', 409)));
  });

  test('reject PATCHes /reject', () async {
    await http.runWithClient(() async {
      await ShareService.reject(8);
    }, () => MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/saved-regions/shares/8/reject');
      return http.Response('{"share_id":8,"status":"REJECTED"}', 200);
    }));
  });
}
