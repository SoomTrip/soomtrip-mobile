import 'package:flutter/material.dart';
import 'gacha_screen.dart';
import 'worldcup_screen.dart';
import 'my_page_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 🌟 현재 선택된 탭의 번호 (0: 월드컵, 1: 가챠, 2: 홈, 3: 친구, 4: 마이페이지)
  // 처음 앱을 켰을 때 '홈'이 먼저 보이도록 기본값을 2로 설정합니다.
  int _currentIndex = 2;

  // 🌟 각 탭을 눌렀을 때 보여줄 화면들
  final List<Widget> _pages = [
    const WorldCupScreen(),
    const GachaScreen(),
    const Center(child: Text("🏠 메인 홈 화면", style: TextStyle(fontSize: 24))),
    const Center(child: Text("👥 친구 화면", style: TextStyle(fontSize: 24))),
    const MyPageScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE), // 앱 기본 배경색

      // 1. 메인 화면 (현재 선택된 탭의 화면을 보여줌)
      body: SafeArea(
        child: _pages[_currentIndex],
      ),

      // 2. 하단 내비게이션 바
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          // 🌟 탭을 누를 때마다 _currentIndex를 바꿔서 화면을 전환하는 마법
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },

          // 디자인 설정
          type: BottomNavigationBarType.fixed, // 탭이 5개일 때는 fixed로 해야 글자가 안 깨집니다
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF6B4E31), // 선택된 탭 색상 (숨트립 테마색)
          unselectedItemColor: Colors.grey.shade400, // 선택 안 된 탭 색상
          selectedFontSize: 12,
          unselectedFontSize: 12,

          // 3. 5개의 탭 버튼들
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_rounded), // 🏆 트로피 모양
              label: '월드컵',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.casino_rounded), // 🎲 주사위 모양 (가챠 느낌)
              label: '가챠',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), // 🏠 홈 모양
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded), // 👥 사람 두 명 모양
              label: '친구',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), // 👤 사람 한 명 모양
              label: '마이',
            ),
          ],
        ),
      ),
    );
  }
}
