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
      backgroundColor: const Color(0xFFFBF9F4), // 시안에 맞춘 따뜻한 아이보리 배경
      appBar: AppBar(
        title: Text(
          "${widget.destinationName} 🌿", // 이름 옆에 귀여운 잎사귀 추가
          style: const TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF333333)), // 뒤로가기 버튼 색상 변경
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(), // 부드러운 스크롤 애니메이션
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategorySection('관광지', Icons.camera_alt_rounded),
                      const SizedBox(height: 24),
                      _buildCategorySection('식당', Icons.restaurant_rounded),
                      const SizedBox(height: 24),
                      _buildCategorySection('카페', Icons.local_cafe_rounded),
                      const Spacer(),
                      const SizedBox(height: 32),
                      
                      // 🌟 이대로 코스 작성하기 버튼 (둥글고 따뜻한 스타일로 변경)
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A7C59), // 숨트립 메인 초록색
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16), // 둥근 모서리
                              ),
                            ),
                            onPressed: () {
                              print("선택된 장소들: $_selectedPlaces");
                              // TODO: 이대로 여행 코스 작성하는 다음 페이지로 이동
                            },
                            child: const Text(
                              "이대로 여행 코스 작성하기 ✏️",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
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

  // 📦 주제(카테고리)별 바깥쪽 둥근 네모칸을 그리는 함수
  Widget _buildCategorySection(String categoryName, IconData icon) {
    final places = _placesData[categoryName] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 카테고리 제목 영역 (아이콘 추가로 귀여움 UP!)
        Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF4A7C59)),
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
        // 🌟 겉에 테두리가 있는 바깥 네모칸 (마이페이지 느낌의 둥근 박스)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF9F5), // 연한 배경색
            border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5), // 부드러운 테두리
            borderRadius: BorderRadius.circular(24), // 둥글둥글하게 깎기
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
        margin: const EdgeInsets.only(bottom: 12), // 항목 간 간격을 살짝 넓힘
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          // 선택 시 메인 초록색과 어울리는 연한 초록 배경 사용
          color: isSelected ? const Color(0xFFEEF3EA) : Colors.white,
          border: Border.all(
            // 선택 시 하단 코스 작성 버튼과 같은 메인 초록색 사용
            color: isSelected ? const Color(0xFF4A7C59) : const Color(0xFFF0F0F0),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16), // 안쪽 상자도 둥글게!
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              placeName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF4A7C59) : const Color(0xFF333333),
              ),
            ),
            // 🗺️ 지도 아이콘 (선택 여부에 따라 색상 변화)
            GestureDetector(
              onTap: () {
                print("$placeName 지도 열기!"); //
                // TODO: 지도 연동 로직
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFDDE9D9) : const Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.map_rounded, 
                  color: isSelected ? const Color(0xFF4A7C59) : Colors.grey.shade400,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
