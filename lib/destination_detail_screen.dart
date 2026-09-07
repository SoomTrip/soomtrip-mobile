import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'route_screen.dart';
import 'saved_region_service.dart';

class DestinationDetailScreen extends StatefulWidget {
  final SavedRegion destination;

  const DestinationDetailScreen({super.key, required this.destination});

  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  final Set<String> _selectedPlaces = {};
  String? _selectedTravelPeriod;
  static const _travelPeriods = ['당일치기', '1박 2일', '2박 3일'];

  Map<String, List<SavedSpot>> get _placesByCategory {
    final grouped = <String, List<SavedSpot>>{};
    for (final spot in widget.destination.spots) {
      final isDuplicatedRegionName = spot.categoryLabel == '기타' &&
          spot.name.trim() == widget.destination.regionName.trim();
      if (isDuplicatedRegionName) continue;

      grouped.putIfAbsent(spot.categoryLabel, () => []).add(spot);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final placesByCategory = _placesByCategory;
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
      appBar: AppBar(
        title: Text(
          '${widget.destination.regionName} 🌿',
          style: const TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '여행 경로에 추가하고 싶은 스팟을 모두 선택해주세요',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(
              child: placesByCategory.isEmpty
                  ? const Center(child: Text('저장된 장소가 없어요.'))
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      itemCount: placesByCategory.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 24),
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildTravelPeriodSection();
                        final entry =
                          placesByCategory.entries.elementAt(index - 1);
                        return _buildCategorySection(entry.key, entry.value);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A7C59),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    if (_selectedTravelPeriod == null) {
                      _showTravelPeriodRequiredDialog();
                      return;
                    }
                    debugPrint('선택된 장소들: $_selectedPlaces');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RouteScreen(
                          savedRegionId: widget.destination.id,
                          travelPeriod: _selectedTravelPeriod!,
                          selectedSpots: widget.destination.spots
                              .where((spot) => _selectedPlaces.contains(
                                  spot.contentId.isNotEmpty
                                      ? spot.contentId
                                      : '${spot.categoryLabel}:${spot.name}'))
                              .toList(growable: false),
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    '이대로 여행 코스 작성하기 ✏️',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelPeriodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 20, color: Color(0xFF4A7C59)),
            SizedBox(width: 8),
            Text(
              '여행기간',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF9F5),
            border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              for (var index = 0; index < _travelPeriods.length; index++) ...[
                Expanded(
                  child: _buildTravelPeriodOption(_travelPeriods[index]),
                ),
                if (index < _travelPeriods.length - 1)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTravelPeriodOption(String period) {
    final isSelected = _selectedTravelPeriod == period;
    return GestureDetector(
      onTap: () => setState(() => _selectedTravelPeriod = period),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A7C59) : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4A7C59)
                : const Color(0xFFF0F0F0),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          period,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }

  bool _isRestaurant(SavedSpot spot) {
    final category = spot.categoryLabel;
    return category.contains('식당') ||
        category.contains('음식') ||
        category.contains('맛집');
  }

  ({int restaurant, int other}) get _selectionLimits {
    return switch (_selectedTravelPeriod) {
      '당일치기' => (restaurant: 3, other: 5),
      '1박 2일' => (restaurant: 6, other: 10),
      '2박 3일' => (restaurant: 9, other: 15),
      _ => (restaurant: 0, other: 0),
    };
  }

  Future<void> _showSelectionLimitDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        title: const Text(
          '선택 가능한 스팟 수를 확인해주세요😢',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSpotSelection(SavedSpot place) async {
    final selectionKey = place.contentId.isNotEmpty
        ? place.contentId
        : '${place.categoryLabel}:${place.name}';
    final isSelected = _selectedPlaces.contains(selectionKey);
    if (isSelected) {
      setState(() => _selectedPlaces.remove(selectionKey));
      return;
    }

    if (_selectedTravelPeriod == null) {
      await _showSelectionLimitDialog('먼저 여행기간을 선택해주세요.');
      return;
    }

    final limits = _selectionLimits;
    final selectedRestaurantCount = widget.destination.spots
        .where((spot) => _selectedPlaces.contains(spot.contentId.isNotEmpty
            ? spot.contentId
            : '${spot.categoryLabel}:${spot.name}'))
        .where(_isRestaurant)
        .length;
    final selectedOtherCount = _selectedPlaces.length - selectedRestaurantCount;
    final selectingRestaurant = _isRestaurant(place);
    final nextCount = selectingRestaurant
        ? selectedRestaurantCount + 1
        : selectedOtherCount + 1;
    final limit = selectingRestaurant ? limits.restaurant : limits.other;

    if (nextCount > limit) {
      await _showSelectionLimitDialog(
        selectingRestaurant
            ? '식당은 최대 ${limits.restaurant}개까지 선택가능해요!'
          : '식당 외 스팟은 최대 ${limits.other}개까지 선택가능해요!',
      );
      return;
    }

    setState(() => _selectedPlaces.add(selectionKey));
  }

  Future<void> _showTravelPeriodRequiredDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        title: const Text('여행기간을 선택해주세요'),
        content: const Text('코스를 작성하려면 여행기간을 먼저 선택해야 해요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String categoryName, List<SavedSpot> places) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_iconForCategory(categoryName),
                size: 20, color: const Color(0xFF4A7C59)),
            const SizedBox(width: 8),
            Text(
              categoryName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF9F5),
            border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              for (var index = 0; index < places.length; index++) ...[
                _buildPlaceItem(places[index]),
                if (index < places.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceItem(SavedSpot place) {
    final selectionKey = place.contentId.isNotEmpty
        ? place.contentId
        : '${place.categoryLabel}:${place.name}';
    final isSelected = _selectedPlaces.contains(selectionKey);

    return GestureDetector(
      onTap: () => _toggleSpotSelection(place),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF3EA) : Colors.white,
          border: Border.all(
            color:
                isSelected ? const Color(0xFF4A7C59) : const Color(0xFFF0F0F0),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                place.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF4A7C59)
                      : const Color(0xFF333333),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFDDE9D9)
                    : const Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: GestureDetector(
                onTap: () => _showSpotMap(place),
                child: Icon(
                  Icons.map_rounded,
                  color: isSelected
                      ? const Color(0xFF4A7C59)
                      : Colors.grey.shade400,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSpotMap(SavedSpot spot) async {
    final latitude = spot.latitude;
    final longitude = spot.longitude;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        title: Text(
          spot.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: latitude == null || longitude == null
              ? const Center(child: Text('이 스팟의 위치 정보가 없어요.'))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: NaverMap(
                    options: NaverMapViewOptions(
                      initialCameraPosition: NCameraPosition(
                        target: NLatLng(latitude, longitude),
                        zoom: 15,
                      ),
                      logoClickEnable: false,
                    ),
                    onMapReady: (controller) {
                      controller.addOverlay(
                        NMarker(
                          id: 'spot_${spot.contentId}_${spot.name}',
                          position: NLatLng(latitude, longitude),
                          caption: NOverlayCaption(text: spot.name),
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    if (category.contains('카페')) return Icons.local_cafe_rounded;
    if (category.contains('식당') ||
        category.contains('음식') ||
        category.contains('맛집')) {
      return Icons.restaurant_rounded;
    }
    if (category.contains('숙박') || category.contains('호텔')) {
      return Icons.hotel_rounded;
    }
    if (category.contains('쇼핑')) return Icons.shopping_bag_rounded;
    if (category.contains('전시') || category.contains('문화')) {
      return Icons.museum_rounded;
    }
    if (category.contains('관광') || category.contains('여행')) {
      return Icons.camera_alt_rounded;
    }
    return Icons.place_rounded;
  }
}
