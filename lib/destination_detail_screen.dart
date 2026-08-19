import 'package:flutter/material.dart';

class DestinationDetailScreen extends StatefulWidget {
  final String destinationName; // 앞 화면에서 전달받을 여행지 이름 (예: 강릉)

  const DestinationDetailScreen({super.key, required this.destinationName});

  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  // 🌟 클릭된 장소들을 기억하는 저장소 (선택되면 테두리 표시용)
  final Set<String> _selectedPlaces = {};

  // 임시 데이터: 주제별 장소 리스트
  final Map<String, List<String>> _placesData = {
    '관광지': ['푸른 수목원', '계곡'],
    '식당': ['할머니 밥상', '비빅이네 밥'],
    '카페': ['분좋카'],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE),
      appBar: AppBar(
        title: Text(widget.destinationName,
            style: const TextStyle(
                color: Color(0xFF6B4E31), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF6B4E31)),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategorySection('관광지'),
                      const SizedBox(height: 24),
                      _buildCategorySection('식당'),
                      const SizedBox(height: 24),
                      _buildCategorySection('카페'),
                      const Spacer(),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.center,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6B4E31),
                            side: const BorderSide(
                              color: Color(0xFF6B4E31),
                              width: 2,
                            ),
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            print("선택된 장소들: $_selectedPlaces");
                            // TODO: 이대로 여행 코스 작성하는 다음 페이지로 이동
                          },
                          child: const Text(
                            "이대로 여행 코스 작성하기",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 📦 주제(카테고리)별 바깥쪽 굵은 네모칸을 그리는 함수
  Widget _buildCategorySection(String categoryName) {
    final places = _placesData[categoryName] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 카테고리 제목
        Text(
          categoryName,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B4E31)),
        ),
        const SizedBox(height: 8),
        // 🌟 겉에 테두리가 있는 바깥 네모칸 (Column을 감싸서 안의 내용물만큼 유동적으로 늘어남!)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
                color: const Color(0xFF6B4E31), width: 2), // 바깥 굵은 테두리
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: places.map((place) => _buildPlaceItem(place)).toList(),
          ),
        ),
      ],
    );
  }

  // 📍 안쪽의 개별 장소 항목을 그리는 함수
  Widget _buildPlaceItem(String placeName) {
    final isSelected = _selectedPlaces.contains(placeName);

    return GestureDetector(
      onTap: () {
        setState(() {
          // 누를 때마다 선택/해제 토글
          if (isSelected) {
            _selectedPlaces.remove(placeName);
          } else {
            _selectedPlaces.add(placeName);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), // 항목 간 간격
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFF8E7)
              : Colors.white, // 선택되면 배경색 살짝 변경
          // 🌟 선택 여부에 따라 테두리 색상과 굵기 변경! (기획하신 주황색 테두리)
          border: Border.all(
            color: isSelected ? const Color(0xFFFF9800) : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              placeName,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
            // 🗺️ 지도 아이콘 (나중에 클릭 이벤트 추가 가능)
            GestureDetector(
              onTap: () {
                print("$placeName 지도 열기!");
                // TODO: 지도 연동 로직
              },
              child: const Icon(Icons.map_outlined, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
