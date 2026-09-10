import 'package:shared_preferences/shared_preferences.dart';
import 'home_logo_button.dart';
import 'package:flutter/material.dart';
import 'destination_action_screen.dart'; // 🌟 두 번째 만들 상세 화면을 불러옵니다.
import 'saved_region_service.dart';

class MyDestinationsScreen extends StatefulWidget {
  const MyDestinationsScreen(
      {super.key, this.showBackButton = true, this.homeLayout = false});

  final bool showBackButton;
  final bool homeLayout;

  @override
  State<MyDestinationsScreen> createState() => _MyDestinationsScreenState();
}

class _MyDestinationsScreenState extends State<MyDestinationsScreen> {
  static const _bookmarkKey = 'home_bookmarked_region_ids';
  Set<int> _bookmarkIds = {};
  bool _updatingBookmark = false;

  Future<void> _loadBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_bookmarkKey) ?? const [];
    if (mounted) {
      setState(() => _bookmarkIds = ids.map(int.parse).toSet());
    }
  }

  Future<void> _toggleBookmark(int id) async {
    if (_updatingBookmark) return;
    _updatingBookmark = true;
    try {
      final next = Set<int>.from(_bookmarkIds);
      next.contains(id) ? next.remove(id) : next.add(id);
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setStringList(
          _bookmarkKey, next.map((e) => e.toString()).toList());
      if (!saved) throw Exception('북마크 저장에 실패했어요.');
      if (mounted) setState(() => _bookmarkIds = next);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('북마크 저장에 실패했어요. 다시 시도해주세요.')));
    } finally {
      _updatingBookmark = false;
    }
  }

  List<SavedRegion> get _homeOrderedDestinations {
    final bookmarked = <SavedRegion>[];
    final rest = <SavedRegion>[];
    for (final destination in destinations) {
      (_bookmarkIds.contains(destination.id) ? bookmarked : rest)
          .add(destination);
    }
    return [...bookmarked, ...rest];
  }

  Widget _buildHome() {
    return Column(children: [
      const Expanded(
        child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('숨트립',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A7C59))))),
      ),
      Expanded(
          child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Card(
            color: const Color(0xFFEEF3EA),
            elevation: 0,
            child: SizedBox(
                width: double.infinity,
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('지금까지',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Flexible(
                              child: Text(
                                  _isLoading
                                      ? '여행지를 불러오는 중이에요'
                                      : _errorMessage != null
                                          ? '여행지를 불러오지 못했어요'
                                          : '${destinations.length}개의 여행지를 저장했어요!',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 23,
                                      color: Color(0xFF4A7C59)))),
                        ])))),
      )),
      Expanded(
          flex: 2,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text('저장한 여행지 🗺️',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            Expanded(child: _buildBody()),
          ])),
    ]);
  }

  List<SavedRegion> destinations = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<int> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _loadBookmark();
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
      if (_bookmarkIds.contains(destination.id))
        await _toggleBookmark(destination.id);
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
      appBar: widget.homeLayout
          ? null
          : AppBar(
              actions: const [HomeLogoButton()],
              automaticallyImplyLeading: widget.showBackButton,
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
        child: widget.homeLayout ? _buildHome() : _buildBody(),
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

    return LayoutBuilder(builder: (context, constraints) => RefreshIndicator(
      onRefresh: _loadDestinations,
      child: ListView.builder(
        itemExtent: widget.homeLayout ? (constraints.maxHeight - 8) / 6 : null,
        physics: const BouncingScrollPhysics(), // 🌟 스크롤할 때 고무줄처럼 부드럽게 튕기는 효과
        padding: EdgeInsets.symmetric(horizontal: widget.homeLayout ? 12 : 20, vertical: widget.homeLayout ? 4 : 12),
        itemCount: widget.homeLayout ? _homeOrderedDestinations.length : destinations.length,
        itemBuilder: (context, index) {
          final destination = widget.homeLayout
              ? _homeOrderedDestinations[index]
              : destinations[index];
          final card = GestureDetector(
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
              margin: EdgeInsets.only(bottom: widget.homeLayout ? 4 : 16),
              padding: EdgeInsets.symmetric(horizontal: widget.homeLayout ? 10 : 20, vertical: widget.homeLayout ? 0 : 18),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF9F5),
                borderRadius: BorderRadius.circular(24), // 🌟 마이페이지처럼 둥글둥글하게!
                border: Border.all(
                    color: const Color(0xFFEBE6D9), width: 1.5), // 연한 테두리
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!widget.homeLayout)
                    const Icon(Icons.location_on_rounded, color: Color(0xFF4A7C59)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(destination.regionName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333)))),
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
          if (!widget.homeLayout) return card;
          return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            destination.isShared
                ? _ShareBubbleIcon(
                    label: destination.sharedFrom?.nickname ?? '나')
                : IconButton(
                    tooltip: _bookmarkIds.contains(destination.id) ? '북마크 해제' : '북마크',
                    onPressed: () => _toggleBookmark(destination.id),
                    icon: Icon(
                        _bookmarkIds.contains(destination.id)
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: const Color(0xFF4A7C59))),
            Expanded(child: card),
          ]);
        },
      ),
    ));
  }
}

class _ShareBubbleIcon extends StatefulWidget {
  const _ShareBubbleIcon({required this.label});
  final String label;

  @override
  State<_ShareBubbleIcon> createState() => _ShareBubbleIconState();
}

class _ShareBubbleIconState extends State<_ShareBubbleIcon> {
  final _link = LayerLink();
  OverlayEntry? _entry;

  void _toggleBubble() {
    if (_entry != null) {
      _hideBubble();
      return;
    }
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        width: 120,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: const Offset(0, -6),
          child: _ShareBubble(text: widget.label),
        ),
      ),
    );
    _entry = entry;
    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(seconds: 2), _hideBubble);
  }

  void _hideBubble() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: IconButton(
        tooltip: widget.label,
        onPressed: _toggleBubble,
        icon: const Icon(Icons.person_rounded, color: Color(0xFF4A7C59)),
      ),
    );
  }
}

class _ShareBubble extends StatelessWidget {
  const _ShareBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFF4A7C59),
              borderRadius: BorderRadius.circular(10)),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
        CustomPaint(
            size: const Size(12, 6), painter: _BubbleTrianglePainter()),
      ]),
    );
  }
}

class _BubbleTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF4A7C59);
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
