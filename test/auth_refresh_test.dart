import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soomtrip/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final url = Uri.parse('https://soomtrip-api.cspc.me/users/me');
  setUp(() => SharedPreferences.setMockInitialValues({
        'soomtrip_access_token': 'old',
        'soomtrip_refresh_token': 'refresh',
      }));

  test('login saves both tokens and logout revokes refresh before clearing',
      () async {
    await http.runWithClient(() async {
      await AuthService.loginWithKakao('kakao');
      final prefs = await SharedPreferences.getInstance();
      expect(await AuthService.getJwt(), 'login-access');
      expect(prefs.getString('soomtrip_refresh_token'), 'login-refresh');
      await AuthService.logout();
      expect(await AuthService.getJwt(), isNull);
      expect(prefs.getString('soomtrip_refresh_token'), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path == '/auth/kakao') {
                return http.Response(
                    '{"access_token":"login-access","refresh_token":"login-refresh"}',
                    200);
              }
              expect(request.url.path, '/auth/logout');
              expect(
                  jsonDecode(request.body), {'refresh_token': 'login-refresh'});
              return http.Response('{}', 200);
            }));
  });

  test('401 refreshes once and replays the original JSON request', () async {
    final tokens = <String?>[];
    var refreshCount = 0;
    await http.runWithClient(() async {
      final response = await AuthService.client.patch(url,
          headers: {'Content-Type': 'application/json'},
          body: '{"nickname":"new"}');
      expect(response.statusCode, 200);
      expect(await AuthService.getJwt(), 'new');
    },
        () => MockClient((request) async {
              if (request.url.path == '/auth/refresh') {
                refreshCount++;
                expect(jsonDecode(request.body), {'refresh_token': 'refresh'});
                return http.Response('{"access_token":"new"}', 200);
              }
              expect(request.method, 'PATCH');
              expect(request.body, '{"nickname":"new"}');
              tokens.add(request.headers['Authorization']);
              return http.Response('{}', tokens.length == 1 ? 401 : 200);
            }));
    expect(tokens, ['Bearer old', 'Bearer new']);
    expect(refreshCount, 1);
  });

  test('concurrent 401s share one refresh request', () async {
    var count = 0;
    final bothExpired = Completer<void>();
    var oldCount = 0;
    await http.runWithClient(() async {
      final responses = await Future.wait([
        AuthService.client.get(url),
        AuthService.client.get(url),
      ]);
      expect(responses.map((r) => r.statusCode), [200, 200]);
    },
        () => MockClient((request) async {
              if (request.url.path == '/auth/refresh') {
                count++;
                await Future<void>.delayed(const Duration(milliseconds: 10));
                return http.Response('{"access_token":"new"}', 200);
              }
              if (request.headers['Authorization'] == 'Bearer old') {
                if (++oldCount == 2) bothExpired.complete();
                await bothExpired.future;
                return http.Response('{}', 401);
              }
              return http.Response('{}', 200);
            }));
    expect(count, 1);
  });

  test('multipart upload bytes and boundary survive retry', () async {
    final bodies = <List<int>>[];
    final types = <String?>[];
    await http.runWithClient(() async {
      final request = http.MultipartRequest('POST', url)
        ..files.add(
            http.MultipartFile.fromBytes('file', [1, 2, 3], filename: 'a.png'));
      final response = await AuthService.client.send(request);
      expect(response.statusCode, 200);
    },
        () => MockClient((request) async {
              if (request.url.path == '/auth/refresh')
                return http.Response('{"access_token":"new"}', 200);
              bodies.add(request.bodyBytes);
              types.add(request.headers['content-type']);
              return http.Response('{}', bodies.length == 1 ? 401 : 200);
            }));
    expect(bodies[0], bodies[1]);
    expect(types[0], types[1]);
    expect(types.first, startsWith('multipart/form-data; boundary='));
  });

  test('rejected refresh clears credentials without retrying original request',
      () async {
    var requests = 0;
    await http.runWithClient(() async {
      expect((await AuthService.client.get(url)).statusCode, 401);
      expect(await AuthService.getJwt(), isNull);
      expect(
          (await SharedPreferences.getInstance())
              .getString('soomtrip_refresh_token'),
          isNull);
    },
        () => MockClient((request) async {
              requests++;
              return http.Response('{}', 401);
            }));
    expect(requests, 2);
  });

  test('second 401 does not create a refresh loop', () async {
    var requests = 0;
    await http.runWithClient(() async {
      expect((await AuthService.client.get(url)).statusCode, 401);
    },
        () => MockClient((request) async {
              requests++;
              return http.Response(
                  request.url.path == '/auth/refresh'
                      ? '{"access_token":"new"}'
                      : '{}',
                  request.url.path == '/auth/refresh' ? 200 : 401);
            }));
    expect(requests, 3);
  });
}
