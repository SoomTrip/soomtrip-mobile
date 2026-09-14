import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'auth_service.dart';
import 'friend_service.dart';
import 'profile_images.dart';

class ProfileService {
  static const _baseUrl = 'https://soomtrip.cspc.me';

  static String imageType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'jpeg';
    }
    if (bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10') {
      return 'png';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'webp';
    }
    throw const FormatException('JPEG, PNG, WebP 사진만 선택할 수 있어요.');
  }

  static Future<FriendUser> save(
      {required String nickname, Uint8List? imageBytes, String? preset}) async {
    if (preset != null &&
        (!profileAssets.containsKey(preset) || imageBytes != null)) {
      throw ArgumentError('올바른 기본 프로필 하나만 선택해주세요.');
    }
    final jwt = await AuthService.getJwt();
    if (jwt == null || jwt.isEmpty) throw Exception('로그인이 필요합니다.');
    final body = <String, dynamic>{'nickname': nickname};
    if (preset != null) body['profile_image'] = preset;
    final client = AuthService.client;
    try {
      if (imageBytes != null) {
        final type = imageType(imageBytes);
        final request = http.MultipartRequest(
            'POST', Uri.parse('$_baseUrl/uploads/profile-image'))
          ..headers['Authorization'] = 'Bearer $jwt'
          ..files.add(http.MultipartFile.fromBytes('file', imageBytes,
              filename: 'profile.$type',
              contentType: MediaType('image', type)));
        final response = await client
            .send(request)
            .then(http.Response.fromStream)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('프로필 사진 업로드 실패 (${response.statusCode})');
        }
        final uploaded = jsonDecode(utf8.decode(response.bodyBytes));
        if (uploaded is! Map<String, dynamic> ||
            uploaded['image_url'] is! String ||
            (uploaded['image_url'] as String).isEmpty) {
          throw const FormatException('프로필 사진 업로드 응답이 올바르지 않습니다.');
        }
        body['profile_image'] = uploaded['image_url'];
      }
      final response = await client
          .patch(Uri.parse('$_baseUrl/users/me'),
              headers: {
                'Authorization': 'Bearer $jwt',
                'Content-Type': 'application/json'
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('프로필 저장 실패 (${response.statusCode})');
      }
      return FriendUser.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }
}
