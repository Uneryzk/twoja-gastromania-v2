import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/special_order/special_order_hub_widgets.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_top_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_jsonld.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

class SpecialOrderHubPage extends StatefulWidget {
  const SpecialOrderHubPage({super.key, this.initialQuery = const {}});

  static const routeName = 'SpecialOrder';
  static const routePath = '/special-order';

  final Map<String, String> initialQuery;

  @override
  State<SpecialOrderHubPage> createState() => _SpecialOrderHubPageState();
}

class _SpecialOrderHubPageState extends State<SpecialOrderHubPage> {
  final _scroll = ScrollController();
  final _mfgKey = GlobalKey();
  final _search = TextEditingController();
  final _selected = <int>{};
  Set<TGStoreSpecialty> _types = {};
  String? _region;
  bool _install = false;
  bool _hasProjects = false;
  bool _rated = false;
  TGSpecialSort _sort = TGSpecialSort.recommended;
  int _page = 1;
  bool _loading = true;
  bool _statsPlayed = false;
  bool _gridFade = true;
  Timer? _loadTimer;
  Timer? _filterTimer;

  static const _perPage = 12;

  @override
  void initState() {
    super.initState();
    TGSpecialOrderService.instance.ensureSeeded();
    TGAnalytics.track('so_hub_view', {});
    _applyQuery(widget.initialQuery);
    _loadTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _loading = false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _statsPlayed = true);
      _publishFaqSeo();
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _filterTimer?.cancel();
    clearFaqPageSeo();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _publishFaqSeo() {
    if (!mounted) return;
    setFaqPageSeo([
      (q: context.t('ui_so_faq_q1'), a: context.t('ui_so_faq_a1')),
      (q: context.t('ui_so_faq_q2'), a: context.t('ui_so_faq_a2')),
      (q: context.t('ui_so_faq_q3'), a: context.t('ui_so_faq_a3')),
      (q: context.t('ui_so_faq_q4'), a: context.t('ui_so_faq_a4')),
      (q: context.t('ui_so_faq_q5'), a: context.t('ui_so_faq_a5')),
      (q: context.t('ui_so_faq_q6'), a: context.t('ui_so_faq_a6')),
    ]);
  }

  void _applyQuery(Map<String, String> qp) {
    final typeRaw = qp['type'] ?? '';
    _types = {
      for (final part in typeRaw.split(','))
        if (specialtyFromKey(part) != null) specialtyFromKey(part)!,
    };
    _region = (qp['region'] ?? '').isEmpty ? null : qp['region'];
    _install = qp['install'] == '1';
    _hasProjects = qp['projects'] == '1';
    _rated = qp['rated'] == '1';
    _sort = switch (qp['sort']) {
      'rating' => TGSpecialSort.highestRated,
      'projects' => TGSpecialSort.mostProjects,
      'response' => TGSpecialSort.fastestResponse,
      _ => TGSpecialSort.recommended,
    };
    _page = int.tryParse(qp['page'] ?? '1') ?? 1;
    _search.text = qp['q'] ?? '';
  }

  void _syncUrl() {
    final qp = <String, String>{};
    if (_search.text.trim().isNotEmpty) qp['q'] = _search.text.trim();
    if (_types.isNotEmpty) qp['type'] = _types.map(specialtyKey).join(',');
    if (_region != null) qp['region'] = _region!;
    if (_install) qp['install'] = '1';
    if (_hasProjects) qp['projects'] = '1';
    if (_rated) qp['rated'] = '1';
    if (_sort != TGSpecialSort.recommended) {
      qp['sort'] = switch (_sort) {
        TGSpecialSort.highestRated => 'rating',
        TGSpecialSort.mostProjects => 'projects',
        TGSpecialSort.fastestResponse => 'response',
        TGSpecialSort.recommended => 'recommended',
      };
    }
    if (_page > 1) qp['page'] = '$_page';
    TGAnalytics.track('so_filter_applied', qp);
    final uri = Uri(path: '/special-order', queryParameters: qp.isEmpty ? null : qp);
    context.go(uri.toString());
  }

  void _setFilters(VoidCallback fn) {
    setState(() {
      fn();
      _page = 1;
      _gridFade = false;
      _loading = true;
    });
    _syncUrl();
    _filterTimer?.cancel();
    _filterTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _gridFade = true;
      });
    });
  }

  void _scrollToMfg() {
    final ctx = _mfgKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: tgAnim(context, const Duration(milliseconds: 350)), curve: Curves.easeOutCubic);
  }

  void _toggleSelect(int publicId) {
    setState(() {
      if (_selected.contains(publicId)) {
        _selected.remove(publicId);
      } else if (_selected.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('ui_so_max_select'))));
        return;
      } else {
        _selected.add(publicId);
      }
    });
    TGAnalytics.track('so_manufacturer_select', {'sellerId': publicId, 'count': _selected.length});
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGSpecialOrderService.instance;
    final all = svc.manufacturers(
      search: _search.text,
      types: _types,
      region: _region,
      installationOnly: _install,
      hasProjects: _hasProjects,
      ratedFourPlus: _rated,
      sort: _sort,
    );
    final pages = (all.length / _perPage).ceil().clamp(1, 999);
    final page = _page.clamp(1, pages);
    final slice = all.skip((page - 1) * _perPage).take(_perPage).toList();
    final sponsored = svc.sponsoredManufacturer();
    final deepSeller = widget.initialQuery['seller'];
    final deepProfile = deepSeller == null || deepSeller.isEmpty ? null : TGSellerProfileService.instance.resolve(deepSeller);
    final deepInactive = deepProfile != null && !deepProfile.isSpecialOrderManufacturer;
    final w = MediaQuery.sizeOf(context).width;
    final phone = w < TGBreakpoints.phone;
    final desktop = w >= TGBreakpoints.desktop;
    final pad = phone ? 16.0 : (desktop ? 80.0 : 24.0);
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final showBar = kb == 0 && (phone || _selected.isNotEmpty);

    void openFilters() {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: TGColors.surface,
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SoFilterBar(
                  search: _search,
                  types: _types,
                  region: _region,
                  install: _install,
                  hasProjects: _hasProjects,
                  rated: _rated,
                  sort: _sort,
                  onSearch: (t) => _setFilters(() => _search.text = t),
                  onTypes: (t) => _setFilters(() => _types = t),
                  onRegion: (r) => _setFilters(() => _region = r),
                  onInstall: (v) => _setFilters(() => _install = v),
                  onHasProjects: (v) => _setFilters(() => _hasProjects = v),
                  onRated: (v) => _setFilters(() => _rated = v),
                  onSort: (s) => _setFilters(() => _sort = s),
                  onClear: () => _setFilters(() {
                    _search.clear();
                    _types = {};
                    _region = null;
                    _install = false;
                    _hasProjects = false;
                    _rated = false;
                    _sort = TGSpecialSort.recommended;
                  }),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TGButton(
                    onPressed: () => Navigator.pop(ctx),
                    label: context.t('ui_so_show_n_makers', {'n': '${all.length}'}),
                    height: 48,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return TGPageScaffold(
      body: Stack(
        children: [
          ListView(
            controller: _scroll,
            padding: EdgeInsets.only(bottom: showBar ? 88 : 0),
            children: [
              const TGTopNav(activeNavId: 'special_order'),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, phone ? 12 : 20, pad, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!phone)
                          TGBreadcrumb(
                            items: [
                              TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                              TGBreadcrumbItem(label: context.t('ui_special_order')),
                            ],
                          ),
                        if (deepInactive) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: theme.alternate, borderRadius: BorderRadius.circular(12), border: Border.all(color: TGColors.border)),
                            child: Text(context.t('ui_so_inactive_notice', {'name': deepProfile.name}), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                          ),
                        ],
                        SizedBox(height: phone ? 8 : 20),
                        SoHero(onRequest: () => context.go('/special-order/new'), onBrowse: _scrollToMfg),
                        const SizedBox(height: 28),
                        SoStatsRow(played: _statsPlayed, manufacturers: svc.manufacturerCount, projects: svc.projectCount),
                        const SizedBox(height: 36),
                        Text(context.t('ui_so_how_title'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 16),
                        const SoHowItWorks(),
                        const SizedBox(height: 36),
                        Text(context.t('ui_so_what_title'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 16),
                        SoWhatWeMake(
                          onType: (s) {
                            _setFilters(() => _types = {s});
                            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMfg());
                          },
                        ),
                        const SizedBox(height: 36),
                        KeyedSubtree(
                          key: _mfgKey,
                          child: Text(context.t('ui_so_manufacturers'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 14),
                        if (phone)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TGButton(
                              onPressed: openFilters,
                              label: context.t('ui_so_filters'),
                              variant: TGButtonVariant.outline,
                              height: 44,
                            ),
                          )
                        else
                          SoFilterBar(
                            search: _search,
                            types: _types,
                            region: _region,
                            install: _install,
                            hasProjects: _hasProjects,
                            rated: _rated,
                            sort: _sort,
                            onSearch: (t) => _setFilters(() => _search.text = t),
                            onTypes: (t) => _setFilters(() => _types = t),
                            onRegion: (r) => _setFilters(() => _region = r),
                            onInstall: (v) => _setFilters(() => _install = v),
                            onHasProjects: (v) => _setFilters(() => _hasProjects = v),
                            onRated: (v) => _setFilters(() => _rated = v),
                            onSort: (s) => _setFilters(() => _sort = s),
                            onClear: () => _setFilters(() {
                              _search.clear();
                              _types = {};
                              _region = null;
                              _install = false;
                              _hasProjects = false;
                              _rated = false;
                              _sort = TGSpecialSort.recommended;
                            }),
                          ),
                        const SizedBox(height: 20),
                        AnimatedOpacity(
                          opacity: _gridFade ? 1 : 0,
                          duration: tgAnim(context, const Duration(milliseconds: 150)),
                          child: _loading
                              ? const SoGridSkeleton()
                              : slice.isEmpty
                                  ? SoEmptyMfg(onTeam: () => context.go('/special-order/new'))
                                  : SoManufacturerGrid(
                                      items: slice,
                                      selected: _selected,
                                      sponsored: sponsored,
                                      onToggle: _toggleSelect,
                                    ),
                        ),
                        if (!_loading && all.length > _perPage) ...[
                          const SizedBox(height: 20),
                          SoPager(
                            page: page,
                            pages: pages,
                            onPage: (p) {
                              setState(() => _page = p);
                              _syncUrl();
                            },
                          ),
                        ],
                        const SizedBox(height: 40),
                        Text(context.t('ui_so_recent_projects'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 16),
                        SoRecentProjects(entries: svc.recentProjectEntries()),
                        const SizedBox(height: 40),
                        Text(context.t('ui_faq'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        const SoFaq(),
                        const SizedBox(height: 36),
                        const SoCtaBand(),
                        const SizedBox(height: 20),
                        const SoMakerBand(),
                      ],
                    ),
                  ),
                ),
              ),
              const TGFooter(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: showBar ? Offset.zero : const Offset(0, 1),
              duration: tgAnim(context, const Duration(milliseconds: 200)),
              curve: Curves.easeOutCubic,
              child: IgnorePointer(
                ignoring: !showBar,
                child: SoSelectionBar(
                  count: _selected.length,
                  alwaysVisible: phone,
                  onClear: () => setState(() => _selected.clear()),
                  onRequest: () {
                    if (_selected.isEmpty) {
                      context.go('/special-order/new');
                    } else {
                      context.go('/special-order/new?sellers=${_selected.join(',')}');
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
