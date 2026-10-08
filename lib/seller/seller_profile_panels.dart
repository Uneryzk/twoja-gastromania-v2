import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/products/products_logic.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/products/products_results.dart' show TGSortDropdown, TGViewToggle;
import 'package:twoja_gastromania/seller/seller_profile_query.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_map_card.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_components/tg_search_field.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_contact.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:url_launcher/link.dart';

class StoreProductsPanel extends StatelessWidget {
  const StoreProductsPanel({
    super.key,
    required this.profile,
    required this.listings,
    required this.query,
    required this.onQuery,
    this.hideSeller = true,
  });

  final TGStoreProfile profile;
  final List<TGProduct> listings;
  final TGStoreQuery query;
  final ValueChanged<TGStoreQuery> onQuery;
  final bool hideSeller;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final q = query.search?.trim().toLowerCase();
    var filtered = listings.where((p) {
      if (query.category != null && p.category != query.category) return false;
      if (query.conditions.isNotEmpty && !query.conditions.contains(p.condition)) return false;
      if (q != null && q.isNotEmpty) {
        final hay = '${p.title} ${p.description ?? ''} ${p.extra['Brand'] ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    });
    final sorted = sortProducts(filtered, TGProductsQueryState(sort: query.sort));
    final featured = sorted.where((p) => p.isPromoted).take(3).toList();
    final organic = sorted.where((p) => !featured.any((f) => f.id == p.id)).toList();
    const perPage = 12;
    final pages = pageCount(organic.length, perPage);
    final page = query.page.clamp(1, pages);
    final visible = paginate(organic, page, perPage: perPage);
    final cats = <TGCategory, int>{};
    for (final p in listings) {
      cats[p.category] = (cats[p.category] ?? 0) + 1;
    }

    void apply(TGStoreQuery next, {bool filter = true}) {
      if (filter) TGAnalytics.track('store_filter_applied', {'seller': profile.publicId, 'q': next.search, 'cat': next.category?.name, 'sort': next.sort.name});
      onQuery(next);
    }

    if (listings.isEmpty) {
      return _EmptyStore(profile: profile);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TGSearchField(
                initialText: query.search ?? '',
                hint: context.t('ui_search_products'),
                height: 44,
                onSubmitted: (t) => apply(query.copyWith(search: t, searchToNull: t.trim().isEmpty, page: 1)),
              ),
            ),
            for (final e in cats.entries)
              _FilterChip(
                label: '${categoryLabel(e.key, t: (k) => context.t(k))} (${e.value})',
                selected: query.category == e.key,
                accent: true,
                onTap: () => apply(query.copyWith(category: e.key, categoryToNull: query.category == e.key, page: 1)),
              ),
            _FilterChip(
              label: conditionLabel(TGCondition.newItem, t: (k) => context.t(k)),
              selected: query.conditions.contains(TGCondition.newItem),
              onTap: () {
                final next = {...query.conditions};
                next.contains(TGCondition.newItem) ? next.remove(TGCondition.newItem) : next.add(TGCondition.newItem);
                apply(query.copyWith(conditions: next, page: 1));
              },
            ),
            _FilterChip(
              label: conditionLabel(TGCondition.used, t: (k) => context.t(k)),
              selected: query.conditions.contains(TGCondition.used),
              onTap: () {
                final next = {...query.conditions};
                next.contains(TGCondition.used) ? next.remove(TGCondition.used) : next.add(TGCondition.used);
                apply(query.copyWith(conditions: next, page: 1));
              },
            ),
            TGSortDropdown(
              value: const {TGProductsSort.recommended, TGProductsSort.newest, TGProductsSort.priceLowHigh, TGProductsSort.priceHighLow}.contains(query.sort) ? query.sort : TGProductsSort.recommended,
              onChanged: (s) => apply(query.copyWith(sort: s, page: 1)),
            ),
            TGViewToggle(value: query.view, onChanged: (v) => apply(query.copyWith(view: v), filter: false)),
          ],
        ),
        const SizedBox(height: 22),
        if (featured.isNotEmpty) ...[
          Text(context.t('ui_promoted_badge'), style: theme.titleMedium.override(fontWeight: FontWeight.w900, color: theme.secondary)),
          const SizedBox(height: 12),
          _StoreGrid(items: featured, layout: query.view, hideSeller: hideSeller),
          const SizedBox(height: 28),
        ],
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(context.t('ui_store_empty'), style: theme.bodyMedium.override(color: theme.secondaryText)),
          )
        else
          _StoreGrid(items: visible, layout: query.view, hideSeller: hideSeller),
        const SizedBox(height: 24),
        _Pages(current: page, total: pages, onPage: (p) => apply(query.copyWith(page: p), filter: false)),
      ],
    );
  }
}

class _EmptyStore extends StatelessWidget {
  const _EmptyStore({required this.profile});
  final TGStoreProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Text(context.t('ui_store_empty'), textAlign: TextAlign.center, style: theme.titleMedium.override(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              TGButton(
                onPressed: () => TGNav.verifiedSellers(context),
                label: context.t('ui_browse_similar'),
                variant: TGButtonVariant.outline,
                height: 44,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
              if (profile.showQuote)
                TGButton(
                  onPressed: () {
                    TGAnalytics.track('store_quote_click', {'seller': profile.publicId});
                    TGNav.storeQuote(context, profile.publicId);
                  },
                  label: context.t('ui_request_quote'),
                  height: 44,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoreGrid extends StatelessWidget {
  const _StoreGrid({required this.items, required this.layout, required this.hideSeller});
  final List<TGProduct> items;
  final TGProductCardLayout layout;
  final bool hideSeller;

  @override
  Widget build(BuildContext context) {
    if (layout == TGProductCardLayout.list) {
      return Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            TGProductCard(product: items[i], layout: TGProductCardLayout.list, showSeller: !hideSeller),
            if (i != items.length - 1) const SizedBox(height: 14),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final cols = storeGridColumnsFor(c.maxWidth);
        final cardW = (c.maxWidth - kStoreGridGutter * (cols - 1)) / cols;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          clipBehavior: Clip.none,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: kStoreGridGutter,
            mainAxisSpacing: kStoreGridGutter,
            mainAxisExtent: TGProductCard.gridExtent(cardW, MediaQuery.textScalerOf(context), showSeller: !hideSeller),
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => TGProductCard(product: items[i], showSeller: !hideSeller),
        );
      },
    );
  }
}

class _Pages extends StatelessWidget {
  const _Pages({required this.current, required this.total, required this.onPage});
  final int current;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);
    Widget btn(String label, {required bool active, VoidCallback? onTap}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TGRadius.input),
          child: Container(
            constraints: const BoxConstraints(minWidth: 42),
            height: 42,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active ? theme.primary : theme.secondaryBackground,
              borderRadius: BorderRadius.circular(TGRadius.input),
              border: Border.all(color: active ? theme.primary : theme.tertiary),
            ),
            child: Text(label, style: theme.bodySmall.override(color: active ? TGColors.onCta : theme.primaryText, fontWeight: FontWeight.w900)),
          ),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        for (var i = 1; i <= total; i++) btn('$i', active: i == current, onTap: () => onPage(i)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.accent = false});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final bg = selected ? (accent ? theme.secondary : theme.primary) : theme.secondaryBackground;
    final fg = selected ? (accent ? const Color(0xFF1A1A1A) : TGColors.onCta) : theme.primaryText;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(TGRadius.pill),
            border: Border.all(color: selected ? bg : theme.tertiary),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(label, style: theme.labelSmall.override(color: fg, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class StoreAboutPanel extends StatefulWidget {
  const StoreAboutPanel({super.key, required this.profile});
  final TGStoreProfile profile;

  @override
  State<StoreAboutPanel> createState() => _StoreAboutPanelState();
}

class _StoreAboutPanelState extends State<StoreAboutPanel> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final p = widget.profile;
    final showProjects = (p.plan == TGStorePlanKind.pro || p.plan == TGStorePlanKind.enterprise) && p.projects.isNotEmpty;
    final desc = p.description.trim();
    final clipped = desc.length > 2000 ? '${desc.substring(0, 2000)}…' : desc;

    return LayoutBuilder(
      builder: (context, c) {
        final stacked = c.maxWidth < 900;
        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (clipped.isNotEmpty) ...[
              Text(
                clipped,
                maxLines: _more ? 80 : 8,
                overflow: TextOverflow.ellipsis,
                style: theme.bodyMedium.override(color: theme.primaryText, lineHeight: 1.55),
              ),
              if (clipped.length > 280 || clipped.split('\n').length > 8)
                TextButton(
                  onPressed: () => setState(() => _more = !_more),
                  child: Text(_more ? context.t('ui_show_less') : context.t('ui_show_more')),
                ),
              const SizedBox(height: 20),
            ],
            Text(context.t('ui_what_we_offer'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in p.categories)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: theme.secondary.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(TGRadius.pill), border: Border.all(color: theme.secondary.withValues(alpha: 0.5))),
                    child: Text(categoryLabel(cat, t: (k) => context.t(k)), style: theme.labelSmall.override(color: theme.secondary, fontWeight: FontWeight.w800)),
                  ),
                for (final b in p.brands)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: theme.alternate, borderRadius: BorderRadius.circular(TGRadius.pill), border: Border.all(color: theme.tertiary)),
                    child: Text(b, style: theme.labelSmall.override(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (final s in p.services)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(_svcIcon(s), size: 18, color: theme.primary),
                    const SizedBox(width: 8),
                    Text(_svcLabel(context, s), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            if (showProjects) ...[
              const SizedBox(height: 24),
              Text(context.t('ui_references'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _ProjectGallery(projects: p.projects),
            ],
          ],
        );
        final right = _BusinessRail(profile: p);
        if (stacked) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 28), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 8, child: left),
            const SizedBox(width: 24),
            Expanded(flex: 4, child: right),
          ],
        );
      },
    );
  }
}

class _BusinessRail extends StatelessWidget {
  const _BusinessRail({required this.profile});
  final TGStoreProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final today = TGStoreHours.dayKey(warsawNow().weekday);
    final maps = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${profile.address ?? profile.city}, ${profile.voivodeship}')}');
    Widget card(String title, List<Widget> children) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: theme.secondaryBackground, borderRadius: BorderRadius.circular(TGRadius.card), border: Border.all(color: theme.tertiary)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...children,
          ]),
        );

    return Column(
      children: [
        card(context.t('ui_business_details'), [
          if (profile.legalName != null) Text(profile.legalName!, style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
          if (profile.nip != null) ...[
            const SizedBox(height: 6),
            Text('NIP ${profile.nip}', style: theme.bodyMedium),
            if (profile.nipVerifiedAt != null)
              Text(context.t('ui_verified_on', {'d': DateFormat('d MMM yyyy', 'en').format(profile.nipVerifiedAt!)}), style: theme.bodySmall.override(color: theme.success, fontWeight: FontWeight.w700)),
          ],
          if (profile.address != null) ...[const SizedBox(height: 8), Text(profile.address!, style: theme.bodySmall.override(color: theme.secondaryText))],
        ]),
        const SizedBox(height: 14),
        card(context.t('ui_opening_hours'), [
          for (final day in kStoreDayKeys)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(color: day == today ? theme.primary.withValues(alpha: 0.12) : null, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(child: Text(context.t('ui_day_$day'), style: theme.bodySmall.override(fontWeight: day == today ? FontWeight.w900 : FontWeight.w600))),
                  Text(profile.hours.of(day) == 'closed' ? context.t('ui_hours_closed') : profile.hours.of(day), style: theme.bodySmall.override(fontWeight: FontWeight.w800, color: profile.hours.of(day) == 'closed' ? theme.secondaryText : theme.primaryText)),
                ],
              ),
            ),
        ]),
        const SizedBox(height: 14),
        card(context.t('ui_location'), [
          TGMapCard(address: profile.address ?? '${profile.city}, ${profile.voivodeship}', mapsUri: maps, actionLabel: context.t('ui_get_directions')),
        ]),
        if (profile.website != null || !profile.social.isEmpty) ...[
          const SizedBox(height: 14),
          card(context.t('ui_links'), [
            if (profile.website != null)
              Link(
                uri: Uri.parse(profile.website!),
                target: LinkTarget.blank,
                builder: (context, follow) => InkWell(
                  onTap: follow,
                  child: Text(profile.website!, style: theme.bodyMedium.override(color: theme.primary, fontWeight: FontWeight.w700)),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (profile.social.facebook != null) _Social(Icons.facebook, profile.social.facebook!),
                if (profile.social.instagram != null) _Social(Icons.camera_alt_outlined, profile.social.instagram!),
                if (profile.social.linkedin != null) _Social(Icons.business_outlined, profile.social.linkedin!),
                if (profile.social.youtube != null) _Social(Icons.play_circle_outline, profile.social.youtube!),
              ],
            ),
          ]),
        ],
      ],
    );
  }
}

class _Social extends StatelessWidget {
  const _Social(this.icon, this.url);
  final IconData icon;
  final String url;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: () => openExternalUrl(context, Uri.parse(url)),
      icon: Icon(icon, size: 18),
    );
  }
}

class _ProjectGallery extends StatelessWidget {
  const _ProjectGallery({required this.projects});
  final List<TGStoreProject> projects;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 800 ? 3 : (c.maxWidth >= 520 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: projects.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 4 / 3.55,
          ),
          itemBuilder: (context, i) {
            final p = projects[i];
            return InkWell(
              onTap: () => showStoreProjectLightbox(context, projects, i),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.asset(p.photos.first, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: FlutterFlowTheme.of(context).bodyMedium.override(fontWeight: FontWeight.w800)),
                  Text('${p.city} · ${p.year}', style: FlutterFlowTheme.of(context).bodySmall.override(color: FlutterFlowTheme.of(context).secondaryText)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Future<void> showStoreProjectLightbox(BuildContext context, List<TGStoreProject> projects, int index) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.t('ui_close'),
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: tgAnim(context, const Duration(milliseconds: 220)),
    pageBuilder: (ctx, _, __) => _ProjectLightbox(projects: projects, index: index),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: curved, child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child));
    },
  );
}

class _ProjectLightbox extends StatefulWidget {
  const _ProjectLightbox({required this.projects, required this.index});
  final List<TGStoreProject> projects;
  final int index;

  @override
  State<_ProjectLightbox> createState() => _ProjectLightboxState();
}

class _ProjectLightboxState extends State<_ProjectLightbox> {
  late int _i = widget.index;
  late int _photo = 0;

  TGStoreProject get project => widget.projects[_i];
  List<String> get photos => project.photos.take(8).toList();

  void _shiftProject(int d) {
    setState(() {
      _i = (_i + d).clamp(0, widget.projects.length - 1);
      _photo = 0;
    });
  }

  void _shiftPhoto(int d) {
    if (photos.isEmpty) return;
    setState(() => _photo = (_photo + d + photos.length) % photos.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return FocusScope(
      autofocus: true,
      child: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.escape): const _CloseIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _LeftIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const _RightIntent(),
        },
        child: Actions(
          actions: {
            _CloseIntent: CallbackAction<_CloseIntent>(onInvoke: (_) {
              Navigator.of(context).pop();
              return null;
            }),
            _LeftIntent: CallbackAction<_LeftIntent>(onInvoke: (_) {
              _shiftPhoto(-1);
              return null;
            }),
            _RightIntent: CallbackAction<_RightIntent>(onInvoke: (_) {
              _shiftPhoto(1);
              return null;
            }),
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
              child: Material(
                color: theme.secondaryBackground,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('${project.title} · ${project.city} · ${project.year}', style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(photos[_photo], fit: BoxFit.contain),
                            ),
                            if (photos.length > 1) ...[
                              Align(alignment: Alignment.centerLeft, child: IconButton.filledTonal(onPressed: () => _shiftPhoto(-1), icon: const Icon(Icons.chevron_left))),
                              Align(alignment: Alignment.centerRight, child: IconButton.filledTonal(onPressed: () => _shiftPhoto(1), icon: const Icon(Icons.chevron_right))),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(project.description, style: theme.bodyMedium.override(color: theme.secondaryText, lineHeight: 1.45)),
                      if (widget.projects.length > 1)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(onPressed: _i > 0 ? () => _shiftProject(-1) : null, child: const Text('‹')),
                            Text('${_i + 1} / ${widget.projects.length}'),
                            TextButton(onPressed: _i < widget.projects.length - 1 ? () => _shiftProject(1) : null, child: const Text('›')),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}

class _LeftIntent extends Intent {
  const _LeftIntent();
}

class _RightIntent extends Intent {
  const _RightIntent();
}

IconData _svcIcon(TGStoreService s) => switch (s) {
      TGStoreService.delivery => Icons.local_shipping_outlined,
      TGStoreService.installation => Icons.build_outlined,
      TGStoreService.service => Icons.handyman_outlined,
      TGStoreService.leasing => Icons.account_balance_outlined,
      TGStoreService.fakturaVat => Icons.receipt_long_outlined,
      TGStoreService.warrantyService => Icons.verified_outlined,
    };

String _svcLabel(BuildContext context, TGStoreService s) => switch (s) {
      TGStoreService.delivery => context.t('ui_delivery'),
      TGStoreService.installation => context.t('ui_svc_installation'),
      TGStoreService.service => context.t('ui_svc_service'),
      TGStoreService.leasing => context.t('ui_svc_leasing'),
      TGStoreService.fakturaVat => context.t('ui_svc_vat'),
      TGStoreService.warrantyService => context.t('ui_svc_warranty'),
    };

class StoreReviewsPlaceholder extends StatelessWidget {
  const StoreReviewsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(child: Text(context.t('ui_coming_next'), style: FlutterFlowTheme.of(context).titleMedium.override(color: FlutterFlowTheme.of(context).secondaryText))),
    );
  }
}

// silence unused math import if analyzer complains about window helpers later
int storePageWindow(int current, int total) => math.max(1, current.clamp(1, total));
