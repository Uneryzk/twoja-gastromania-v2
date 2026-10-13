import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/duration_service.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_services/ad_slot_service.dart';

/// "20 Oct – 27 Oct" (end = last shown day, inclusive).
String tgBannerWindowLabel(BuildContext context, DateTime start, int durationDays) {
  final locale = Localizations.localeOf(context).languageCode;
  final fmt = DateFormat('d MMM', locale);
  final last = DurationService.addDays(start, durationDays - 1);
  return '${fmt.format(start)} – ${fmt.format(last)}';
}

/// Day-seat calendar for hero banners: free / partly booked / full days,
/// selected window highlight, earliest free window suggestion, waitlist.
class TGBannerCalendar extends StatelessWidget {
  const TGBannerCalendar({
    super.key,
    required this.ownerId,
    required this.durationDays,
    required this.selectedStart,
    required this.onSelect,
  });

  final String ownerId;
  final int durationDays;
  final DateTime? selectedStart;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final ads = AdSlotService.instance;
    final locale = Localizations.localeOf(context).languageCode;
    final days = ads.calendar(ignoreHoldOf: ownerId);
    final first = days.first.day;
    final lead = (first.weekday - DateTime.monday) % 7;
    final sel = selectedStart == null ? null : AdSlotService.dayOf(selectedStart!);
    final selEnd = sel == null ? null : DurationService.addDays(sel, durationDays);
    final selectionFree = sel != null && ads.windowFree(sel, durationDays, ignoreHoldOf: ownerId);
    final next = ads.nextAvailableStart(durationDays, from: sel, ignoreHoldOf: ownerId) ??
        ads.nextAvailableStart(durationDays, ignoreHoldOf: ownerId);
    final horizonFull = next == null;
    final weekdayFmt = DateFormat('EEEEE', locale);
    final monthFmt = DateFormat('LLLL yyyy', locale);
    final longFmt = DateFormat('d MMMM', locale);

    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (final d in days)
        _DayCell(
          day: d,
          inSelection: sel != null && !d.day.isBefore(sel) && d.day.isBefore(selEnd!),
          isStart: sel != null && d.day == sel,
          semanticsLabel: d.isFull
              ? context.t('ui_banner_day_full_sem', {'date': longFmt.format(d.day)})
              : context.t('ui_banner_day_free_sem', {
                  'date': longFmt.format(d.day),
                  'n': '${d.free}',
                  'cap': '${d.capacity}',
                }),
          onTap: d.isFull ? null : () => onSelect(d.day),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            '${monthFmt.format(first)} – ${monthFmt.format(days.last.day)}',
            style: theme.titleSmall.override(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdayFmt.format(DateTime(2024, 1, 1 + i)),
                      style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 1,
          children: cells,
        ),
        const SizedBox(height: 10),
        const _Legend(),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: _StatusLine(
            selection: sel,
            selectionFree: selectionFree,
            next: next,
            horizonFull: horizonFull,
            durationDays: durationDays,
            ownerId: ownerId,
            onUseNext: next == null ? null : () => onSelect(next),
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inSelection,
    required this.isStart,
    required this.semanticsLabel,
    required this.onTap,
  });

  final TGAdDay day;
  final bool inSelection;
  final bool isStart;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final full = day.isFull;
    final conflict = inSelection && full;
    final Color bg;
    final Color fg;
    if (conflict) {
      bg = TGColors.error.withValues(alpha: 0.12);
      fg = TGColors.error;
    } else if (inSelection) {
      bg = theme.primary;
      fg = TGColors.onCta;
    } else if (full) {
      bg = theme.alternate.withValues(alpha: 0.6);
      fg = theme.secondaryText;
    } else {
      bg = TGColors.surface;
      fg = theme.primaryText;
    }
    return Semantics(
      button: !full,
      enabled: !full,
      selected: inSelection,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: conflict ? TGColors.error : (isStart ? theme.primaryText : TGColors.border),
            width: conflict || isStart ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day.day}',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    decoration: full && !inSelection ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < day.capacity; i++)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < day.taken ? fg.withValues(alpha: 0.85) : fg.withValues(alpha: 0.2),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget item(Color c, String label, {Color? border}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: border ?? TGColors.border),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: theme.bodySmall),
          ],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        item(TGColors.surface, context.t('ui_banner_legend_free')),
        item(theme.alternate.withValues(alpha: 0.6), context.t('ui_banner_legend_full')),
        item(theme.primary, context.t('ui_banner_legend_selected'), border: theme.primary),
      ],
    );
  }
}

class _StatusLine extends StatefulWidget {
  const _StatusLine({
    required this.selection,
    required this.selectionFree,
    required this.next,
    required this.horizonFull,
    required this.durationDays,
    required this.ownerId,
    required this.onUseNext,
  });

  final DateTime? selection;
  final bool selectionFree;
  final DateTime? next;
  final bool horizonFull;
  final int durationDays;
  final String ownerId;
  final VoidCallback? onUseNext;

  @override
  State<_StatusLine> createState() => _StatusLineState();
}

class _StatusLineState extends State<_StatusLine> {
  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final ads = AdSlotService.instance;
    if (widget.horizonFull) {
      final joined = ads.isOnWaitlist(widget.ownerId);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('ui_banner_horizon_full', {'n': '${ads.pricing.waitlistHorizonDays}'}),
            style: theme.bodyMedium.override(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TGButton(
            onPressed: joined
                ? null
                : () {
                    ads.joinWaitlist(widget.ownerId, widget.durationDays);
                    setState(() {});
                  },
            label: joined ? context.t('ui_banner_waitlist_joined') : context.t('ui_banner_notify_me'),
            variant: TGButtonVariant.outline,
            height: 44,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          ),
        ],
      );
    }
    if (widget.selection != null && widget.selectionFree) {
      return Text(
        context.t('ui_banner_selected_window', {'window': tgBannerWindowLabel(context, widget.selection!, widget.durationDays)}),
        style: theme.bodyMedium.override(fontWeight: FontWeight.w800),
      );
    }
    final nextLabel = context.t('ui_banner_next_available', {
      'window': tgBannerWindowLabel(context, widget.next!, widget.durationDays),
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selection != null)
          Text(context.t('ui_banner_selection_full'), style: theme.bodySmall.override(color: TGColors.error, fontWeight: FontWeight.w700)),
        Text(nextLabel, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        TGButton(
          onPressed: widget.onUseNext,
          label: context.t('ui_banner_use_dates'),
          variant: TGButtonVariant.outline,
          height: 40,
          borderRadius: BorderRadius.circular(TGRadius.pill),
        ),
      ],
    );
  }
}
