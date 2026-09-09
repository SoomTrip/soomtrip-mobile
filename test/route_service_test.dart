import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soomtrip/route_service.dart';

Map<String, dynamic> spot(String id) => {'content_id': id, 'name': id};

void main() {
  test('new spot fields take priority, including nulls, and survive saving',
      () {
    final plan = RoutePlan.fromJson({
      'route_by_day': {
        'day1': {
          'spots': [
            {
              ...spot('A'),
              'distance_from_prev_km': null,
              'duration_from_prev_minutes': null
            },
            {
              ...spot('B'),
              'distance_from_prev_km': 0.9,
              'duration_from_prev_minutes': 3
            },
            {
              ...spot('C'),
              'distance_from_prev_km': null,
              'duration_from_prev_minutes': null
            },
          ],
          'segments': [
            null, // Index 0 has no incoming trip.
            {'distance_km': 99, 'duration_minutes': 99},
            {'distance_km': 99, 'duration_minutes': 99},
          ],
        },
      },
    }, mobilityChoice: 'car');
    final ids = {'A': 120, 'B': 108, 'C': 130};
    final mapped = RoutePlan({
      1: plan.byDay[1]!
          .map((s) => s.withSavedRegionSpotId(ids[s.contentId]!))
          .toList()
    });
    final entries = mapped.toSaveEntries();
    expect(entries.map((e) => e['saved_region_spot_id']), [120, 108, 130]);
    expect(entries.map((e) => e['distance_from_prev_km']), [null, 0.9, null]);
    expect(
        entries.map((e) => e['duration_from_prev_minutes']), [null, 3, null]);
    final loaded = RoutePlan.fromJson({
      'route_by_day': {'day1': entries}
    });
    expect(loaded.byDay[1]![1].durationFromPreviousMinutes, 3);
    expect(loaded.byDay[1]![2].durationFromPreviousMinutes, isNull);
  });

  test('new spot fields work without segments', () {
    final plan = RoutePlan.fromJson({
      'route_by_day': {
        'day1': {
          'spots': [
            spot('A'),
            {
              ...spot('B'),
              'distance_from_prev_km': 1.2,
              'duration_from_prev_minutes': 5
            }
          ],
          'segments': [],
        }
      }
    });
    expect(plan.byDay[1]![1].distanceFromPreviousKm, 1.2);
    expect(plan.byDay[1]![1].durationFromPreviousMinutes, 5);
  });

  test('maps segments to arrival spots per day, saves and reloads the values',
      () {
    final optimized = RoutePlan.fromJson({
      'route_by_day': {
        'day1': {
          'spots': [spot('A'), spot('B'), spot('C')],
          'segments': [
            null, // Index 0 has no incoming trip.
            {'distance_km': 1.2, 'duration_minutes': 4},
            {'distance_km': '3.5', 'duration_minutes': '12'},
          ],
        },
        'day2': {
          'spots': [spot('D'), spot('E')],
          'segments': [
            null, // Index 0 has no incoming trip.
            {'distance_km': 0.0, 'duration_minutes': 0}
          ],
        },
      },
    }, mobilityChoice: 'car');
    var id = 0;
    final mapped = RoutePlan(optimized.byDay.map((day, spots) => MapEntry(
        day, spots.map((spot) => spot.withSavedRegionSpotId(++id)).toList())));
    final entries = jsonDecode(jsonEncode(mapped.toSaveEntries())) as List;
    expect(entries.map((e) => e['duration_from_prev_minutes']),
        [null, 4, 12, null, 0]);
    expect(entries.map((e) => e['distance_from_prev_km']),
        [null, 1.2, 3.5, null, 0.0]);
    expect(entries.map((e) => e['visit_order']), [1, 2, 3, 1, 2]);
    final loaded = RoutePlan.fromJson({
      'route_by_day': {
        for (final day in [1, 2])
          'day$day': entries
              .where((e) => e['visit_day'] == day)
              .map((e) => <String, dynamic>{...e, 'mobility_choice': 'car'})
              .toList(),
      },
    });
    expect(loaded.byDay[1]![1].durationFromPreviousMinutes, 4);
    expect(loaded.byDay[1]![2].durationFromPreviousMinutes, 12);
    expect(loaded.byDay[2]!.first.durationFromPreviousMinutes, isNull);
    expect(loaded.byDay[2]![1].durationFromPreviousMinutes, 0);
    expect(loaded.byDay[1]![1].mobilityChoice, 'car');
  });

  test('empty segments do not invent travel times', () {
    final plan = RoutePlan.fromJson({
      'route_by_day': {
        'day1': {
          'spots': [spot('A'), spot('B')],
          'segments': []
        },
      },
    });
    expect(
        plan.byDay[1]!.map((s) => s.durationFromPreviousMinutes), [null, null]);
  });

  test('repeated places keep segment indices and walking mode', () {
    final plan = RoutePlan.fromJson({
      'route_by_day': {
        'day1': {
          'spots': [spot('A'), spot('B'), spot('A')],
          'segments': [
            null, // Index 0 has no incoming trip.
            {'duration_minutes': 10},
            {'duration_minutes': 15},
          ],
        },
      },
    }, mobilityChoice: 'walk_transit');
    expect(plan.byDay[1]!.map((s) => s.durationFromPreviousMinutes),
        [null, 10, 15]);
    expect(plan.byDay[1]!.last.mobilityChoice, 'walk_transit');
  });

  test('missing saved place ID cannot silently drop a route entry', () {
    final plan = RoutePlan.fromJson({
      'route_by_day': {
        'day1': [spot('A')]
      }
    });
    expect(plan.toSaveEntries, throwsFormatException);
  });
}
