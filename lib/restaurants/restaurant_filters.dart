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
    final t = (String k) => context.t(k);
    if (loading) {
      return Container(
        height: 480,
        decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Semantics(
      label: context.t('ui_filters'),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2F2F2F)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(context.t('ui_filters'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (query.activeFilterCount > 0)
                    TextButton(
                      onPressed: () => _emit(query.clearedFilters()),
                      child: Text(context.t('ui_clear_all')),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _section(
                theme,
                context.t('ui_verified_seller'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(context.t('ui_verified_only'), style: theme.bodyMedium.override(fontWeight: FontWeight.w600)),
                  activeThumbColor: Colors.greenAccent.shade400,
                  value: query.verifiedOnly,
                  onChanged: (v) => _emit(query.copyWith(verifiedOnly: v)),
                ),
              ),
              _section(
                theme,
                context.t('ui_business_type'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: RestaurantBusinessType.values.map((bt) {
                    final on = query.businessTypes.contains(bt);
                    return FilterChip(
                      label: Text(restoLocalizedBusinessType(context, bt)),
                      selected: on,
                      onSelected: (sel) {
                        final next = {...query.businessTypes};
                        sel ? next.add(bt) : next.remove(bt);
                        _emit(query.copyWith(businessTypes: next));
                      },
                    );
                  }).toList(),
                ),
              ),
              _section(
                theme,
                context.t('ui_location'),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: query.city ?? '',
                      decoration: InputDecoration(labelText: context.t('ui_city'), isDense: true),
                      items: [
                        DropdownMenuItem(value: '', child: Text(context.t('ui_any_city'))),
                        ...TGGeo.cities.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
                      ],
                      onChanged: (v) {
                        final empty = v == null || v.isEmpty;
                        _emit(query.copyWith(city: empty ? null : v, cityToNull: empty));
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(context.t('ui_radius'), style: theme.bodySmall),
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
                context.t('ui_area_m2'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: query.areaMin?.toString() ?? '',
                        decoration: InputDecoration(labelText: context.t('ui_min'), isDense: true),
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
                        decoration: InputDecoration(labelText: context.t('ui_max'), isDense: true),
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
                context.t('ui_monthly_rent_pln'),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<RestaurantVatBasis>(
                      segments: [
                        ButtonSegment(value: RestaurantVatBasis.netto, label: Text(context.t('ui_netto'))),
                        ButtonSegment(value: RestaurantVatBasis.brutto, label: Text(context.t('ui_brutto'))),
                      ],
                      selected: {query.rentBasis == RestaurantVatBasis.brutto ? RestaurantVatBasis.brutto : RestaurantVatBasis.netto},
                      onSelectionChanged: (s) => _emit(query.copyWith(rentBasis: s.first)),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: query.rentMax?.toString() ?? '',
                      decoration: InputDecoration(labelText: context.t('ui_max_rent'), isDense: true),
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
                      title: Text(context.t('ui_include_vat_unspecified'), style: theme.bodySmall),
                    ),
                  ],
                ),
              ),
              _section(
                theme,
                context.t('ui_transfer_fee_pln'),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      initialValue: query.feeMax?.toString() ?? '',
                      decoration: InputDecoration(labelText: context.t('ui_max_fee'), isDense: true),
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
                      title: Text(context.t('ui_include_no_fee'), style: theme.bodySmall),
                    ),
                  ],
                ),
              ),
              _section(
                theme,
                context.t('ui_lease'),
                Wrap(
                  spacing: 6,
                  children: RestaurantLeaseMin.values.map((m) {
                    final label = switch (m) {
                      RestaurantLeaseMin.any => context.t('ui_lease_any'),
                      RestaurantLeaseMin.m12 => context.t('ui_lease_12mo'),
                      RestaurantLeaseMin.m24 => context.t('ui_lease_24mo'),
                      RestaurantLeaseMin.m36 => context.t('ui_lease_36mo'),
                      RestaurantLeaseMin.indefinite => context.t('ui_indefinite_lease'),
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
                context.t('ui_features'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: RestaurantFeature.values.map((f) {
                    final on = query.features.contains(f);
                    return FilterChip(
                      label: Text(featureLabel(f, t: t)),
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
                context.t('ui_available'),
                Wrap(
                  spacing: 6,
                  children: [
                    (RestaurantAvailFilter.any, context.t('ui_avail_any')),
                    (RestaurantAvailFilter.immediately, context.t('ui_avail_immediately')),
                    (RestaurantAvailFilter.within1m, context.t('ui_avail_1m')),
                    (RestaurantAvailFilter.within3m, context.t('ui_avail_3m')),
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
                context.t('ui_seller'),
                Wrap(
                  spacing: 6,
                  children: [
                    FilterChip(
                      label: Text(context.t('resto_poster_owner')),
                      selected: query.sellerFilters.contains(RestaurantSellerFilter.owner),
                      onSelected: (sel) {
                        final next = {...query.sellerFilters};
                        sel ? next.add(RestaurantSellerFilter.owner) : next.remove(RestaurantSellerFilter.owner);
                        _emit(query.copyWith(sellerFilters: next));
                      },
                    ),
                    FilterChip(
                      label: Text(context.t('resto_poster_agent')),
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
                localizedResultsCount(context, countRestaurantResults(all, query)),
                style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700),
              ),
            ],
          ),
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
    final t = (String k) => context.t(k);
    final chips = <(String, VoidCallback)>[];
    if (query.verifiedOnly) {
      chips.add(('✔ ${context.t('ui_verified_only')}', () => onChanged(query.copyWith(verifiedOnly: false, page: 1))));
    }
    for (final bt in query.businessTypes) {
      chips.add((
        restoLocalizedBusinessType(context, bt),
        () {
          final next = {...query.businessTypes}..remove(bt);
          onChanged(query.copyWith(businessTypes: next, page: 1));
        },
      ));
    }
    if (query.hasCity) {
      chips.add((context.t('ui_city_chip', {'c': '${query.city}'}), () => onChanged(query.copyWith(cityToNull: true, page: 1))));
    }
    if (query.rentMax != null) {
      chips.add((context.t('ui_rent_lte', {'n': '${query.rentMax}'}), () => onChanged(query.copyWith(rentMaxToNull: true, page: 1))));
    }
    if (query.feeMax != null) {
      chips.add((context.t('ui_fee_lte', {'n': '${query.feeMax}'}), () => onChanged(query.copyWith(feeMaxToNull: true, page: 1))));
    }
    for (final f in query.features) {
      chips.add((
        featureLabel(f, t: t),
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
        TextButton(onPressed: () => onChanged(query.clearedFilters()), child: Text(context.t('ui_clear_all'))),
      ],
    );
  }
}
