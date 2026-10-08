import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/products/products_logic.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_components/tg_special_order_band.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// Minimum width of a grid card; the column count is derived from the width the
/// results area actually gets (not from the screen), so it is right with or
/// without the sidebar.
const double kTGMinCardWidth = 250;
const double kTGGridGutter = 20;

int gridColumnsFor(double width) {
  final cols = ((width + kTGGridGutter) / (kTGMinCardWidth + kTGGridGutter)).floor();
  return cols.clamp(1, 3);
}

// ---------------------------------------------------------------------------
// Toolbar controls
// ---------------------------------------------------------------------------

/// Sorting dropdown.
class TGSortDropdown extends StatelessWidget {
  const TGSortDropdown({super.key, required this.value, required this.onChanged});

  final TGProductsSort value;
  final ValueChanged<TGProductsSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      label: context.t('ui_sort_listings'),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(TGRadius.input),
          border: Border.all(color: theme.tertiary),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<TGProductsSort>(
            value: value,
            isDense: true,
            borderRadius: BorderRadius.circular(TGRadius.input),
            dropdownColor: theme.secondaryBackground,
            iconEnabledColor: theme.secondaryText,
            focusColor: Colors.transparent,
            style: theme.bodySmall.override(color: theme.primaryText, fontWeight: FontWeight.w800, fontSize: 13),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            items: [
              for (final s in TGProductsSort.values) DropdownMenuItem(value: s, child: Text(sortLabel(s, t: (k) => context.t(k)))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid / list switch.
class TGViewToggle extends StatelessWidget {
  const TGViewToggle({super.key, required this.value, required this.onChanged, this.single = false});

  final TGProductCardLayout value;
  final ValueChanged<TGProductCardLayout> onChanged;

  /// One button that flips between the two layouts (phones).
  final bool single;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    Widget btn({required IconData icon, required String label, required bool active, required VoidCallback onTap}) {
      return Semantics(
        button: true,
        selected: active,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(TGRadius.input),
            onTap: onTap,
            child: AnimatedContainer(
              duration: TGMotion.quick,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active ? theme.primary : theme.secondaryBackground,
                borderRadius: BorderRadius.circular(TGRadius.input),
                border: Border.all(color: active ? theme.primary : theme.tertiary),
              ),
              child: Icon(icon, size: 20, color: active ? theme.primaryBtnText : theme.primaryText),
            ),
          ),
        ),
      );
    }

    if (single) {
      final isList = value == TGProductCardLayout.list;
      return btn(
        icon: isList ? Icons.grid_view_rounded : Icons.view_list_rounded,
        label: isList ? context.t('ui_switch_grid') : context.t('ui_switch_list'),
        active: false,
        onTap: () => onChanged(isList ? TGProductCardLayout.grid : TGProductCardLayout.list),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(
          icon: Icons.grid_view_rounded,
          label: context.t('ui_grid_view'),
          active: value == TGProductCardLayout.grid,
          onTap: () => onChanged(TGProductCardLayout.grid),
        ),
        const SizedBox(width: 8),
        btn(
          icon: Icons.view_list_rounded,
          label: context.t('ui_list_view'),
          active: value == TGProductCardLayout.list,
          onTap: () => onChanged(TGProductCardLayout.list),
        ),
      ],
    );
  }
}

/// Top toolbar of the results area (desktop + tablets): live count, sort
/// dropdown and the grid/list switch.
class TGResultsToolbar extends StatelessWidget {
  const TGResultsToolbar({
    super.key,
    required this.total,
    required this.query,
    required this.onChanged,
    this.loading = false,
  });

  final int total;
  final bool loading;
  final TGProductsQueryState query;
  final ValueChanged<TGProductsQueryState> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              loading ? context.t('ui_loading') : localizedResultsCount(context, total),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.titleSmall.override(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(width: 12),
        TGSortDropdown(value: query.sort, onChanged: (s) => onChanged(query.copyWith(sort: s, page: 1))),
        const SizedBox(width: 10),
        TGViewToggle(value: query.view, onChanged: (v) => onChanged(query.copyWith(view: v))),
      ],
    );
  }
}

/// Pinned bar for screens without the sidebar: Filters (n) · Sort · layout.
class TGCompactControls extends StatelessWidget {
  const TGCompactControls({
    super.key,
    required this.filterCount,
    required this.sort,
    required this.view,
    required this.onFilters,
    required this.onSort,
    required this.onView,
    required this.singleViewButton,
  });

  final int filterCount;
  final TGProductsSort sort;
  final TGProductCardLayout view;
  final VoidCallback onFilters;
  final VoidCallback onSort;
  final ValueChanged<TGProductCardLayout> onView;
  final bool singleViewButton;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget pill({required Widget child, required VoidCallback onTap, required String label}) => Expanded(
          child: Semantics(
            button: true,
            label: label,
            child: InkWell(
              borderRadius: BorderRadius.circular(TGRadius.input),
              onTap: onTap,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(TGRadius.input),
                  border: Border.all(color: theme.tertiary),
                ),
                child: child,
              ),
            ),
          ),
        );

    return Row(
      children: [
        pill(
          label: context.t('ui_open_filters'),
          onTap: onFilters,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tune, color: theme.primaryText, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(context.t('ui_filters'), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(fontWeight: FontWeight.w900))),
              AnimatedSwitcher(
                duration: reduceMotion ? Duration.zero : TGMotion.quick,
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: filterCount == 0
                    ? const SizedBox.shrink(key: ValueKey('none'))
                    : Container(
                        key: ValueKey(filterCount),
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: theme.primary, borderRadius: BorderRadius.circular(TGRadius.pill)),
                        child: Text('$filterCount', style: theme.labelSmall.override(color: theme.primaryBtnText, fontWeight: FontWeight.w900)),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        pill(
          label: '${context.t('ui_sort_by')}: ${sortLabel(sort, t: (k) => context.t(k))}',
          onTap: onSort,
          child: Row(
            children: [
              Icon(Icons.sort, color: theme.primaryText, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(sortLabel(sort, t: (k) => context.t(k)), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodySmall.override(fontWeight: FontWeight.w900))),
              Icon(Icons.keyboard_arrow_down, color: theme.secondaryText, size: 20),
            ],
          ),
        ),
        const SizedBox(width: 10),
        TGViewToggle(value: view, onChanged: onView, single: singleViewButton),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Applied filter chips
// ---------------------------------------------------------------------------

class _ChipSpec {
  const _ChipSpec(this.label, this.next);
  final String label;
  final TGProductsQueryState next;
}

List<_ChipSpec> _chipSpecs(BuildContext context, TGProductsQueryState q) {
  final specs = <_ChipSpec>[];
  void add(String label, TGProductsQueryState next) => specs.add(_ChipSpec(label, next.copyWith(page: 1)));
  String t(String key, [Map<String, String>? p]) => context.t(key, p);

  if (q.listingType != null) {
    add(q.listingType == TGListingType.rent ? t('ui_rent') : t('ui_buy'), q.copyWith(listingTypeToNull: true));
  }
  if (q.verifiedOnly) add(t('ui_verified_sellers'), q.copyWith(verifiedOnly: false));
  for (final c in q.conditions) {
    add(c == TGCondition.newItem ? t('ui_condition_new') : t('ui_condition_used'), q.copyWith(conditions: {...q.conditions}..remove(c)));
  }
  for (final c in q.categories) {
    add(categoryLabel(c, t: t), q.copyWith(categories: {...q.categories}..remove(c)));
  }
  final basis = q.priceFilterBasis == TGPriceFilterBasis.brutto ? t('ui_brutto').toLowerCase() : t('ui_netto').toLowerCase();
  if (q.minPrice != null) add(t('ui_from_price', {'price': formatPln(q.minPrice!), 'basis': basis}), q.copyWith(minPriceToNull: true));
  if (q.maxPrice != null) add(t('ui_up_to_price', {'price': formatPln(q.maxPrice!), 'basis': basis}), q.copyWith(maxPriceToNull: true));
  if (!q.includeNoPrice) add(t('ui_without_price_hidden'), q.copyWith(includeNoPrice: true));
  if (q.hasCity) {
    add(q.radiusKm > 0 ? '${q.city} ${t('ui_plus_km', {'n': '${q.radiusKm}'})}' : q.city!, q.copyWith(cityToNull: true, radiusKm: 0));
  }
  for (final v in q.voivodeships) {
    add(v, q.copyWith(voivodeships: {...q.voivodeships}..remove(v)));
  }
  for (final p in q.powerTypes) {
    final label = switch (p) { TGPowerType.electric => t('ui_electric'), TGPowerType.gas => t('ui_gas'), TGPowerType.other => t('ui_other_power') };
    add(label, q.copyWith(powerTypes: {...q.powerTypes}..remove(p)));
  }
  if (q.delivery != null) add(q.delivery! ? t('ui_delivery_yes') : t('ui_delivery_no'), q.copyWith(deliveryToNull: true));
  if (q.pickup != null) add(q.pickup! ? t('ui_pickup_yes') : t('ui_pickup_no'), q.copyWith(pickupToNull: true));
  if (q.warrantyMinMonths != null) add(t('ui_warranty_n', {'n': '${q.warrantyMinMonths}'}), q.copyWith(warrantyToNull: true));
  for (final s in q.sellerTypes) {
    add(s == TGSellerType.store ? t('ui_store') : t('ui_private'), q.copyWith(sellerTypes: {...q.sellerTypes}..remove(s)));
  }
  if (q.hasBrand) add(t('ui_brand_n', {'n': q.brand!}), q.copyWith(brandToNull: true));
  if (q.hasSearch) add('“${q.search}”', q.copyWith(searchToNull: true));
  return specs;
}

/// Removable chips for every active filter, plus "Clear all".
class TGAppliedChips extends StatelessWidget {
  const TGAppliedChips({super.key, required this.query, required this.onChanged, this.scrollable = false});

  final TGProductsQueryState query;
  final ValueChanged<TGProductsQueryState> onChanged;

  /// Single horizontally scrolling row (phones) instead of a wrapping block.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final specs = _chipSpecs(context, query);
    if (specs.isEmpty) return const SizedBox.shrink();

    final chips = <Widget>[
      for (final s in specs) _AppliedChip(label: s.label, onRemove: () => onChanged(s.next)),
      _AppliedChip(label: context.t('ui_clear_all'), accent: true, onRemove: () => onChanged(query.clearedFilters().copyWith(page: 1))),
    ];

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [for (final c in chips) Padding(padding: const EdgeInsets.only(right: 8), child: c)]),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _AppliedChip extends StatelessWidget {
  const _AppliedChip({required this.label, required this.onRemove, this.accent = false});

  final String label;
  final VoidCallback onRemove;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      button: true,
      label: accent ? context.t('ui_clear_all_filters') : context.t('ui_remove_n', {'n': label}),
      child: InkWell(
        borderRadius: BorderRadius.circular(TGRadius.pill),
        onTap: onRemove,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: accent ? Colors.transparent : theme.secondaryBackground,
            borderRadius: BorderRadius.circular(TGRadius.pill),
            border: Border.all(color: accent ? theme.primary : theme.tertiary),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodySmall.override(color: accent ? theme.primary : theme.primaryText, fontWeight: FontWeight.w800),
                ),
              ),
              if (!accent) ...[
                const SizedBox(width: 6),
                Icon(Icons.close, size: 15, color: theme.secondaryText),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results body
// ---------------------------------------------------------------------------

/// Everything under the toolbar: sticky promoted block, all listings (grid or
/// list with a 220 ms transition), pagination / "show more", the Special Order
/// band.
class TGResultsBody extends StatelessWidget {
  const TGResultsBody({
    super.key,
    required this.loading,
    required this.query,
    required this.results,
    required this.isPhone,
    required this.onChanged,
  });

  final bool loading;
  final TGProductsQueryState query;
  final TGProductResults results;
  final bool isPhone;
  final ValueChanged<TGProductsQueryState> onChanged;

  @override
  Widget build(BuildContext context) {
    final perPage = isPhone ? 12 : 24;
    final organic = results.organic;
    final totalPages = pageCount(organic.length, perPage);
    final page = query.page.clamp(1, totalPages);

    // Phones accumulate ("Show more"); larger screens show one page at a time.
    final visible = isPhone ? organic.take(page * perPage).toList() : paginate(organic, page, perPage: perPage);

    Widget content;
    if (loading) {
      content = _SkeletonCards(layout: query.view);
    } else if (results.total == 0) {
      content = TGEmptyResults(query: query, onChanged: onChanged);
    } else {
      content = _LayoutSwitcher(
        layout: query.view,
        child: _CardsContent(
          key: ValueKey(query.view),
          layout: query.view,
          promoted: results.promoted,
          visible: visible,
          hasOrganic: organic.isNotEmpty,
          isPhone: isPhone,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        content,
        if (!loading && organic.isNotEmpty) ...[
          const SizedBox(height: 28),
          if (isPhone)
            _ShowMore(shown: visible.length, total: organic.length, onMore: () => onChanged(query.copyWith(page: page + 1)))
          else
            _Pagination(current: page, total: totalPages, onPage: (p) => onChanged(query.copyWith(page: p))),
        ],
        const SizedBox(height: 32),
        const TGSpecialOrderBand(),
      ],
    );
  }
}

/// Cross-fades between the grid and the list layout in 220 ms while the
/// container eases to its new height, so the page below never jumps.
class _LayoutSwitcher extends StatelessWidget {
  const _LayoutSwitcher({required this.layout, required this.child});

  final TGProductCardLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduceMotion ? Duration.zero : TGMotion.layoutSwitch;

    return AnimatedSize(
      duration: duration,
      curve: TGMotion.layoutCurve,
      alignment: Alignment.topCenter,
      // Never clip: cards glow and lift outside their own bounds on hover.
      clipBehavior: Clip.none,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // The outgoing layout floats on top of the same spot and stops
            // reacting to the pointer; only the incoming one sizes the stack.
            for (final p in previous) Positioned(top: 0, left: 0, right: 0, child: IgnorePointer(child: p)),
            if (current != null) current,
          ],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(animation),
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _CardsContent extends StatelessWidget {
  const _CardsContent({
    super.key,
    required this.layout,
    required this.promoted,
    required this.visible,
    required this.hasOrganic,
    required this.isPhone,
  });

  final TGProductCardLayout layout;
  final List<TGProduct> promoted;
  final List<TGProduct> visible;
  final bool hasOrganic;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Promoted listings are pinned here no matter how the rest is sorted.
        if (promoted.isNotEmpty) ...[
          _SectionHeader(label: context.t('ui_featured_promoted'), color: theme.secondary, key: const ValueKey('promoted-header')),
          const SizedBox(height: 12),
          if (isPhone && layout == TGProductCardLayout.grid)
            _PromotedCarousel(items: promoted)
          else
            _CardCollection(items: promoted, layout: layout, withBanner: false),
          const SizedBox(height: 28),
        ],
        if (hasOrganic) ...[
          _SectionHeader(label: context.t('ui_all_listings')),
          const SizedBox(height: 12),
          _CardCollection(items: visible, layout: layout, withBanner: true),
        ] else if (promoted.isNotEmpty)
          Text(context.t('ui_no_other_listings'), style: theme.bodyMedium.override(color: theme.secondaryText)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color ?? theme.primary, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
      ],
    );
  }
}

/// A set of cards laid out as a grid (1–3 columns) or as horizontal list rows.
class _CardCollection extends StatelessWidget {
  const _CardCollection({required this.items, required this.layout, required this.withBanner});

  final List<TGProduct> items;
  final TGProductCardLayout layout;
  final bool withBanner;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;

        if (layout == TGProductCardLayout.list) {
          const bannerAfter = 4;
          final before = withBanner ? items.take(bannerAfter).toList() : items;
          final after = withBanner ? items.skip(bannerAfter).toList() : const <TGProduct>[];
          Widget rows(List<TGProduct> part) => Column(
                children: [
                  for (var i = 0; i < part.length; i++) ...[
                    TGProductCard(key: ValueKey('list-${part[i].id}'), product: part[i], layout: TGProductCardLayout.list),
                    if (i != part.length - 1) const SizedBox(height: 14),
                  ],
                ],
              );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              rows(before),
              if (withBanner) ...[const SizedBox(height: 18), const _SellBanner(), if (after.isNotEmpty) const SizedBox(height: 18)],
              if (after.isNotEmpty) rows(after),
            ],
          );
        }

        final cols = gridColumnsFor(width);
        final cardW = (width - kTGGridGutter * (cols - 1)) / cols;
        final extent = TGProductCard.gridExtent(cardW, MediaQuery.textScalerOf(context));
        final bannerAfter = cols * 3;
        final before = withBanner ? items.take(bannerAfter).toList() : items;
        final after = withBanner ? items.skip(bannerAfter).toList() : const <TGProduct>[];

        Widget grid(List<TGProduct> part) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              clipBehavior: Clip.none, // let the hover glow paint outside the grid
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: kTGGridGutter,
                mainAxisSpacing: kTGGridGutter,
                mainAxisExtent: extent,
              ),
              itemCount: part.length,
              itemBuilder: (_, i) => TGProductCard(key: ValueKey('grid-${part[i].id}'), product: part[i]),
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            grid(before),
            if (withBanner) ...[const SizedBox(height: 24), const _SellBanner(), if (after.isNotEmpty) const SizedBox(height: 24)],
            if (after.isNotEmpty) grid(after),
          ],
        );
      },
    );
  }
}

/// Phones: the promoted trio scrolls sideways instead of eating three screens.
class _PromotedCarousel extends StatelessWidget {
  const _PromotedCarousel({required this.items});
  final List<TGProduct> items;

  @override
  Widget build(BuildContext context) {
    const cardW = 292.0;
    final extent = TGProductCard.gridExtent(cardW, MediaQuery.textScalerOf(context));
    return SizedBox(
      // Extra room so the hover/focus glow is not cut off.
      height: extent + 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => SizedBox(
          width: cardW,
          child: TGProductCard(key: ValueKey('promo-${items[i].id}'), product: items[i]),
        ),
      ),
    );
  }
}

class _SkeletonCards extends StatelessWidget {
  const _SkeletonCards({required this.layout});
  final TGProductCardLayout layout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (layout == TGProductCardLayout.list) {
          return Column(
            children: [
              for (var i = 0; i < 5; i++) ...[
                const TGProductCardSkeleton(layout: TGProductCardLayout.list),
                const SizedBox(height: 14),
              ],
            ],
          );
        }
        final cols = gridColumnsFor(c.maxWidth);
        final cardW = (c.maxWidth - kTGGridGutter * (cols - 1)) / cols;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: kTGGridGutter,
            mainAxisSpacing: kTGGridGutter,
            mainAxisExtent: TGProductCard.gridExtent(cardW, MediaQuery.textScalerOf(context)),
          ),
          itemCount: math.min(6, cols * 2),
          itemBuilder: (_, __) => const TGProductCardSkeleton(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Pagination
// ---------------------------------------------------------------------------

class _ShowMore extends StatelessWidget {
  const _ShowMore({required this.shown, required this.total, required this.onMore});

  final int shown;
  final int total;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      children: [
        if (shown < total)
          TGButton(
            onPressed: onMore,
            label: context.t('ui_show_more'),
            icon: Icons.expand_more,
            height: 46,
            variant: TGButtonVariant.outline,
            borderRadius: BorderRadius.circular(TGRadius.pill),
          ),
        const SizedBox(height: 10),
        Text('$shown / $total', style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.current, required this.total, required this.onPage});

  final int current;
  final int total;
  final ValueChanged<int> onPage;

  static List<int?> window(int current, int total) {
    if (total <= 7) return [for (var i = 1; i <= total; i++) i];
    final pages = <int?>[1];
    if (current > 3) pages.add(null);
    final start = math.max(2, current - 1);
    final end = math.min(total - 1, current + 1);
    for (var i = start; i <= end; i++) {
      pages.add(i);
    }
    if (current < total - 2) pages.add(null);
    pages.add(total);
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);

    Widget btn(String label, {required bool active, required VoidCallback? onTap, String? semantics}) {
      return Semantics(
        button: true,
        selected: active,
        enabled: onTap != null,
        label: semantics ?? context.t('ui_page_n', {'n': label}),
        child: InkWell(
          borderRadius: BorderRadius.circular(TGRadius.input),
          onTap: onTap,
          child: AnimatedContainer(
            duration: TGMotion.quick,
            constraints: const BoxConstraints(minWidth: 42),
            height: 42,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active ? theme.primary : theme.secondaryBackground,
              borderRadius: BorderRadius.circular(TGRadius.input),
              border: Border.all(color: active ? theme.primary : theme.tertiary),
            ),
            child: Text(
              label,
              style: theme.bodySmall.override(
                color: active ? theme.primaryBtnText : (onTap == null ? theme.secondaryText.withValues(alpha: 0.5) : theme.primaryText),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        btn('«', active: false, semantics: context.t('ui_prev_page'), onTap: current > 1 ? () => onPage(current - 1) : null),
        for (final p in window(current, total))
          if (p == null)
            SizedBox(width: 24, height: 42, child: Center(child: Text('…', style: theme.bodySmall.override(color: theme.secondaryText))))
          else
            btn('$p', active: p == current, onTap: () => onPage(p)),
        btn('»', active: false, semantics: context.t('ui_next_page'), onTap: current < total ? () => onPage(current + 1) : null),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Banners + empty state
// ---------------------------------------------------------------------------

class _SellBanner extends StatelessWidget {
  const _SellBanner();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 560;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('ui_sell_banner_title'),
          style: theme.titleSmall.override(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          context.t('ui_sell_banner_sub'),
          style: theme.bodySmall.override(color: theme.secondaryText, lineHeight: 1.5),
        ),
      ],
    );
    final button = TGButton(
      onPressed: () => TGNav.addProduct(context),
      label: context.t('ui_add_product_plus'),
      icon: Icons.add,
      height: 44,
      borderRadius: BorderRadius.circular(TGRadius.pill),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [theme.primary.withValues(alpha: 0.16), theme.secondary.withValues(alpha: 0.16)]),
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: theme.tertiary),
      ),
      child: narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [text, const SizedBox(height: 14), button])
          : Row(children: [Expanded(child: text), const SizedBox(width: 16), button]),
    );
  }
}


class TGEmptyResults extends StatelessWidget {
  const TGEmptyResults({super.key, required this.query, required this.onChanged});

  final TGProductsQueryState query;
  final ValueChanged<TGProductsQueryState> onChanged;

  /// The single most useful filter to drop, as a one-tap suggestion.
  ({String label, TGProductsQueryState next})? _suggestion(BuildContext context) {
    final q = query;
    if (q.hasCity) return (label: context.t('ui_filter_city'), next: q.copyWith(cityToNull: true, radiusKm: 0, page: 1));
    if (q.categories.isNotEmpty) return (label: context.t('ui_filter_category'), next: q.copyWith(categories: {}, page: 1));
    if (q.minPrice != null || q.maxPrice != null) {
      return (label: context.t('ui_filter_price'), next: q.copyWith(minPriceToNull: true, maxPriceToNull: true, page: 1));
    }
    if (q.verifiedOnly) return (label: context.t('ui_filter_verified'), next: q.copyWith(verifiedOnly: false, page: 1));
    if (q.conditions.isNotEmpty) return (label: context.t('ui_filter_condition'), next: q.copyWith(conditions: {}, page: 1));
    if (q.hasSearch) return (label: context.t('ui_filter_search'), next: q.copyWith(searchToNull: true, page: 1));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final suggestion = _suggestion(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: theme.tertiary),
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: theme.alternate,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.tertiary),
            ),
            child: Icon(Icons.inventory_2_outlined, size: 44, color: theme.secondaryText.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 14),
          Text(context.t('ui_no_results'), style: theme.titleLarge.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            query.hasCity ? context.t('ui_try_removing_or_radius') : context.t('ui_try_removing_filters'),
            textAlign: TextAlign.center,
            style: theme.bodyMedium.override(color: theme.secondaryText),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              if (suggestion != null)
                TGButton(
                  onPressed: () => onChanged(suggestion.next),
                  label: context.t('ui_remove_n', {'n': suggestion.label}),
                  icon: Icons.close,
                  variant: TGButtonVariant.outline,
                  height: 44,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
              if (query.hasCity && query.radiusKm < 100)
                TGButton(
                  onPressed: () => onChanged(query.copyWith(radiusKm: 100, page: 1)),
                  label: context.t('ui_search_100km'),
                  icon: Icons.my_location,
                  variant: TGButtonVariant.ghost,
                  height: 44,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
              if (query.activeFilterCount > 0)
                TGButton(
                  onPressed: () => onChanged(query.clearedFilters().copyWith(page: 1)),
                  label: context.t('ui_clear_all_filters'),
                  icon: Icons.filter_alt_off_outlined,
                  variant: TGButtonVariant.ghost,
                  height: 44,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
              TGButton(
                onPressed: () => TGNav.specialOrder(context),
                label: context.t('ui_special_order'),
                icon: Icons.send,
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
