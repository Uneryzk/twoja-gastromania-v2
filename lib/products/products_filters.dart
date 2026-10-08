import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/products/products_logic.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/products/tg_geo.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// Sticky desktop sidebar: a scrollable card that hosts the [TGFilterForm].
class TGFiltersPanel extends StatefulWidget {
  const TGFiltersPanel({
    super.key,
    required this.loading,
    required this.allProducts,
    required this.query,
    required this.onChanged,
  });

  final bool loading;
  final List<TGProduct> allProducts;
  final TGProductsQueryState query;
  final ValueChanged<TGProductsQueryState> onChanged;

  @override
  State<TGFiltersPanel> createState() => _TGFiltersPanelState();
}

class _TGFiltersPanelState extends State<TGFiltersPanel> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: theme.tertiary),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TGRadius.card),
        child: widget.loading
            ? const _FiltersSkeleton()
            : Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: TGFilterForm(
                    allProducts: widget.allProducts,
                    query: widget.query,
                    onChanged: widget.onChanged,
                    expandCategories: false,
                  ),
                ),
              ),
      ),
    );
  }
}

/// All filters of the products page.
///
/// Sections, in order: verified sellers toggle, listing type (All/Buy/Rent),
/// condition (NOWY/UŻYWANY), category tree, price (slider + numeric inputs),
/// location (autocomplete + radius) and "more filters". It is purely driven by
/// [query] / [onChanged], so the same widget serves the desktop sidebar (applies
/// instantly) and the mobile bottom sheet (edits a draft with a live counter).
class TGFilterForm extends StatefulWidget {
  const TGFilterForm({
    super.key,
    required this.allProducts,
    required this.query,
    required this.onChanged,
    this.showHeader = true,
    this.expandCategories = true,
  });

  final List<TGProduct> allProducts;
  final TGProductsQueryState query;
  final ValueChanged<TGProductsQueryState> onChanged;
  final bool showHeader;

  /// Desktop sticky sidebar keeps Price/Location on-screen by starting with
  /// the category tree collapsed; the mobile sheet has enough height to open it.
  final bool expandCategories;

  @override
  State<TGFilterForm> createState() => _TGFilterFormState();
}

class _TGFilterFormState extends State<TGFilterForm> {
  bool _verifiedOpen = true;
  bool _listingOpen = true;
  bool _conditionOpen = true;
  late bool _categoriesOpen = widget.expandCategories;
  bool _priceOpen = true;
  bool _locationOpen = true;
  bool _moreOpen = false;

  void _emit(TGProductsQueryState next) => widget.onChanged(next.copyWith(page: 1));

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final q = widget.query;
    final all = widget.allProducts;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduceMotion ? Duration.zero : TGMotion.layoutSwitch;
    final count = q.activeFilterCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          Row(
            children: [
              Expanded(child: Text(context.t('ui_filters'), style: theme.titleMedium.override(fontSize: 16, fontWeight: FontWeight.w800))),
              _ClearButton(count: count, onPressed: () => widget.onChanged(q.clearedFilters().copyWith(page: 1))),
            ],
          ),
          const SizedBox(height: 8),
        ],
        _FilterSection(
          title: context.t('ui_verified_sellers'),
          open: _verifiedOpen,
          duration: duration,
          onToggle: () => setState(() => _verifiedOpen = !_verifiedOpen),
          child: _VerifiedCard(
            value: q.verifiedOnly,
            count: all.where((p) => p.seller.verified).length,
            onChanged: (v) => _emit(q.copyWith(verifiedOnly: v)),
          ),
        ),
        const _SectionDivider(),
        _FilterSection(
          title: context.t('ui_listing_type'),
          open: _listingOpen,
          duration: duration,
          onToggle: () => setState(() => _listingOpen = !_listingOpen),
          child: _ListingTypeSegment(
            value: q.listingType,
            onChanged: (v) => _emit(q.copyWith(listingType: v, listingTypeToNull: v == null)),
          ),
        ),
        const _SectionDivider(),
        _FilterSection(
          title: context.t('ui_condition'),
          open: _conditionOpen,
          duration: duration,
          onToggle: () => setState(() => _conditionOpen = !_conditionOpen),
          child: _ConditionChips(all: all, value: q.conditions, onChanged: (s) => _emit(q.copyWith(conditions: s))),
        ),
        const _SectionDivider(),
        _FilterSection(
          title: context.t('ui_categories'),
          open: _categoriesOpen,
          duration: duration,
          onToggle: () => setState(() => _categoriesOpen = !_categoriesOpen),
          child: _CategoryTree(all: all, value: q.categories, onChanged: (s) => _emit(q.copyWith(categories: s))),
        ),
        const _SectionDivider(),
        _FilterSection(
          title: context.t('ui_price'),
          open: _priceOpen,
          duration: duration,
          onToggle: () => setState(() => _priceOpen = !_priceOpen),
          child: _PriceFilter(all: all, query: q, onChanged: _emit),
        ),
        const _SectionDivider(),
        _FilterSection(
          title: context.t('ui_location'),
          open: _locationOpen,
          duration: duration,
          onToggle: () => setState(() => _locationOpen = !_locationOpen),
          child: _LocationFilter(all: all, query: q, onChanged: _emit),
        ),
        const _SectionDivider(),
        _FilterSection(
          title: context.t('ui_more_filters'),
          open: _moreOpen,
          duration: duration,
          onToggle: () => setState(() => _moreOpen = !_moreOpen),
          child: _MoreFilters(all: all, query: q, onChanged: _emit),
        ),
      ],
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.count, required this.onPressed});
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final enabled = count > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onPressed : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          context.t('ui_clear_n', {'n': '$count'}),
          style: theme.bodySmall.override(
            color: enabled ? theme.primary : theme.secondaryText.withValues(alpha: 0.45),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section chrome
// ---------------------------------------------------------------------------

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(height: 1, color: theme.tertiary),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.open,
    required this.onToggle,
    required this.child,
    required this.duration,
  });

  final String title;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          label: title,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: theme.titleSmall.override(fontSize: 13, fontWeight: FontWeight.w800))),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: duration,
                    child: Icon(Icons.keyboard_arrow_down, size: 20, color: theme.secondaryText),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          crossFadeState: open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: duration,
          alignment: Alignment.topCenter,
          firstChild: Padding(padding: const EdgeInsets.only(top: 6), child: child),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Selectable pill used by every chip group (radius, voivodeship, power, ...).
class _PillChip extends StatelessWidget {
  const _PillChip({required this.label, required this.selected, required this.onTap, this.enabled = true});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final fg = !enabled ? theme.secondaryText.withValues(alpha: 0.5) : (selected ? theme.primary : theme.primaryText);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(TGRadius.pill),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? theme.primary.withValues(alpha: 0.16) : theme.alternate,
            borderRadius: BorderRadius.circular(TGRadius.pill),
            border: Border.all(color: selected ? theme.primary : theme.tertiary),
          ),
          child: Text(label, style: theme.bodySmall.override(color: fg, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w800)),
    );
  }
}

// ---------------------------------------------------------------------------
// Verified sellers toggle
// ---------------------------------------------------------------------------

class _VerifiedCard extends StatelessWidget {
  const _VerifiedCard({required this.value, required this.count, required this.onChanged});

  final bool value;
  final int count;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: theme.alternate,
        borderRadius: BorderRadius.circular(TGRadius.input),
        border: Border.all(color: value ? theme.success.withValues(alpha: 0.7) : theme.tertiary),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.success.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.success.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.verified_user, color: theme.success, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('ui_verified_sellers_only'), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(context.t('ui_listings_count', {'n': '$count'}), style: theme.bodySmall.override(color: theme.secondaryText)),
              ],
            ),
          ),
          Semantics(
            label: context.t('ui_verified_sellers_only'),
            toggled: value,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Listing type (All / Buy / Rent)
// ---------------------------------------------------------------------------

class _ListingTypeSegment extends StatelessWidget {
  const _ListingTypeSegment({required this.value, required this.onChanged});

  final TGListingType? value;
  final ValueChanged<TGListingType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget seg(String label, TGListingType? v) {
      final active = value == v;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(TGRadius.pill),
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? theme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
              child: Text(
                label,
                style: theme.bodySmall.override(
                  color: active ? theme.primaryBtnText : theme.primaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.alternate,
        borderRadius: BorderRadius.circular(TGRadius.pill),
        border: Border.all(color: theme.tertiary),
      ),
      child: Row(
        children: [
          seg(context.t('ui_all'), null),
          const SizedBox(width: 4),
          seg(context.t('ui_buy'), TGListingType.buy),
          const SizedBox(width: 4),
          seg(context.t('ui_rent'), TGListingType.rent),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Condition
// ---------------------------------------------------------------------------

class _ConditionChips extends StatelessWidget {
  const _ConditionChips({required this.all, required this.value, required this.onChanged});

  final List<TGProduct> all;
  final Set<TGCondition> value;
  final ValueChanged<Set<TGCondition>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    Widget chip(TGCondition c, String label, Color dot) {
      final count = all.where((p) => p.condition == c).length;
      final active = value.contains(c);
      return Semantics(
        button: true,
        selected: active,
        label: '$label ($count)',
        child: InkWell(
          borderRadius: BorderRadius.circular(TGRadius.pill),
          onTap: () {
            final next = {...value};
            if (!next.add(c)) next.remove(c);
            onChanged(next);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: active ? theme.primary.withValues(alpha: 0.14) : theme.alternate,
              borderRadius: BorderRadius.circular(TGRadius.pill),
              border: Border.all(color: active ? theme.primary : theme.tertiary),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label, style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
                const SizedBox(width: 6),
                Text('($count)', style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(TGCondition.newItem, context.t('ui_condition_new'), theme.primary),
        chip(TGCondition.used, context.t('ui_condition_used'), theme.secondary),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category tree
// ---------------------------------------------------------------------------

class _CategoryTree extends StatelessWidget {
  const _CategoryTree({required this.all, required this.value, required this.onChanged});

  final List<TGProduct> all;
  final Set<TGCategory> value;
  final ValueChanged<Set<TGCategory>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    const cats = TGCategory.values;
    final selected = value.length;
    final allSelected = selected == cats.length;
    final partial = selected > 0 && selected < cats.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CheckRow(
          label: context.t('ui_all_categories'),
          count: all.length,
          state: allSelected ? _Check.on : (partial ? _Check.partial : _Check.off),
          bold: true,
          onTap: () => onChanged(allSelected ? <TGCategory>{} : cats.toSet()),
        ),
        // Children hang off a vertical guide line, which is what makes this a tree.
        Container(
          margin: const EdgeInsets.only(left: 9, top: 4),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: theme.tertiary, width: 1.5))),
          child: Column(
            children: [
              for (final c in cats)
                _CheckRow(
                  label: categoryLabel(c, t: (k) => context.t(k)),
                  count: all.where((p) => p.category == c).length,
                  state: value.contains(c) ? _Check.on : _Check.off,
                  onTap: () {
                    final next = {...value};
                    if (!next.add(c)) next.remove(c);
                    onChanged(next);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _Check { off, partial, on }

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.count, required this.state, required this.onTap, this.bold = false});

  final String label;
  final int count;
  final _Check state;
  final VoidCallback onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final icon = switch (state) {
      _Check.on => Icons.check_box,
      _Check.partial => Icons.indeterminate_check_box,
      _Check.off => Icons.check_box_outline_blank,
    };
    return Semantics(
      button: true,
      checked: state == _Check.on,
      label: '$label ($count)',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Icon(icon, size: 18, color: state == _Check.off ? theme.secondaryText : theme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyMedium.override(fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text('$count', style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Price: histogram + range slider + numeric inputs
// ---------------------------------------------------------------------------

class _PriceFilter extends StatefulWidget {
  const _PriceFilter({required this.all, required this.query, required this.onChanged});

  final List<TGProduct> all;
  final TGProductsQueryState query;
  final ValueChanged<TGProductsQueryState> onChanged;

  @override
  State<_PriceFilter> createState() => _PriceFilterState();
}

class _PriceFilterState extends State<_PriceFilter> {
  static const int _maxPrice = 100000;

  late final TextEditingController _minCtrl = TextEditingController(text: widget.query.minPrice?.toString() ?? '');
  late final TextEditingController _maxCtrl = TextEditingController(text: widget.query.maxPrice?.toString() ?? '');
  final FocusNode _minFocus = FocusNode();
  final FocusNode _maxFocus = FocusNode();
  Timer? _debounce;

  /// Slider position while the thumb is being dragged (so it follows the finger
  /// before the query – and therefore the URL – is updated on release).
  RangeValues? _drag;

  /// Thumb chosen on pointer-down. Material [RangeSlider] otherwise re-selects
  /// at drag-start using the *current* pointer (a 120px test jump lands in the
  /// middle and would drag the start thumb).
  Thumb? _pointerThumb;

  @override
  void didUpdateWidget(covariant _PriceFilter old) {
    super.didUpdateWidget(old);
    _syncText(_minCtrl, _minFocus, widget.query.minPrice);
    _syncText(_maxCtrl, _maxFocus, widget.query.maxPrice);
  }

  void _syncText(TextEditingController c, FocusNode f, int? value) {
    final text = value?.toString() ?? '';
    if (c.text != text && !f.hasFocus) c.text = text;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _minFocus.dispose();
    _maxFocus.dispose();
    super.dispose();
  }

  void _commitFromText() {
    _debounce?.cancel();
    var min = int.tryParse(_minCtrl.text.trim());
    var max = int.tryParse(_maxCtrl.text.trim());
    if (min != null && max != null && min > max) {
      final t = min;
      min = max;
      max = t;
    }
    final q = widget.query;
    if (min == q.minPrice && max == q.maxPrice) return;
    widget.onChanged(q.copyWith(minPrice: min, minPriceToNull: min == null, maxPrice: max, maxPriceToNull: max == null));
  }

  void _commitDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _commitFromText);
  }

  // Log-ish mapping: slider 0..1 -> 0..100k (more precision at the low end).
  double _toSlider(int price) {
    final p = price.clamp(0, _maxPrice).toDouble();
    return (math.log(1 + p) / math.log(1 + _maxPrice)).clamp(0.0, 1.0);
  }

  int _fromSlider(double v) {
    final x = v.clamp(0.0, 1.0);
    final raw = (math.pow(1 + _maxPrice, x) - 1).round().clamp(0, _maxPrice);
    final step = raw < 1000 ? 10 : (raw < 10000 ? 50 : 500);
    return ((raw / step).round() * step).clamp(0, _maxPrice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final q = widget.query;
    final prices = widget.all
        .map((e) => productPriceForBasis(e, q.priceFilterBasis))
        .whereType<int>()
        .where((p) => p >= 0)
        .toList()
      ..sort();

    final values = _drag ?? RangeValues(_toSlider(q.minPrice ?? 0), _toSlider(q.maxPrice ?? _maxPrice));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _BasisToggle(
                value: q.priceFilterBasis,
                onChanged: (next) {
                  if (next == q.priceFilterBasis) return;
                  // Re-express the current bounds in the new basis (same real price).
                  int? conv(int? v) => v == null ? null : netToBasis(basisToNet(v, q.priceFilterBasis), next);
                  final nextMin = conv(q.minPrice);
                  final nextMax = conv(q.maxPrice);
                  _minCtrl.text = nextMin?.toString() ?? '';
                  _maxCtrl.text = nextMax?.toString() ?? '';
                  widget.onChanged(q.copyWith(
                    priceFilterBasis: next,
                    minPrice: nextMin,
                    minPriceToNull: nextMin == null,
                    maxPrice: nextMax,
                    maxPriceToNull: nextMax == null,
                  ));
                },
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: context.t('ui_price_compared_net'),
              child: Icon(Icons.info_outline, size: 18, color: theme.secondaryText),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(height: 24, child: _Histogram(prices: prices)),
        Listener(
          onPointerDown: (event) {
            final box = context.findRenderObject();
            if (box is! RenderBox || !box.hasSize) return;
            final t = (box.globalToLocal(event.position).dx / box.size.width).clamp(0.0, 1.0);
            _pointerThumb = t >= 0.5 ? Thumb.end : Thumb.start;
          },
          onPointerUp: (_) => _pointerThumb = null,
          onPointerCancel: (_) => _pointerThumb = null,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbSelector: (textDirection, values, tapValue, thumbSize, trackSize, dx) {
                return _pointerThumb ?? (tapValue * 2 < values.start + values.end ? Thumb.start : Thumb.end);
              },
            ),
            child: RangeSlider(
              values: values,
              min: 0,
              max: 1,
              onChanged: (v) {
                setState(() => _drag = v);
                final lo = _fromSlider(v.start);
                final hi = _fromSlider(v.end);
                _minCtrl.text = lo == 0 ? '' : lo.toString();
                _maxCtrl.text = hi >= _maxPrice ? '' : hi.toString();
              },
              onChangeEnd: (v) {
                final lo = _fromSlider(v.start);
                final hi = _fromSlider(v.end);
                setState(() => _drag = null);
                widget.onChanged(q.copyWith(
                  minPrice: lo == 0 ? null : lo,
                  minPriceToNull: lo == 0,
                  maxPrice: hi >= _maxPrice ? null : hi,
                  maxPriceToNull: hi >= _maxPrice,
                ));
              },
            ),
          ),
        ),
        Row(
          children: [
            Expanded(child: _NumericField(controller: _minCtrl, focusNode: _minFocus, label: context.t('ui_min'), onChanged: _commitDebounced, onSubmitted: _commitFromText)),
            const SizedBox(width: 10),
            Expanded(child: _NumericField(controller: _maxCtrl, focusNode: _maxFocus, label: context.t('ui_max'), onChanged: _commitDebounced, onSubmitted: _commitFromText)),
          ],
        ),
        const SizedBox(height: 4),
        _CheckRow(
          label: context.t('ui_include_no_price'),
          count: widget.all.where((p) => p.price == null).length,
          state: q.includeNoPrice ? _Check.on : _Check.off,
          onTap: () => widget.onChanged(q.copyWith(includeNoPrice: !q.includeNoPrice)),
        ),
      ],
    );
  }
}

class _BasisToggle extends StatelessWidget {
  const _BasisToggle({required this.value, required this.onChanged});

  final TGPriceFilterBasis value;
  final ValueChanged<TGPriceFilterBasis> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget seg(String label, TGPriceFilterBasis b) {
      final active = value == b;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(TGRadius.pill),
            onTap: () => onChanged(b),
            child: Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? theme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
              child: Text(
                label,
                style: theme.bodySmall.override(color: active ? theme.primaryBtnText : theme.primaryText, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.alternate,
        borderRadius: BorderRadius.circular(TGRadius.pill),
        border: Border.all(color: theme.tertiary),
      ),
      child: Row(children: [seg(context.t('ui_netto'), TGPriceFilterBasis.netto), seg(context.t('ui_brutto'), TGPriceFilterBasis.brutto)]),
    );
  }
}

class _NumericField extends StatelessWidget {
  const _NumericField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(TGRadius.input),
          borderSide: BorderSide(color: c, width: w),
        );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
      onChanged: (_) => onChanged(),
      onSubmitted: (_) => onSubmitted(),
      onTapOutside: (_) => focusNode.unfocus(),
      style: theme.bodyMedium.override(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: theme.bodySmall.override(color: theme.secondaryText),
        suffixText: 'PLN',
        suffixStyle: theme.bodySmall.override(color: theme.secondaryText),
        isDense: true,
        filled: true,
        fillColor: theme.alternate,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: border(theme.tertiary),
        focusedBorder: border(theme.primary, 1.6),
      ),
    );
  }
}

class _Histogram extends StatelessWidget {
  const _Histogram({required this.prices});
  final List<int> prices;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return CustomPaint(
      painter: _HistogramPainter(
        prices: prices,
        color: theme.primary.withValues(alpha: 0.7),
        bg: theme.tertiary.withValues(alpha: 0.35),
      ),
    );
  }
}

class _HistogramPainter extends CustomPainter {
  _HistogramPainter({required this.prices, required this.color, required this.bg});

  final List<int> prices;
  final Color color;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      Paint()..color = bg,
    );
    if (prices.isEmpty) return;

    const buckets = 18;
    const maxP = 100000;
    final counts = List<int>.filled(buckets, 0);
    for (final p in prices) {
      final x = math.log(1 + p.clamp(0, maxP)) / math.log(1 + maxP);
      counts[(x * (buckets - 1)).round().clamp(0, buckets - 1)] += 1;
    }
    final maxCount = counts.fold<int>(1, (m, v) => v > m ? v : m);
    final barW = size.width / buckets;
    final paint = Paint()..color = color;
    for (var i = 0; i < buckets; i++) {
      final h = (counts[i] / maxCount) * (size.height - 8);
      final r = Rect.fromLTWH(i * barW + 2, size.height - h - 3, math.max(0.0, barW - 4), h);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(5)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HistogramPainter old) =>
      !listEquals(old.prices, prices) || old.color != color || old.bg != bg;
}

// ---------------------------------------------------------------------------
// Location: autocomplete + radius
// ---------------------------------------------------------------------------

class _CityOption {
  const _CityOption(this.name, this.listings);
  final String name;
  final int listings;
}

class _LocationFilter extends StatefulWidget {
  const _LocationFilter({required this.all, required this.query, required this.onChanged});

  final List<TGProduct> all;
  final TGProductsQueryState query;
  final ValueChanged<TGProductsQueryState> onChanged;

  @override
  State<_LocationFilter> createState() => _LocationFilterState();
}

class _LocationFilterState extends State<_LocationFilter> {
  // Owned here (not created inside build) so focus and text survive rebuilds.
  late final TextEditingController _ctrl = TextEditingController(text: widget.query.city ?? '');
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _LocationFilter old) {
    super.didUpdateWidget(old);
    final city = widget.query.city ?? '';
    if (old.query.city != widget.query.city && _ctrl.text != city && !_focus.hasFocus) {
      _ctrl.text = city;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Map<String, int> get _counts {
    final m = <String, int>{};
    for (final p in widget.all) {
      final key = TGGeo.normalize(p.city);
      m[key] = (m[key] ?? 0) + 1;
    }
    return m;
  }

  Iterable<_CityOption> _options(String text) {
    final t = TGGeo.normalize(text);
    if (t.isEmpty) return const [];
    final counts = _counts;
    final starts = <TGCity>[];
    final contains = <TGCity>[];
    for (final c in TGGeo.cities) {
      final n = TGGeo.normalize(c.name);
      if (n.startsWith(t)) {
        starts.add(c);
      } else if (n.contains(t)) {
        contains.add(c);
      }
    }
    return [...starts, ...contains].take(8).map((c) => _CityOption(c.name, counts[TGGeo.normalize(c.name)] ?? 0));
  }

  void _setCity(String? city) {
    final q = widget.query;
    if (city == null || city.trim().isEmpty) {
      widget.onChanged(q.copyWith(cityToNull: true, radiusKm: 0));
    } else {
      widget.onChanged(q.copyWith(city: city.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final q = widget.query;
    final counts = _counts;
    final voivodeships = widget.all.map((e) => e.voivodeship).toSet().toList()..sort();
    final popular = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(4)
        .map((e) => TGGeo.lookup(e.key)?.name)
        .whereType<String>()
        .toList();

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(TGRadius.input),
          borderSide: BorderSide(color: c, width: w),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final r in const [0, 10, 25, 50, 100])
              _PillChip(
                label: r == 0 ? context.t('ui_exact') : context.t('ui_plus_km', {'n': '$r'}),
                selected: q.radiusKm == r,
                enabled: q.hasCity,
                onTap: () => widget.onChanged(q.copyWith(radiusKm: r)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) => RawAutocomplete<_CityOption>(
            textEditingController: _ctrl,
            focusNode: _focus,
            displayStringForOption: (o) => o.name,
            optionsBuilder: (value) => _options(value.text),
            onSelected: (o) => _setCity(o.name),
            fieldViewBuilder: (context, ctrl, focus, onFieldSubmitted) {
              return TextField(
                controller: ctrl,
                focusNode: focus,
                textInputAction: TextInputAction.search,
                onChanged: (v) {
                  if (v.trim().isEmpty && q.hasCity) _setCity(null);
                },
                onSubmitted: (v) {
                  if (_options(v).isNotEmpty) {
                    onFieldSubmitted();
                  } else {
                    _setCity(v);
                  }
                },
                style: theme.bodyMedium.override(fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: context.t('ui_city_hint'),
                  hintStyle: theme.bodyMedium.override(color: theme.secondaryText),
                  isDense: true,
                  filled: true,
                  fillColor: theme.alternate,
                  prefixIcon: Icon(Icons.place_outlined, size: 20, color: theme.secondaryText),
                  suffixIcon: q.hasCity
                      ? IconButton(
                          tooltip: context.t('ui_clear_city'),
                          icon: Icon(Icons.close_rounded, size: 18, color: theme.secondaryText),
                          onPressed: () {
                            ctrl.clear();
                            _setCity(null);
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  enabledBorder: border(theme.tertiary),
                  focusedBorder: border(theme.primary, 1.6),
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: c.maxWidth, maxHeight: 260),
                  child: Material(
                    elevation: 8,
                    color: theme.secondaryBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(TGRadius.input),
                      side: BorderSide(color: theme.tertiary),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      children: [
                        for (final o in options)
                          InkWell(
                            onTap: () => onSelected(o),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(child: Text(o.name, style: theme.bodyMedium.override(fontWeight: FontWeight.w700))),
                                  Text(
                                    o.listings == 0 ? context.t('ui_no_listings') : '${o.listings}',
                                    style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (popular.isNotEmpty) ...[
          const SizedBox(height: 10),
          _GroupLabel(context.t('ui_popular_cities')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in popular)
                _PillChip(
                  label: name,
                  selected: q.hasCity && TGGeo.sameName(q.city!, name),
                  onTap: () {
                    _ctrl.text = name;
                    _setCity(name);
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        _GroupLabel(context.t('ui_voivodeship')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in voivodeships)
              _PillChip(
                label: v,
                selected: q.voivodeships.any((s) => TGGeo.sameName(s, v)),
                onTap: () {
                  final next = {...q.voivodeships};
                  final existing = next.where((s) => TGGeo.sameName(s, v)).toList();
                  if (existing.isEmpty) {
                    next.add(v);
                  } else {
                    next.removeAll(existing);
                  }
                  widget.onChanged(q.copyWith(voivodeships: next));
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.t('ui_radius_hint'),
          style: theme.bodySmall.override(color: theme.secondaryText),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// More filters
// ---------------------------------------------------------------------------

class _MoreFilters extends StatefulWidget {
  const _MoreFilters({required this.all, required this.query, required this.onChanged});

  final List<TGProduct> all;
  final TGProductsQueryState query;
  final ValueChanged<TGProductsQueryState> onChanged;

  @override
  State<_MoreFilters> createState() => _MoreFiltersState();
}

class _MoreFiltersState extends State<_MoreFilters> {
  late final TextEditingController _brandCtrl = TextEditingController(text: widget.query.brand ?? '');
  final FocusNode _brandFocus = FocusNode();

  @override
  void didUpdateWidget(covariant _MoreFilters old) {
    super.didUpdateWidget(old);
    final b = widget.query.brand ?? '';
    if (old.query.brand != widget.query.brand && _brandCtrl.text != b && !_brandFocus.hasFocus) {
      _brandCtrl.text = b;
    }
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _brandFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final q = widget.query;
    final brandOptions = widget.all.map(productBrand).where((b) => b.trim().isNotEmpty).toSet().toList()..sort();

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(TGRadius.input),
          borderSide: BorderSide(color: c, width: w),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GroupLabel(context.t('ui_power_type')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in TGPowerType.values)
              _PillChip(
                label: switch (p) {
                  TGPowerType.electric => context.t('ui_electric'),
                  TGPowerType.gas => context.t('ui_gas'),
                  TGPowerType.other => context.t('ui_other'),
                },
                selected: q.powerTypes.contains(p),
                onTap: () {
                  final next = {...q.powerTypes};
                  if (!next.add(p)) next.remove(p);
                  widget.onChanged(q.copyWith(powerTypes: next));
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        _GroupLabel(context.t('ui_delivery')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PillChip(label: context.t('ui_any'), selected: q.delivery == null, onTap: () => widget.onChanged(q.copyWith(deliveryToNull: true))),
            _PillChip(label: context.t('ui_yes'), selected: q.delivery == true, onTap: () => widget.onChanged(q.copyWith(delivery: true))),
            _PillChip(label: context.t('ui_no'), selected: q.delivery == false, onTap: () => widget.onChanged(q.copyWith(delivery: false))),
          ],
        ),
        const SizedBox(height: 14),
        _GroupLabel(context.t('ui_pickup')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PillChip(label: context.t('ui_any'), selected: q.pickup == null, onTap: () => widget.onChanged(q.copyWith(pickupToNull: true))),
            _PillChip(label: context.t('ui_yes'), selected: q.pickup == true, onTap: () => widget.onChanged(q.copyWith(pickup: true))),
            _PillChip(label: context.t('ui_no'), selected: q.pickup == false, onTap: () => widget.onChanged(q.copyWith(pickup: false))),
          ],
        ),
        const SizedBox(height: 14),
        _GroupLabel(context.t('ui_warranty_months')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final w in const <int?>[null, 6, 12, 24])
              _PillChip(
                label: w == null ? context.t('ui_any') : '$w+',
                selected: q.warrantyMinMonths == w,
                onTap: () => widget.onChanged(w == null ? q.copyWith(warrantyToNull: true) : q.copyWith(warrantyMinMonths: w)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _GroupLabel(context.t('ui_seller_type')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in TGSellerType.values)
              _PillChip(
                label: t == TGSellerType.store ? context.t('ui_store') : context.t('ui_private'),
                selected: q.sellerTypes.contains(t),
                onTap: () {
                  final next = {...q.sellerTypes};
                  if (!next.add(t)) next.remove(t);
                  widget.onChanged(q.copyWith(sellerTypes: next));
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        _GroupLabel(context.t('ui_brand')),
        LayoutBuilder(
          builder: (context, c) => RawAutocomplete<String>(
            textEditingController: _brandCtrl,
            focusNode: _brandFocus,
            optionsBuilder: (value) {
              final t = value.text.trim().toLowerCase();
              if (t.isEmpty) return const Iterable<String>.empty();
              return brandOptions.where((b) => b.toLowerCase().contains(t)).take(8);
            },
            onSelected: (v) => widget.onChanged(q.copyWith(brand: v)),
            fieldViewBuilder: (context, ctrl, focus, onSubmitted) => TextField(
              controller: ctrl,
              focusNode: focus,
              onChanged: (v) {
                if (v.trim().isEmpty && q.hasBrand) widget.onChanged(q.copyWith(brandToNull: true));
              },
              onSubmitted: (v) => widget.onChanged(v.trim().isEmpty ? q.copyWith(brandToNull: true) : q.copyWith(brand: v.trim())),
              style: theme.bodyMedium.override(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: context.t('ui_search_brand'),
                hintStyle: theme.bodyMedium.override(color: theme.secondaryText),
                isDense: true,
                filled: true,
                fillColor: theme.alternate,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                enabledBorder: border(theme.tertiary),
                focusedBorder: border(theme.primary, 1.6),
              ),
            ),
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth, maxHeight: 240),
                child: Material(
                  elevation: 8,
                  color: theme.secondaryBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(TGRadius.input),
                    side: BorderSide(color: theme.tertiary),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    children: [
                      for (final opt in options)
                        InkWell(
                          onTap: () => onSelected(opt),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(opt, style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _FiltersSkeleton extends StatelessWidget {
  const _FiltersSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget bar(double h, [double? w]) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(color: theme.alternate, borderRadius: BorderRadius.circular(10)),
        );
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar(16, 120),
          const SizedBox(height: 18),
          for (var i = 0; i < 5; i++) ...[bar(14, 90), const SizedBox(height: 12), bar(44), const SizedBox(height: 22)],
        ],
      ),
    );
  }
}
