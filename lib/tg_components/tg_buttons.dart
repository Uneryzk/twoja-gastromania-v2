import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

enum TGButtonVariant { primary, outline, ghost }

/// Brand buttons without splash effects (modern, minimal).
class TGButton extends StatefulWidget {
  const TGButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.variant = TGButtonVariant.primary,
    this.height = 44,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
    this.borderRadius,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final TGButtonVariant variant;
  final double height;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;

  @override
  State<TGButton> createState() => _TGButtonState();
}

class _TGButtonState extends State<TGButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(theme.designToken.radius.input);

    final enabled = widget.onPressed != null;
    final bg = switch (widget.variant) {
      TGButtonVariant.primary => theme.primary,
      TGButtonVariant.outline => Colors.transparent,
      TGButtonVariant.ghost => Colors.transparent,
    };
    final border = switch (widget.variant) {
      TGButtonVariant.primary => BorderSide.none,
      TGButtonVariant.outline => BorderSide(color: theme.primary, width: 2),
      TGButtonVariant.ghost => BorderSide.none,
    };
    final fg = switch (widget.variant) {
      TGButtonVariant.primary => TGColors.onCta,
      TGButtonVariant.outline => theme.primary,
      TGButtonVariant.ghost => theme.primaryText,
    };

    final hoverOverlay = switch (widget.variant) {
      TGButtonVariant.primary => theme.primary.withValues(alpha: 0.90),
      TGButtonVariant.outline => theme.primary.withValues(alpha: 0.10),
      TGButtonVariant.ghost => theme.primary.withValues(alpha: 0.10),
    };

    final effectiveBg = !enabled
        ? theme.tertiary.withValues(alpha: 0.35)
        : (_hovered ? hoverOverlay : bg);
    final effectiveFg = !enabled ? theme.secondaryText : fg;

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: widget.height,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: effectiveBg,
              borderRadius: radius,
              border: border == BorderSide.none ? null : Border.fromBorderSide(border),
              boxShadow: const [],
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: effectiveFg),
                        const SizedBox(width: 10),
                      ],
                      // Flexible + ellipsis so a long label can never overflow
                      // a narrow button.
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.titleSmall.override(color: effectiveFg, fontSize: 14, letterSpacing: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_focused)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(color: theme.primary, width: 2),
                        ),
                        margin: const EdgeInsets.all(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TGIconButton extends StatefulWidget {
  const TGIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  State<TGIconButton> createState() => _TGIconButtonState();
}

class _TGIconButtonState extends State<TGIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final child = MouseRegion(
      cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _hovered ? theme.primary.withValues(alpha: 0.10) : theme.alternate,
            borderRadius: BorderRadius.circular(theme.designToken.radius.full),
            border: Border.all(color: theme.tertiary, width: 1),
          ),
          child: Icon(widget.icon, color: theme.primaryText, size: 18),
        ),
      ),
    );
    return widget.tooltip == null ? child : Tooltip(message: widget.tooltip!, child: child);
  }
}
