import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'; // 🌟 카카오 로그인 도구상자
import 'auth_service.dart';
import 'friend_service.dart';
import 'main_screen.dart';
import 'intro_screen.dart';
import 'saved_region_service.dart';
import 'worldcup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool isLoggedIn = false;
  bool _isCheckingLogin = true;
  bool _isLoading = false;
  bool _checkingEntry = false;
  String? _entryError;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    if (_checkingEntry) return;
    _checkingEntry = true;
    setState(() {
      _entryError = null;
      _isCheckingLogin = true;
    });
    try {
      final hasJwt = await AuthService.hasJwt();
      if (!mounted) return;

      if (!hasJwt) {
        setState(() {
          _isCheckingLogin = false;
          isLoggedIn = false;
        });
        return;
      }

      setState(() => isLoggedIn = true);
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final completedIntro = await AuthService.hasCompletedIntro();
      if (!mounted) return;
      if (!completedIntro) {
        _openIntro();
        return;
      }

      // 인트로는 봤어도 월드컵/가챠 도중 이탈했을 수 있으니, 실제로 저장된
      // 여행지가 있는지 서버에 물어봐서 홈 진입 여부를 계정 단위로 판단한다.
      final hasSavedRegion = await _hasSavedRegion();
      if (!mounted) return;
      if (hasSavedRegion) {
        _openHome();
      } else {
        _openWorldCup();
      }
    } catch (_) {
      final hasJwt = await AuthService.hasJwt();
      if (!mounted) return;
      setState(() {
        isLoggedIn = hasJwt;
        _isCheckingLogin = false;
        _entryError = hasJwt ? '회원 정보를 확인하지 못했어요. 다시 시도해 주세요.' : null;
      });
    } finally {
      _checkingEntry = false;
    }
  }

  Future<bool> _hasSavedRegion() async {
    final regions = await SavedRegionService.getAll();
    return regions.isNotEmpty;
  }

  void _openHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  void _openIntro() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const IntroScreen()),
    );
  }

  void _openWorldCup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WorldCupScreen()),
    );
  }

  // 🌟 [핵심] 카카오 로그인 버튼을 눌렀을 때 실행될 마법의 함수!
  Future<void> _loginWithKakao() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // 1. 휴대폰에 카카오톡 앱이 깔려있는지 확인
      bool isInstalled = await isKakaoTalkInstalled();

      OAuthToken token;
      if (isInstalled) {
        // 2-A. 깔려있다면 카카오톡 앱을 열어서 로그인 시도
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          // 유저가 카카오톡 화면에서 '취소'를 누른 경우 예외 처리
          if (error is PlatformException && error.code == 'CANCELED') {
            return;
          }
          // 카카오톡에 연결되어 있지만 로그인이 안 될 경우, 브라우저로 다시 시도
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        // 2-B. 카카오톡 앱이 없다면 웹 브라우저를 띄워서 아이디/비밀번호로 로그인
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      // 카카오 토큰을 백엔드로 보내 SoomTrip JWT를 발급받아 저장합니다.
      await AuthService.loginWithKakao(token.accessToken);

      // 기존 닉네임을 보존하고, 비어 있는 경우에만 카카오 닉네임을 사용합니다.
      try {
        final user = await FriendService.getMe();
        if (user.nickname.trim().isEmpty) {
          final kakaoUser = await UserApi.instance.me();
          final nickname = kakaoUser.kakaoAccount?.profile?.nickname;
          if (nickname != null && nickname.trim().isNotEmpty) {
            await AuthService.updateNickname(nickname);
          }
        }
      } catch (error) {
        debugPrint('[Kakao Login] Nickname sync failed: $error');
      }

      if (!mounted) return;
      _openIntro();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인에 실패했습니다. 잠시 후 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _enterDebugMode() {
    if (!kDebugMode || _isLoading) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('테스트 모드로 입장합니다.')),
    );
    _openIntro();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE),
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/images/intro_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          if (_entryError != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_entryError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _checkLoginStatus,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          if (!_isCheckingLogin && !isLoggedIn)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80.0),
                child: GestureDetector(
                  onTap: () async {
                    // 🌟 아까 만든 로그인 함수를 여기서 실행합니다!
                    await _loginWithKakao();
                  },
                  onLongPress: _enterDebugMode,
                  child: Container(
                    width: 300,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE500),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black87,
                            ),
                          )
                        else ...[
                          const Icon(Icons.chat_bubble_rounded,
                              color: Colors.black87, size: 20),
                          const SizedBox(width: 10),
                          const Text(
                            "카카오 로그인",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
