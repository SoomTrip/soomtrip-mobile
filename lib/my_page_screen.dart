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
import 'share_service.dart';
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
  bool _isDeletingAccount = false;
  String? _userCode;
  String? _nickname;
  String? _profileImageUrl;
  String? _selectedProfileAsset;
  Uint8List? _selectedProfileBytes;
  int? _savedDestinationCount;
  List<ShareRequest> _pendingReceivedShares = [];

  @override
  void initState() {
    super.initState();
    _savedDestinationCount = SavedRegionService.cachedRegions?.length;
    _loadUserProfile();
    _loadSavedDestinationCount();
    _loadReceivedShares();
  }

  Future<void> _loadReceivedShares() async {
    try {
      final shares = await ShareService.getReceived();
      if (!mounted) return;
      setState(() => _pendingReceivedShares =
          shares.where((share) => share.status == 'PENDING').toList());
    } catch (error) {
      debugPrint('[My Page] Failed to load received shares: $error');
    }
  }

  Future<void> _respondToShare(ShareRequest request, bool accept) async {
    Navigator.pop(context);
    try {
      accept
          ? await ShareService.accept(request.shareId)
          : await ShareService.reject(request.shareId);
      if (accept) {
        SavedRegionService.invalidateCache();
        await _loadSavedDestinationCount();
      }
      if (!mounted) return;
      setState(() => _pendingReceivedShares = _pendingReceivedShares
          .where((share) => share.shareId != request.shareId)
          .toList());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accept
              ? '${request.regionName} 여행지를 저장했어요.'
              : '${request.regionName} 공유를 거절했어요.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  void _showReceivedSharesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFBF9F4),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('받은 공유 여행지 ${_pendingReceivedShares.length}개',
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (_pendingReceivedShares.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('받은 공유 요청이 없어요.')))
              else
                ..._pendingReceivedShares.map(_buildReceivedShareItem),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceivedShareItem(ShareRequest request) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request.regionName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${request.senderNickname} 님이 공유했어요',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        TextButton(
            onPressed: () => _respondToShare(request, false),
            child: const Text('거절', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A7C59),
                foregroundColor: Colors.white),
            onPressed: () => _respondToShare(request, true),
            child: const Text('수락')),
      ]),
    );
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
        if (_nickname == null && nickname != null && nickname.isNotEmpty) {
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

  Future<void> _showProfileEditor() async {
    final nicknameController = TextEditingController(text: _nickname ?? '');
    final formKey = GlobalKey<FormState>();
    var draftAsset = _selectedProfileAsset;
    var draftBytes = _selectedProfileBytes;
    var saving = false;
    var picking = false;
    String? errorMessage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFFFBF9F4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) => PopScope(
          canPop: !saving && !picking,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('프로필 수정',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Center(
                      child: CircleAvatar(
                        radius: 38,
                        backgroundImage: draftBytes != null
                            ? MemoryImage(draftBytes!)
                            : draftAsset != null
                                ? AssetImage(draftAsset!)
                                : _profileImageUrl != null
                                    ? NetworkImage(_profileImageUrl!)
                                    : null,
                        child: draftBytes == null &&
                                draftAsset == null &&
                                _profileImageUrl == null
                            ? const Icon(Icons.person, size: 38)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('프로필 사진',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final asset in _defaultProfileAssets)
                          InkWell(
                            onTap: saving || picking
                                ? null
                                : () => updateSheet(() {
                                      draftAsset = asset;
                                      draftBytes = null;
                                    }),
                            borderRadius: BorderRadius.circular(32),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: draftAsset == asset
                                      ? const Color(0xFF4A7C59)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                  radius: 25,
                                  backgroundImage: AssetImage(asset)),
                            ),
                          ),
                        IconButton(
                          tooltip: '갤러리에서 사진 선택',
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          onPressed: saving || picking
                              ? null
                              : () async {
                                  updateSheet(() {
                                    picking = true;
                                    errorMessage = null;
                                  });
                                  try {
                                    final image = await ImagePicker().pickImage(
                                      source: ImageSource.gallery,
                                      maxWidth: 600,
                                      imageQuality: 80,
                                    );
                                    if (image != null) {
                                      final bytes = await image.readAsBytes();
                                      if (!sheetContext.mounted) return;
                                      updateSheet(() {
                                        draftBytes = bytes;
                                        draftAsset = null;
                                      });
                                    }
                                  } catch (_) {
                                    if (sheetContext.mounted) {
                                      updateSheet(() => errorMessage =
                                          '사진을 불러오지 못했어요. 다시 시도해 주세요.');
                                    }
                                  } finally {
                                    if (sheetContext.mounted) {
                                      updateSheet(() => picking = false);
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nicknameController,
                      enabled: !saving,
                      decoration: const InputDecoration(labelText: '닉네임'),
                      textInputAction: TextInputAction.done,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? '닉네임을 입력해주세요.'
                              : null,
                    ),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(errorMessage!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: saving || picking
                              ? null
                              : () => Navigator.pop(sheetContext),
                          child: const Text('취소'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4A7C59),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: saving || picking
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  updateSheet(() {
                                    saving = true;
                                    errorMessage = null;
                                  });
                                  try {
                                    final nickname =
                                        nicknameController.text.trim();
                                    if (nickname != _nickname) {
                                      await AuthService.updateNickname(
                                          nickname);
                                    }
                                    final preferences =
                                        await SharedPreferences.getInstance();
                                    if (draftBytes != null) {
                                      await preferences.setString(
                                          _profileBytesKey,
                                          base64Encode(draftBytes!));
                                      await preferences
                                          .remove(_profileAssetKey);
                                    } else if (draftAsset != null) {
                                      await preferences.setString(
                                          _profileAssetKey, draftAsset!);
                                      await preferences
                                          .remove(_profileBytesKey);
                                    }
                                    if (!mounted || !sheetContext.mounted) {
                                      return;
                                    }
                                    setState(() {
                                      _nickname = nickname;
                                      _selectedProfileAsset = draftAsset;
                                      _selectedProfileBytes = draftBytes;
                                    });
                                    Navigator.pop(sheetContext);
                                  } catch (_) {
                                    if (sheetContext.mounted) {
                                      updateSheet(() {
                                        saving = false;
                                        errorMessage =
                                            '프로필을 저장하지 못했어요. 다시 시도해 주세요.';
                                      });
                                    }
                                  }
                                },
                          child: Text(saving ? '저장 중...' : '저장'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Wait until the sheet's closing animation releases its text field.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    nicknameController.dispose();
  }

  Future<void> _showLogoutDialog() async {
    if (_isLoggingOut || _isDeletingAccount) return;

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
    if (_isLoggingOut || _isDeletingAccount) return;
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

  Future<void> _showDeleteAccountDialog() async {
    if (_isLoggingOut || _isDeletingAccount) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text(
          '정말 탈퇴하시겠습니까?\n\n'
          '탈퇴하면 모든 데이터가 영구적으로 삭제되며 복구할 수 없어요. 😢',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '탈퇴하기',
              style: TextStyle(color: Color(0xFFE57373)),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    if (_isLoggingOut || _isDeletingAccount) return;
    setState(() => _isDeletingAccount = true);

    try {
      try {
        // 로그아웃과 달리 탈퇴는 카카오 계정 연결 자체를 끊어야 함
        await UserApi.instance.unlink();
      } catch (error) {
        debugPrint('[Delete Account] Kakao unlink failed: $error');
      }

      await AuthService.deleteAccount();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } catch (error) {
      debugPrint('[Delete Account] SoomTrip account deletion failed: $error');
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원 탈퇴에 실패했습니다. 다시 시도해 주세요.')),
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
            icon: Stack(clipBehavior: Clip.none, children: [
              const Icon(Icons.notifications_none_rounded,
                  color: Color(0xFF6B4E31)),
              if (_pendingReceivedShares.isNotEmpty)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: Color(0xFFE57373), shape: BoxShape.circle),
                  ),
                ),
            ]),
            onPressed: _showReceivedSharesSheet,
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
            const SizedBox(height: 12),

            // 7. 회원 탈퇴 버튼
            _buildDeleteAccountButton(),
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
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
        Image.asset(
          'assets/images/character.png',
          width: 100,
          height: 100,
          fit: BoxFit.contain,
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
          _buildProfileImage(),
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
          IconButton(
            tooltip: '프로필 수정',
            onPressed: _showProfileEditor,
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF4A7C59)),
          ),
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
                const Row(
                  children: [
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
  Widget _buildTravelRecordsCard() => Container(
        decoration: BoxDecoration(
            color: const Color(0xFFFAF9F5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(20),
          leading:
              const Icon(Icons.people_alt_rounded, color: Color(0xFF4A7C59)),
          title: const Text('공유된 여행지',
              style: TextStyle(fontWeight: FontWeight.bold)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      const MyDestinationsScreen(sharedOnly: true))),
        ),
      );

  // ==========================================
  // 6. 로그아웃 버튼
  // ==========================================
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: (_isLoggingOut || _isDeletingAccount) ? null : _showLogoutDialog,
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

  // ==========================================
  // 7. 회원 탈퇴 버튼
  // ==========================================
  Widget _buildDeleteAccountButton() {
    return GestureDetector(
      onTap: (_isLoggingOut || _isDeletingAccount)
          ? null
          : _showDeleteAccountDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE), // 로그아웃보다 살짝 진한 연붉은색 배경
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.person_remove_alt_1_rounded,
                    color: Color(0xFFD32F2F)),
                SizedBox(width: 12),
                Text("회원 탈퇴",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333))),
              ],
            ),
            if (_isDeletingAccount)
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
