import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'splash_screen.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
void main() async {
  // 🌟 플러터 엔진이 켜지기 전에 확실히 준비하도록 기다리는 마법의 코드
  WidgetsFlutterBinding.ensureInitialized(); 

  await dotenv.load(fileName: ".env");

  // 🌟 카카오 SDK 초기화 (여기에 아까 메모해둔 네이티브 앱 키를 넣으세요!)
  KakaoSdk.init(nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY']);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '숨트립',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFFDECB3),
        fontFamily: 'CustomFont',
      ),
      // 🌟 2. 앱을 켜면 무조건 SplashScreen부터 시작하도록 설정!
      home: const SplashScreen(), 
    );
  }
}

// ... 아래는 기존 WorldCupScreen 코드들 ...