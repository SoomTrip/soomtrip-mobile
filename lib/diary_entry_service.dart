import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'auth_service.dart';

class DiaryEntry {
  final int id;
  final int savedRegionId;
  final String? title;
  final String? message;
  final String? imageUrl;
  final String? signedImageUrl;
  final String? weather;
  final DateTime date;
  final bool isPublic;
  final DateTime createdAt;

  const DiaryEntry({
    required this.id,
    required this.savedRegionId,
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.signedImageUrl,
    required this.weather,
    required this.date,
    required this.isPublic,
    required this.createdAt,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] as int,
      savedRegionId: json['saved_region_id'] as int,
      title: json['title'] as String?,
      message: json['message'] as String?,
      imageUrl: json['image_url'] as String?,
      signedImageUrl: json['signed_image_url'] as String?,
      weather: json['weather'] as String?,
      date: DateTime.parse(json['date'] as String),
      isPublic: json['is_public'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class DiaryEntryService {
  static const _baseUrl = 'https://soomtrip-api.cspc.me';
  static final ValueNotifier<int> entriesChanged = ValueNotifier<int>(0);

  static Future<String> _jwt() async {
    final jwt = await AuthService.getJwt();
    if (jwt == null || jwt.isEmpty) throw Exception('로그인이 필요합니다.');
    return jwt;
  }

  static Future<DiaryEntry?> getBySavedRegion(int savedRegionId) async {
    final jwt = await _jwt();
    final response = await AuthService.client.get(
      Uri.parse('$_baseUrl/diary-entries/saved-region/$savedRegionId'),
      headers: {'Authorization': 'Bearer $jwt'},
    ).timeout(const Duration(seconds: 15));

    debugPrint('[Diary API] GET status: ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('그림일기 불러오기 실패 (${response.statusCode})');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) throw const FormatException('그림일기 응답 형식이 올바르지 않습니다.');

    final entries = body
        .whereType<Map<String, dynamic>>()
        .map(DiaryEntry.fromJson)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries.isEmpty ? null : entries.first;
  }

  static Future<String> uploadImage(Uint8List bytes) async {
    final jwt = await _jwt();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/uploads/diary-image'),
    )
      ..headers['Authorization'] = 'Bearer $jwt'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'diary_${DateTime.now().millisecondsSinceEpoch}.png',
        contentType: MediaType('image', 'png'),
      ));

    final streamedResponse =
        await AuthService.client.send(request).timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);
    debugPrint('[Diary Image API] POST status: ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('그림 업로드 실패 (${response.statusCode})');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic> || body['image_url'] is! String) {
      throw const FormatException('그림 업로드 응답 형식이 올바르지 않습니다.');
    }
    return body['image_url'] as String;
  }

  static Future<DiaryEntry> save({
    required int savedRegionId,
    required int? diaryEntryId,
    required String title,
    required String message,
    required String? imageUrl,
    required String weather,
    required DateTime date,
  }) async {
    final jwt = await _jwt();
    final isNew = diaryEntryId == null;
    final uri = isNew
        ? Uri.parse('$_baseUrl/diary-entries')
        : Uri.parse('$_baseUrl/diary-entries/$diaryEntryId');
    final body = <String, dynamic>{
      if (isNew) 'saved_region_id': savedRegionId,
      'title': title.trim().isEmpty ? null : title.trim(),
      'message': message.trim().isEmpty ? null : message.trim(),
      'image_url': imageUrl,
      'weather': weather,
      'date': _dateOnly(date),
      'is_public': true,
    };
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $jwt',
    };
    final response = isNew
        ? await AuthService.client
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 15))
        : await AuthService.client
            .patch(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 15));

    debugPrint(
        '[Diary API] ${isNew ? 'POST' : 'PATCH'} status: ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('그림일기 저장 실패 (${response.statusCode})');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('그림일기 저장 응답 형식이 올바르지 않습니다.');
    }
    final entry = DiaryEntry.fromJson(decoded);
    entriesChanged.value++;
    return entry;
  }

  static String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
