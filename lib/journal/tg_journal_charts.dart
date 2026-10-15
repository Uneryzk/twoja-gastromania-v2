import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';

/// Fixed industry mix used by the B2B journal charts.
abstract final class TGJournalMetrics {
  static const double capex = 0.42;
  static const double opexEnergy = 0.36;
  static const double opexService = 0.22;
  static const double aClassSaving = 0.32;
  static const int usedPaybackMonths = 14;
  static const int newPaybackMonths = 36;

  static int get monthsSaved => newPaybackMonths - usedPaybackMonths;
  static int get fasterPct => ((monthsSaved / newPaybackMonths) * 100).round();
}

TextStyle _label(Color color, {double size = 13, FontWeight weight = FontWeight.w500}) =>
    GoogleFonts.inter(
      color: color,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 0.25,
      height: 1.35,
    );

TextStyle _figure(Color color, {double size = 28}) => GoogleFonts.interTight(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.40,
      height: 1.1,
    );

/// Horizontal CapEx / OpEx mix. Segments are selectable.
class TGJournalCapexBar extends StatefulWidget {
  const TGJournalCapexBar({super.key});

  @override
  State<TGJournalCapexBar> createState() => _TGJournalCapexBarState();
}

class _TGJournalCapexBarState extends State<TGJournalCapexBar> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final segments = [
      (key: 'journal_seg_capex', share: TGJournalMetrics.capex, color: TGColors.cta, semantics: context.t('journal_seg_capex')),
      (key: 'journal_seg_energy', share: TGJournalMetrics.opexEnergy, color: const Color(0xFF7DCFC0), semantics: context.t('journal_seg_energy')),
      (key: 'journal_seg_service', share: TGJournalMetrics.opexService, color: const Color(0xFF8A9399), semantics: context.t('journal_seg_service')),
    ];

    return Semantics(
      container: true,
      label: context.t('journal_chart1_a11y'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TGRadius.pill),
              child: Row(
                children: [
                  for (var i = 0; i < segments.length; i++)
                    Expanded(
                      flex: (segments[i].share * 1000).round(),
                      child: Semantics(
                        button: true,
                        selected: _selected == i,
                        label: '${segments[i].semantics}, ${(segments[i].share * 100).round()}%',
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => setState(() => _selected = _selected == i ? null : i),
                            child: AnimatedContainer(
                              duration: reduce ? Duration.zero : TGMotion.layoutSwitch,
                              color: _selected == null || _selected == i
                                  ? segments[i].color
                                  : segments[i].color.withValues(alpha: 0.38),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              for (var i = 0; i < segments.length; i++)
                _LegendDot(
                  key: Key('journal-legend-${segments[i].key}'),
                  color: segments[i].color,
                  label: '${context.t(segments[i].key)}  ${(segments[i].share * 100).round()}%',
                  active: _selected == null || _selected == i,
                  onTap: () => setState(() => _selected = _selected == i ? null : i),
                ),
            ],
          ),
          AnimatedSwitcher(
            duration: reduce ? Duration.zero : TGMotion.fade,
            child: _selected == null
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey(_selected),
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      context.t('journal_chart1_focus', {
                        'name': context.t(segments[_selected!].key),
                        'pct': '${(segments[_selected!].share * 100).round()}',
                      }),
                      style: _label(theme.secondaryText),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Conventional vs A-class energy draw. A-class is 32% lower.
class TGJournalEnergyBars extends StatelessWidget {
  const TGJournalEnergyBars({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    const aClass = 1 - TGJournalMetrics.aClassSaving;
    return Semantics(
      container: true,
      label: context.t('journal_chart2_a11y', {'pct': '${(TGJournalMetrics.aClassSaving * 100).round()}'}),
      child: Column(
        children: [
          _CompareRow(
            label: context.t('journal_energy_standard'),
            fraction: 1,
            color: const Color(0xFF5C646A),
            value: '100%',
          ),
          const SizedBox(height: 12),
          _CompareRow(
            label: context.t('journal_energy_aclass'),
            fraction: aClass,
            color: TGColors.cta,
            value: '${(aClass * 100).round()}%',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: TGColors.cta.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(TGRadius.input),
              border: Border.all(color: TGColors.cta.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Text(
                  '−${(TGJournalMetrics.aClassSaving * 100).round()}%',
                  style: _figure(TGColors.cta, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.t('journal_energy_save_note'),
                    style: _label(theme.primaryText, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Used / transfer payback vs new kit, with a downward trend chip.
class TGJournalRoiPanel extends StatelessWidget {
  const TGJournalRoiPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      container: true,
      label: context.t('journal_chart3_a11y', {
        'used': '${TGJournalMetrics.usedPaybackMonths}',
        'fresh': '${TGJournalMetrics.newPaybackMonths}',
      }),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: context.t('journal_roi_used'),
                  value: context.t('journal_roi_months', {'n': '${TGJournalMetrics.usedPaybackMonths}'}),
                  accent: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: context.t('journal_roi_new'),
                  value: context.t('journal_roi_months', {'n': '${TGJournalMetrics.newPaybackMonths}'}),
                  accent: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: TGColors.surfaceHover,
              borderRadius: BorderRadius.circular(TGRadius.input),
              border: Border.all(color: TGColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: TGColors.cta.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(TGRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.trending_down_rounded, size: 18, color: TGColors.cta),
                      const SizedBox(width: 6),
                      Text(
                        '−${TGJournalMetrics.fasterPct}%',
                        style: _label(TGColors.cta, size: 14, weight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.t('journal_roi_trend', {'n': '${TGJournalMetrics.monthsSaved}'}),
                    style: _label(theme.primaryText, size: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.fraction,
    required this.color,
    required this.value,
  });

  final String label;
  final double fraction;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: _label(theme.secondaryText))),
            Text(value, style: _label(theme.primaryText, weight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) {
            return Container(
              height: 10,
              width: c.maxWidth,
              decoration: BoxDecoration(
                color: TGColors.surfaceHover,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: reduce ? Duration.zero : const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                width: c.maxWidth * fraction,
                height: 10,
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

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: TGColors.surface,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: accent ? TGColors.cta.withValues(alpha: 0.45) : TGColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _label(theme.secondaryText, size: 12)),
          const SizedBox(height: 8),
          Text(value, style: _figure(accent ? TGColors.cta : theme.primaryText, size: 24)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    super.key,
    required this.color,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: active ? 1 : 0.45,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(label, style: _label(FlutterFlowTheme.of(context).primaryText, size: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
