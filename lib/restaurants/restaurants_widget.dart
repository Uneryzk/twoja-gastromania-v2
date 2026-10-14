import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/tg_components/tg_ranking_info.dart';
import 'package:twoja_gastromania/tg_components/tg_special_order_band.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/restaurants/restaurant_card.dart';
import 'package:twoja_gastromania/restaurants/restaurant_filters.dart';
import 'package:twoja_gastromania/restaurants/restaurant_l10n.dart';
import 'package:twoja_gastromania/restaurants/restaurant_logic.dart';
import 'package:twoja_gastromania/restaurants/restaurant_query.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_top_nav.dart';
import 'package:twoja_gastromania/tg_core/restaurant_config.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart' show TGProductCardLayout;
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

/// `/restaurants` — Restaurants for Sale hub (RESTO-1).
class RestaurantsPageWidget extends StatefulWidget {
  const RestaurantsPageWidget({super.key});

  static const String routeName = 'restaurants';
  static const String routePath = '/restaurants';

  @override
  State<RestaurantsPageWidget> createState() => _RestaurantsPageWidgetState();
}

class _RestaurantsPageWidgetState extends State<RestaurantsPageWidget> {
  static const double _maxOuter = 1440;
  static const double _maxContainer = 1280;
  static const double _sideW = 280;
  static const double _gap = 24;
  static const String _viewPrefsKey = '__tg_resto_view_pref__';

  final ScrollController _scroll = ScrollController();
  final int _promotedSeed = Random().nextInt(1 << 31);

  bool _loading = true;
  List<RestaurantListing> _all = const [];
  TGProductCardLayout _preferredView = TGProductCardLayout.grid;
  int _mobileShown = kRestoMobilePageSize;

  @override
  void initState() {
    super.initState();
    TGAnalytics.track('resto_hub_view');
    TGRevenueConfigService.instance.addListener(_onRevenueChanged);
    RestaurantConfigService.instance.addListener(_onConfigChanged);
    _load();
    _loadViewPref();
  }

  @override
  void dispose() {
    TGRevenueConfigService.instance.removeListener(_onRevenueChanged);
    RestaurantConfigService.instance.removeListener(_onConfigChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onRevenueChanged() {
    if (!mounted) return;
    setState(() => _all = RestaurantService.instance.publicListings);
  }

  void _onConfigChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _all = RestaurantService.instance.publicListings;
      _loading = false;
    });
  }

  Future<void> _loadViewPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_viewPrefsKey);
      if (raw == null || !mounted) return;
      setState(() => _preferredView = raw == 'list' ? TGProductCardLayout.list : TGProductCardLayout.grid);
    } catch (_) {}
  }

  Future<void> _persistView(TGProductCardLayout view) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_viewPrefsKey, view == TGProductCardLayout.list ? 'list' : 'grid');
    } catch (_) {}
  }

  RestaurantQueryState _queryFromUrl() {
    final qp = GoRouterState.of(context).uri.queryParameters;
    final parsed = RestaurantQueryState.fromQuery(qp);
    return qp.containsKey('view') ? parsed : parsed.copyWith(view: _preferredView);
  }

  void _apply(RestaurantQueryState next, {bool scrollTop = false}) {
    if (next.view != _preferredView) {
      setState(() => _preferredView = next.view);
      _persistView(next.view);
    }
    setState(() => _mobileShown = next.mobileShown);
    context.go(next.toLocation(path: RestaurantsPageWidget.routePath));
    if (scrollTop && _scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hideSidebar = width < TGBreakpoints.desktop;
    final twoCol = width < 1100;
    final phone = width < 480;
    final query = _queryFromUrl();
    final results = _loading
        ? RestaurantResults.empty
        : computeRestaurantResults(_all, query, promotedSeed: _promotedSeed);
    final cfg = RestaurantConfigService.instance.config;

    return TGPageScaffold(
      header: TGHeader(searchHint: context.t('ui_search_products')),
      body: SingleChildScrollView(
        controller: _scroll,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxOuter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TGTopNav(activeNavId: 'restaurants'),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxContainer),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: phone ? 16 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          TGBreadcrumb(items: [
                            TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                            TGBreadcrumbItem(label: context.t('ui_restaurants')),
                          ]),
                          const SizedBox(height: 8),
                          _hero(cfg, phone: phone),
                          if (hideSidebar) ...[
                            const SizedBox(height: 12),
                            _mobileControls(query, results.total),
                            if (query.activeFilterCount > 0) ...[
                              const SizedBox(height: 10),
                              RestaurantAppliedChips(query: query, onChanged: _apply),
                            ],
                            const SizedBox(height: 16),
                            _resultsBlock(query, results, phone: true, twoCol: false),
                          ] else ...[
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: _sideW,
                                  child: StickyHeader(
                                    child: RestaurantFiltersPanel(
                                      loading: _loading,
                                      all: _all,
                                      query: query,
                                      onChanged: _apply,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: _gap),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _toolbar(query, results.total),
                                      if (query.activeFilterCount > 0) ...[
                                        const SizedBox(height: 12),
                                        RestaurantAppliedChips(query: query, onChanged: _apply),
                                      ],
                                      const SizedBox(height: 16),
                                      _resultsBlock(query, results, phone: false, twoCol: twoCol),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 28),
                          _beforeYouTakeOver(),
                          const SizedBox(height: 20),
                          _specialOrderBand(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
                const TGFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(RestaurantConfig cfg, {required bool phone}) {
    final theme = FlutterFlowTheme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final stack = c.maxWidth < 820;
        final title = Text(
          context.t('ui_restaurants'),
          style: theme.displaySmall.override(
            fontSize: phone ? 28 : 40,
            fontWeight: FontWeight.w800,
            lineHeight: phone ? 1.15 : 48 / 40,
            letterSpacing: -0.5,
          ),
        );
        final sub = Text(
          context.t('ui_resto_hub_sub'),
          style: theme.bodyMedium.override(color: theme.secondaryText, fontSize: phone ? 14 : 16),
        );
        final cta = FilledButton(
          onPressed: () => context.go('/restaurants/new'),
          style: FilledButton.styleFrom(
            backgroundColor: TGColors.cta,
            foregroundColor: TGColors.onCta,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          child: Text(
            context.t('ui_resto_list_cta', {'n': '${cfg.freeDays}'}),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        );
        if (stack) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 8), sub, const SizedBox(height: 14), cta]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 8), sub])),
            const SizedBox(width: 16),
            cta,
          ],
        );
      },
    );
  }

  Widget _toolbar(RestaurantQueryState query, int total) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      children: [
        Semantics(
          liveRegion: true,
          child: Text(localizedResultsCount(context, total), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        ),
        const Spacer(),
        const TGRankingInfoLink(surface: 'restaurants', compact: true),
        const SizedBox(width: 4),
        DropdownButton<RestaurantSort>(
          value: query.sort,
          underline: const SizedBox.shrink(),
          items: RestaurantSort.values
              .map((s) => DropdownMenuItem(value: s, child: Text(sortLabel(s, t: (k) => context.t(k)))))
              .toList(),
          onChanged: (s) {
            if (s != null) _apply(query.copyWith(sort: s, page: 1));
          },
        ),
        const SizedBox(width: 8),
        ToggleButtons(
          isSelected: [query.view == TGProductCardLayout.grid, query.view == TGProductCardLayout.list],
          onPressed: (i) => _apply(query.copyWith(view: i == 0 ? TGProductCardLayout.grid : TGProductCardLayout.list)),
          borderRadius: BorderRadius.circular(10),
          children: const [
            Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.grid_view_rounded, size: 18)),
            Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.view_agenda_outlined, size: 18)),
          ],
        ),
      ],
    );
  }

  Widget _mobileControls(RestaurantQueryState query, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(localizedResultsCount(context, total), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        Material(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _openFiltersSheet(query),
                    icon: const Icon(Icons.tune),
                    label: Text(context.t('ui_filters_n', {'n': '${query.activeFilterCount}'})),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _openSortSheet(query),
                    icon: const Icon(Icons.sort),
                    label: Text(context.t('ui_sort')),
                  ),
                ),
                IconButton(
                  onPressed: () => _apply(query.copyWith(
                    view: query.view == TGProductCardLayout.grid ? TGProductCardLayout.list : TGProductCardLayout.grid,
                  )),
                  icon: Icon(query.view == TGProductCardLayout.grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded),
                ),
              ],
            ),
          ),
        ),
        const Align(alignment: AlignmentDirectional.centerEnd, child: TGRankingInfoLink(surface: 'restaurants', compact: true)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text('✔ ${context.t('ui_verified_only')}'),
                selected: query.verifiedOnly,
                onSelected: (v) => _apply(query.copyWith(verifiedOnly: v, page: 1)),
              ),
              const SizedBox(width: 6),
              ...RestaurantBusinessType.values.take(4).map((t) {
                final on = query.businessTypes.contains(t);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(restoLocalizedBusinessType(context, t)),
                    selected: on,
                    onSelected: (sel) {
                      final next = {...query.businessTypes};
                      sel ? next.add(t) : next.remove(t);
                      _apply(query.copyWith(businessTypes: next, page: 1));
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultsBlock(RestaurantQueryState query, RestaurantResults results, {required bool phone, required bool twoCol}) {
    final reduce = tgReduceMotion(context);
    if (_loading) return _skeleton(phone: phone);

    if (results.total == 0) {
      return _empty(query);
    }

    final ordered = results.allOrdered;
    final pageItems = phone
        ? ordered.take(_mobileShown).toList()
        : restoPaginate(ordered, query.page, perPage: kRestoPerPage);

    final cols = phone
        ? 1
        : (query.view == TGProductCardLayout.list ? 1 : (twoCol ? 2 : 3));
    final useCompact = phone && query.view != TGProductCardLayout.grid;

    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduce ? 0 : 150),
      child: Column(
        key: ValueKey('${query.toLocation()}-$_mobileShown'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (phone && results.promoted.isNotEmpty) ...[
            RestaurantCard(
              listing: results.promoted.first,
              variant: RestaurantCardVariant.grid,
              promotionTier: results.promoById[results.promoted.first.id],
              promotionId: results.promoIdByTarget[results.promoted.first.id],
            ),
            const SizedBox(height: 16),
          ],
          if (!phone && results.promoted.isNotEmpty && query.page == 1) ...[
            Text(context.t('ui_featured_promoted'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth - _gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: _gap,
                  runSpacing: _gap,
                  children: [
                    for (final r in results.promoted)
                      SizedBox(
                        width: cols == 1 ? c.maxWidth : w,
                        child: RestaurantCard(
                          listing: r,
                          variant: query.view == TGProductCardLayout.list ? RestaurantCardVariant.list : RestaurantCardVariant.grid,
                          promotionTier: results.promoById[r.id],
                          promotionId: results.promoIdByTarget[r.id],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
          ],
          LayoutBuilder(
            builder: (context, c) {
              final organic = phone
                  ? pageItems.where((r) => results.promoted.isEmpty || r.id != results.promoted.first.id).toList()
                  : (query.page == 1 ? results.organic : pageItems);
              final display = phone ? pageItems : (query.page == 1 ? results.organic : pageItems);
              final cards = phone ? display : organic;
              final w = cols == 1 ? c.maxWidth : (c.maxWidth - _gap * (cols - 1)) / cols;
              final children = <Widget>[];
              for (var i = 0; i < cards.length; i++) {
                final listing = cards[i];
                children.add(
                  SizedBox(
                    width: w,
                    child: RestaurantCard(
                      listing: listing,
                      variant: useCompact
                          ? RestaurantCardVariant.compact
                          : (query.view == TGProductCardLayout.list ? RestaurantCardVariant.list : RestaurantCardVariant.grid),
                      promotionTier: results.promoById[listing.id],
                      promotionId: results.promoIdByTarget[listing.id],
                    ),
                  ),
                );
                if (!phone && query.page == 1 && i + 1 == kRestoBannerAfterCard) {
                  children.add(SizedBox(width: c.maxWidth, child: _listBanner()));
                }
              }
              return Wrap(spacing: _gap, runSpacing: _gap, children: children);
            },
          ),
          const SizedBox(height: 24),
          if (phone) _mobileShowMore(query, results.total) else _pagination(query, results.total),
          const SizedBox(height: 32),
          const TGSpecialOrderBand(kind: TGNeedMoreBandKind.restaurants),
        ],
      ),
    );
  }

  Widget _mobileShowMore(RestaurantQueryState query, int total) {
    final shown = min(_mobileShown, total);
    return Column(
      children: [
        Text('$shown / $total', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (shown < total)
          OutlinedButton(
            onPressed: () => setState(() => _mobileShown = min(_mobileShown + kRestoMobilePageSize, total)),
            child: Text(context.t('ui_show_more')),
          ),
      ],
    );
  }

  Widget _pagination(RestaurantQueryState query, int total) {
    final pages = restoPageCount(total, kRestoPerPage);
    if (pages <= 1) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      children: [
        for (var p = 1; p <= pages; p++)
          ChoiceChip(
            label: Text('$p'),
            selected: query.page == p,
            onSelected: (_) => _apply(query.copyWith(page: p), scrollTop: true),
          ),
      ],
    );
  }

  Widget _listBanner() {
    final cfg = RestaurantConfigService.instance.config;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2F2F2F)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.t('ui_resto_selling_banner', {'n': '${cfg.freeDays}'}),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
          FilledButton(
            onPressed: () => context.go('/restaurants/new'),
            style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: TGColors.onCta),
            child: Text(context.t('ui_resto_list_cta', {'n': '${cfg.freeDays}'})),
          ),
        ],
      ),
    );
  }

  Widget _beforeYouTakeOver() {
    final theme = FlutterFlowTheme.of(context);
    final tips = [
      context.t('ui_before_tip_1'),
      context.t('ui_before_tip_2'),
      context.t('ui_before_tip_3'),
      context.t('ui_before_tip_4'),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2F2F2F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('ui_before_takeover'), style: theme.titleMedium.override(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final tip in tips) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(tip, style: theme.bodyMedium)),
              ],
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 8),
          Text(
            context.t('ui_before_disclaimer'),
            style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _specialOrderBand() {
    return Material(
      color: TGColors.cta.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => TGNav.specialOrder(context),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.t('ui_planning_refit'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(RestaurantQueryState query) {
    final cfg = RestaurantConfigService.instance.config;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(context.t('ui_no_listings_match'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (query.activeFilterCount > 0)
            TextButton(onPressed: () => _apply(query.clearedFilters()), child: Text(context.t('ui_remove_filters'))),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => context.go('/restaurants/new'),
            style: FilledButton.styleFrom(backgroundColor: TGColors.cta),
            child: Text(context.t('ui_resto_list_cta', {'n': '${cfg.freeDays}'})),
          ),
        ],
      ),
    );
  }

  Widget _skeleton({required bool phone}) {
    return Column(
      children: List.generate(
        6,
        (i) => Container(
          height: phone ? 140 : 280,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(16)),
          child: const _Shimmer(),
        ),
      ),
    );
  }

  Future<void> _openFiltersSheet(RestaurantQueryState current) async {
    final applied = await showModalBottomSheet<RestaurantQueryState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        var draft = current;
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scroll) {
            return StatefulBuilder(
              builder: (context, setSheet) {
                final n = countRestaurantResults(_all, draft);
                return Material(
                  color: const Color(0xFF1F1F1F),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          controller: scroll,
                          padding: const EdgeInsets.all(16),
                          children: [
                            RestaurantFiltersPanel(
                              all: _all,
                              query: draft,
                              onChanged: (q) => setSheet(() => draft = q),
                            ),
                          ],
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context, draft),
                              style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: TGColors.onCta),
                              child: Text(context.t('ui_show_n_results', {'n': '$n'})),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
    if (applied != null && mounted) _apply(applied);
  }

  Future<void> _openSortSheet(RestaurantQueryState current) async {
    final picked = await showModalBottomSheet<RestaurantSort>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: RestaurantSort.values
              .map((s) => ListTile(
                    title: Text(sortLabel(s, t: (k) => context.t(k))),
                    trailing: current.sort == s ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, s),
                  ))
              .toList(),
        ),
      ),
    );
    if (picked != null && mounted) _apply(current.copyWith(sort: picked, page: 1));
  }
}

/// Lightweight sticky wrapper (scroll parent moves; child sticks via Transform).
class StickyHeader extends StatelessWidget {
  const StickyHeader({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child; // Products page uses custom sticky; keep panel in flow for RESTO-1.
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer();
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (tgReduceMotion(context)) return const SizedBox.expand();
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1 + 2 * _c.value, 0),
            end: Alignment(1 + 2 * _c.value, 0),
            colors: const [Color(0xFF1F1F1F), Color(0xFF2A2A2A), Color(0xFF1F1F1F)],
          ),
        ),
      ),
    );
  }
}

