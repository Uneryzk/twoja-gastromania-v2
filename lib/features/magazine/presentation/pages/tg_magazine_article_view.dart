import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_util.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_top_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Editorial constants for the EuroGastro 2027 B2B magazine article.
abstract final class TGMagazineMetrics {
  static const double savingsRate = 0.28;
  static const double equipmentCostPln = 24000;
  static const double defaultBillPln = 5000;
  static const double billMin = 1000;
  static const double billMax = 20000;
  static const int billDivisions = 38;
  static const double traditionalCapex = 0.65;
  static const double smartCapex = 0.35;
  static const int energySavePct = 28;
  static const int capexCutPct = 35;
  static const int editorialRoiMonths = 11;
  static const int combiPln = 672;
  static const int coldPln = 597;
  static const int washPln = 331;
  static const double combiShare = 0.80;
  static const double coldShare = 0.65;
  static const double washShare = 0.35;
  static const double cateringSharePct = 32.3;
  static const double foodSharePct = 20.2;
  static const double techSharePct = 11.3;
  static const int edition = 30;
  static const int year = 2027;
}

/// Twoja Gastromania B2B magazine article: costs, charts, live ROI.
class TgMagazineArticleView extends StatefulWidget {
  const TgMagazineArticleView({super.key});

  static const String routeName = 'TgMagazineArticle';
  static const String routePath = '/magazine/article';

  @override
  State<TgMagazineArticleView> createState() => _TgMagazineArticleViewState();
}

class _TgMagazineArticleViewState extends State<TgMagazineArticleView> {
  double _monthlyBillPln = TGMagazineMetrics.defaultBillPln;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final phone = w < TGBreakpoints.phone;
    final pad = phone ? 16.0 : 28.0;
    final titleSize = phone ? 24.0 : 32.0;
    final monthlySavings = _monthlyBillPln * TGMagazineMetrics.savingsRate;
    final roiMonths = TGMagazineMetrics.equipmentCostPln / (monthlySavings == 0 ? 1 : monthlySavings);

    TextStyle kicker() => GoogleFonts.inter(
          color: TGColors.cta,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.40,
          height: 1.3,
        );
    TextStyle heading(double size) => GoogleFonts.interTight(
          color: theme.primaryText,
          fontSize: size,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.40,
          height: 1.2,
        );
    TextStyle body() => GoogleFonts.inter(
          color: theme.primaryText.withValues(alpha: 0.88),
          fontSize: phone ? 14 : 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.20,
          height: 1.6,
        );
    TextStyle sectionTitle() => GoogleFonts.interTight(
          color: theme.primaryText,
          fontSize: phone ? 15 : 17,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.40,
          height: 1.3,
        );
    TextStyle caption() => GoogleFonts.inter(
          color: theme.secondaryText,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.20,
          height: 1.5,
        );
    TextStyle label() => GoogleFonts.inter(
          color: theme.secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.20,
          height: 1.3,
        );

    return TGPageScaffold(
      backgroundColor: TGColors.background,
      body: ListView(
        key: const Key('journal-article'),
        children: [
          const TGTopNav(),
          _HeroCover(
            phone: phone,
            titleSize: titleSize,
            heading: heading,
            kicker: kicker(),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 20, pad, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TGBreadcrumb(
                      items: [
                        TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                        TGBreadcrumbItem(label: context.t('journal_kicker')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _IconStrip(phone: phone, labelStyle: label()),
                    const SizedBox(height: 28),
                    _IntroBlock(phone: phone, bodyStyle: body()),
                    const SizedBox(height: 32),
                    _CapexChart(titleStyle: sectionTitle(), labelStyle: label()),
                    const SizedBox(height: 28),
                    _ConsumptionChart(titleStyle: sectionTitle(), labelStyle: label()),
                    const SizedBox(height: 28),
                    const _Gallery(),
                    const SizedBox(height: 28),
                    _RoiCalculator(
                      bill: _monthlyBillPln,
                      savings: monthlySavings,
                      months: roiMonths,
                      titleStyle: sectionTitle(),
                      captionStyle: caption(),
                      onBillChanged: (v) => setState(() => _monthlyBillPln = v),
                    ),
                    const SizedBox(height: 24),
                    _SourceBox(style: caption()),
                  ],
                ),
              ),
            ),
          ),
          const TGFooter(),
        ],
      ),
    );
  }
}

class _HeroCover extends StatelessWidget {
  const _HeroCover({
    required this.phone,
    required this.titleSize,
    required this.heading,
    required this.kicker,
  });

  final bool phone;
  final double titleSize;
  final TextStyle Function(double size) heading;
  final TextStyle kicker;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final height = phone ? 240.0 : 320.0;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            TGListingImages.heroSlide(0),
            key: const Key('magazine-photo-cover'),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => ColoredBox(color: TGColors.surfaceHover),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  TGColors.background.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(phone ? 16 : 28, 0, phone ? 16 : 28, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        image: true,
                        label: context.t('mag_cover_a11y'),
                        child: const SizedBox.shrink(),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: TGColors.cta,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          context.t('mag_badge'),
                          style: GoogleFonts.inter(
                            color: TGColors.onCta,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(context.t('journal_kicker'), style: kicker),
                      const SizedBox(height: 8),
                      Semantics(
                        header: true,
                        child: Text(context.t('journal_title'), style: heading(titleSize).copyWith(color: theme.primaryText)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconStrip extends StatelessWidget {
  const _IconStrip({required this.phone, required this.labelStyle});

  final bool phone;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.bolt_rounded, context.t('mag_icon_energy', {'pct': '${TGMagazineMetrics.energySavePct}'}), TGColors.rating, 'magazine-icon-energy'),
      (Icons.trending_down_rounded, context.t('mag_icon_capex', {'pct': '${TGMagazineMetrics.capexCutPct}'}), TGColors.verified, 'magazine-icon-capex'),
      (Icons.timer_outlined, context.t('mag_icon_roi', {'n': '${TGMagazineMetrics.editorialRoiMonths}'}), const Color(0xFF5B8DEF), 'magazine-icon-roi'),
      (Icons.verified_outlined, context.t('mag_icon_aclass'), FlutterFlowTheme.of(context).primary, 'magazine-icon-aclass'),
    ];
    return Container(
      key: const Key('magazine-icon-strip'),
      padding: EdgeInsets.symmetric(vertical: phone ? 12 : 14, horizontal: phone ? 8 : 10),
      decoration: BoxDecoration(
        color: TGColors.surface,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: TGColors.border),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: Semantics(
                label: item.$2,
                child: Column(
                  children: [
                    Icon(item.$1, key: Key(item.$4), color: item.$3, size: phone ? 18 : 20),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(item.$2, maxLines: 1, style: labelStyle.copyWith(color: FlutterFlowTheme.of(context).primaryText, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntroBlock extends StatelessWidget {
  const _IntroBlock({required this.phone, required this.bodyStyle});

  final bool phone;
  final TextStyle bodyStyle;

  Widget _photo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(TGRadius.input),
      child: Image.asset(
        TGListingImages.combiOven,
        key: const Key('magazine-photo-intro'),
        width: phone ? double.infinity : 128,
        height: phone ? 160 : 128,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => ColoredBox(color: TGColors.surfaceHover, child: SizedBox(width: phone ? double.infinity : 128, height: phone ? 160 : 128)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photo = Semantics(
      image: true,
      label: context.t('mag_photo_intro_a11y'),
      child: _photo(),
    );
    final copy = Text(context.t('mag_lead'), style: bodyStyle);
    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          photo,
          const SizedBox(height: 14),
          copy,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        photo,
        const SizedBox(width: 16),
        Expanded(child: copy),
      ],
    );
  }
}

class _CapexChart extends StatelessWidget {
  const _CapexChart({required this.titleStyle, required this.labelStyle});

  final TextStyle titleStyle;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: context.t('mag_chart1_a11y', {
        'a': '${(TGMagazineMetrics.traditionalCapex * 100).round()}',
        'b': '${(TGMagazineMetrics.smartCapex * 100).round()}',
      }),
      child: Container(
        key: const Key('journal-chart-capex'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: TGColors.surface,
          borderRadius: BorderRadius.circular(TGRadius.card),
          border: Border.all(color: TGColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('mag_chart1_title'), style: titleStyle),
            const SizedBox(height: 14),
            _ProgressBar(
              label: context.t('mag_setup_traditional'),
              value: TGMagazineMetrics.traditionalCapex,
              color: TGColors.error,
              badge: context.t('mag_capex_share', {'pct': '${(TGMagazineMetrics.traditionalCapex * 100).round()}'}),
              labelStyle: labelStyle,
            ),
            const SizedBox(height: 12),
            _ProgressBar(
              label: context.t('mag_setup_smart'),
              value: TGMagazineMetrics.smartCapex,
              color: TGColors.verified,
              badge: context.t('mag_capex_share', {'pct': '${(TGMagazineMetrics.smartCapex * 100).round()}'}),
              labelStyle: labelStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsumptionChart extends StatelessWidget {
  const _ConsumptionChart({required this.titleStyle, required this.labelStyle});

  final TextStyle titleStyle;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: context.t('mag_chart2_a11y'),
      child: Container(
        key: const Key('journal-chart-energy'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: TGColors.surface,
          borderRadius: BorderRadius.circular(TGRadius.card),
          border: Border.all(color: TGColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('mag_chart2_title'), style: titleStyle),
            const SizedBox(height: 14),
            _ProgressBar(
              label: context.t('mag_eq_combi'),
              value: TGMagazineMetrics.combiShare,
              color: const Color(0xFFE08A3C),
              badge: context.t('mag_pln_month', {'n': '${TGMagazineMetrics.combiPln}'}),
              labelStyle: labelStyle,
            ),
            const SizedBox(height: 12),
            _ProgressBar(
              label: context.t('mag_eq_cold'),
              value: TGMagazineMetrics.coldShare,
              color: TGColors.rating,
              badge: context.t('mag_pln_month', {'n': '${TGMagazineMetrics.coldPln}'}),
              labelStyle: labelStyle,
            ),
            const SizedBox(height: 12),
            _ProgressBar(
              label: context.t('mag_eq_wash'),
              value: TGMagazineMetrics.washShare,
              color: const Color(0xFF5B8DEF),
              badge: context.t('mag_pln_month', {'n': '${TGMagazineMetrics.washPln}'}),
              labelStyle: labelStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GalleryShot(
            key: const Key('magazine-photo-gallery-a'),
            asset: TGListingImages.productionKitchen,
            label: context.t('mag_photo_gallery_a_a11y'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GalleryShot(
            key: const Key('magazine-photo-gallery-b'),
            asset: TGListingImages.refrigeration,
            label: context.t('mag_photo_gallery_b_a11y'),
          ),
        ),
      ],
    );
  }
}

class _GalleryShot extends StatelessWidget {
  const _GalleryShot({super.key, required this.asset, required this.label});

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TGRadius.input),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => ColoredBox(color: TGColors.surfaceHover),
          ),
        ),
      ),
    );
  }
}

class _RoiCalculator extends StatelessWidget {
  const _RoiCalculator({
    required this.bill,
    required this.savings,
    required this.months,
    required this.titleStyle,
    required this.captionStyle,
    required this.onBillChanged,
  });

  final double bill;
  final double savings;
  final double months;
  final TextStyle titleStyle;
  final TextStyle captionStyle;
  final ValueChanged<double> onBillChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final billN = bill.round().toString();
    final saveN = savings.round().toString();
    final monthsN = months.toStringAsFixed(1);
    return Semantics(
      container: true,
      label: context.t('mag_roi_a11y', {'bill': billN, 'save': saveN, 'months': monthsN}),
      child: Container(
        key: const Key('journal-chart-roi'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: TGColors.surface,
          borderRadius: BorderRadius.circular(TGRadius.card),
          border: Border.all(color: TGColors.cta.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate_outlined, color: TGColors.cta, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(context.t('mag_roi_title'), style: titleStyle.copyWith(color: TGColors.cta))),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context.t('mag_roi_bill', {'n': billN}),
              key: const Key('magazine-roi-bill'),
              style: captionStyle.copyWith(color: theme.primaryText),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: TGColors.cta,
                thumbColor: TGColors.cta,
                inactiveTrackColor: TGColors.border,
                overlayColor: TGColors.cta.withValues(alpha: 0.16),
              ),
              child: Slider(
                key: const Key('magazine-roi-slider'),
                value: bill,
                min: TGMagazineMetrics.billMin,
                max: TGMagazineMetrics.billMax,
                divisions: TGMagazineMetrics.billDivisions,
                label: '$billN PLN',
                onChanged: onBillChanged,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TGColors.background,
                borderRadius: BorderRadius.circular(TGRadius.input),
                border: Border.all(color: TGColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.t('mag_roi_savings'), style: captionStyle),
                        const SizedBox(height: 4),
                        Text(
                          context.t('mag_pln_month', {'n': saveN}),
                          key: const Key('magazine-roi-savings'),
                          style: GoogleFonts.interTight(
                            color: TGColors.verified,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.40,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(context.t('mag_roi_period'), style: captionStyle),
                      const SizedBox(height: 4),
                      Text(
                        context.t('mag_months', {'n': monthsN}),
                        key: const Key('magazine-roi-months'),
                        style: GoogleFonts.interTight(
                          color: TGColors.rating,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.40,
                        ),
                      ),
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
}

class _SourceBox extends StatelessWidget {
  const _SourceBox({required this.style});

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TGColors.surface,
        borderRadius: BorderRadius.circular(TGRadius.input),
        border: Border.all(color: TGColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, color: TGColors.cta, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(context.t('mag_source'), style: style.copyWith(fontStyle: FontStyle.italic))),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.label,
    required this.value,
    required this.color,
    required this.badge,
    required this.labelStyle,
  });

  final String label;
  final double value;
  final Color color;
  final String badge;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: labelStyle, maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(badge, style: labelStyle.copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) {
            return Container(
              height: 8,
              width: c.maxWidth,
              decoration: BoxDecoration(
                color: TGColors.surfaceHover,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: reduce ? Duration.zero : TGMotion.barFill,
                curve: Curves.easeOutCubic,
                width: c.maxWidth * value.clamp(0.04, 1),
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
