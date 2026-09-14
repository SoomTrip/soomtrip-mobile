import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ShareRequest {
  final int shareId;
  final int savedRegionId;
  final String regionName;
  final String status;
  final int senderId;
  final String senderNickname;
  final String? senderProfileImage;
  final String? senderSignedProfileImageUrl;
  final int receiverId;
  final String receiverNickname;
  final String? receiverProfileImage;
  final String? receiverSignedProfileImageUrl;
  final DateTime createdAt;

  const ShareRequest({
    required this.shareId,
    required this.savedRegionId,
    required this.regionName,
    required this.status,
    required this.senderId,
    required this.senderNickname,
    this.senderProfileImage,
    this.senderSignedProfileImageUrl,
    required this.receiverId,
    required this.receiverNickname,
    this.receiverProfileImage,
    this.receiverSignedProfileImageUrl,
    required this.createdAt,
  });

  factory ShareRequest.fromJson(Map<String, dynamic> json) {
    final shareId = json['share_id'];
    final savedRegionId = json['saved_region_id'];
    final regionName = json['region_name'];
    final status = json['status'];
    final senderId = json['sender_id'];
    final senderNickname = json['sender_nickname'];
    final receiverId = json['receiver_id'];
    final receiverNickname = json['receiver_nickname'];
    final createdAtRaw = json['created_at'];
    if (shareId is! int ||
        savedRegionId is! int ||
        regionName is! String ||
        status is! String ||
        senderId is! int ||
        senderNickname is! String ||
        receiverId is! int ||
        receiverNickname is! String ||
        createdAtRaw is! String) {
      throw const FormatException('공유 요청 응답 형식이 올바르지 않습니다.');
    }
    return ShareRequest(
      shareId: shareId,
      savedRegionId: savedRegionId,
      regionName: regionName,
      status: status,
      senderId: senderId,
      senderNickname: senderNickname,
      senderProfileImage: json['sender_profile_image'] as String?,
      senderSignedProfileImageUrl:
          json['sender_signed_profile_image_url'] as String?,
      receiverId: receiverId,
      receiverNickname: receiverNickname,
      receiverProfileImage: json['receiver_profile_image'] as String?,
      receiverSignedProfileImageUrl:
          json['receiver_signed_profile_image_url'] as String?,
      createdAt: DateTime.parse(createdAtRaw),
    );
  }
}

class ShareException implements Exception {
  final String reason;
  final String message;
  const ShareException(this.reason, this.message);
  @override
  String toString() => message;
}

class ShareService {
  static const _baseUrl = 'https://soomtrip.cspc.me';

  static Future<Map<String, String>> _headers({bool json = false}) async {
    final jwt = await AuthService.getJwt();
    if (jwt == null || jwt.isEmpty) throw Exception('로그인이 필요합니다.');
    return {
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $jwt',
    };
  }

  static Future<void> create(
      {required int savedRegionId, required int friendUserId}) async {
    final response = await AuthService.client
        .post(
          Uri.parse('$_baseUrl/saved-regions/$savedRegionId/share'),
          headers: await _headers(json: true),
          body: jsonEncode({
            'friend_user_ids': [friendUserId]
          }),
        )
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(response, '여행지 공유');
    final body = _decodeMap(response);
    final failed = body['failed'];
    if (failed is List) {
      for (final item in failed) {
        if (item is Map && item['friend_user_id'] == friendUserId) {
          final reason = item['reason']?.toString() ?? '';
          throw ShareException(reason, _reasonMessage(reason));
        }
      }
    }
    final created = body['created'];
    if (created is! List ||
        !created.any(
            (item) => item is Map && item['friend_user_id'] == friendUserId)) {
      throw Exception('여행지 공유 결과를 확인하지 못했어요.');
    }
  }

  static String _reasonMessage(String reason) => switch (reason) {
        'CANNOT_SHARE_TO_SELF' => '자기 자신에게는 공유할 수 없어요.',
        'NOT_ACCEPTED_FRIEND' => '친구 관계인 사용자에게만 공유할 수 있어요.',
        'SHARE_ALREADY_PENDING' => '이미 보낸 여행지에요. 친구의 응답을 기다려주세요!',
        'ALREADY_SAVED' => '상대방이 이미 같은 여행지를 저장하고 있어요.',
        _ => '여행지를 공유하지 못했어요.',
      };

  static Future<List<ShareRequest>> getSent() =>
      _getShares('/saved-regions/shares/sent', '보낸 공유 목록 불러오기');
  static Future<List<ShareRequest>> getReceived() =>
      _getShares('/saved-regions/shares/received', '받은 공유 목록 불러오기');

  static Future<int> accept(int shareId) async {
    final response = await AuthService.client
        .patch(Uri.parse('$_baseUrl/saved-regions/shares/$shareId/accept'),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 409) {
      throw Exception('이미 같은 여행지를 저장하고 있어요.');
    }
    if (response.statusCode == 404) {
      throw Exception('공유 요청을 찾을 수 없어요. 새로고침 후 다시 시도해주세요.');
    }
    _ensureSuccess(response, '공유 요청 수락');
    final body = _decodeMap(response);
    final clonedId = body['cloned_saved_region_id'];
    if (clonedId is! int) {
      throw const FormatException('공유 수락 응답 형식이 올바르지 않습니다.');
    }
    return clonedId;
  }

  static Future<void> reject(int shareId) async {
    final response = await AuthService.client
        .patch(Uri.parse('$_baseUrl/saved-regions/shares/$shareId/reject'),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) {
      throw Exception('공유 요청을 찾을 수 없어요. 새로고침 후 다시 시도해주세요.');
    }
    _ensureSuccess(response, '공유 요청 거절');
  }

  static Future<List<ShareRequest>> _getShares(
      String path, String action) async {
    final response = await AuthService.client
        .get(Uri.parse('$_baseUrl$path'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(response, action);
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) {
      throw const FormatException('공유 요청 응답이 올바르지 않습니다.');
    }
    return body.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('공유 요청 항목이 올바르지 않습니다.');
      }
      return ShareRequest.fromJson(item);
    }).toList(growable: false);
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
