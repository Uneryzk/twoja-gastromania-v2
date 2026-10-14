import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_user_text.dart';
import 'package:twoja_gastromania/tg_core/tg_i18n_audit.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Dev-only overlay: red frames on chrome that did not come from a key, plus ⚠ list.
class TGI18nAuditOverlay extends StatefulWidget {
  const TGI18nAuditOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<TGI18nAuditOverlay> createState() => _TGI18nAuditOverlayState();
}

class _TGI18nAuditOverlayState extends State<TGI18nAuditOverlay> {
  List<Rect> _boxes = const [];

  @override
  void initState() {
    super.initState();
    TGI18nAudit.instance.addListener(_onAudit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    TGI18nAudit.instance.removeListener(_onAudit);
    super.dispose();
  }

  void _onAudit() {
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void didUpdateWidget(covariant TGI18nAuditOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  void _scan() {
    if (!mounted || !TGI18nAudit.instance.enabled) {
      if (_boxes.isNotEmpty) setState(() => _boxes = const []);
      return;
    }
    final boxes = <Rect>[];
    final overlayBox = context.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.hasSize) return;
    void visitor(Element el) {
      final w = el.widget;
      if (w is TGUserText) return;
      var skip = false;
      el.visitAncestorElements((a) {
        if (a.widget is TGUserText) {
          skip = true;
          return false;
        }
        return true;
      });
      if (skip) {
        el.visitChildren(visitor);
        return;
      }
      final texts = _textsOf(w);
      final resolved = TGI18nAudit.instance.resolvedThisFrame;
      for (final t in texts) {
        if (!_looksLikeChrome(t)) continue;
        if (resolved.contains(t)) continue;
        if (t.startsWith(TGI18nAudit.markerPrefix)) continue;
        final ro = el.renderObject;
        if (ro is RenderBox && ro.hasSize && ro.attached) {
          final origin = ro.localToGlobal(Offset.zero, ancestor: overlayBox);
          boxes.add(origin & ro.size);
        }
        break;
      }
      el.visitChildren(visitor);
    }

    context.visitChildElements(visitor);
    setState(() => _boxes = boxes);
  }

  static List<String> _textsOf(Widget w) {
    if (w is Text) {
      final d = w.data ?? w.textSpan?.toPlainText() ?? '';
      return d.trim().isEmpty ? const [] : [d.trim()];
    }
    if (w is RichText) {
      final d = w.text.toPlainText().trim();
      return d.isEmpty ? const [] : [d];
    }
    final tip = w is Tooltip ? w.message?.trim() : null;
    if (tip != null && tip.isNotEmpty) return [tip];
    if (w is Semantics && (w.properties.label ?? '').trim().isNotEmpty) {
      return [w.properties.label!.trim()];
    }
    return const [];
  }

  static bool _looksLikeChrome(String t) {
    if (t.length < 2) return false;
    return RegExp(r'[A-Za-zĄąĆćĘęŁłŃńÓóŚśŹźŻżİıĞğŞşÄäÖöÜüß]').hasMatch(t);
  }

  @override
  Widget build(BuildContext context) {
    final audit = TGI18nAudit.instance;
    return Stack(
      children: [
        widget.child,
        if (audit.enabled) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _RedFramesPainter(_boxes)),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: const Color(0xCC1A1A1A),
              borderRadius: BorderRadius.circular(TGRadius.card),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320, maxHeight: 240),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.t('ui_dev_language_audit'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_boxes.length} hardcoded · ${audit.missingKeys.length} missing',
                        style: const TextStyle(color: Color(0xFFFFB4A2), fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      if (audit.missingKeys.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: [
                              for (final k in audit.missingKeys.take(40))
                                Text('⚠ $k', style: const TextStyle(color: Color(0xFFFFCC00), fontSize: 11, height: 1.35)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RedFramesPainter extends CustomPainter {
  _RedFramesPainter(this.boxes);
  final List<Rect> boxes;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFF3B30);
    for (final r in boxes) {
      canvas.drawRect(r.deflate(0.5), p);
    }
  }

  @override
  bool shouldRepaint(covariant _RedFramesPainter old) => old.boxes != boxes;
}
