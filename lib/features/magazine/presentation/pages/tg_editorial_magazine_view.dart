import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twoja_gastromania/features/magazine/presentation/pages/euro_gastro_2027_banner.dart';
import 'package:twoja_gastromania/features/magazine/presentation/pages/tg_magazine_article_view.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_util.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_top_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Inverted ROI panel: cream on a dark page, charcoal on a light page.
@immutable
class TGEditorialRoiContrast {
  const TGEditorialRoiContrast({
    required this.box,
    required this.text,
    required this.inner,
    required this.accent,
    required this.muted,
  });

  final Color box;
  final Color text;
  final Color inner;
  final Color accent;
  final Color muted;

  static const cream = Color(0xFFF4F1EA);
  static const ink = Color(0xFF111111);
  static const charcoal = Color(0xFF181818);
  static const innerDark = Color(0xFF0F0F0F);
  static const emerald = Color(0xFF059669);

  factory TGEditorialRoiContrast.of(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return TGEditorialRoiContrast(
      box: dark ? cream : charcoal,
      text: dark ? ink : Colors.white,
      inner: dark ? Colors.white : innerDark,
      accent: dark ? emerald : TGColors.cta,
      muted: dark ? const Color(0xFF5C564C) : const Color(0xFFB8BEC2),
    );
  }
}

/// B2B magazine template: inverted-contrast ROI box, circular mix stats, live calculator.
class TgEditorialMagazineView extends StatefulWidget {
  const TgEditorialMagazineView({super.key});

  static const String routeName = 'TgEditorialMagazine';
  static const String routePath = '/magazine/article';

  @override
  State<TgEditorialMagazineView> createState() => _TgEditorialMagazineViewState();
}

class _TgEditorialMagazineViewState extends State<TgEditorialMagazineView> {
  double _monthlyBillPln = TGMagazineMetrics.defaultBillPln;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final brightness = Theme.of(context).brightness;
    final contrast = TGEditorialRoiContrast.of(brightness);
    final w = MediaQuery.sizeOf(context).width;
    final phone = w < TGBreakpoints.phone;
    final pad = phone ? 16.0 : 28.0;
    final titleSize = phone ? 28.0 : 38.0;
    final monthlySavings = _monthlyBillPln * TGMagazineMetrics.savingsRate;
    final roiMonths = TGMagazineMetrics.equipmentCostPln / (monthlySavings == 0 ? 1 : monthlySavings);

    TextStyle kicker() => GoogleFonts.inter(
          color: TGColors.cta,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.40,
          height: 1.3,
        );
    TextStyle display() => GoogleFonts.interTight(
          color: theme.primaryText,
          fontSize: titleSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.40,
          height: 1.08,
        );
    TextStyle body() => GoogleFonts.inter(
          color: theme.secondaryText,
          fontSize: phone ? 14 : 15,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.20,
          height: 1.65,
        );
    TextStyle section() => GoogleFonts.interTight(
          color: theme.primaryText,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.40,
          height: 1.3,
        );

    return TGPageScaffold(
      backgroundColor: TGColors.background,
      body: ListView(
        key: const Key('journal-article'),
        children: [
          const TGTopNav(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
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
                    const SizedBox(height: 18),
                    Text(context.t('mag_page_line'), style: kicker()),
                    const SizedBox(height: 12),
                    const EuroGastro2027BannerWidget(),
                    const SizedBox(height: 22),
                    Semantics(
                      header: true,
                      child: Text(context.t('journal_title'), style: display()),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, c) {
                        final wide = c.maxWidth > 700;
                        final left = Text(context.t('mag_editorial_p1'), style: body());
                        final right = Text(context.t('mag_editorial_p2'), style: body());
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: left),
                              const SizedBox(width: 32),
                              Expanded(child: right),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            left,
                            const SizedBox(height: 16),
                            right,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 36),
                    Text(context.t('mag_balance_title'), style: section()),
                    const SizedBox(height: 14),
                    _BalanceCircles(phone: phone),
                    const SizedBox(height: 36),
                    _ContrastRoiBox(
                      contrast: contrast,
                      bill: _monthlyBillPln,
                      savings: monthlySavings,
                      months: roiMonths,
                      onBillChanged: (v) => setState(() => _monthlyBillPln = v),
                    ),
                    const SizedBox(height: 28),
                    Text(context.t('mag_source'), style: body().copyWith(fontSize: 13, fontStyle: FontStyle.italic)),
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

class _BalanceCircles extends StatelessWidget {
  const _BalanceCircles({required this.phone});

  final bool phone;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final a = TGMagazineMetrics.cateringSharePct.toStringAsFixed(1);
    final b = TGMagazineMetrics.foodSharePct.toStringAsFixed(1);
    final c = TGMagazineMetrics.techSharePct.toStringAsFixed(1);
    final items = [
      (context.t('mag_pct', {'pct': a}), context.t('mag_stat_catering'), const Color(0xFFE08A3C), 'magazine-stat-catering'),
      (context.t('mag_pct', {'pct': b}), context.t('mag_stat_food'), const Color(0xFF059669), 'magazine-stat-food'),
      (context.t('mag_pct', {'pct': c}), context.t('mag_stat_tech'), const Color(0xFF5B8DEF), 'magazine-stat-tech'),
    ];
    return Semantics(
      container: true,
      label: context.t('mag_balance_a11y', {'a': '$a', 'b': '$b', 'c': '$c'}),
      child: Container(
        key: const Key('journal-chart-capex'),
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: phone ? 16 : 20, horizontal: phone ? 10 : 20),
        decoration: BoxDecoration(
          color: TGColors.surface,
          borderRadius: BorderRadius.circular(TGRadius.card),
          border: Border.all(color: TGColors.border),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          runAlignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 16,
          children: [
            for (final item in items)
              SizedBox(
                width: phone ? 96 : 140,
                child: _CircularStat(
                  key: Key(item.$4),
                  percent: item.$1,
                  label: item.$2,
                  color: item.$3,
                  textColor: theme.primaryText,
                  size: phone ? 64 : 76,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircularStat extends StatelessWidget {
  const _CircularStat({
    super.key,
    required this.percent,
    required this.label,
    required this.color,
    required this.textColor,
    required this.size,
  });

  final String percent;
  final String label;
  final Color color;
  final Color textColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$percent. $label',
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3.5),
            ),
            alignment: Alignment.center,
            child: Text(
              percent,
              style: GoogleFonts.interTight(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: size < 70 ? 13 : 15,
                letterSpacing: 0.40,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: textColor.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.20,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContrastRoiBox extends StatelessWidget {
  const _ContrastRoiBox({
    required this.contrast,
    required this.bill,
    required this.savings,
    required this.months,
    required this.onBillChanged,
  });

  final TGEditorialRoiContrast contrast;
  final double bill;
  final double savings;
  final double months;
  final ValueChanged<double> onBillChanged;

  @override
  Widget build(BuildContext context) {
    final billN = bill.round().toString();
    final saveN = savings.round().toString();
    final monthsN = months.toStringAsFixed(1);
    return Semantics(
      container: true,
      label: context.t('mag_roi_a11y', {'bill': billN, 'save': saveN, 'months': monthsN}),
      child: Container(
        key: const Key('journal-chart-roi'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: contrast.box,
          borderRadius: BorderRadius.circular(TGRadius.card),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.30 : 0.14),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate_outlined, color: contrast.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.t('mag_roi_title'),
                    style: GoogleFonts.interTight(
                      color: contrast.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.40,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              context.t('mag_roi_bill', {'n': billN}),
              key: const Key('magazine-roi-bill'),
              style: GoogleFonts.inter(
                color: contrast.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.20,
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: contrast.accent,
                thumbColor: contrast.accent,
                inactiveTrackColor: contrast.text.withValues(alpha: 0.22),
                overlayColor: contrast.accent.withValues(alpha: 0.16),
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
              key: const Key('magazine-roi-contrast'),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: contrast.inner,
                borderRadius: BorderRadius.circular(TGRadius.input),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('mag_roi_savings'),
                          style: GoogleFonts.inter(color: contrast.muted, fontSize: 11, letterSpacing: 0.20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.t('mag_pln_month', {'n': saveN}),
                          key: const Key('magazine-roi-savings'),
                          style: GoogleFonts.interTight(
                            color: contrast.accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.40,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        context.t('mag_roi_period'),
                        style: GoogleFonts.inter(color: contrast.muted, fontSize: 11, letterSpacing: 0.20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t('mag_months', {'n': monthsN}),
                        key: const Key('magazine-roi-months'),
                        style: GoogleFonts.interTight(
                          color: TGColors.rating,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
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
