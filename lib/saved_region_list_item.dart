import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'destination_action_screen.dart';
import 'saved_region_service.dart';

/// One row of a saved-destinations list: the destination card itself, plus
/// (in [homeLayout] mode) a leading bookmark/share icon and a "start" button
/// for the active trip. The shared-only list uses the same plain card look
/// as the regular saved-destinations screen.
class SavedRegionListItem extends StatelessWidget {
  const SavedRegionListItem({
    super.key,
    required this.destination,
    required this.isBookmarked,
    required this.isDeleting,
    required this.onDelete,
    required this.onToggleBookmark,
    this.homeLayout = false,
    this.showShareIcon = false,
    this.isActiveTrip = false,
    this.onToggleStart,
  });

  final SavedRegion destination;
  final bool homeLayout;
  final bool showShareIcon;
  final bool isBookmarked;
  final bool isActiveTrip;
  final bool isDeleting;
  final VoidCallback onDelete;
  final VoidCallback onToggleBookmark;
  final VoidCallback? onToggleStart;

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DestinationActionScreen(destination: destination),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: homeLayout ? 4 : 16),
        padding: EdgeInsets.symmetric(
            horizontal: homeLayout ? 10 : 20, vertical: homeLayout ? 0 : 18),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF9F5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!homeLayout && !showShareIcon)
              const Icon(Icons.location_on_rounded, color: Color(0xFF4A7C59)),
            if (showShareIcon && destination.isShared) _buildShareBubbleIcon(),
            const SizedBox(width: 8),
            Expanded(
                child: Text(destination.regionName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333)))),
            if (homeLayout && isBookmarked)
              Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: SizedBox(
                      height: 28,
                      child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              minimumSize: const Size(48, 28),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              backgroundColor: isActiveTrip
                                  ? const Color(0xFF4A7C59)
                                  : Colors.transparent,
                              foregroundColor: isActiveTrip
                                  ? Colors.white
                                  : const Color(0xFF4A7C59)),
                          onPressed: onToggleStart,
                          child: const Text('start')))),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: isDeleting
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

    if (!homeLayout) return card;

    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      destination.isShared
          ? _buildShareBubbleIcon()
          : IconButton(
              tooltip: isBookmarked ? '북마크 해제' : '북마크',
              onPressed: onToggleBookmark,
              icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked ? const Color(0xFF4A7C59) : Colors.grey)),
      Expanded(child: card),
    ]));
  }

  Widget _buildShareBubbleIcon() {
    return _ShareBubbleIcon(
        key: ValueKey(destination.id),
        label: [
          if (destination.sharedFrom != null)
            'From\n${destination.sharedFrom!.nickname}',
          if (destination.sharedTo.isNotEmpty)
            'To\n${destination.sharedTo.map((person) => person.nickname).join(', ')}',
        ].join('\n'),
        received: destination.sharedFrom != null,
        onTap: onToggleBookmark);
  }
}

class _ShareBubbleIcon extends StatefulWidget {
  const _ShareBubbleIcon(
      {super.key,
      required this.label,
      required this.received,
      required this.onTap});
  final String label;
  final bool received;
  final VoidCallback onTap;

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
      child: RawGestureDetector(
        gestures: {
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                  () => LongPressGestureRecognizer(
                      duration: const Duration(milliseconds: 500)),
                  (recognizer) => recognizer.onLongPress = _toggleBubble),
        },
        child: IconButton(
          onPressed: widget.onTap,
          icon: Icon(
            widget.received ? Icons.people_alt_rounded : Icons.person_rounded,
            color: const Color(0xFF4A7C59),
          ),
        ),
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
        CustomPaint(size: const Size(12, 6), painter: _BubbleTrianglePainter()),
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
