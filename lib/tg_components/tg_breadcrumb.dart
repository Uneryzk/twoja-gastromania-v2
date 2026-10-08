import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';

class TGBreadcrumbItem {
  const TGBreadcrumbItem({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
}

class TGBreadcrumb extends StatelessWidget {
  const TGBreadcrumb({super.key, required this.items});
  final List<TGBreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _Crumb(item: items[i]),
          if (i != items.length - 1) Icon(Icons.chevron_right, size: 18, color: theme.secondaryText),
        ]
      ],
    );
  }
}

class _Crumb extends StatefulWidget {
  const _Crumb({required this.item});
  final TGBreadcrumbItem item;

  @override
  State<_Crumb> createState() => _CrumbState();
}

class _CrumbState extends State<_Crumb> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final tappable = widget.item.onTap != null;

    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.item.onTap,
        child: Text(
          widget.item.label,
          style: theme.bodySmall.override(
            color: tappable
                ? (_hovered ? theme.primary : theme.secondaryText)
                : theme.secondaryText,
            fontWeight: tappable ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
