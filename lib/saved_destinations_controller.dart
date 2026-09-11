import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'saved_region_service.dart';

/// Shared destinations/bookmark/delete state for any screen that lists
/// [SavedRegion]s (the saved-destinations list, the shared-only list, and
/// the home screen). Call [initSavedDestinations] from `initState`.
mixin SavedDestinationsController<T extends StatefulWidget> on State<T> {
  static const _bookmarkKey = 'home_bookmarked_region_ids';

  List<SavedRegion> destinations = [];
  bool isLoadingDestinations = true;
  String? destinationsError;
  Set<int> bookmarkIds = {};
  final Set<int> deletingIds = {};
  bool _updatingBookmark = false;

  void initSavedDestinations() {
    loadBookmarks();
    final cached = SavedRegionService.cachedRegions;
    if (cached != null) {
      destinations = cached;
      isLoadingDestinations = false;
    }
    loadDestinations(showLoading: cached == null);
  }

  Future<void> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_bookmarkKey) ?? const [];
    if (mounted) {
      setState(() => bookmarkIds = ids.map(int.tryParse).whereType<int>().toSet());
    }
  }

  Future<void> toggleBookmark(int id) async {
    if (_updatingBookmark) return;
    _updatingBookmark = true;
    try {
      final next = Set<int>.from(bookmarkIds);
      next.contains(id) ? next.remove(id) : next.add(id);
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setStringList(
          _bookmarkKey, next.map((e) => e.toString()).toList());
      if (!saved) throw Exception('북마크 저장에 실패했어요.');
      if (mounted) setState(() => bookmarkIds = next);
      await onBookmarkIdsChanged(next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('북마크 저장에 실패했어요. 다시 시도해주세요.')));
      }
    } finally {
      _updatingBookmark = false;
    }
  }

  /// Lets a screen react when the bookmark set changes (e.g. HomeScreen
  /// clears its active trip when that region is unbookmarked).
  Future<void> onBookmarkIdsChanged(Set<int> next) async {}

  Future<void> loadDestinations({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        isLoadingDestinations = true;
        destinationsError = null;
      });
    }

    try {
      final saved = await SavedRegionService.getAll();
      if (!mounted) return;
      setState(() {
        destinations = saved;
        destinationsError = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (destinations.isEmpty) {
        setState(() =>
            destinationsError = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted && showLoading) setState(() => isLoadingDestinations = false);
    }
  }

  Future<void> showDeleteDialog(SavedRegion destination) async {
    if (deletingIds.contains(destination.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('여행지 삭제',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF333333))),
        content: Text("'${destination.regionName}' 여행지를 진짜로 삭제할까요? 🥲",
            style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소',
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제',
                style: TextStyle(
                    color: Color(0xFFE57373), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => deletingIds.add(destination.id));

    try {
      await SavedRegionService.remove(destination.id);
      if (bookmarkIds.contains(destination.id)) await toggleBookmark(destination.id);
      if (!mounted) return;
      setState(() {
        destinations = destinations
            .where((item) => item.id != destination.id)
            .toList(growable: false);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('저장한 여행지를 삭제했어요.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => deletingIds.remove(destination.id));
    }
  }
}
