import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soomtrip/profile_service.dart';
import 'package:soomtrip/profile_images.dart';

void main() {
  test('signed URL takes priority; only preset IDs resolve to assets', () {
    expect(profileAsset('profile3', null), 'assets/images/profile3.jpeg');
    expect(profileAsset('profile3', 'https://example.com/image'), isNull);
    expect(profileAsset('profile/7/file.png', null), isNull);
    expect(profileAsset(null, null), isNull);
  });
  test('preset save patches its ID without uploading', () async {
    await http.runWithClient(() async {
      final user =
          await ProfileService.save(nickname: 'name', preset: 'profile3');
      expect(user.profileImage, 'profile3');
    },
        () => MockClient((request) async {
              expect(request.method, 'PATCH');
              expect(jsonDecode(request.body),
                  {'nickname': 'name', 'profile_image': 'profile3'});
              return http.Response(
                  '{"id":7,"nickname":"name","user_code":"ABC","profile_image":"profile3"}',
                  200);
            }));
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  setUp(() => SharedPreferences.setMockInitialValues(
      {'soomtrip_access_token': 'test'}));

  test('uploads file then saves storage path and returns signed display URL',
      () async {
    final paths = <String>[];
    await http.runWithClient(() async {
      final user =
          await ProfileService.save(nickname: 'name', imageBytes: bytes);
      expect(user.profileImage, 'profile/7/new.png');
      expect(user.signedProfileImageUrl, 'https://example.com/signed');
    },
        () => MockClient((request) async {
              paths.add(request.url.path);
              expect(request.headers['Authorization'], 'Bearer test');
              if (request.method == 'POST') {
                expect(request.headers['content-type'],
                    startsWith('multipart/form-data;'));
                final body = latin1.decode(request.bodyBytes);
                expect(body, contains('name="file"'));
                expect(body, contains('image/png'));
                return http.Response('{"image_url":"profile/7/new.png"}', 200);
              }
              expect(request.method, 'PATCH');
              expect(jsonDecode(request.body),
                  {'nickname': 'name', 'profile_image': 'profile/7/new.png'});
              return http.Response(
                  '{"id":7,"nickname":"name","user_code":"ABC","profile_image":"profile/7/new.png","signed_profile_image_url":"https://example.com/signed"}',
                  200);
            }));
    expect(paths, ['/uploads/profile-image', '/users/me']);
  });

  test('upload failure does not patch profile', () async {
    var calls = 0;
    await http.runWithClient(() async {
      await expectLater(
          ProfileService.save(nickname: 'name', imageBytes: bytes),
          throwsException);
    },
        () => MockClient((request) async {
              calls++;
              expect(request.method, 'POST');
              return http.Response('{}', 500);
            }));
    expect(calls, 1);
  });

  test('nickname-only edit skips upload and leaves image out of patch',
      () async {
    await http.runWithClient(() async {
      await ProfileService.save(nickname: 'name');
    },
        () => MockClient((request) async {
              expect(request.method, 'PATCH');
              expect(jsonDecode(request.body), {'nickname': 'name'});
              return http.Response(
                  '{"id":7,"nickname":"name","user_code":"ABC"}', 200);
            }));
  });

  test('unsupported files are rejected', () {
    expect(() => ProfileService.imageType(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
  });
}
