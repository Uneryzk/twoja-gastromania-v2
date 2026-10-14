import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';

class TGNavItem {
  const TGNavItem({
    required this.label,
    this.onTap,
    this.isPrimary = false,
    this.icon,
    this.id,
  });
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;
  final IconData? icon;

  /// Stable identity across locales so overflow collapse does not depend on English copy.
  final String? id;
}

class TGNavPills extends StatelessWidget {
  const TGNavPills({super.key, required this.items, this.activeIndex});

  final List<TGNavItem> items;

  /// Index of the highlighted pill, or `null` when none is active (e.g. on the
  /// home page, where neither "Buy" nor "Rent" is selected yet).
  final int? activeIndex;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 900;
    final gap = isMobile ? 4.0 : 10.0;
    final horizontalPad = isMobile
        ? const EdgeInsets.symmetric(horizontal: 6)
        : const EdgeInsets.symmetric(horizontal: 18);

    final pills = Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            flex: items[i].label.trim().length.clamp(4, 28),
            child: _NavPill(
              item: items[i],
              active: i == activeIndex,
              padding: horizontalPad,
              compact: isMobile,
              expand: true,
            ),
          ),
        ],
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pills,
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 2,
          decoration: BoxDecoration(color: theme.tertiary.withValues(alpha: 0.55)),
          child: activeIndex == null || items.length < 2
              ? null
              : Align(
                  alignment: Alignment(-1 + (2 * (activeIndex! / (items.length - 1).clamp(1, 999))), 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / items.length,
                    child: Container(height: 2, color: theme.primary),
                  ),
                ),
        ),
      ],
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.item,
    required this.active,
    required this.padding,
    this.compact = false,
    this.expand = false,
  });
  final TGNavItem item;
  final bool active;
  final EdgeInsets padding;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    if (item.isPrimary) {
      return TGButton(
        onPressed: item.onTap,
        label: item.label,
        icon: item.icon,
        variant: TGButtonVariant.primary,
        height: compact ? 40 : 44,
        padding: padding,
        dense: compact,
        expand: expand,
        borderRadius: BorderRadius.circular(theme.designToken.radius.full),
      );
    }

    return Semantics(
      selected: active,
      button: true,
      label: item.label,
      child: TGButton(
        onPressed: item.onTap,
        label: item.label,
        icon: item.icon,
        variant: active ? TGButtonVariant.outline : TGButtonVariant.ghost,
        height: compact ? 40 : 44,
        padding: padding,
        dense: compact,
        expand: expand,
        borderRadius: BorderRadius.circular(theme.designToken.radius.full),
      ),
    );
  }
}
