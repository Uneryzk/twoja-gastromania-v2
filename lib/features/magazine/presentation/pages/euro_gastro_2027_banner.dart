import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_util.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Official EuroGastro 2027 brochure strip: floor stats, mix bar, local HoReCa photo.
class EuroGastro2027BannerWidget extends StatelessWidget {
  const EuroGastro2027BannerWidget({super.key});

  static const Color accent = Color(0xFFD97706);
  static const Color gold = Color(0xFFFCD34D);
  static const Color mixKit = Color(0xFFF59E0B);
  static const Color mixFood = Color(0xFF10B981);
  static const Color mixTech = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    return Semantics(
      container: true,
      label: context.t('mag_fair_a11y'),
      child: Container(
        key: const Key('magazine-fair-banner'),
        margin: EdgeInsets.symmetric(vertical: phone ? 8 : 12),
        decoration: BoxDecoration(
          color: TGColors.surface,
          borderRadius: BorderRadius.circular(TGRadius.card),
          border: Border.all(color: TGColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: phone ? 16 / 11 : 16 / 7.2,
                  child: Image.asset(
                    TGListingImages.foodHall,
                    key: const Key('magazine-photo-cover'),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => ColoredBox(color: TGColors.surfaceHover),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0xBF000000)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: phone ? 12 : 16,
                  left: phone ? 12 : 16,
                  right: phone ? 12 : 16,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(TGRadius.pill),
                      ),
                      child: Text(
                        context.t('mag_fair_badge'),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.40,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: phone ? 16 : 20,
                  right: phone ? 16 : 20,
                  bottom: phone ? 14 : 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('mag_fair_when'),
                        style: GoogleFonts.inter(
                          color: gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.40,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.t('mag_fair_headline'),
                        style: GoogleFonts.interTight(
                          color: Colors.white,
                          fontSize: phone ? 18 : 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.40,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(phone ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatChip(
                        value: context.t('mag_fair_chip_exhibitors'),
                        label: context.t('mag_fair_chip_exhibitors_label'),
                        dark: dark,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        value: context.t('mag_fair_chip_visitors'),
                        label: context.t('mag_fair_chip_visitors_label'),
                        dark: dark,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        value: context.t('mag_fair_chip_area'),
                        label: context.t('mag_fair_chip_area_label'),
                        dark: dark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    context.t('mag_fair_p1'),
                    style: GoogleFonts.inter(
                      color: theme.primaryText,
                      fontSize: 15,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(context.t('mag_fair_p2'), style: _body(theme)),
                  const SizedBox(height: 14),
                  Text(context.t('mag_fair_p3'), style: _body(theme)),
                  const SizedBox(height: 24),
                  Text(
                    context.t('mag_fair_mix_title'),
                    style: GoogleFonts.interTight(
                      color: theme.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.40,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      key: const Key('magazine-fair-mix'),
                      height: 8,
                      child: Row(
                        children: [
                          const Expanded(flex: 32, child: ColoredBox(color: mixKit)),
                          const Expanded(flex: 20, child: ColoredBox(color: mixFood)),
                          const Expanded(flex: 11, child: ColoredBox(color: mixTech)),
                          Expanded(flex: 37, child: ColoredBox(color: TGColors.surfaceHover)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _Legend(color: mixKit, label: context.t('mag_fair_leg_kit')),
                      _Legend(color: mixFood, label: context.t('mag_fair_leg_food')),
                      _Legend(color: mixTech, label: context.t('mag_fair_leg_tech')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _body(FlutterFlowTheme theme) => GoogleFonts.inter(
        color: theme.secondaryText,
        fontSize: 13,
        height: 1.6,
        letterSpacing: 0.20,
      );
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label, required this.dark});

  final String value;
  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$value. $label',
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: EuroGastro2027BannerWidget.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(TGRadius.input),
            border: Border.all(color: EuroGastro2027BannerWidget.accent.withValues(alpha: 0.28)),
          ),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: GoogleFonts.interTight(
                    color: EuroGastro2027BannerWidget.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.40,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: dark ? const Color(0xFFB8BEC2) : const Color(0xFF4B5563),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.20,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: FlutterFlowTheme.of(context).secondaryText,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.20,
          ),
        ),
      ],
    );
  }
}
