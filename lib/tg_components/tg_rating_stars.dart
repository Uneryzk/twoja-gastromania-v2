import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Five gold stars (design token: rating gold) with half-star support.
class TGRatingStars extends StatelessWidget {
  const TGRatingStars({super.key, required this.rating, this.size = 18, this.showValue = true});

  final double rating;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final r = rating.clamp(0.0, 5.0);

    IconData iconFor(int i) {
      if (r >= i + 1) return Icons.star_rounded;
      if (r >= i + 0.5) return Icons.star_half_rounded;
      return Icons.star_outline_rounded;
    }

    return Semantics(
      label: 'Rated ${r.toStringAsFixed(1)} out of 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++) Icon(iconFor(i), size: size, color: TGColors.rating),
          if (showValue) ...[
            const SizedBox(width: 6),
            Text(r.toStringAsFixed(1), style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}
