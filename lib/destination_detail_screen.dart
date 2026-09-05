import 'package:flutter/material.dart';

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
            Expanded(
              child: placesByCategory.isEmpty
                  ? const Center(child: Text('저장된 장소가 없어요.'))
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      itemCount: placesByCategory.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 24),
                      itemBuilder: (context, index) {
                        final entry = placesByCategory.entries.elementAt(index);
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
                    debugPrint('선택된 장소들: $_selectedPlaces');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RouteScreen(),
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
      onTap: () {
        setState(() {
          isSelected
              ? _selectedPlaces.remove(selectionKey)
              : _selectedPlaces.add(selectionKey);
        });
      },
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
              child: Icon(
                Icons.map_rounded,
                color:
                    isSelected ? const Color(0xFF4A7C59) : Colors.grey.shade400,
                size: 18,
              ),
            ),
          ],
        ),
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
