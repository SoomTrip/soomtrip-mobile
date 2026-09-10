import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soomtrip/recommendation_service.dart';
import 'package:soomtrip/route_service.dart';
import 'package:soomtrip/saved_region_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({
        'soomtrip_access_token': 'test-token',
      }));

  for (final mode in ['walk_transit', 'car']) {
    test('$mode is saved from recommendation; server owns route mobility',
        () async {
      final calls = <String>[];
      final savedSpots = [
        {'id': 999, 'content_id': 'A', 'name': '지역명', 'is_anchor': true},
        {'id': 120, 'content_id': 'A', 'name': 'A', 'category_label': '자연'},
        {'id': 108, 'content_id': 'B', 'name': 'B', 'category_label': '식당'},
      ];
      final region = {
        'id': 42,
        'region_name': '여행지',
        'mobility_choice': mode,
        'spots': savedSpots
      };
      final routeSpots = [
        {
          'content_id': 'B',
          'name': 'B',
          'distance_from_prev_km': null,
          'duration_from_prev_minutes': null
        },
        {
          'content_id': 'A',
          'name': 'A',
          'distance_from_prev_km': 1.2,
          'duration_from_prev_minutes': 5
        },
      ];
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(request.body) as Map<String, dynamic>;
        Object response;
        switch ('${request.method} ${request.url.path}') {
          case 'POST /recommendations':
            expect(body, {'preference_id': 12});
            response = {
              'mobility_choice': mode,
              'candidates': [
                {
                  'content_id': 'A',
                  'name': '여행지',
                  'nearby_spots': savedSpots,
                  'one_line_review': '추천해요!',
                }
              ]
            };
          case 'POST /saved-regions':
            expect(body['mobility_choice'], mode);
            final savedItems = body['spots'] as List;
            expect(savedItems.map((s) => s['content_id']), ['A', 'B']);
            expect(savedItems.first['name'], 'A');
            response = region;
          case 'GET /saved-regions':
            response = [region];
          case 'POST /route/optimize':
            final selected = body['selected_spots'] as List;
            expect(selected.map((s) => s['content_id']), ['A', 'B']);
            expect(selected.first['name'], 'A');
            expect(body.keys.toSet(),
                {'saved_region_id', 'selected_spots', 'num_days'});
            expect(body['saved_region_id'], 42);
            response = {
              'route_by_day': {
                'day1': {'spots': routeSpots, 'segments': []}
              }
            };
          case 'POST /route/save':
            expect(body.keys.toSet(), {'saved_region_id', 'entries'});
            expect(body['saved_region_id'], 42);
            final entries = body['entries'] as List;
            expect(entries.map((e) => e['saved_region_spot_id']), [108, 120]);
            expect(
                entries.map((e) => e['duration_from_prev_minutes']), [null, 5]);
            expect(entries[1]['distance_from_prev_km'], 1.2);
            response = {'saved_region_id': 42, 'entries': entries};
          case 'GET /route/saved-region/42':
            response = {
              'saved_region_id': 42,
              'route_by_day': {
                'day1': [
                  {
                    ...routeSpots[0],
                    'saved_region_spot_id': 108,
                    'mobility_choice': mode
                  },
                  {
                    ...routeSpots[1],
                    'saved_region_spot_id': 120,
                    'mobility_choice': mode
                  },
                ]
              }
            };
          default:
            fail('Unexpected request: ${request.method} ${request.url.path}');
        }
        return http.Response(jsonEncode(response), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      await http.runWithClient(() async {
        final candidate = await RecommendationService.create(12);
        expect(candidate['mobility_choice'], mode);
        expect(candidate['one_line_review'], '추천해요!');
        await SavedRegionService.save(candidate);
        final saved = (await SavedRegionService.getAll()).single;
        expect(saved.mobilityChoice, mode);
        final plan = await RouteService.optimize(
            savedRegionId: saved.id, spots: saved.spots, dayCount: 1);
        await RouteService.save(savedRegionId: saved.id, plan: plan);
        final reloaded = await RouteService.getSaved(saved.id);
        expect(reloaded.byDay[1]![1].mobilityChoice, mode);
        expect(reloaded.byDay[1]![1].durationFromPreviousMinutes, 5);
      }, () => client);
      expect(calls.length, 6);
    });
  }

  test('missing recommendation mobility cannot silently become car', () async {
    await http.runWithClient(() async {
      await expectLater(
          RecommendationService.create(12), throwsFormatException);
    },
        () => MockClient((_) async => http.Response(
            '{"candidates":[{"content_id":"A","name":"A"}]}', 200)));
  });
}
