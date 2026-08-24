import 'package:flutter/material.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  // 🌟 임시 친구 데이터
  final List<Map<String, String>> _friends = [
    {'name': '민지 🌲', 'recent': '최근 여행 · 전남 강진'},
    {'name': '현우 ⛰️', 'recent': '최근 여행 · 충북 단양'},
    {'name': '지은 🌊', 'recent': '최근 여행 · 경북 청도'},
    {'name': '승민 🌲', 'recent': '최근 여행 · 강원 평창'},
    {'name': '서연 🌸', 'recent': '최근 여행 · 제주 서귀포'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4), // 따뜻한 아이보리 배경
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "숨트립 🌱",
          style: TextStyle(color: Color(0xFF4A7C59), fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF6B4E31)),
            onPressed: () {},
          ),
          // 🌟 상단 내 프로필 아이콘 (시안 우측 상단)
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 8.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.brown[300],
              child: const Icon(Icons.face, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 헤더 (타이틀 + 일러스트)
            _buildHeader(),
            const SizedBox(height: 24),

            // 2. 검색창
            _buildSearchBar(),
            const SizedBox(height: 12),

            // 3. 내 코드 영역
            _buildMyCodeBox(),
            const SizedBox(height: 12),

            // 4. 친구 요청 버튼 (클릭 시 바텀시트 팝업)
            _buildFriendRequestBtn(),
            const SizedBox(height: 32),

            // 5. 내 친구 목록 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 15, color: Color(0xFF333333), fontWeight: FontWeight.bold, fontFamily: 'CustomFont'),
                    children: [
                      TextSpan(text: "내 친구 "),
                      TextSpan(text: "7명", style: TextStyle(color: Color(0xFF4A7C59))),
                    ],
                  ),
                ),
                Row(
                  children: const [
                    Text("최근 활동순", style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 6. 친구 리스트
            ..._friends.map((friend) => _buildFriendItem(friend['name']!, friend['recent']!)).toList(),
            const SizedBox(height: 16),

            // 7. 더 많은 친구 보기 버튼
            _buildMoreFriendsBtn(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // UI 컴포넌트들
  // ==========================================

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("친구", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF333333))),
            SizedBox(height: 10),
            Text("함께 여행할 친구를\n찾아보세요 🌱", style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4)),
          ],
        ),
        // 🌟 일러스트 들어갈 자리
        Container(
          width: 120, height: 100,
          decoration: BoxDecoration(color: const Color(0xFFEEF3EA), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.people_alt_rounded, color: Color(0xFF4A7C59), size: 50),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5),
      ),
      child: const TextField(
        decoration: InputDecoration(
          icon: Icon(Icons.search_rounded, color: Colors.grey),
          hintText: "닉네임 또는 친구 코드로 검색",
          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildMyCodeBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F0), // 연한 연두색 배경
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5),
      ),
      child: Row(
        children: const [
          Text("내 코드", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4A7C59))),
          SizedBox(width: 24),
          Expanded(child: Text("SoomTrip-3A7K9", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF333333)))),
          Icon(Icons.copy_rounded, color: Colors.black54, size: 20),
        ],
      ),
    );
  }

  Widget _buildFriendRequestBtn() {
    return GestureDetector(
      onTap: _showFriendRequestSheet, // 🌟 클릭 시 바텀 시트 열기
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            const Text("💌", style: TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            const Text("친구 요청", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            const SizedBox(width: 8),
            // 빨간 뱃지
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFFE57373), shape: BoxShape.circle),
              child: const Text("2", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendItem(String name, String recentInfo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          // 프로필 이미지
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.orange[100],
            child: const Icon(Icons.face_retouching_natural, color: Colors.brown),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                const SizedBox(height: 4),
                Text(recentInfo, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  Widget _buildMoreFriendsBtn() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text("🌻", style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Text("더 많은 친구 보기", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B4E31))),
          SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B4E31), size: 20),
        ],
      ),
    );
  }

  // ==========================================
  // 🌟 친구 요청 모달 바텀 시트 (오른쪽 시안)
  // ==========================================
  void _showFriendRequestSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 내용물에 맞춰 높이 조절
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 40),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 드래그 손잡이 (회색 바)
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              // 헤더 영역
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text("친구 요청", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Color(0xFFE57373), shape: BoxShape.circle),
                        child: const Text("2", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 요청 리스트
              _buildRequestItem('민지', '@minji_123', '친구가 되고 싶어요!'),
              const Divider(color: Color(0xFFF0F0F0), height: 32),
              _buildRequestItem('현우', '@hyunwoo_00', '친구 요청을 보냈어요!'),
              const SizedBox(height: 32),
              // 하단 일러스트 및 문구
              Center(
                child: Column(
                  children: [
                    const Text("💌", style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    const Text("새로운 친구와\n더 많은 여행을 함께해요! 🌱", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF4A7C59), fontWeight: FontWeight.w600, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestItem(String name, String handle, String message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // 프로필과 텍스트 위쪽 정렬
      children: [
        CircleAvatar(radius: 24, backgroundColor: Colors.blue[100], child: const Icon(Icons.face, color: Colors.brown)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
              Text(handle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF333333))),
            ],
          ),
        ),
        // 수락/거절 버튼
        Row(
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                side: const BorderSide(color: Color(0xFFEBE6D9)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {},
              child: const Text("거절", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A7C59),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {},
              child: const Text("수락", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }
}