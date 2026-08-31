import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'; // 🌟 카카오 로그인 도구상자
import 'auth_service.dart';
import 'main_screen.dart';
import 'worldcup_screen.dart'; // WorldCupScreen이 있는 파일

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool isLoggedIn = false;
  bool _isCheckingLogin = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final hasJwt = await AuthService.hasJwt();
    if (!mounted) return;

    if (!hasJwt) {
      setState(() => _isCheckingLogin = false);
      return;
    }

    setState(() => isLoggedIn = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    _openHome();
  }

  void _openHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
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

      // 카카오 프로필 닉네임을 SoomTrip 사용자 DB에도 동기화합니다.
      try {
        final kakaoUser = await UserApi.instance.me();
        final nickname = kakaoUser.kakaoAccount?.profile?.nickname;
        if (nickname != null && nickname.trim().isNotEmpty) {
          await AuthService.updateNickname(nickname);
        }
      } catch (error) {
        debugPrint('[Kakao Login] Nickname sync failed: $error');
      }

      if (!mounted) return;
      _openWorldCup();
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
    _openWorldCup();
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
