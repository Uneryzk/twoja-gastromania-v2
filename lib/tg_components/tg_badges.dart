import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/products/products_query.dart';

enum TGItemCondition { nowy, uzywany }

class TGStatusRibbon extends StatelessWidget {
  const TGStatusRibbon({super.key, required this.condition});
  final TGItemCondition condition;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final bg = condition == TGItemCondition.nowy ? theme.secondary : theme.primary;
    final fg = condition == TGItemCondition.nowy ? const Color(0xFF1A1A1A) : const Color(0xFF0E1A16);
    final label = conditionLabel(
      condition == TGItemCondition.nowy ? TGCondition.newItem : TGCondition.used,
      t: (k) => context.t(k),
    );
    return Transform.rotate(
      angle: -0.14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: theme.labelLarge.override(color: fg, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      ),
    );
  }
}

class TGPromotedBadge extends StatelessWidget {
  const TGPromotedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.alternate,
        borderRadius: BorderRadius.circular(theme.designToken.radius.chip),
        border: Border.all(color: theme.tertiary, width: 1),
      ),
      child: Text(context.t('ui_promoted_badge'), style: theme.labelSmall.override(color: theme.primaryText, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
    );
  }
}

class TGVerifiedSellerBadge extends StatelessWidget {
  const TGVerifiedSellerBadge({super.key, this.tooltip, this.pulse = false});

  final String? tooltip;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(theme.designToken.radius.chip),
        border: Border.all(color: theme.success.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, size: 16, color: theme.success),
          const SizedBox(width: 6),
          Text(context.t('ui_verified_seller'), style: theme.labelSmall.override(color: theme.primaryText, fontWeight: FontWeight.w700)),
        ],
      ),
    );
    if (pulse && !(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      badge = _OncePulse(child: badge);
    }
    if (tooltip != null && tooltip!.trim().isNotEmpty) {
      badge = Tooltip(message: tooltip!, child: badge);
    }
    return badge;
  }
}

class _OncePulse extends StatefulWidget {
  const _OncePulse({required this.child});
  final Widget child;
  @override
  State<_OncePulse> createState() => _OncePulseState();
}

class _OncePulseState extends State<_OncePulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut)),
      child: FadeTransition(opacity: Tween(begin: 0.55, end: 1.0).animate(_c), child: widget.child),
    );
  }
}

class TGRatingBadge extends StatelessWidget {
  const TGRatingBadge({super.key, required this.rating, this.maxStars = 5});
  final double rating;
  final int maxStars;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final fullStars = rating.floor().clamp(0, maxStars);
    final hasHalf = (rating - fullStars) >= 0.5 && fullStars < maxStars;
    return Transform.rotate(
      angle: -0.10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.warning,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < fullStars; i++) Icon(Icons.star, size: 14, color: const Color(0xFF1A1A1A)),
            if (hasHalf) Icon(Icons.star_half, size: 14, color: const Color(0xFF1A1A1A)),
            const SizedBox(width: 6),
            Text(rating.toStringAsFixed(1), style: theme.labelLarge.override(color: const Color(0xFF1A1A1A), fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
