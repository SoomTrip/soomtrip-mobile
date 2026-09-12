import 'home_logo_button.dart';
import 'package:flutter/material.dart';
import 'destination_detail_screen.dart'; // 기존에 만든 상세(경로) 화면 불러오기
import 'picture_diary_screen.dart';
import 'saved_region_service.dart';

class DestinationActionScreen extends StatelessWidget {
  final SavedRegion destination;

  const DestinationActionScreen({super.key, required this.destination});

  String get destinationName => destination.regionName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4), // 따뜻한 아이보리 배경
      appBar: AppBar(
        actions: const [HomeLogoButton()],
        title: Text(
          "$destinationName 🌿", // 선택한 여행지 이름이 상단에 뜹니다
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            children: [
              // ==========================================
              // 1. 위쪽 칸: 추천 여행지 경로
              // ==========================================
              Expanded(
                child: _buildActionCard(
                  context,
                  title: "추천 관광지 보러가기",
                  imagePath: 'assets/images/dest1.png',
                  borderColor: const Color(0xFFFFC107), // 노란 배경 카드 → 노란 테두리
                  onTap: () {
                    // 🌟 누르면 기존에 만들었던 상세(코스) 화면으로 넘어갑니다!
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DestinationDetailScreen(destination: destination),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10), // 위아래 칸 사이의 간격

              // ==========================================
              // 2. 아래쪽 칸: 그림일기 작성하기
              // ==========================================
              Expanded(
                child: _buildActionCard(
                  context,
                  title: "그림일기 작성하기",
                  imagePath: 'assets/images/dest2.png',
                  borderColor: const Color(0xFF4CAF50), // 초록 배경 카드 → 초록 테두리
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PictureDiaryScreen(
                          savedRegionId: destination.id,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📦 위아래 큼직한 버튼 칸을 그리는 공통 함수
  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String imagePath,
    required VoidCallback onTap,
    required Color borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(54),
              border: Border.all(color: borderColor, width: 4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(51),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Transform.scale(
                    scale: 1.16,
                    child: Image.asset(imagePath, fit: BoxFit.cover),
                  ),
                  Center(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
