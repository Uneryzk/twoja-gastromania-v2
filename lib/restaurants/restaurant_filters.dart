import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/products/tg_geo.dart';
import 'package:twoja_gastromania/restaurants/restaurant_l10n.dart';
import 'package:twoja_gastromania/restaurants/restaurant_logic.dart';
import 'package:twoja_gastromania/restaurants/restaurant_query.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';

/// Desktop sticky filter panel (#1F1F1F, radius 16, accordion sections).
class RestaurantFiltersPanel extends StatelessWidget {
  const RestaurantFiltersPanel({
    super.key,
    required this.query,
    required this.all,
    required this.onChanged,
    this.loading = false,
  });

  final RestaurantQueryState query;
  final List<RestaurantListing> all;
  final ValueChanged<RestaurantQueryState> onChanged;
  final bool loading;

  void _emit(RestaurantQueryState next) {
    TGAnalytics.track('resto_filter_applied', {'filters': next.activeFilterCount});
    onChanged(next.copyWith(page: 1, mobileShown: kRestoMobilePageSize));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    if (loading) {
      return Container(
        height: 480,
        decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Semantics(
      label: 'Restaurant filters',
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2F2F2F)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Filters', style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                const Spacer(),
                if (query.activeFilterCount > 0)
                  TextButton(
                    onPressed: () => _emit(query.clearedFilters()),
                    child: const Text('Clear all'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _section(
              theme,
              'Verified seller',
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('Verified only', style: theme.bodyMedium.override(fontWeight: FontWeight.w600)),
                activeThumbColor: Colors.greenAccent.shade400,
                value: query.verifiedOnly,
                onChanged: (v) => _emit(query.copyWith(verifiedOnly: v)),
              ),
            ),
            _section(
              theme,
              'Business type',
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: RestaurantBusinessType.values.map((t) {
                  final on = query.businessTypes.contains(t);
                  return FilterChip(
                    label: Text(restoLocalizedBusinessType(context, t)),
                    selected: on,
                    onSelected: (sel) {
                      final next = {...query.businessTypes};
                      sel ? next.add(t) : next.remove(t);
                      _emit(query.copyWith(businessTypes: next));
                    },
                  );
                }).toList(),
              ),
            ),
            _section(
              theme,
              'Location',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: query.city ?? '',
                    decoration: const InputDecoration(labelText: 'City', isDense: true),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Any city')),
                      ...TGGeo.cities.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
                    ],
                    onChanged: (v) {
                      final empty = v == null || v.isEmpty;
                      _emit(query.copyWith(city: empty ? null : v, cityToNull: empty));
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Radius', style: theme.bodySmall),
                  Wrap(
                    spacing: 6,
                    children: [0, 10, 25, 50, 100].map((km) {
                      final on = query.radiusKm == km;
                      return ChoiceChip(
                        label: Text(km == 0 ? '+0 km' : '+$km km'),
                        selected: on,
                        onSelected: (_) => _emit(query.copyWith(radiusKm: km)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: const ['Śląskie', 'Małopolskie', 'Mazowieckie'].map((v) {
                      final on = query.voivodeships.contains(v);
                      return FilterChip(
                        label: Text(v),
                        selected: on,
                        onSelected: (sel) {
                          final next = {...query.voivodeships};
                          sel ? next.add(v) : next.remove(v);
                          _emit(query.copyWith(voivodeships: next));
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            _section(
              theme,
              'Area m²',
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: query.areaMin?.toString() ?? '',
                      decoration: const InputDecoration(labelText: 'Min', isDense: true),
                      keyboardType: TextInputType.number,
                      onFieldSubmitted: (v) {
                        final n = int.tryParse(v);
                        _emit(query.copyWith(areaMin: n, areaMinToNull: n == null));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: query.areaMax?.toString() ?? '',
                      decoration: const InputDecoration(labelText: 'Max', isDense: true),
                      keyboardType: TextInputType.number,
                      onFieldSubmitted: (v) {
                        final n = int.tryParse(v);
                        _emit(query.copyWith(areaMax: n, areaMaxToNull: n == null));
                      },
                    ),
                  ),
                ],
              ),
            ),
            _section(
              theme,
              'Monthly rent PLN',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<RestaurantVatBasis>(
                    segments: const [
                      ButtonSegment(value: RestaurantVatBasis.netto, label: Text('Netto')),
                      ButtonSegment(value: RestaurantVatBasis.brutto, label: Text('Brutto')),
                    ],
                    selected: {query.rentBasis == RestaurantVatBasis.brutto ? RestaurantVatBasis.brutto : RestaurantVatBasis.netto},
                    onSelectionChanged: (s) => _emit(query.copyWith(rentBasis: s.first)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: query.rentMax?.toString() ?? '',
                    decoration: const InputDecoration(labelText: 'Max rent', isDense: true),
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: (v) {
                      final n = int.tryParse(v);
                      _emit(query.copyWith(rentMax: n, rentMaxToNull: n == null));
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: query.includeVatUnspecified,
                    onChanged: (v) => _emit(query.copyWith(includeVatUnspecified: v ?? true)),
                    title: Text('Include listings without VAT info', style: theme.bodySmall),
                  ),
                ],
              ),
            ),
            _section(
              theme,
              'Transfer fee PLN',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    initialValue: query.feeMax?.toString() ?? '',
                    decoration: const InputDecoration(labelText: 'Max fee', isDense: true),
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: (v) {
                      final n = int.tryParse(v);
                      _emit(query.copyWith(feeMax: n, feeMaxToNull: n == null));
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: query.includeNoTransferFee,
                    onChanged: (v) => _emit(query.copyWith(includeNoTransferFee: v ?? true)),
                    title: Text('Include listings with no transfer fee', style: theme.bodySmall),
                  ),
                ],
              ),
            ),
            _section(
              theme,
              'Lease',
              Wrap(
                spacing: 6,
                children: RestaurantLeaseMin.values.map((m) {
                  final label = switch (m) {
                    RestaurantLeaseMin.any => 'Any',
                    RestaurantLeaseMin.m12 => '12+ mo',
                    RestaurantLeaseMin.m24 => '24+ mo',
                    RestaurantLeaseMin.m36 => '36+ mo',
                    RestaurantLeaseMin.indefinite => 'Indefinite lease',
                  };
                  return ChoiceChip(
                    label: Text(label),
                    selected: query.leaseMin == m,
                    onSelected: (_) => _emit(query.copyWith(leaseMin: m)),
                  );
                }).toList(),
              ),
            ),
            _section(
              theme,
              'Features',
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: RestaurantFeature.values.map((f) {
                  final on = query.features.contains(f);
                  return FilterChip(
                    label: Text(featureLabel(f)),
                    selected: on,
                    onSelected: (sel) {
                      final next = {...query.features};
                      sel ? next.add(f) : next.remove(f);
                      _emit(query.copyWith(features: next));
                    },
                  );
                }).toList(),
              ),
            ),
            _section(
              theme,
              'Available',
              Wrap(
                spacing: 6,
                children: [
                  (RestaurantAvailFilter.any, 'Any'),
                  (RestaurantAvailFilter.immediately, 'Immediately'),
                  (RestaurantAvailFilter.within1m, 'Within 1 month'),
                  (RestaurantAvailFilter.within3m, 'Within 3 months'),
                ].map((e) {
                  return ChoiceChip(
                    label: Text(e.$2),
                    selected: query.avail == e.$1,
                    onSelected: (_) => _emit(query.copyWith(avail: e.$1)),
                  );
                }).toList(),
              ),
            ),
            _section(
              theme,
              'Seller',
              Wrap(
                spacing: 6,
                children: [
                  FilterChip(
                    label: const Text('Owner'),
                    selected: query.sellerFilters.contains(RestaurantSellerFilter.owner),
                    onSelected: (sel) {
                      final next = {...query.sellerFilters};
                      sel ? next.add(RestaurantSellerFilter.owner) : next.remove(RestaurantSellerFilter.owner);
                      _emit(query.copyWith(sellerFilters: next));
                    },
                  ),
                  FilterChip(
                    label: const Text('Agent'),
                    selected: query.sellerFilters.contains(RestaurantSellerFilter.agent),
                    onSelected: (sel) {
                      final next = {...query.sellerFilters};
                      sel ? next.add(RestaurantSellerFilter.agent) : next.remove(RestaurantSellerFilter.agent);
                      _emit(query.copyWith(sellerFilters: next));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${countRestaurantResults(all, query)} results',
              style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(FlutterFlowTheme theme, String title, Widget child) {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        initiallyExpanded: true,
        title: Text(title, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        children: [child],
      ),
    );
  }
}

/// Applied filter chips + Clear all.
class RestaurantAppliedChips extends StatelessWidget {
  const RestaurantAppliedChips({super.key, required this.query, required this.onChanged});

  final RestaurantQueryState query;
  final ValueChanged<RestaurantQueryState> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = <(String, VoidCallback)>[];
    if (query.verifiedOnly) {
      chips.add(('✔ Verified only', () => onChanged(query.copyWith(verifiedOnly: false, page: 1))));
    }
    for (final t in query.businessTypes) {
      chips.add((
        restoLocalizedBusinessType(context, t),
        () {
          final next = {...query.businessTypes}..remove(t);
          onChanged(query.copyWith(businessTypes: next, page: 1));
        },
      ));
    }
    if (query.hasCity) {
      chips.add(('City: ${query.city}', () => onChanged(query.copyWith(cityToNull: true, page: 1))));
    }
    if (query.rentMax != null) {
      chips.add(('Rent ≤ ${query.rentMax}', () => onChanged(query.copyWith(rentMaxToNull: true, page: 1))));
    }
    if (query.feeMax != null) {
      chips.add(('Fee ≤ ${query.feeMax}', () => onChanged(query.copyWith(feeMaxToNull: true, page: 1))));
    }
    for (final f in query.features) {
      chips.add((
        featureLabel(f),
        () {
          final next = {...query.features}..remove(f);
          onChanged(query.copyWith(features: next, page: 1));
        },
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final c in chips)
          InputChip(
            label: Text(c.$1),
            onDeleted: c.$2,
            deleteIconColor: TGColors.cta,
          ),
        TextButton(onPressed: () => onChanged(query.clearedFilters()), child: const Text('Clear all')),
      ],
    );
  }
}
