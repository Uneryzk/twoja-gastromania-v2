import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/dash2_widgets.dart';
import 'package:twoja_gastromania/dashboard/dashboard_shell.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_listing_stats.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/listing_stats_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

/// One row of the insights table (equipment or restaurant listing).
class InsightsListing {
  const InsightsListing({
    required this.id,
    required this.key,
    required this.title,
    required this.listingNo,
    required this.liveSince,
    required this.promotion,
    required this.restaurant,
  });

  final String id;
  final String key;
  final String title;
  final String? listingNo;
  final DateTime? liveSince;
  final Promotion? promotion;
  final bool restaurant;

  static List<InsightsListing> forAccount(FakeAuthState auth) => [
        for (final p in auth.ownedListings)
          if (p.publishedAt != null && p.status != TGListingStatus.draft && p.status != TGListingStatus.paymentPending)
            InsightsListing(
              id: p.id,
              key: TGListingStatsService.keyOfProduct(p),
              title: p.title,
              listingNo: p.listingNo,
              liveSince: p.publishedAt,
              promotion: PromotionService.instance.effectiveListingPromo(p),
              restaurant: false,
            ),
        for (final r in RestaurantService.instance.ownedBy(auth.userId))
          if (r.publishedAt != null && r.status != RestaurantListingStatus.draft)
            InsightsListing(
              id: r.id,
              key: TGListingStatsService.keyOfRestaurant(r),
              title: r.title,
              listingNo: r.listingNo,
              liveSince: r.publishedAt,
              promotion: PromotionService.instance.effectiveRestaurantPromo(r),
              restaurant: true,
            ),
      ];
}

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key, this.period, this.listingId});

  static const routeName = 'DashboardInsights';
  static const routePath = '/dashboard/insights';

  final int? period;
  final String? listingId;

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  late int _days = TGListingStatsService.periods.contains(widget.period) ? widget.period! : 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TGAnalytics.track('insights_view', {'source': 'page', 'period': _days});
      _openFromUrl();
    });
  }

  @override
  void didUpdateWidget(InsightsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period && TGListingStatsService.periods.contains(widget.period)) _days = widget.period!;
    if (widget.listingId != oldWidget.listingId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFromUrl();
      });
    }
  }

  void _openFromUrl() {
    final id = widget.listingId;
    if (id == null || id.isEmpty) return;
    final row = InsightsListing.forAccount(context.read<FakeAuthState>()).where((l) => l.id == id).firstOrNull;
    if (row != null) _open(row);
  }

  void _open(InsightsListing l) {
    showListingInsights(
      context,
      listingKey: l.key,
      title: l.title,
      listingNo: l.listingNo,
      liveSince: l.liveSince,
      promotion: l.promotion,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      current: 'insights',
      child: ListenableBuilder(
        listenable: TGListingStatsService.instance,
        builder: (context, _) {
          final theme = FlutterFlowTheme.of(context);
          final auth = context.watch<FakeAuthState>();
          final stats = TGListingStatsService.instance;
          final rows = InsightsListing.forAccount(auth);
          final enough = rows.any((l) => stats.hasEnoughData(l.key, days: _days, liveSince: l.liveSince));
          final totals = stats.totalsFor(rows.map((l) => l.key), days: _days);
          final promoted = rows.where((l) => l.promotion != null).toList();
          final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
          return Column(
            key: const Key('insights-page'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(context.t('dash_insights_title'), style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 4),
              Text(context.t('dash_insights_sub'), style: theme.bodySmall.override(color: theme.secondaryText)),
              const SizedBox(height: 14),
              DashPeriodSwitch(
                value: _days,
                onChanged: (d) {
                  TGAnalytics.track('insights_view', {'source': 'period', 'period': d});
                  setState(() => _days = d);
                },
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                Text(context.t('dash_insights_empty'), key: const Key('insights-empty'), style: theme.bodyMedium)
              else ...[
                if (!enough)
                  const DashNotEnoughData()
                else
                  Wrap(
                    key: const Key('insights-totals'),
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final k in ListingStatKind.values) _TotalTile(kind: k, value: totals.of(k), days: _days),
                    ],
                  ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(context.t('dash_insights_per_listing'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 8),
                if (phone)
                  for (final l in rows) _PhoneRow(listing: l, days: _days, onOpen: () => _open(l))
                else
                  _InsightsTable(rows: rows, days: _days, onOpen: _open),
                if (promoted.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  for (final l in promoted) ...[
                    Text(l.title, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    PromotionComparisonCard(listingKey: l.key, promotion: l.promotion!),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

String _metricKey(ListingStatKind k) => switch (k) {
      ListingStatKind.view => 'dash_m_views',
      ListingStatKind.callTap => 'dash_m_calls',
      ListingStatKind.message => 'dash_m_messages',
      ListingStatKind.favorite => 'dash_m_favorites',
    };

class _TotalTile extends StatelessWidget {
  const _TotalTile({required this.kind, required this.value, required this.days});
  final ListingStatKind kind;
  final int value;
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      container: true,
      label: '${context.t(_metricKey(kind))}: $value, ${context.t('dash_period_n', {'n': '$days'})}',
      excludeSemantics: true,
      child: Container(
        key: Key('insights-total-${kind.name}'),
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TGColors.surface,
          border: Border.all(color: TGColors.border),
          borderRadius: BorderRadius.circular(TGRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.t(_metricKey(kind)), style: theme.bodySmall.override(color: theme.secondaryText)),
            const SizedBox(height: 4),
            Text('$value', style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _InsightsTable extends StatelessWidget {
  const _InsightsTable({required this.rows, required this.days, required this.onOpen});
  final List<InsightsListing> rows;
  final int days;
  final ValueChanged<InsightsListing> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final stats = TGListingStatsService.instance;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: TGColors.border), borderRadius: BorderRadius.circular(TGRadius.card)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Table(
        key: const Key('insights-table'),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: const {0: FlexColumnWidth(3), 5: IntrinsicColumnWidth()},
        children: [
          TableRow(children: [
            DashTh(context.t('dash_col_listing')),
            for (final k in ListingStatKind.values) DashTh(context.t(_metricKey(k))),
            const SizedBox.shrink(),
          ]),
          for (final l in rows)
            () {
              final t = stats.totals(l.key, days: days);
              final enough = stats.hasEnoughData(l.key, days: days, liveSince: l.liveSince);
              return TableRow(
                key: ValueKey('insights-row-${l.id}'),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: TGColors.border))),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Semantics(
                      header: true,
                      hint: 'row header',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                          Text(
                            [
                              context.t(l.restaurant ? 'dash_type_restaurant' : 'dash_type_equipment'),
                              if (l.listingNo != null) context.t('ui_listing_no_short', {'n': l.listingNo!}),
                              if (!enough) context.t('dash_not_enough_short'),
                            ].join(' · '),
                            style: theme.bodySmall.override(color: theme.secondaryText, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (final k in ListingStatKind.values)
                    Text('${t.of(k)}', style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                  TGFocusRing(
                    radius: 99,
                    child: IconButton(
                      key: Key('insights-open-${l.id}'),
                      tooltip: context.t('dash_insights_open'),
                      onPressed: () => onOpen(l),
                      icon: const Icon(Icons.insights_outlined, size: 20),
                    ),
                  ),
                ],
              );
            }(),
        ],
      ),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.listing, required this.days, required this.onOpen});
  final InsightsListing listing;
  final int days;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final t = TGListingStatsService.instance.totals(listing.key, days: days);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TGFocusRing(
        child: Material(
          color: TGColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TGRadius.card), side: const BorderSide(color: TGColors.border)),
          child: InkWell(
            key: Key('insights-open-${listing.id}'),
            borderRadius: BorderRadius.circular(TGRadius.card),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    [for (final k in ListingStatKind.values) '${context.t(_metricKey(k))} ${t.of(k)}'].join(' · '),
                    style: theme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
