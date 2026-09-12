import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'destination_detail_screen.dart';
import 'home_logo_button.dart';
import 'route_screen.dart';
import 'route_service.dart';
import 'saved_destinations_controller.dart';
import 'saved_region_list_item.dart';
import 'saved_region_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SavedDestinationsController {
  static const _activeKey = 'home_active_trip_id';
  int? _activeId;
  bool _changingTrip = false;
  bool _openingTrip = false;

  @override
  void initState() {
    super.initState();
    initSavedDestinations();
  }

  @override
  Future<void> loadBookmarks() async {
    await super.loadBookmarks();
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _activeId = prefs.getInt(_activeKey));
  }

  @override
  Future<void> onBookmarkIdsChanged(Set<int> next) async {
    if (next.contains(_activeId)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    if (mounted) setState(() => _activeId = null);
  }

  Future<void> _startTrip(int id) async {
    if (!bookmarkIds.contains(id) || _changingTrip) return;
    _changingTrip = true;
    try {
      final next = _activeId == id ? null : id;
      final prefs = await SharedPreferences.getInstance();
      final saved = next == null
          ? await prefs.remove(_activeKey)
          : await prefs.setInt(_activeKey, next);
      if (!saved) throw Exception('저장 실패');
      if (mounted) setState(() => _activeId = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('여행중 상태를 저장하지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      _changingTrip = false;
    }
  }

  Future<void> _openActiveTrip(SavedRegion destination) async {
    if (_openingTrip) return;
    setState(() => _openingTrip = true);
    try {
      final plan = await RouteService.getSaved(destination.id);
      if (!mounted) return;
      final hasRoute = plan.byDay.values.any((spots) => spots.isNotEmpty);
      final result = await Navigator.push<Object>(
          context,
          MaterialPageRoute(
              builder: (_) => hasRoute
                  ? RouteScreen(
                      initialPlan: plan,
                      savedRegionId: destination.id,
                      travelPeriod: const ['당일치기', '1박 2일', '2박 3일'][
                          (plan.byDay.keys.reduce((a, b) => a > b ? a : b) - 1)
                              .clamp(0, 2)],
                      selectedSpots: destination.spots)
                  : DestinationDetailScreen(destination: destination)));
      if (result == 'reset' && mounted) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DestinationDetailScreen(
                    destination: destination, resetRoute: true)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('경로를 불러오지 못했어요. 다시 시도해주세요.')));
      }
    } finally {
      if (mounted) setState(() => _openingTrip = false);
    }
  }

  Future<void> _showAppInfoDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        title: const Text('숨트립 🌱',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF4A7C59))),
        content: const Text(
            '나만의 취향에 맞는 여행지를 추천받고,\n친구와 함께 여행 코스를 공유해보세요.\n\n버전 1.0.0'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인',
                  style: TextStyle(color: Color(0xFF4A7C59)))),
        ],
      ),
    );
  }

  Widget _buildTraveling() {
    final active = destinations
        .where((item) => item.id == _activeId && bookmarkIds.contains(item.id));
    final name = active.isEmpty ? null : active.first.regionName;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:
          active.isEmpty || _openingTrip ? null : () => _openActiveTrip(active.first),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 0, 5, 28),
        child: AspectRatio(
          aspectRatio: 1448 / 1086,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1448,
              height: 1086,
              child: Stack(children: [
                Positioned.fill(
                    child: Image.asset('assets/images/traveling.png',
                        fit: BoxFit.contain)),
                Positioned(
                    left: 260,
                    right: 260,
                    top: 370,
                    height: 320,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(name ?? '어디로 떠나볼까요?',
                                      maxLines: 1,
                                      softWrap: false,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 100,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF4A7C59))))),
                          if (name != null) const SizedBox(height: 24),
                          if (name != null)
                            const Text('클릭하시면 추천 경로로 바로 이동해요. \n즐거운 여행 되세요~!☺️',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 45,
                                    color: Color.fromARGB(255, 0, 0, 0),
                                    fontWeight: FontWeight.w600)),
                          if (name == null)
                            const Text('북마크된 여행지에서 start를 눌러주시면\n여행이 시작돼요!',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 40)),
                        ])),
                if (name != null)
                  for (var i = 0; i < 5; i++)
                    Positioned(
                        left:
                            const [188.0, 458.0, 722.0, 995.0, 1258.0][i] - 44,
                        top: 784,
                        width: 88,
                        height: 80,
                        child: Center(
                            child: Text(const ['💛', '여', '행', '중', '💛'][i],
                                style: const TextStyle(
                                    fontSize: 45,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)))),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  List<SavedRegion> get _homeOrderedDestinations {
    final bookmarked = <SavedRegion>[];
    final rest = <SavedRegion>[];
    for (final destination in destinations) {
      (bookmarkIds.contains(destination.id) ? bookmarked : rest)
          .add(destination);
    }
    return [...bookmarked, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4), // 시안에 맞춘 따뜻한 아이보리 배경
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: '앱 정보',
          onPressed: _showAppInfoDialog,
          icon: const Icon(Icons.help_outline_rounded, color: Colors.grey),
        ),
        actions: const [HomeLogoButton()],
      ),
      body: SafeArea(
        child: Column(children: [
          _buildTraveling(),
          Expanded(
              flex: 2,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 24, 12),
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A7C59),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              Icon(Icons.location_on_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Text('저장한 여행지',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ]))),
                    Expanded(child: _buildBody()),
                  ])),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoadingDestinations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (destinationsError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(destinationsError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: loadDestinations, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    if (destinations.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadDestinations,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Center(child: Text('저장한 여행지가 아직 없어요.')),
          ],
        ),
      );
    }

    final ordered = _homeOrderedDestinations;
    return LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
              onRefresh: loadDestinations,
              child: ListView.builder(
                itemExtent: (constraints.maxHeight - 8) / 6,
                physics:
                    const BouncingScrollPhysics(), // 🌟 스크롤할 때 고무줄처럼 부드럽게 튕기는 효과
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: ordered.length,
                itemBuilder: (context, index) {
                  final destination = ordered[index];
                  return SavedRegionListItem(
                    key: ValueKey(destination.id),
                    destination: destination,
                    homeLayout: true,
                    isBookmarked: bookmarkIds.contains(destination.id),
                    isActiveTrip: _activeId == destination.id,
                    isDeleting: deletingIds.contains(destination.id),
                    onDelete: () => showDeleteDialog(destination),
                    onToggleBookmark: () => toggleBookmark(destination.id),
                    onToggleStart: () => _startTrip(destination.id),
                  );
                },
              ),
            ));
  }
}
