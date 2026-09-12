import 'package:flutter/material.dart';

// Parenthetical notes are omitted from the compact sign label.
String routeSignName(String name) {
  final shortened = name
      .replaceAll(RegExp(r'\s*[\(（][^\)）]*[\)）]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return shortened.isEmpty ? name.trim() : shortened;
}

class RouteSignLabel extends StatelessWidget {
  const RouteSignLabel({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final label = routeSignName(name);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    const baseStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      fontSize: 14,
      height: 1.15,
      fontFamily: 'CustomHandwriting',
    );

    return LayoutBuilder(builder: (context, constraints) {
      bool fits(String text, TextStyle style, {int lines = 2}) {
        // Six-character lines use smaller type within the existing sign inset.
        if (lines == 1 && text.characters.length >= 6 && style.fontSize! > 12) {
          return false;
        }
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: direction,
          textScaler: scaler,
          maxLines: lines,
        )..layout(maxWidth: constraints.maxWidth);
        final fits = !painter.didExceedMaxLines &&
            painter.height <= constraints.maxHeight &&
            painter
                .computeLineMetrics()
                .every((line) => line.width <= constraints.maxWidth);
        painter.dispose();
        return fits;
      }

      double textWidth(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: direction,
          textScaler: scaler,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }

      final words = RegExp(r' ').allMatches(label).map((m) => m.start).toList();
      // Keep whole words when possible; unspaced names can break between letters.
      final letterBreaks = <int>[];
      var offset = 0;
      for (final letter in label.characters) {
        offset += letter.length;
        if (offset < label.length) letterBreaks.add(offset);
      }
      var display = label;
      var style = baseStyle;
      for (var size = 14; size >= 11; size--) {
        style = baseStyle.copyWith(fontSize: size.toDouble());
        if (fits(label, style, lines: 1)) break;

        String? wrapped;
        var bestDifference = double.infinity;
        final breaks = words.isEmpty ? letterBreaks : words;
        for (final split in breaks) {
          final first = label.substring(0, split).trim();
          final second = label.substring(split).trim();
          if (fits(first, style, lines: 1) &&
              fits(second, style, lines: 1) &&
              fits('$first\n$second', style)) {
            final difference =
                (textWidth(first, style) - textWidth(second, style)).abs();
            if (difference < bestDifference) {
              bestDifference = difference;
              wrapped = '$first\n$second';
            }
          }
        }
        if (wrapped != null) {
          display = wrapped;
          break;
        }
      }

      return Center(
        child: Text(
          display,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      );
    });
  }
}
