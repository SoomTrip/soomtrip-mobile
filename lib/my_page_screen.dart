import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soomtrip/my_destination_screen.dart';

import 'auth_service.dart';
import 'friend_service.dart';
import 'saved_region_service.dart';
import 'splash_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  static const _profileAssetKey = 'my_page_profile_asset';
  static const _profileBytesKey = 'my_page_profile_bytes';
  static const _defaultProfileAssets = [
    'assets/images/profile1.jpeg',
    'assets/images/profile2.jpeg',
    'assets/images/profile3.jpeg',
    'assets/images/profile4.jpeg',
    'assets/images/profile5.jpeg',
  ];

  bool _isLoggingOut = false;
  String? _userCode;
  String? _nickname;
  String? _profileImageUrl;
  String? _selectedProfileAsset;
  Uint8List? _selectedProfileBytes;
  int? _savedDestinationCount;

  @override
  void initState() {
    super.initState();
    _savedDestinationCount = SavedRegionService.cachedRegions?.length;
    _loadUserProfile();
    _loadSavedDestinationCount();
  }

  Future<void> _loadSavedDestinationCount() async {
    try {
      final savedRegions = await SavedRegionService.getAll();
      if (!mounted) return;
      setState(() => _savedDestinationCount = savedRegions.length);
    } catch (error) {
      debugPrint('[My Page] Failed to load saved region count: $error');
    }
  }

  Future<void> _loadUserProfile() async {
    final preferences = await SharedPreferences.getInstance();
    final savedAsset = preferences.getString(_profileAssetKey);
    final savedBytes = preferences.getString(_profileBytesKey);
    Uint8List? decodedBytes;
    if (savedBytes != null) {
      try {
        decodedBytes = base64Decode(savedBytes);
      } on FormatException {
        await preferences.remove(_profileBytesKey);
      }
    }

    if (mounted) {
      setState(() {
        _selectedProfileAsset = savedAsset;
        _selectedProfileBytes = decodedBytes;
      });
    }

    try {
      final user = await FriendService.getMe();
      if (mounted) {
        setState(() {
          _userCode = user.userCode;
          _nickname = user.nickname;
          _profileImageUrl ??= user.profileImage;
        });
      }
    } catch (error) {
      debugPrint('[My Page] Failed to load user profile: $error');
    }

    try {
      final kakaoUser = await UserApi.instance.me();
      final kakaoProfile = kakaoUser.kakaoAccount?.profile;
      if (!mounted) return;

      setState(() {
        final nickname = kakaoProfile?.nickname?.trim();
        if (nickname != null && nickname.isNotEmpty) {
          _nickname = nickname;
        }

        final profileImageUrl = kakaoProfile?.profileImageUrl?.trim();
        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
          _profileImageUrl = profileImageUrl;
        }
      });
    } catch (error) {
      debugPrint('[My Page] Failed to load Kakao profile: $error');
    }
  }

  Future<void> _showProfileImagePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFBF9F4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '프로필 사진 선택',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                '기본 이미지를 고르거나 + 버튼으로 사진을 추가해 보세요.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final asset in _defaultProfileAssets)
                    _buildProfileOption(
                      image: AssetImage(asset),
                      isSelected: _selectedProfileAsset == asset,
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _selectDefaultProfile(asset);
                      },
                    ),
                  _buildGalleryOption(sheetContext),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required ImageProvider image,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        height: 68,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFF4A7C59) : Colors.transparent,
            width: 3,
          ),
        ),
        child: CircleAvatar(backgroundImage: image),
      ),
    );
  }

  Widget _buildGalleryOption(BuildContext sheetContext) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(sheetContext);
        await _pickProfileFromGallery();
      },
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD9E4D6), width: 2),
        ),
        child:
            const Icon(Icons.add_rounded, size: 34, color: Color(0xFF4A7C59)),
      ),
    );
  }

  Future<void> _selectDefaultProfile(String asset) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_profileAssetKey, asset);
    await preferences.remove(_profileBytesKey);
    if (!mounted) return;
    setState(() {
      _selectedProfileAsset = asset;
      _selectedProfileBytes = null;
    });
  }

  Future<void> _pickProfileFromGallery() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 80,
      );
      if (image == null) return;

      final imageBytes = await image.readAsBytes();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _profileBytesKey,
        base64Encode(imageBytes),
      );
      await preferences.remove(_profileAssetKey);
      if (!mounted) return;
      setState(() {
        _selectedProfileBytes = imageBytes;
        _selectedProfileAsset = null;
      });
    } catch (error) {
      debugPrint('[My Page] Failed to pick profile image: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진을 불러오지 못했어요. 다시 시도해 주세요.')),
      );
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
              _buildProfileImage(),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showProfileImagePicker,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_outlined,
                        size: 16, color: Color(0xFF4A7C59)),
                  ),
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

  Widget _buildProfileImage() {
    final selectedBytes = _selectedProfileBytes;
    final selectedAsset = _selectedProfileAsset;
    final imageUrl = _profileImageUrl;

    return CircleAvatar(
      radius: 35,
      backgroundColor: Colors.white,
      child: ClipOval(
        child: selectedBytes != null
            ? Image.memory(
                selectedBytes,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultProfileIcon(),
              )
            : selectedAsset != null
                ? Image.asset(
                    selectedAsset,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  )
                : imageUrl == null
                    ? _buildDefaultProfileIcon()
                    : Image.network(
                        imageUrl,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildDefaultProfileIcon(),
                      ),
      ),
    );
  }

  Widget _buildDefaultProfileIcon() {
    return const Icon(
      Icons.face_retouching_natural,
      size: 45,
      color: Color(0xFF8B5A2B),
    );
  }

  // ==========================================
  // 3. 저장한 여행지 카드
  // ==========================================
  Widget _buildSavedDestinationsCard(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MyDestinationsScreen(),
          ),
        );
        if (context.mounted) await _loadSavedDestinationCount();
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
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontFamily: 'CustomFont'), // 폰트 패밀리 적용 필요
                    children: [
                      const TextSpan(text: "총 "),
                      TextSpan(
                          text: _savedDestinationCount == null
                              ? "-곳"
                              : "${_savedDestinationCount!}곳",
                          style: const TextStyle(
                              color: Color(0xFF4A7C59),
                              fontWeight: FontWeight.bold)),
                      const TextSpan(text: "을 저장했어요"),
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
