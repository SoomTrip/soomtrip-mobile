import 'package:flutter/material.dart';
import 'my_destination_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  // 프로필에 들어갈 임시 데이터
  String nickname = "예원";
  String friendCode = "abc12";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE), // 앱 기본 배경색
      appBar: AppBar(
        title: const Text(
          "마이페이지",
          style: TextStyle(
            color: Color(0xFF6B4E31),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // ✏️ 오른쪽 상단 프로필 수정 버튼
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF6B4E31)),
            onPressed: () {
              // TODO: 이후 프로필 수정 페이지 이동 또는 다이얼로그 팝업 연결
              print("프로필 수정 버튼 클릭");
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            children: [
              // ==========================================
              // 1. 상단 프로필 영역 (동그란 이미지 + 닉네임/코드)
              // ==========================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 동그란 프로필 이미지 영역
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                          color: const Color(0xFF6B4E31), width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const ClipOval(
                      child: Icon(
                        Icons.person,
                        size: 55,
                        color: Color(0xFF8B5A2B),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // 닉네임 및 친구 코드 정보 (밑줄 스타일)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 닉네임 섹션
                        Text(
                          nickname,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B4E31),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 2,
                          color: const Color(0xFF6B4E31),
                        ),

                        const SizedBox(height: 16),

                        // 친구 코드 섹션
                        Text(
                          "코드 : $friendCode",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B4E31),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 2,
                          color: const Color(0xFF6B4E31),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ==========================================
              // 2. 하단 메뉴 영역 (큰 네모 박스 안 목록들)
              // ==========================================
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0xFF6B4E31), width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // [메뉴 1] 나의 여행 취향
                      _buildMenuItem(
                        title: "나의 여행 취향",
                        onTap: () {
                          // TODO: 추후 '나의 여행 취향' 상세 페이지로 연결
                          print("나의 여행 취향 클릭");
                        },
                      ),

                      const SizedBox(height: 16),

                      // [메뉴 2] 나의 여행지
                      _buildMenuItem(
                        title: "나의 여행지",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyDestinationsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // 📦 목록 아이템용 네모 버튼 위젯
  Widget _buildMenuItem({required String title, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFFFAF6EE),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6B4E31), width: 1.5),
          ),
          child: Row(
            children: [
              // 불릿 포인트 (점)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF6B4E31),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B4E31),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF6B4E31),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
