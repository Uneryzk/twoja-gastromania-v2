import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
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
    final isSmall = w < 430;
    final isMobile = w < 700;
    final gap = isSmall ? 8.0 : 10.0;
    final indicatorW = isSmall ? 72.0 : 110.0;
    final horizontalPad = isSmall ? const EdgeInsets.symmetric(horizontal: 14) : const EdgeInsets.symmetric(horizontal: 18);

    final (effectiveItems, effectiveActiveIndex) = _maybeCollapseOthersMenu(context: context, isMobile: isMobile, items: items, activeIndex: activeIndex);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < effectiveItems.length; i++) ...[
                _NavPill(item: effectiveItems[i], active: i == effectiveActiveIndex, padding: horizontalPad),
                SizedBox(width: gap),
              ]
            ],
          ),
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 2,
          decoration: BoxDecoration(color: theme.tertiary.withValues(alpha: 0.55)),
          child: effectiveActiveIndex == null
              ? null
              : Align(
                  alignment: Alignment(-1 + (2 * (effectiveActiveIndex / (effectiveItems.length - 1).clamp(1, 999))), 0),
                  child: Container(
                    width: indicatorW,
                    height: 2,
                    color: theme.primary,
                  ),
                ),
        ),
      ],
    );
  }

  (List<TGNavItem>, int?) _maybeCollapseOthersMenu({required BuildContext context, required bool isMobile, required List<TGNavItem> items, required int? activeIndex}) {
    if (!isMobile) return (items, activeIndex);

    const collapseIds = {'restaurants', 'special_order'};
    bool collapses(TGNavItem item) => item.id != null && collapseIds.contains(item.id);
    final collapsedIndices = <int>[];
    for (var i = 0; i < items.length; i++) {
      if (collapses(items[i])) collapsedIndices.add(i);
    }
    if (collapsedIndices.isEmpty) return (items, activeIndex);

    final othersActions = <TGNavItem>[];
    final effective = <TGNavItem>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (collapses(item)) {
        othersActions.add(item);
        continue;
      }
      effective.add(item);
    }

    // Insert "Others" where the first collapsed item used to be, but clamp to list bounds.
    final insertAt = collapsedIndices.first.clamp(0, effective.length);
    effective.insert(
      insertAt,
      TGNavItem(
        id: 'others',
        label: context.t('ui_others'),
        icon: Icons.menu,
        onTap: () => _openOthersMenu(context, othersActions),
      ),
    );

    if (activeIndex == null) return (effective, null);

    final wasCollapsedActive = collapsedIndices.contains(activeIndex);
    final effectiveActiveIndex = wasCollapsedActive
        ? insertAt
        : _remapActiveIndexAfterRemoval(activeIndex: activeIndex, removedIndices: collapsedIndices, insertAt: insertAt);
    return (effective, effectiveActiveIndex);
  }

  int _remapActiveIndexAfterRemoval({required int activeIndex, required List<int> removedIndices, required int insertAt}) {
    // If activeIndex is after any removed item, shift left by number of removed indices before it.
    final removedBefore = removedIndices.where((i) => i < activeIndex).length;
    var idx = activeIndex - removedBefore;
    // If the insertion point is <= idx, shift right by 1 (because we inserted Others).
    if (insertAt <= idx) idx += 1;
    return idx.clamp(0, 9999);
  }

  void _openOthersMenu(BuildContext context, List<TGNavItem> items) {
    final theme = FlutterFlowTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.secondaryBackground,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.t('ui_others'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                for (var i = 0; i < items.length; i++) ...[
                  _OthersMenuTile(
                    icon: _iconForItem(items[i]),
                    title: items[i].label,
                    onTap: () {
                      context.pop();
                      items[i].onTap?.call();
                    },
                  ),
                  if (i != items.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconForItem(TGNavItem item) {
    switch (item.id) {
      case 'restaurants':
        return Icons.storefront;
      case 'special_order':
        return Icons.assignment;
      default:
        return item.icon ?? Icons.chevron_right;
    }
  }
}

class _OthersMenuTile extends StatefulWidget {
  const _OthersMenuTile({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  State<_OthersMenuTile> createState() => _OthersMenuTileState();
}

class _OthersMenuTileState extends State<_OthersMenuTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _pressed ? theme.tertiary.withValues(alpha: 0.35) : theme.alternate,
          borderRadius: BorderRadius.circular(theme.designToken.radius.card),
          border: Border.all(color: theme.tertiary, width: 1),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 20, color: theme.primaryText),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.title, style: theme.bodyMedium.override(fontWeight: FontWeight.w700))),
            Icon(Icons.chevron_right, size: 20, color: theme.secondaryText),
          ],
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({required this.item, required this.active, required this.padding});
  final TGNavItem item;
  final bool active;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    if (item.isPrimary) {
      return TGButton(
        onPressed: item.onTap,
        label: item.label,
        icon: item.icon,
        variant: TGButtonVariant.primary,
        height: 44,
        padding: padding,
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
        height: 44,
        padding: padding,
        borderRadius: BorderRadius.circular(theme.designToken.radius.full),
      ),
    );
  }
}
