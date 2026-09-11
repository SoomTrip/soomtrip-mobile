import 'package:flutter/material.dart';
import 'friend_service.dart';
import 'saved_region_service.dart';
import 'share_service.dart';

class ShareRegionDialog extends StatefulWidget {
  const ShareRegionDialog({super.key, required this.friend});
  final FriendUser friend;

  @override
  State<ShareRegionDialog> createState() => _ShareRegionDialogState();
}

class _ShareRegionDialogState extends State<ShareRegionDialog> {
  late Future<List<SavedRegion>> _regions;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _regions = SavedRegionService.getAll();
  }

  Future<void> _send(SavedRegion region) async {
    if (_busy) return;
    setState(() { _busy = true; _message = null; });
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFFFBF9F4),
      title: Text('${widget.friend.nickname} 님에게 여행지를 공유하시겠습니까?'),
      content: Text(region.regionName),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: const Text('아니요', style: TextStyle(color: Colors.grey))),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: const Text('예', style: TextStyle(color: Color(0xFF4A7C59)))),
      ],
    ));
    if (!mounted) return;
    if (confirmed != true) { setState(() => _busy = false); return; }
    try {
      await ShareService.create(savedRegionId: region.id, friendUserId: widget.friend.id);
      if (!mounted) return;
      setState(() => _message = '${widget.friend.nickname} 님에게 ${region.regionName} 여행지 공유 요청을 보냈어요.');
    } on ShareException catch (error) {
      if (!mounted) return;
      setState(() => _message = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      backgroundColor: const Color(0xFFFBF9F4),
      title: const Text('공유할 여행지'),
      content: SizedBox(width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * .45,
        child: Column(children: [
          if (_busy) const LinearProgressIndicator(color: Color(0xFF4A7C59)),
          if (_message != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_message!)),
          Expanded(child: FutureBuilder<List<SavedRegion>>(
            future: _regions,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('여행지를 불러오지 못했어요.'),
                TextButton(onPressed: () => setState(() => _regions = SavedRegionService.getAll()), child: const Text('다시 시도')),
              ]));
              final regions = snapshot.data ?? [];
              if (regions.isEmpty) return const Center(child: Text('저장한 여행지가 아직 없어요.'));
              return ListView.builder(itemCount: regions.length, itemBuilder: (context, index) {
                final region = regions[index];
                return ListTile(contentPadding: EdgeInsets.zero,
                  title: Text(region.regionName),
                  trailing: IconButton(tooltip: '${region.regionName} 보내기',
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF4A7C59)),
                    onPressed: _busy ? null : () => _send(region)),
                );
              });
            },
          )),
        ])),
      actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('닫기'))],
    ),
  );
}
