import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// The standard interactive card chrome of the app.
///
/// On hover (mouse) or keyboard focus the card **rises by 4 px
/// ([TGMotion.hoverLift]) and gains a turquoise glow**; the border turns
/// turquoise too. It is tappable and keyboard-activatable (Enter / Space).
///
/// Respects the OS "reduce motion" setting (no lift, instant colour change).
class TGHoverCard extends StatefulWidget {
  const TGHoverCard({
    super.key,
    required this.child,
    required this.onTap,
    this.gradientBorder = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Pink → turquoise gradient border (used for promoted listings).
  final bool gradientBorder;

  final String? semanticLabel;

  @override
  State<TGHoverCard> createState() => _TGHoverCardState();
}

class _TGHoverCardState extends State<TGHoverCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final active = _hovered || _focused;
    final duration = reduceMotion ? Duration.zero : TGMotion.hover;
    final lift = reduceMotion ? 0.0 : TGMotion.hoverLift;
    const r = TGRadius.card;
    final gradient = widget.gradientBorder;
    final innerRadius = BorderRadius.circular(gradient ? r - 1.5 : r - 1);

    final glow = <BoxShadow>[
      BoxShadow(color: theme.primary.withValues(alpha: 0.30), blurRadius: 22, spreadRadius: 1, offset: const Offset(0, 8)),
    ];

    Widget card = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          // translateY(-4px) on hover/focus.
          transform: Matrix4.translationValues(0, active ? -lift : 0, 0),
          padding: gradient ? const EdgeInsets.all(1.5) : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(r),
            gradient: gradient
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [theme.secondary, theme.primary],
                  )
                : null,
            border: gradient ? null : Border.all(color: active ? theme.primary : theme.tertiary, width: 1),
            boxShadow: active ? glow : const [],
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: theme.secondaryBackground, borderRadius: innerRadius),
            child: ClipRRect(borderRadius: innerRadius, child: widget.child),
          ),
        ),
      ),
    ),
    );

    if (widget.semanticLabel != null) {
      card = Semantics(button: true, label: widget.semanticLabel, child: card);
    }
    return card;
  }
}
