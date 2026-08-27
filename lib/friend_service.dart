import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class FriendUser {
  final int id;
  final String nickname;
  final String userCode;
  final String? profileImage;

  const FriendUser(
      {required this.id,
      required this.nickname,
      required this.userCode,
      this.profileImage});

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nickname = json['nickname'];
    final userCode = json['user_code'];
    if (id is! int || nickname is! String || userCode is! String) {
      throw const FormatException('친구 사용자 응답 형식이 올바르지 않습니다.');
    }
    return FriendUser(
        id: id,
        nickname: nickname,
        userCode: userCode,
        profileImage: json['profile_image'] as String?);
  }
}

class FriendRelation {
  final int id;
  final FriendUser requester;
  final FriendUser receiver;

  const FriendRelation(
      {required this.id, required this.requester, required this.receiver});

  factory FriendRelation.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final requester = json['requester'];
    final receiver = json['receiver'];
    if (id is! int ||
        requester is! Map<String, dynamic> ||
        receiver is! Map<String, dynamic>) {
      throw const FormatException('친구 응답 형식이 올바르지 않습니다.');
    }
    return FriendRelation(
        id: id,
        requester: FriendUser.fromJson(requester),
        receiver: FriendUser.fromJson(receiver));
  }

  FriendUser otherUser(int myUserId) =>
      requester.id == myUserId ? receiver : requester;
}

class FriendService {
  static const _baseUrl = 'https://soomtrip-api.cspc.me';

  static Future<Map<String, String>> _headers({bool json = false}) async {
    final jwt = await AuthService.getJwt();
    if (jwt == null || jwt.isEmpty) throw Exception('로그인이 필요합니다.');
    return {
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $jwt'
    };
  }

  static Future<FriendUser> getMe() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/users/me'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(response, '내 정보 불러오기');
    return FriendUser.fromJson(_decodeMap(response));
  }

  static Future<List<FriendRelation>> getFriends() =>
      _getRelations('/friends', '친구 목록 불러오기');
  static Future<List<FriendRelation>> getRequests() =>
      _getRelations('/friends/requests', '친구 요청 불러오기');

  static Future<void> requestFriend(String userCode) async {
    final response = await http
        .post(Uri.parse('$_baseUrl/friends/request'),
            headers: await _headers(json: true),
            body: jsonEncode({'user_code': userCode}))
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(response, '친구 요청');
  }

  static Future<void> accept(int id) =>
      _patch('/friends/$id/accept', '친구 요청 수락');
  static Future<void> reject(int id) =>
      _patch('/friends/$id/reject', '친구 요청 거절');

  static Future<void> remove(int id) async {
    final response = await http
        .delete(Uri.parse('$_baseUrl/friends/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(response, '친구 삭제');
  }

  static Future<List<FriendRelation>> _getRelations(
      String path, String action) async {
    final response = await http
        .get(Uri.parse('$_baseUrl$path'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(response, action);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) {
      throw const FormatException('친구 목록 응답이 올바르지 않습니다.');
    }
    return body.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('친구 항목 응답이 올바르지 않습니다.');
      }
      return FriendRelation.fromJson(item);
    }).toList(growable: false);
  }

  static Future<void> _patch(String path, String action) async {
    final response = await http
        .patch(Uri.parse('$_baseUrl$path'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(response, action);
  }

  static Map<String, dynamic> _decodeMap(http.Response response) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw const FormatException('서버 응답 형식이 올바르지 않습니다.');
    }
    return body;
  }

  static void _ensureSuccess(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String detail = '';
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic> && body['detail'] is String) {
        detail = ': ${body['detail']}';
      }
    } catch (_) {}
    throw Exception('$action 실패 (${response.statusCode})$detail');
  }
}
