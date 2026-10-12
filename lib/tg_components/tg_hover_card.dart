import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';

/// The standard interactive card chrome of the app.
///
/// On hover (mouse) or keyboard focus the card **rises by 4 px
/// ([TGMotion.hoverLift]) and gains a turquoise glow**; the border turns
/// turquoise too. It is tappable and keyboard-activatable (Enter / Space).
///
/// Glow / Spotlight use a static pink→turquoise frame (no pulse animation).
/// Respects the OS "reduce motion" setting (no lift, instant colour change).
class TGHoverCard extends StatefulWidget {
  const TGHoverCard({
    super.key,
    required this.child,
    required this.onTap,
    this.gradientBorder = false,
    this.tier,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Pink → turquoise gradient border (legacy promoted flag).
  final bool gradientBorder;

  /// VITRIN-1 tier chrome. When set, overrides [gradientBorder] for glow/spotlight.
  final PromotionTier? tier;

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

    final tier = widget.tier;
    final neon = tier == PromotionTier.glow || tier == PromotionTier.spotlight || (widget.gradientBorder && tier != PromotionTier.bold);
    final strong = tier == PromotionTier.spotlight;
    final frame = neon ? 2.0 : (widget.gradientBorder ? 1.5 : 0.0);
    final innerRadius = BorderRadius.circular(neon || widget.gradientBorder ? r - frame : r - 1);

    final hoverGlow = <BoxShadow>[
      BoxShadow(color: theme.primary.withValues(alpha: 0.30), blurRadius: 22, spreadRadius: 1, offset: const Offset(0, 8)),
    ];
    final staticNeon = <BoxShadow>[
      BoxShadow(
        color: theme.secondary.withValues(alpha: strong ? 0.45 : 0.32),
        blurRadius: strong ? 18 : 12,
        spreadRadius: strong ? 1 : 0,
        offset: Offset.zero,
      ),
      BoxShadow(
        color: theme.primary.withValues(alpha: strong ? 0.28 : 0.18),
        blurRadius: strong ? 14 : 10,
        spreadRadius: 0,
        offset: Offset.zero,
      ),
    ];

    final fill = neon
        ? Color.alphaBlend(theme.secondary.withValues(alpha: 0.08), theme.secondaryBackground)
        : theme.secondaryBackground;

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
            transform: Matrix4.translationValues(0, active ? -lift : 0, 0),
            padding: frame > 0 ? EdgeInsets.all(frame) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(r),
              gradient: neon || widget.gradientBorder
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [theme.secondary, theme.primary],
                    )
                  : null,
              border: neon || widget.gradientBorder ? null : Border.all(color: active ? theme.primary : theme.tertiary, width: 1),
              boxShadow: neon ? [...staticNeon, if (active) ...hoverGlow] : (active ? hoverGlow : const []),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: fill, borderRadius: innerRadius),
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
