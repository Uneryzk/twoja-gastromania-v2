import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

class TGFilterOption {
  const TGFilterOption({required this.id, required this.label});
  final String id;
  final String label;
}

/// Filter tabs that wrap on desktop and collapse to a hamburger sheet on phones.
class TGFilterMenu extends StatelessWidget {
  const TGFilterMenu({
    super.key,
    required this.options,
    required this.currentId,
    required this.onSelect,
    this.title,
    this.menuKey,
  });

  final List<TGFilterOption> options;
  final String currentId;
  final ValueChanged<String> onSelect;
  final String? title;
  final Key? menuKey;

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    if (phone) {
      return _Hamburger(
        options: options,
        currentId: currentId,
        onSelect: onSelect,
        title: title,
        menuKey: menuKey,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            key: Key('filter-chip-${o.id}'),
            selected: currentId == o.id,
            label: Text(o.label, softWrap: false),
            onSelected: (_) => onSelect(o.id),
          ),
      ],
    );
  }
}

class _Hamburger extends StatelessWidget {
  const _Hamburger({
    required this.options,
    required this.currentId,
    required this.onSelect,
    this.title,
    this.menuKey,
  });
  final List<TGFilterOption> options;
  final String currentId;
  final ValueChanged<String> onSelect;
  final String? title;
  final Key? menuKey;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final current = options.where((o) => o.id == currentId).firstOrNull ?? options.first;
    return Tooltip(
      message: title ?? context.t('ui_filters'),
      child: Material(
      color: theme.alternate,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TGRadius.pill),
        side: BorderSide(color: theme.tertiary),
      ),
      child: InkWell(
        key: menuKey ?? const Key('deals-filter-menu'),
        borderRadius: BorderRadius.circular(TGRadius.pill),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Icon(Icons.menu, size: 20, color: theme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  current.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyMedium.override(fontWeight: FontWeight.w800),
                ),
              ),
              Icon(Icons.expand_more, color: theme.secondaryText),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final theme = FlutterFlowTheme.of(context);
    final heading = title ?? context.t('ui_filters');
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: theme.secondaryBackground,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.72),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(heading, style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  for (final o in options) ...[
                    _Tile(
                      label: o.label,
                      selected: o.id == currentId,
                      onTap: () => Navigator.pop(ctx, o.id),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
    if (picked != null && picked != currentId) onSelect(picked);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: selected ? theme.primary.withValues(alpha: 0.16) : theme.alternate,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TGRadius.card),
        side: BorderSide(color: selected ? theme.primary : theme.tertiary, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TGRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.bodyMedium.override(fontWeight: FontWeight.w800, color: selected ? theme.primary : theme.primaryText))),
              if (selected) Icon(Icons.check, size: 18, color: theme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
