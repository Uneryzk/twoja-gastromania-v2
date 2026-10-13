import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/renew_sheet.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/restaurants/restaurant_renew_sheet.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/restaurant_config.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_listing_stats.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/listing_stats_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';

/// 2 px turquoise outline while keyboard focus is inside [child].
class TGFocusRing extends StatefulWidget {
  const TGFocusRing({super.key, required this.child, this.radius = TGRadius.card});
  final Widget child;
  final double radius;

  static const activeKey = ValueKey('tg-focus-ring-active');

  @override
  State<TGFocusRing> createState() => _TGFocusRingState();
}

class _TGFocusRingState extends State<TGFocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final show = _focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Container(
        key: show ? TGFocusRing.activeKey : null,
        foregroundDecoration: show
            ? BoxDecoration(
                border: Border.all(color: TGColors.cta, width: 2),
                borderRadius: BorderRadius.circular(widget.radius),
              )
            : null,
        child: widget.child,
      ),
    );
  }
}

String _metricLabel(BuildContext context, ListingStatKind kind) => context.t(switch (kind) {
      ListingStatKind.view => 'dash_m_views',
      ListingStatKind.callTap => 'dash_m_calls',
      ListingStatKind.message => 'dash_m_messages',
      ListingStatKind.favorite => 'dash_m_favorites',
    });

IconData _metricIcon(ListingStatKind kind) => switch (kind) {
      ListingStatKind.view => Icons.visibility_outlined,
      ListingStatKind.callTap => Icons.call_outlined,
      ListingStatKind.message => Icons.chat_bubble_outline,
      ListingStatKind.favorite => Icons.favorite_border,
    };

/// "Last 30 days" counters for one listing (real recorded data only).
class ListingMetricsStrip extends StatelessWidget {
  const ListingMetricsStrip({super.key, required this.listingKey});
  final String listingKey;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ListenableBuilder(
      listenable: TGListingStatsService.instance,
      builder: (context, _) {
        final t = TGListingStatsService.instance.totals(listingKey, days: 30);
        return Semantics(
          container: true,
          label: context.t('dash_metrics_sem', {
            'v': '${t.views}',
            'c': '${t.callTaps}',
            'm': '${t.messages}',
            'f': '${t.favorites}',
          }),
          excludeSemantics: true,
          child: Wrap(
            key: Key('listing-metrics-$listingKey'),
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.t('dash_last_30'), style: theme.bodySmall.override(fontSize: 11, color: theme.secondaryText)),
              for (final k in ListingStatKind.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_metricIcon(k), size: 13, color: theme.secondaryText),
                    const SizedBox(width: 3),
                    Text(
                      '${_metricLabel(context, k)} ${t.of(k)}',
                      style: theme.bodySmall.override(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

String _tierName(PromotionTier t) => switch (t) {
      PromotionTier.bold => 'Bold',
      PromotionTier.glow => 'Glow',
      PromotionTier.spotlight => 'Spotlight',
    };

/// Promote state of a listing: active tier and end date, or "Not promoted".
class ListingPromoStatus extends StatelessWidget {
  const ListingPromoStatus({super.key, this.product, this.restaurant});
  final TGProduct? product;
  final RestaurantListing? restaurant;

  @override
  Widget build(BuildContext context) {
    final promo = product != null
        ? PromotionService.instance.effectiveListingPromo(product!)
        : PromotionService.instance.effectiveRestaurantPromo(restaurant!);
    final locale = Localizations.localeOf(context).languageCode;
    final on = promo != null;
    final color = on ? TGColors.cta : TGColors.border;
    final label = on
        ? context.t('dash_promo_active', {'tier': _tierName(promo.tier), 'd': DateFormat('d MMM', locale).format(promo.endsAt)})
        : context.t('dash_promo_none');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(on ? Icons.bolt : Icons.bolt_outlined, size: 13, color: on ? TGColors.cta : Colors.white70),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: on ? TGColors.cta : Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple per-day bar chart; announced as one summary to screen readers.
class StatsBarChart extends StatelessWidget {
  const StatsBarChart({super.key, required this.series, required this.kind, this.height = 72});
  final List<ListingStatsDaily> series;
  final ListingStatKind kind;
  final double height;

  @override
  Widget build(BuildContext context) {
    final values = [for (final d in series) d.of(kind)];
    final top = values.fold<int>(0, max);
    final total = values.fold<int>(0, (a, b) => a + b);
    return Semantics(
      container: true,
      label: context.t('dash_chart_sem', {
        'metric': _metricLabel(context, kind),
        'n': '${series.length}',
        'total': '$total',
      }),
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final v in values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.5),
                  child: Container(
                    height: top == 0 ? 1 : max(1.0, height * v / top),
                    decoration: BoxDecoration(
                      color: v == 0 ? TGColors.border : TGColors.cta.withValues(alpha: 0.85),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the per-listing insights drawer: right-side panel on wide screens,
/// bottom sheet on phones.
Future<void> showListingInsights(
  BuildContext context, {
  required String listingKey,
  required String title,
  String? listingNo,
  DateTime? liveSince,
  Promotion? promotion,
}) {
  TGAnalytics.track('insights_view', {'source': 'drawer', 'listingKey': listingKey});
  final body = ListingInsightsPanel(
    listingKey: listingKey,
    title: title,
    listingNo: listingNo,
    liveSince: liveSince,
    promotion: promotion,
    showClose: true,
  );
  final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
  if (phone) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: TGColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => FractionallySizedBox(heightFactor: 0.9, child: body),
    );
  }
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.t('ui_close'),
    barrierColor: Colors.black54,
    transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
    pageBuilder: (ctx, _, __) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: TGColors.surface,
        child: SizedBox(width: 440, height: double.infinity, child: SafeArea(child: body)),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween(begin: const Offset(0.15, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: FadeTransition(opacity: anim, child: child),
    ),
  );
}

class ListingInsightsPanel extends StatefulWidget {
  const ListingInsightsPanel({
    super.key,
    required this.listingKey,
    required this.title,
    this.listingNo,
    this.liveSince,
    this.promotion,
    this.showClose = false,
  });

  final String listingKey;
  final String title;
  final String? listingNo;
  final DateTime? liveSince;
  final Promotion? promotion;
  final bool showClose;

  @override
  State<ListingInsightsPanel> createState() => _ListingInsightsPanelState();
}

class _ListingInsightsPanelState extends State<ListingInsightsPanel> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final stats = TGListingStatsService.instance;
    return ListenableBuilder(
      listenable: stats,
      builder: (context, _) {
        final enough = stats.hasEnoughData(widget.listingKey, days: _days, liveSince: widget.liveSince);
        final series = stats.daily(widget.listingKey, days: _days);
        final totals = stats.totals(widget.listingKey, days: _days);
        return ListView(
          key: const Key('insights-drawer'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                  ),
                ),
                if (widget.showClose)
                  IconButton(
                    key: const Key('insights-close'),
                    tooltip: context.t('ui_close'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            if (widget.listingNo != null)
              Text(context.t('ui_listing_no_short', {'n': widget.listingNo!}), style: theme.bodySmall.override(color: theme.secondaryText)),
            const SizedBox(height: 12),
            DashPeriodSwitch(value: _days, onChanged: (d) => setState(() => _days = d)),
            const SizedBox(height: 14),
            if (!enough)
              const DashNotEnoughData()
            else
              for (final k in ListingStatKind.values) ...[
                Row(
                  children: [
                    Icon(_metricIcon(k), size: 16, color: theme.secondaryText),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_metricLabel(context, k), style: theme.bodyMedium.override(fontWeight: FontWeight.w800))),
                    Text('${totals.of(k)}', style: theme.bodyMedium.override(fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 6),
                StatsBarChart(series: series, kind: k, height: 56),
                const SizedBox(height: 14),
              ],
            if (widget.promotion != null) ...[
              const SizedBox(height: 4),
              PromotionComparisonCard(listingKey: widget.listingKey, promotion: widget.promotion!),
            ],
          ],
        );
      },
    );
  }
}

class DashPeriodSwitch extends StatelessWidget {
  const DashPeriodSwitch({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final d in TGListingStatsService.periods)
          ChoiceChip(
            key: Key('insights-period-$d'),
            label: Text(context.t('dash_period_n', {'n': '$d'})),
            selected: value == d,
            onSelected: (_) => onChanged(d),
          ),
      ],
    );
  }
}

class DashNotEnoughData extends StatelessWidget {
  const DashNotEnoughData({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      key: const Key('insights-not-enough'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: TGColors.border), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, size: 18, color: theme.secondaryText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.t('dash_not_enough_data', {'n': '${TGListingStatsService.minDays}'}),
              style: theme.bodyMedium.override(color: theme.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-day averages during a promotion vs the 14 days before. Descriptive only.
class PromotionComparisonCard extends StatelessWidget {
  const PromotionComparisonCard({super.key, required this.listingKey, required this.promotion});
  final String listingKey;
  final Promotion promotion;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final c = TGListingStatsService.instance.compareWithPromotion(listingKey, promotion);
    String avg(ListingStatKind k, bool promoted) => c.perDay(k, promoted: promoted).toStringAsFixed(1);
    return Container(
      key: const Key('insights-promo-compare'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: TGColors.border), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(context.t('dash_promo_compare_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 8),
          if (!c.enoughData)
            const DashNotEnoughData()
          else
            Table(
              columnWidths: const {0: FlexColumnWidth(1.4), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
              children: [
                TableRow(children: [
                  const SizedBox.shrink(),
                  DashTh(context.t('dash_promo_compare_during', {'n': '${c.duringDays}'})),
                  DashTh(context.t('dash_promo_compare_before', {'n': '${c.beforeDays}'})),
                ]),
                for (final k in ListingStatKind.values)
                  TableRow(children: [
                    DashTh(_metricLabel(context, k), row: true),
                    _td(context, context.t('dash_per_day', {'n': avg(k, true)})),
                    _td(context, context.t('dash_per_day', {'n': avg(k, false)})),
                  ]),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            context.t('dash_promo_compare_note'),
            key: const Key('insights-promo-note'),
            style: theme.bodySmall.override(color: theme.secondaryText, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _td(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(text, style: FlutterFlowTheme.of(context).bodySmall.override(fontWeight: FontWeight.w700)),
      );
}

/// Table header cell. Flutter has no `<th scope>`; the column / row header
/// role is exposed with `Semantics(header: true)` and a scope hint.
class DashTh extends StatelessWidget {
  const DashTh(this.text, {super.key, this.row = false});
  final String text;
  final bool row;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      hint: row ? 'row header' : 'column header',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: FlutterFlowTheme.of(context).bodySmall.override(fontWeight: FontWeight.w900, color: FlutterFlowTheme.of(context).secondaryText),
        ),
      ),
    );
  }
}

/// Renew offers for an expired listing: renew only, renew + promote (shortest
/// and next promote duration). All prices come from the admin config.
class RenewOffersCard extends StatelessWidget {
  const RenewOffersCard({super.key, this.product, this.restaurant}) : assert(product != null || restaurant != null);
  final TGProduct? product;
  final RestaurantListing? restaurant;

  static const promoTier = PromotionTier.glow;

  /// `(promoteDays, totalPln)`; promoteDays 0 = renew only.
  static List<(int, int)> offersForProduct() {
    final cfg = PricingConfigService.instance.config;
    final base = cfg.listingFeePln(cfg.defaultListingDays);
    final days = (cfg.promotions.prices[promoTier]?.keys.toList() ?? <int>[])..sort();
    return [(0, base), for (final d in days.take(2)) (d, base + cfg.promoFeePln(promoTier, d))];
  }

  static List<(int, int)> offersForRestaurant() {
    final cfg = RestaurantConfigService.instance.config;
    return [(0, cfg.paidPricePln), for (final d in cfg.promote.durations.take(2)) (d, cfg.paidPricePln + cfg.promote.pricePln(d))];
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final offers = product != null ? offersForProduct() : offersForRestaurant();
    final id = product?.id ?? restaurant!.id;
    final days = product != null
        ? PricingConfigService.instance.config.defaultListingDays
        : RestaurantConfigService.instance.config.paidDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        key: Key('renew-offers-$id'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TGColors.surface,
          border: Border.all(color: TGColors.border),
          borderRadius: BorderRadius.circular(TGRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t('dash_renew_offers_title'), style: theme.bodyMedium.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < offers.length; i++)
                  TGFocusRing(
                    radius: 12,
                    child: Material(
                      color: i == 0 ? TGColors.cta.withValues(alpha: 0.10) : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: i == 0 ? TGColors.cta : TGColors.border),
                      ),
                      child: InkWell(
                        key: Key('renew-offer-$id-$i'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _open(context, offers[i].$1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offers[i].$1 == 0
                                    ? context.t('dash_offer_renew', {'d': '$days'})
                                    : context.t('dash_offer_renew_promo', {'d': '$days', 'p': '${offers[i].$1}'}),
                                style: theme.bodySmall.override(fontWeight: FontWeight.w700),
                              ),
                              Text('${offers[i].$2} PLN', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, int promoteDays) {
    TGAnalytics.track('listing_action', {
      'action': 'renew_offer',
      'listingId': product?.id ?? restaurant!.id,
      'kind': product != null ? 'equipment' : 'restaurant',
      'promoteDays': promoteDays,
    });
    if (product != null) {
      showRenewSheet(context, product!, initialTier: promoteDays == 0 ? null : promoTier, initialPromoDays: promoteDays == 0 ? null : promoteDays);
    } else {
      showRestaurantRenewSheet(context, restaurant!, initialPromoteDays: promoteDays);
    }
  }
}

/// Confirmation before spending a store slot on an existing listing.
Future<void> confirmMoveToStore(BuildContext context, TGProduct product) async {
  final auth = context.read<FakeAuthState>();
  final locale = Localizations.localeOf(context).languageCode;
  final until = DateFormat('d MMM y', locale).format(auth.storeRenewsOn);
  TGAnalytics.track('listing_action', {'action': 'move_to_store_open', 'listingId': product.id});
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = FlutterFlowTheme.of(ctx);
      return AlertDialog(
        key: const Key('move-store-dialog'),
        backgroundColor: theme.secondaryBackground,
        title: Text(ctx.t('dash_move_title')),
        content: Text(ctx.t(
          product.source == TGListingSource.free ? 'dash_move_body_free' : 'dash_move_body',
          {
            'used': '${auth.storeSlotsUsed}',
            'limit': '${auth.storeActiveLimit}',
            'd': until,
          },
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          TGButton(
            key: const Key('move-store-confirm'),
            onPressed: auth.storeHasFreeSlot ? () => Navigator.pop(ctx, true) : null,
            label: ctx.t('dash_move_confirm'),
            height: 40,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          ),
        ],
      );
    },
  );
  if (ok != true || !context.mounted) return;
  final from = product.source.name;
  final err = auth.moveToStorePlan(product.id);
  if (err != null) {
    showTGToast(context, context.t(err));
    return;
  }
  TGAnalytics.track('move_to_store', {
    'listingId': product.id,
    'from': from,
    'used': auth.storeSlotsUsed,
    'limit': auth.storeActiveLimit,
  });
  TGAnalytics.track('listing_action', {'action': 'move_to_store', 'listingId': product.id});
  showTGToast(context, context.t('dash_move_done', {'d': until}));
}
