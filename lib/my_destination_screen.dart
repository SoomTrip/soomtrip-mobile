import 'package:flutter/material.dart';
import 'destination_action_screen.dart'; // 🌟 두 번째 만들 상세 화면을 불러옵니다.
import 'saved_region_service.dart';

class MyDestinationsScreen extends StatefulWidget {
  const MyDestinationsScreen({super.key});

  @override
  State<MyDestinationsScreen> createState() => _MyDestinationsScreenState();
}

class _MyDestinationsScreenState extends State<MyDestinationsScreen> {
  List<SavedRegion> destinations = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<int> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    final cached = SavedRegionService.cachedRegions;
    if (cached != null) {
      destinations = cached;
      _isLoading = false;
    }
    _loadDestinations(showLoading: cached == null);
  }

  Future<void> _loadDestinations({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final savedRegions = await SavedRegionService.getAll();
      if (!mounted) return;
      setState(() {
        destinations = savedRegions;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (destinations.isEmpty) {
        setState(() =>
            _errorMessage = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && showLoading) setState(() => _isLoading = false);
    }
  }

  // 🗑️ 삭제 확인 팝업 (팝업도 귀여운 테마로 변경!)
  Future<void> _showDeleteDialog(SavedRegion destination) async {
    if (_deletingIds.contains(destination.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFBF9F4), // 따뜻한 배경색
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)), // 둥근 모서리
          title: const Text(
            "여행지 삭제",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF333333)),
          ),
          content: Text("'${destination.regionName}' 여행지를 진짜로 삭제할까요? 🥲",
              style: const TextStyle(color: Colors.black87)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("취소",
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              // 삭제 버튼은 눈에 띄면서도 부드러운 붉은색으로
              child: const Text("삭제",
                  style: TextStyle(
                      color: Color(0xFFE57373), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() => _deletingIds.add(destination.id));

    try {
      await SavedRegionService.remove(destination.id);
      if (!mounted) return;
      setState(() {
        destinations = destinations
            .where((item) => item.id != destination.id)
            .toList(growable: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장한 여행지를 삭제했어요.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(destination.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4), // 시안에 맞춘 따뜻한 아이보리 배경
      appBar: AppBar(
        title: const Text(
          "저장한 여행지 🗺️",
          style: TextStyle(
              color: Color(0xFF333333),
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF333333)),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _loadDestinations, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    if (destinations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDestinations,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 220),
            Center(child: Text('저장한 여행지가 아직 없어요.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDestinations,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(), // 🌟 스크롤할 때 고무줄처럼 부드럽게 튕기는 효과
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: destinations.length,
        itemBuilder: (context, index) {
          final destination = destinations[index];
          return GestureDetector(
            onTap: () {
              // 오른쪽 상세 화면으로 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DestinationActionScreen(
                    destination: destination,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF9F5),
                borderRadius: BorderRadius.circular(24), // 🌟 마이페이지처럼 둥글둥글하게!
                border: Border.all(
                    color: const Color(0xFFEBE6D9), width: 1.5), // 연한 테두리
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // 📍 여행지 이름 옆에 들어가는 귀여운 초록색 마커 포인트
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF3EA), // 연두색 배경
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            color: Color(0xFF4A7C59), size: 22),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        destination.regionName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333)),
                      ),
                    ],
                  ),
                  // ❌ 삭제 버튼 (너무 튀지 않게 연한 회색으로 변경)
                  GestureDetector(
                    onTap: () => _showDeleteDialog(destination),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: _deletingIds.contains(destination.id)
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.close_rounded,
                              color: Color(0xFFBDBDBD), size: 22),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
