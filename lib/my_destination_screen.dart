import 'package:flutter/material.dart';
import 'destination_detail_screen.dart'; // 🌟 두 번째 만들 상세 화면을 불러옵니다.

class MyDestinationsScreen extends StatefulWidget {
  const MyDestinationsScreen({super.key});

  @override
  State<MyDestinationsScreen> createState() => _MyDestinationsScreenState();
}

class _MyDestinationsScreenState extends State<MyDestinationsScreen> {
  // 🌟 임시 여행지 데이터 목록 (수정/추가가 없으므로 일단 리스트로 관리)
  List<String> destinations = ['강릉', '부산', '제주'];

  // 🗑️ 삭제 확인 팝업을 띄우는 함수
  void _showDeleteDialog(String destination) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("여행지 삭제", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text("'$destination' 여행지를 진짜로 삭제하시겠습니까?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // 취소 누르면 팝업 닫기
              child: const Text("취소", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                // 확인 누르면 리스트에서 지우고 화면 새로고침
                setState(() {
                  destinations.remove(destination);
                });
                Navigator.pop(context); // 팝업 닫기
              },
              child: const Text("삭제", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EE), // 앱 기본 배경색
      appBar: AppBar(
        title: const Text("나의 여행지", style: TextStyle(color: Color(0xFF6B4E31), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF6B4E31)), // 뒤로가기 버튼 색상
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: destinations.length,
          itemBuilder: (context, index) {
            final dest = destinations[index];
            return GestureDetector(
              onTap: () {
                // 🌟 네모 박스를 누르면 오른쪽(상세) 화면으로 이동! (여행지 이름 전달)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DestinationDetailScreen(destinationName: dest),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF6B4E31), width: 2),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dest,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B4E31)),
                    ),
                    // ❌ 삭제 버튼
                    GestureDetector(
                      onTap: () => _showDeleteDialog(dest),
                      child: const Icon(Icons.close_rounded, color: Color(0xFF6B4E31), size: 28),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}