import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:soomtrip/my_destination_screen.dart';

import 'auth_service.dart';
import 'friend_service.dart';
import 'splash_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _isLoggingOut = false;
  String? _userCode;
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await FriendService.getMe();
      if (mounted) {
        setState(() {
          _userCode = user.userCode;
          _nickname = user.nickname;
        });
      }
    } catch (error) {
      debugPrint('[My Page] Failed to load user profile: $error');
    }
  }

  Future<void> _showLogoutDialog() async {
    if (_isLoggingOut) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '로그아웃',
              style: TextStyle(color: Color(0xFFE57373)),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    try {
      try {
        await UserApi.instance.logout();
      } catch (error) {
        debugPrint('[Logout] Kakao logout failed: $error');
      }

      await AuthService.logout();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } catch (error) {
      debugPrint('[Logout] SoomTrip logout failed: $error');
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃에 실패했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4), // 시안에 맞춘 따뜻한 아이보리 배경
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("숨트립 🌱",
            style: TextStyle(
                color: Color(0xFF4A7C59),
                fontWeight: FontWeight.bold,
                fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded,
                color: Color(0xFF6B4E31)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF6B4E31)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 상단 마이페이지 타이틀 & 일러스트 영역
            _buildHeaderSection(),
            const SizedBox(height: 20),

            // 2. 프로필 카드
            _buildProfileCard(),
            const SizedBox(height: 16),

            // 3. 저장한 여행지 카드
            _buildSavedDestinationsCard(context),
            const SizedBox(height: 16),

            // 5. 나의 여행 기록 카드
            _buildTravelRecordsCard(),
            const SizedBox(height: 24),

            // 6. 로그아웃 버튼
            _buildLogoutButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 1. 헤더 영역 (마이페이지 글씨 + 캐릭터)
  // ==========================================
  Widget _buildHeaderSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "마이페이지",
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF333333)),
            ),
            SizedBox(height: 8),
            Text(
              "좋은 여행은\n언제나, 너와 함께",
              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
            ),
          ],
        ),
        // 🌟 나중에 여기에 잎사귀 캐릭터 이미지를 넣으세요!
        // Image.asset('assets/images/character.png', width: 100),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.park_rounded,
              color: Color(0xFF4A7C59), size: 50),
        ),
      ],
    );
  }

  // ==========================================
  // 2. 프로필 카드
  // ==========================================
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F0), // 연한 연두색 배경
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // 프사 영역
          Stack(
            children: [
              const CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white,
                // 나중에 실제 유저 프사로 변경
                child: Icon(Icons.face_retouching_natural,
                    size: 45, color: Color(0xFF8B5A2B)),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_outlined,
                      size: 16, color: Color(0xFF4A7C59)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // 텍스트 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${_nickname ?? '불러오는 중...'} 🌱",
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333))),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2EBE0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_userCode ?? '불러오는 중...',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4A7C59),
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 8),
                const Text("오늘도 새로운 곳을 꿈꾸는 중! 🌱",
                    style: TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }

  // ==========================================
  // 3. 저장한 여행지 카드
  // ==========================================
  Widget _buildSavedDestinationsCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MyDestinationsScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF9F5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.bookmark_border_rounded,
                        color: Color(0xFF6B4E31)),
                    SizedBox(width: 8),
                    Text("저장한 여행지",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333))),
                  ],
                ),
                const SizedBox(height: 12),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontFamily: 'CustomFont'), // 폰트 패밀리 적용 필요
                    children: [
                      TextSpan(text: "총 "),
                      TextSpan(
                          text: "28곳",
                          style: TextStyle(
                              color: Color(0xFF4A7C59),
                              fontWeight: FontWeight.bold)),
                      TextSpan(text: "을 저장했어요"),
                    ],
                  ),
                ),
              ],
            ),
            // 🌟 지도 일러스트 들어갈 곳
            const Icon(Icons.map_rounded, size: 40, color: Color(0xFFCDDC39)),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 5. 나의 여행 기록 카드
  // ==========================================
  Widget _buildTravelRecordsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.book_outlined, color: Color(0xFF6B4E31)),
              SizedBox(width: 8),
              Text("나의 여행 기록",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333))),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRecordItem(Icons.location_on_outlined, "방문한 여행지", "12곳",
                  const Color(0xFF4A7C59)),
              _buildRecordItem(
                  Icons.inventory_2_outlined, "타임캡슐", "8개", Colors.blue),
              _buildRecordItem(
                  Icons.approval_outlined, "스탬프", "15개", Colors.orange),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(
      IconData icon, String title, String count, Color iconColor) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(count,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333))),
      ],
    );
  }

  // ==========================================
  // 6. 로그아웃 버튼
  // ==========================================
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _isLoggingOut ? null : _showLogoutDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5), // 연한 붉은색 배경
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.logout_rounded, color: Color(0xFFE57373)),
                SizedBox(width: 12),
                Text("로그아웃",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333))),
              ],
            ),
            if (_isLoggingOut)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
