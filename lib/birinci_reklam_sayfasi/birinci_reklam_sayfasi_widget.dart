import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_util.dart';
import 'package:twoja_gastromania/journal/tg_journal_charts.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_top_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'birinci_reklam_sayfasi_model.dart';
export 'birinci_reklam_sayfasi_model.dart';

/// Home-banner “Read more” destination: B2B journal article with cost charts.
class BirinciReklamSayfasiWidget extends StatefulWidget {
  const BirinciReklamSayfasiWidget({super.key});

  static String routeName = 'BirinciReklamSayfasi';
  static String routePath = '/birinciReklamSayfasi';

  @override
  State<BirinciReklamSayfasiWidget> createState() => _BirinciReklamSayfasiWidgetState();
}

class _BirinciReklamSayfasiWidgetState extends State<BirinciReklamSayfasiWidget> {
  late BirinciReklamSayfasiModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BirinciReklamSayfasiModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final pad = w < 700 ? 16.0 : 28.0;
    final titleSize = w < 700 ? 28.0 : 36.0;

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
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.20,
          height: 1.65,
        );
    TextStyle chartTitle() => GoogleFonts.interTight(
          color: theme.primaryText,
          fontSize: 17,
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

    return TGPageScaffold(
      body: ListView(
        key: const Key('journal-article'),
        children: [
          const TGTopNav(),
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
                    const SizedBox(height: 28),
                    Text(context.t('journal_kicker'), style: kicker()),
                    const SizedBox(height: 10),
                    Semantics(
                      header: true,
                      child: Text(context.t('journal_title'), style: heading(titleSize)),
                    ),
                    const SizedBox(height: 12),
                    Text(context.t('journal_dek'), style: body()),
                    const SizedBox(height: 8),
                    Text(context.t('journal_read_time'), style: caption()),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(TGRadius.card),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(
                          TGListingImages.heroSlide(0),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => const ColoredBox(color: TGColors.surfaceHover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(context.t('journal_p1'), style: body()),
                    const SizedBox(height: 28),
                    _ChartBlock(
                      chartKey: const Key('journal-chart-capex'),
                      title: context.t('journal_chart1_title'),
                      caption: context.t('journal_chart1_caption'),
                      titleStyle: chartTitle(),
                      captionStyle: caption(),
                      child: const TGJournalCapexBar(),
                    ),
                    const SizedBox(height: 28),
                    Text(context.t('journal_p2'), style: body()),
                    const SizedBox(height: 28),
                    _ChartBlock(
                      chartKey: const Key('journal-chart-energy'),
                      title: context.t('journal_chart2_title'),
                      caption: context.t('journal_chart2_caption'),
                      titleStyle: chartTitle(),
                      captionStyle: caption(),
                      child: const TGJournalEnergyBars(),
                    ),
                    const SizedBox(height: 28),
                    Text(context.t('journal_p3'), style: body()),
                    const SizedBox(height: 28),
                    _ChartBlock(
                      chartKey: const Key('journal-chart-roi'),
                      title: context.t('journal_chart3_title'),
                      caption: context.t('journal_chart3_caption'),
                      titleStyle: chartTitle(),
                      captionStyle: caption(),
                      child: const TGJournalRoiPanel(),
                    ),
                    const SizedBox(height: 32),
                    Text(context.t('journal_close'), style: body()),
                    const SizedBox(height: 20),
                    Text(context.t('journal_source'), style: caption()),
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

class _ChartBlock extends StatelessWidget {
  const _ChartBlock({
    required this.chartKey,
    required this.title,
    required this.caption,
    required this.titleStyle,
    required this.captionStyle,
    required this.child,
  });

  final Key chartKey;
  final String title;
  final String caption;
  final TextStyle titleStyle;
  final TextStyle captionStyle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: chartKey,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: TGColors.surface,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: TGColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: titleStyle),
          const SizedBox(height: 6),
          Text(caption, style: captionStyle),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
