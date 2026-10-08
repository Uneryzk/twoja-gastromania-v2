import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/products/products_filters.dart';
import 'package:twoja_gastromania/products/products_logic.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/products/products_results.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_search_field.dart';
import 'package:twoja_gastromania/tg_components/tg_top_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

export 'package:twoja_gastromania/products/products_query.dart' show TGProductsQueryState, TGProductsSort, TGPriceFilterBasis;

/// `/products` – the marketplace search page.
///
/// * **Desktop (>= 1024 px):** left sticky sidebar with all filters, toolbar
///   (sort dropdown + grid/list switch) above the results.
/// * **Below 1024 px:** no sidebar; a pinned "Filters / Sort / layout" bar opens
///   the filters in a 90 %-height bottom sheet with a live result counter.
/// * Promoted listings stay pinned above the results for every sort order.
///
/// All filter state lives in the URL (`/products?type=rent&cat=cooking&...`), so
/// links from the home page, the footer and the browser back button all work.
class ProductsPageWidget extends StatefulWidget {
  const ProductsPageWidget({super.key});

  static const String routeName = 'products';
  static const String routePath = '/products';

  @override
  State<ProductsPageWidget> createState() => _ProductsPageWidgetState();
}

class _ProductsPageWidgetState extends State<ProductsPageWidget> {
  static const double _maxContainer = 1360;
  static const double _sideW = 280;
  static const double _gap = 24;
  static const double _stickyInset = 16;
  static const String _viewPrefsKey = '__tg_products_view_pref__';
  static const Duration _prefsTimeout = Duration(seconds: 2);

  final ScrollController _scroll = ScrollController();
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _regionKey = GlobalKey();
  final ValueNotifier<int> _stickyTick = ValueNotifier<int>(0);

  bool _loading = true;
  List<TGProduct> _all = const [];
  bool _showBackToTop = false;
  TGProductCardLayout _preferredView = TGProductCardLayout.grid;

  /// Rotation seed for promoted slots (stable during a session).
  final int _promotedSeed = Random().nextInt(1 << 31);

  String? _memoKey;
  TGProductResults _memoResults = TGProductResults.empty;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScroll);
    _load();
    _loadViewPreference();
  }

  @override
  void dispose() {
    _scroll.removeListener(_handleScroll);
    _scroll.dispose();
    _stickyTick.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- data

  Future<void> _load() async {
    try {
      final all = await TGProductService.instance.getAll();
      if (!mounted) return;
      setState(() {
        _all = all.where((p) => p.isPubliclyVisible).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Products load failed: $e');
      if (!mounted) return;
      setState(() {
        _all = const [];
        _loading = false;
      });
    }
  }

  Future<void> _loadViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      final raw = prefs.getString(_viewPrefsKey);
      if (raw == null || !mounted) return;
      setState(() => _preferredView = raw == 'list' ? TGProductCardLayout.list : TGProductCardLayout.grid);
    } catch (e) {
      debugPrint('Failed to load products view pref: $e');
    }
  }

  Future<void> _persistViewPreference(TGProductCardLayout view) async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(_prefsTimeout);
      await prefs.setString(_viewPrefsKey, view == TGProductCardLayout.list ? 'list' : 'grid').timeout(_prefsTimeout);
    } catch (e) {
      debugPrint('Failed to persist products view pref: $e');
    }
  }

  // ---------------------------------------------------------------- state (URL)

  /// The URL is the single source of truth. When it carries no explicit
  /// `view=`, the user's last chosen layout is used.
  TGProductsQueryState _queryFromUrl() {
    final qp = GoRouterState.of(context).uri.queryParameters;
    final parsed = TGProductsQueryState.fromQuery(qp);
    return qp.containsKey('view') ? parsed : parsed.copyWith(view: _preferredView);
  }

  void _apply(TGProductsQueryState next, {bool scrollToTop = false}) {
    if (next.view != _preferredView) {
      setState(() => _preferredView = next.view);
      _persistViewPreference(next.view);
    }
    context.go(next.toLocation(path: ProductsPageWidget.routePath));
    if (scrollToTop) _scrollToTop();
  }

  TGProductResults _results(TGProductsQueryState q) {
    if (_loading) return TGProductResults.empty;
    final key = '${identityHashCode(_all)}|${q.copyWith(page: 1, view: TGProductCardLayout.grid).toLocation()}';
    if (key != _memoKey) {
      _memoKey = key;
      _memoResults = computeResults(_all, q, promotedSeed: _promotedSeed);
    }
    return _memoResults;
  }

  // ---------------------------------------------------------------- scrolling

  void _handleScroll() {
    if (!_scroll.hasClients) return;
    final show = _scroll.offset > _scroll.position.viewportDimension * 2;
    if (show != _showBackToTop) setState(() => _showBackToTop = show);
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  // ---------------------------------------------------------------- sheets

  Future<void> _openFiltersSheet(TGProductsQueryState current) async {
    if (_loading) return;
    final applied = await showModalBottomSheet<TGProductsQueryState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => _FiltersSheet(all: _all, initial: current),
    );
    if (applied != null && mounted) _apply(applied);
  }

  Future<void> _openSortSheet(TGProductsQueryState current) async {
    final picked = await showModalBottomSheet<TGProductsSort>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => _SortSheet(selected: current.sort),
    );
    if (picked != null && mounted) _apply(current.copyWith(sort: picked, page: 1));
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < TGBreakpoints.desktop;
    final phone = width < TGBreakpoints.phone;
    final query = _queryFromUrl();
    final results = _results(query);

    return TGPageScaffold(
      header: TGHeader(
        searchHint: context.t('ui_search_products'),
        searchText: query.search ?? '',
        onSearch: (text) {
          final t = text.trim();
          _apply(query.copyWith(search: t, searchToNull: t.isEmpty, page: 1));
        },
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: compact
                ? _compactBody(query, results, phone: phone)
                : _desktopBody(query, results),
          ),
          if (_showBackToTop)
            Positioned(right: 16, bottom: 16, child: _BackToTopButton(onPressed: _scrollToTop)),
        ],
      ),
    );
  }

  // ---- shared bits

  Widget _breadcrumb() => TGBreadcrumb(
        items: [
          TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
          TGBreadcrumbItem(label: context.t('ui_products')),
        ],
      );

  Widget _title(FlutterFlowTheme theme, {required double size}) => Text(
        context.t('ui_products'),
        style: theme.displaySmall.override(fontSize: size, fontWeight: FontWeight.w900, letterSpacing: -0.5),
      );

  Widget _contained({required Widget child, double padding = 24}) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContainer),
          child: Padding(padding: EdgeInsets.symmetric(horizontal: padding), child: child),
        ),
      );

  // ---- desktop (>= 1024): sticky sidebar + toolbar

  Widget _desktopBody(TGProductsQueryState query, TGProductResults results) {
    final theme = FlutterFlowTheme.of(context);
    // Keep the sticky measurements fresh after layout (results / viewport changes).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _stickyTick.value++;
    });

    final panel = TGFiltersPanel(
      loading: _loading,
      allProducts: _all,
      query: query,
      onChanged: (q) => _apply(q),
    );

    return SingleChildScrollView(
      key: const ValueKey('products-scroll-desktop'),
      controller: _scroll,
      child: Column(
        key: _contentKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TGTopNav(activeType: query.listingType),
          _contained(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _breadcrumb(),
                const SizedBox(height: 8),
                _title(theme, size: 34),
                const SizedBox(height: 14),
              ],
            ),
          ),
          _contained(
            child: Row(
              key: _regionKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: _sideW, child: _sticky(panel)),
                const SizedBox(width: _gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TGResultsToolbar(total: results.total, loading: _loading, query: query, onChanged: _apply),
                      if (query.activeFilterCount > 0) ...[
                        const SizedBox(height: 14),
                        TGAppliedChips(query: query, onChanged: _apply),
                      ],
                      const SizedBox(height: 20),
                      TGResultsBody(
                        loading: _loading,
                        query: query,
                        results: results,
                        isPhone: false,
                        onChanged: (q) => _apply(q, scrollToTop: q.page != query.page),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 56),
          const TGFooter(),
        ],
      ),
    );
  }

  /// CSS-`position: sticky` for the sidebar: it rides along while the results
  /// scroll and stops at the bottom of the results region (so it never overlaps
  /// the footer). Positions are derived from layout geometry relative to the
  /// scroll content, which is independent of the scroll offset, and from the
  /// *current* offset, so there is no one-frame lag.
  Widget _sticky(Widget panel) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scroll, _stickyTick]),
      child: panel,
      builder: (context, child) {
        var dy = 0.0;
        var panelH = 560.0;
        final region = _regionKey.currentContext?.findRenderObject();
        final content = _contentKey.currentContext?.findRenderObject();
        if (region is RenderBox &&
            content is RenderBox &&
            region.attached &&
            content.attached &&
            region.hasSize &&
            _scroll.hasClients) {
          final regionTop = region.localToGlobal(Offset.zero, ancestor: content).dy;
          final regionH = region.size.height;
          final viewportH = _scroll.position.viewportDimension;
          panelH = min(max(360.0, viewportH - 2 * _stickyInset), regionH);
          dy = (_scroll.offset - regionTop + _stickyInset).clamp(0.0, max(0.0, regionH - panelH));
        }
        return Transform.translate(offset: Offset(0, dy), child: SizedBox(height: panelH, child: child));
      },
    );
  }

  // ---- compact (< 1024): pinned controls + bottom sheets

  Widget _compactBody(TGProductsQueryState query, TGProductResults results, {required bool phone}) {
    final theme = FlutterFlowTheme.of(context);
    final pad = phone ? 16.0 : 24.0;

    return CustomScrollView(
      key: const ValueKey('products-scroll-compact'),
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(child: TGTopNav(activeType: query.listingType)),
        SliverToBoxAdapter(
          child: _contained(
            padding: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _breadcrumb(),
                const SizedBox(height: 10),
                _title(theme, size: phone ? 28 : 34),
                const SizedBox(height: 6),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _loading ? context.t('ui_loading') : localizedResultsCount(context, results.total),
                    style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700),
                  ),
                ),
                if (phone) ...[
                  // The global header hides its search box on phones.
                  const SizedBox(height: 14),
                  TGSearchField(
                    hint: context.t('ui_search_products'),
                    initialText: query.search ?? '',
                    onSubmitted: (text) {
                      final t = text.trim();
                      _apply(query.copyWith(search: t, searchToNull: t.isEmpty, page: 1));
                    },
                  ),
                ],
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedBarDelegate(
            height: 68,
            child: ColoredBox(
              color: theme.primaryBackground,
              child: _contained(
                padding: pad,
                child: Align(
                  alignment: Alignment.center,
                  child: TGCompactControls(
                    filterCount: query.activeFilterCount,
                    sort: query.sort,
                    view: query.view,
                    singleViewButton: phone,
                    onFilters: () => _openFiltersSheet(query),
                    onSort: () => _openSortSheet(query),
                    onView: (v) => _apply(query.copyWith(view: v)),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _contained(
            padding: pad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (query.activeFilterCount > 0) ...[
                  TGAppliedChips(query: query, onChanged: _apply, scrollable: true),
                  const SizedBox(height: 14),
                ] else
                  const SizedBox(height: 6),
                TGResultsBody(
                  loading: _loading,
                  query: query,
                  results: results,
                  isPhone: phone,
                  // "Show more" on phones appends; keep the scroll position.
                  onChanged: (q) => _apply(q, scrollToTop: !phone && q.page != query.page),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 48)),
        const SliverToBoxAdapter(child: TGFooter()),
      ],
    );
  }
}

class _PinnedBarDelegate extends SliverPersistentHeaderDelegate {
  _PinnedBarDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = FlutterFlowTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        border: Border(bottom: BorderSide(color: overlapsContent ? theme.tertiary : Colors.transparent)),
      ),
      child: SizedBox.expand(child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedBarDelegate oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// Mobile / tablet bottom sheets
// ---------------------------------------------------------------------------

/// Filters in a bottom sheet that is exactly 90 % of the screen height. Edits
/// are applied to a draft; the button shows how many listings the draft matches
/// (live) and applies it on tap.
class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.all, required this.initial});

  final List<TGProduct> all;
  final TGProductsQueryState initial;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late TGProductsQueryState _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations;
    final count = countResults(widget.all, _draft);
    final countLabel = localizedResultsCount(context, count);
    final animDuration = reduceMotion ? Duration.zero : const Duration(milliseconds: 200);

    Widget animatedText(String text, {required TextStyle style}) => AnimatedSwitcher(
          duration: animDuration,
          transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, child: c)),
          child: Text(text, key: ValueKey(text), maxLines: 1, style: style),
        );

    return SizedBox(
      height: media.size.height * 0.9, // 90 % height bottom sheet
      child: Container(
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(TGRadius.modal)),
          border: Border.all(color: theme.tertiary),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: theme.tertiary, borderRadius: BorderRadius.circular(99))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 6),
              child: Row(
                children: [
                  Text(context.t('ui_filters'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                  const SizedBox(width: 12),
                  // Live result counter.
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(TGRadius.pill),
                      ),
                      child: animatedText(countLabel, style: theme.bodySmall.override(color: theme.primary, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: context.t('ui_close'),
                    icon: Icon(Icons.close, color: theme.secondaryText),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: theme.tertiary),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: TGFilterForm(
                  showHeader: false,
                  allProducts: widget.all,
                  query: _draft,
                  onChanged: (q) => setState(() => _draft = q),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + media.padding.bottom),
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                border: Border(top: BorderSide(color: theme.tertiary)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TGButton(
                      onPressed: _draft.activeFilterCount == 0 ? null : () => setState(() => _draft = _draft.clearedFilters()),
                      label: context.t('ui_clear'),
                      variant: TGButtonVariant.outline,
                      height: 48,
                      borderRadius: BorderRadius.circular(TGRadius.pill),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Semantics(
                      button: true,
                      label: context.t('ui_show_n', {'n': countLabel}),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(TGRadius.pill),
                        onTap: () => Navigator.of(context).pop(_draft.copyWith(page: 1)),
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: theme.primary, borderRadius: BorderRadius.circular(TGRadius.pill)),
                          child: animatedText(
                            context.t('ui_show_n', {'n': countLabel}),
                            style: theme.titleSmall.override(color: theme.primaryBtnText, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
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

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.selected});
  final TGProductsSort selected;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SafeArea(
      top: false,
      child: Material(
        color: theme.secondaryBackground,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(TGRadius.modal)),
          side: BorderSide(color: theme.tertiary),
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 42, height: 4, decoration: BoxDecoration(color: theme.tertiary, borderRadius: BorderRadius.circular(99))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    Text(context.t('ui_sort_by'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                    const Spacer(),
                    IconButton(
                      tooltip: context.t('ui_close'),
                      icon: Icon(Icons.close, color: theme.secondaryText),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              for (final s in TGProductsSort.values)
                ListTile(
                  onTap: () => Navigator.of(context).pop(s),
                  title: Text(
                    sortLabel(s, t: (k) => context.t(k)),
                    style: theme.bodyMedium.override(fontWeight: s == selected ? FontWeight.w900 : FontWeight.w600),
                  ),
                  trailing: s == selected ? Icon(Icons.check_rounded, color: theme.primary) : null,
                ),
              const SizedBox(height: 8),
            ],
        ),
      ),
    );
  }
}

class _BackToTopButton extends StatelessWidget {
  const _BackToTopButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      button: true,
      label: context.t('ui_back_to_top'),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: theme.primary,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(blurRadius: 18, offset: const Offset(0, 8), color: theme.primary.withValues(alpha: 0.28))],
          ),
          child: const Icon(Icons.keyboard_arrow_up_rounded, color: TGColors.onCta, size: 28),
        ),
      ),
    );
  }
}
