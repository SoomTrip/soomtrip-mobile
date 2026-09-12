import 'package:flutter/material.dart';

import 'home_logo_button.dart';
import 'saved_destinations_controller.dart';
import 'saved_region_list_item.dart';

class MyDestinationsScreen extends StatefulWidget {
  const MyDestinationsScreen(
      {super.key, this.showBackButton = true, this.sharedOnly = false});

  final bool showBackButton;
  final bool sharedOnly;

  @override
  State<MyDestinationsScreen> createState() => _MyDestinationsScreenState();
}

class _MyDestinationsScreenState extends State<MyDestinationsScreen>
    with SavedDestinationsController {
  @override
  void initState() {
    super.initState();
    initSavedDestinations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4), // 시안에 맞춘 따뜻한 아이보리 배경
      appBar: AppBar(
        actions: const [HomeLogoButton()],
        automaticallyImplyLeading: widget.showBackButton,
        title: Text(
          widget.sharedOnly ? "공유된 여행지 👥" : "저장한 여행지 🗺️",
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
      body: SafeArea(child: _buildBody()),
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

    final visible = widget.sharedOnly
        ? destinations.where((item) => item.isShared).toList()
        : destinations;
    if (visible.isEmpty) {
      return RefreshIndicator(
        onRefresh: loadDestinations,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            Center(
                child: Text(widget.sharedOnly
                    ? '아직 공유된 여행지가 없어요😢'
                    : '저장한 여행지가 아직 없어요.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadDestinations,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(), // 🌟 스크롤할 때 고무줄처럼 부드럽게 튕기는 효과
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final destination = visible[index];
          return SavedRegionListItem(
            key: ValueKey(destination.id),
            destination: destination,
            showShareIcon: widget.sharedOnly,
            isBookmarked: bookmarkIds.contains(destination.id),
            isDeleting: deletingIds.contains(destination.id),
            onDelete: () => showDeleteDialog(destination),
            onToggleBookmark: () => toggleBookmark(destination.id),
          );
        },
      ),
    );
  }
}
