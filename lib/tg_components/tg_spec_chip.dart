import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';

class TGSpecChip extends StatefulWidget {
  const TGSpecChip({super.key, required this.icon, required this.label, this.tooltip});

  final IconData icon;
  final String label;
  final String? tooltip;

  @override
  State<TGSpecChip> createState() => _TGSpecChipState();
}

class _TGSpecChipState extends State<TGSpecChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final child = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _hovered ? theme.alternate : theme.secondaryBackground,
          borderRadius: BorderRadius.circular(theme.designToken.radius.chip),
          border: Border.all(color: theme.tertiary, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 16, color: theme.secondaryText),
            const SizedBox(width: 8),
            Text(widget.label, style: theme.bodySmall.override(color: theme.primaryText, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
    return widget.tooltip == null ? child : Tooltip(message: widget.tooltip!, child: child);
  }
}
