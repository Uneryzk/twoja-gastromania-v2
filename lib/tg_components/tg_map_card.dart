import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_contact.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Location card: a stylised dark street map with a glowing turquoise pin, the
/// address, and an "Open in Maps" button that deep-links to the real map.
class TGMapCard extends StatelessWidget {
  const TGMapCard({super.key, required this.address, required this.mapsUri, this.actionLabel});

  final String address;
  final Uri mapsUri;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: theme.tertiary),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: 'Map showing $address. Opens in maps.',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => openExternalUrl(context, mapsUri, failMessage: 'Could not open Maps'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(TGRadius.input),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: _MapPainter(
                            land: theme.alternate,
                            street: theme.tertiary,
                            park: theme.success,
                            pin: theme.primary,
                          ),
                        ),
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.secondaryBackground.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.tertiary),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: theme.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.bodySmall.override(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TGButton(
            onPressed: () => openExternalUrl(context, mapsUri, failMessage: 'Could not open Maps'),
            label: actionLabel ?? context.t('ui_open_in_maps'),
            icon: Icons.map_outlined,
            variant: TGButtonVariant.outline,
            height: 42,
          ),
        ],
      ),
    );
  }
}

/// Deterministic, dependency-free "map" illustration.
class _MapPainter extends CustomPainter {
  const _MapPainter({required this.land, required this.street, required this.park, required this.pin});

  final Color land;
  final Color street;
  final Color park;
  final Color pin;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = land);

    // Parks / blocks.
    final parkPaint = Paint()..color = park.withValues(alpha: 0.10);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.06, h * 0.10, w * 0.22, h * 0.26), const Radius.circular(10)), parkPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.70, h * 0.58, w * 0.24, h * 0.22), const Radius.circular(10)), parkPaint);

    // River.
    final river = Path()
      ..moveTo(-10, h * 0.62)
      ..cubicTo(w * 0.25, h * 0.45, w * 0.55, h * 0.85, w + 10, h * 0.55);
    canvas.drawPath(
      river,
      Paint()
        ..color = pin.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );

    // Minor street grid.
    final minor = Paint()
      ..color = street.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var x = w * 0.08; x < w; x += w * 0.14) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), minor);
    }
    for (var y = h * 0.12; y < h; y += h * 0.2) {
      canvas.drawLine(Offset(0, y), Offset(w, y), minor);
    }

    // Main avenues.
    final avenue = Paint()
      ..color = street
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-6, h * 0.82), Offset(w + 6, h * 0.22), avenue);
    canvas.drawLine(Offset(w * 0.38, -6), Offset(w * 0.62, h + 6), avenue);

    // Pin with glow + ring.
    final c = Offset(w * 0.5, h * 0.46);
    canvas.drawCircle(
      c,
      44,
      Paint()
        ..shader = RadialGradient(colors: [pin.withValues(alpha: 0.38), pin.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: 44)),
    );
    canvas.drawCircle(c, 15, Paint()..color = pin.withValues(alpha: 0.22));
    canvas.drawCircle(
      c,
      15,
      Paint()
        ..color = pin
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(c, 6.5, Paint()..color = pin);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.land != land || old.street != street || old.park != park || old.pin != pin;
}
