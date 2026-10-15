import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/tg_components/tg_watermarked_image.dart';
import 'package:twoja_gastromania/tg_models/tg_watermark.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/restaurants/restaurant_l10n.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:url_launcher/url_launcher.dart';

String restoInvCatLabel(BuildContext context, RestaurantInventoryCategory c) {
  final key = switch (c) {
    RestaurantInventoryCategory.cooking => 'ui_cat_cooking',
    RestaurantInventoryCategory.refrigeration => 'ui_cat_refrigeration',
    RestaurantInventoryCategory.warewashing => 'ui_cat_warewashing',
    RestaurantInventoryCategory.foodPrep => 'ui_cat_food_prep',
    RestaurantInventoryCategory.stainlessFurniture => 'ui_cat_stainless',
    RestaurantInventoryCategory.barBeverage => 'ui_cat_bar',
    RestaurantInventoryCategory.other => 'ui_others',
  };
  final t = context.t(key);
  return t.isEmpty
      ? switch (c) {
          RestaurantInventoryCategory.cooking => 'Cooking',
          RestaurantInventoryCategory.refrigeration => 'Refrigeration',
          RestaurantInventoryCategory.warewashing => 'Warewashing',
          RestaurantInventoryCategory.foodPrep => 'Food prep',
          RestaurantInventoryCategory.stainlessFurniture => 'Furniture',
          RestaurantInventoryCategory.barBeverage => 'Bar',
          RestaurantInventoryCategory.other => 'Other',
        }
      : t;
}

String restoConditionLabel(BuildContext context, RestaurantInventoryCondition c) => switch (c) {
      RestaurantInventoryCondition.newItem => context.t('ui_condition_new'),
      RestaurantInventoryCondition.used => context.t('ui_condition_used'),
      RestaurantInventoryCondition.unknown => '—',
    };

class RestoInsideChips extends StatelessWidget {
  const RestoInsideChips({super.key, required this.listing, required this.onJump});
  final RestaurantListing listing;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final active = listing.inventory.where((i) => i.status == RestaurantInventoryStatus.active && i.availability != RestaurantInventoryAvailability.excluded);
    if (active.isEmpty) return const SizedBox.shrink();
    final counts = <RestaurantInventoryCategory, int>{};
    for (final i in active) {
      counts[i.category] = (counts[i.category] ?? 0) + i.qty;
    }
    final total = active.fold<int>(0, (a, b) => a + b.qty);
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text(context.t('ui_inside_business'), style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
            Text(context.t('ui_items_n', {'n': '$total'}), style: theme.bodySmall.override(fontWeight: FontWeight.w700, color: theme.secondaryText)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final e in counts.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text('${restoInvCatLabel(context, e.key)} ${e.value}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    onPressed: onJump,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class RestoKeyFigures extends StatelessWidget {
  const RestoKeyFigures({super.key, required this.listing, required this.money});
  final RestaurantListing listing;
  final String Function(int?) money;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final lease = listing.leaseEndsAt == null
        ? (listing.leaseType == RestaurantLeaseType.indefinite ? context.t('ui_indefinite') : '—')
        : DateFormat('d MMM yyyy').format(listing.leaseEndsAt!);
    final items = [
      (context.t('ui_area_label'), '${listing.totalAreaM2.toStringAsFixed(0)} m²'),
      (context.t('ui_rent_label'), money(listing.rentMonthly)),
      (context.t('ui_transfer_fee'), listing.transferFee.isNone ? context.t('ui_none') : money(listing.transferFee.amountPln)),
      (context.t('ui_lease_until_label'), lease),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('ui_key_figures'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth < 480 ? 2 : 4;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              children: [
                for (final it in items)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.alternate),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(it.$1, style: theme.bodySmall.override(color: theme.secondaryText)),
                        const SizedBox(height: 4),
                        Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class RestoDescription extends StatelessWidget {
  const RestoDescription({
    super.key,
    required this.listing,
    required this.open,
    required this.maxLines,
    required this.onToggle,
    this.editing = false,
    this.descCtrl,
    this.onAdminEdit,
  });
  final RestaurantListing listing;
  final bool open;
  final int maxLines;
  final VoidCallback onToggle;
  final bool editing;
  final TextEditingController? descCtrl;
  final VoidCallback? onAdminEdit;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(context.t('ui_description'), style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
            if (onAdminEdit != null)
              TextButton(
                onPressed: onAdminEdit,
                child: Text(context.t('ui_admin_edit_page'), style: const TextStyle(fontWeight: FontWeight.w800, color: TGColors.cta)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (editing && descCtrl != null)
          TextField(
            controller: descCtrl,
            maxLines: 8,
            decoration: InputDecoration(hintText: context.t('ui_description')),
          )
        else ...[
          Text(listing.description, maxLines: open ? 999 : maxLines, overflow: TextOverflow.ellipsis),
          TextButton(
            onPressed: onToggle,
            child: Text(
              open ? context.t('ui_show_less') : context.t('ui_show_more'),
              style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }
}

class RestoEquipmentSection extends StatelessWidget {
  const RestoEquipmentSection({super.key, required this.listing, required this.catalogue, required this.onPhoto});
  final RestaurantListing listing;
  final List<TGProduct> catalogue;
  final void Function(List<String> urls, int index) onPhoto;

  TGProduct? _linked(RestaurantInventoryItem item) {
    if (item.linkedListingNo == null) return null;
    for (final p in catalogue) {
      if (p.listingNo == item.linkedListingNo && p.isPubliclyVisible) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    if (listing.equipmentIncluded == RestaurantEquipmentIncluded.none) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('ui_equipment_inventory'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(context.t('ui_equipment_none')),
        ],
      );
    }
    final active = listing.publicInventory;
    final separate = active.where((i) => i.availability == RestaurantInventoryAvailability.maySellSeparately).take(3).toList();
    final rest = active
        .where((i) => i.availability != RestaurantInventoryAvailability.maySellSeparately || !separate.contains(i))
        .where((i) => i.availability != RestaurantInventoryAvailability.excluded)
        .toList();
    final excluded = active.where((i) => i.availability == RestaurantInventoryAvailability.excluded).toList();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('ui_equipment_inventory'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        if (separate.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(context.t('ui_sold_separately'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(context.t('ui_also_listed_separately'), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 12),
          if (phone)
            SizedBox(
              height: 420,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: separate.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => SizedBox(width: 260, child: _separateCard(context, separate[i])),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final w = ((c.maxWidth - 32) / 3).clamp(220.0, 320.0);
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final item in separate) SizedBox(width: w, child: _separateCard(context, item)),
                  ],
                );
              },
            ),
        ],
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(context.t('ui_included_in_transfer'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final cols = phone ? 2 : (c.maxWidth >= 900 ? 4 : 3);
              final gap = 12.0;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in rest) SizedBox(width: w, child: _gridTile(context, item)),
                ],
              );
            },
          ),
        ],
        if (excluded.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(context.t('ui_not_included_transfer'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in excluded) SizedBox(width: phone ? 160 : 180, child: _gridTile(context, item, muted: true)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _separateCard(BuildContext context, RestaurantInventoryItem item) {
    final linked = _linked(item);
    if (linked != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF5C5A32),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              context.t('ui_also_listed_separately'),
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          TGProductCard(product: linked, showSeller: true),
        ],
      );
    }
    return _InventoryMiniCard(item: item, onPhoto: onPhoto, badge: context.t('ui_sold_separately'));
  }

  Widget _gridTile(BuildContext context, RestaurantInventoryItem item, {bool muted = false}) {
    return Opacity(
      opacity: muted ? 0.65 : 1,
      child: _InventoryMiniCard(item: item, onPhoto: onPhoto),
    );
  }
}

class _InventoryMiniCard extends StatelessWidget {
  const _InventoryMiniCard({required this.item, required this.onPhoto, this.badge});
  final RestaurantInventoryItem item;
  final void Function(List<String> urls, int index) onPhoto;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final name = restoLocalizedInventoryName(context, item);
    final photos = TGListingImages.photosForInventory(nameKey: item.name, photos: item.photos);
    final cover = photos.first;
    return Material(
      color: TGColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onPhoto(photos, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: WatermarkedImage(url: cover, surface: TGImageSurface.listingCard, fit: BoxFit.cover),
                  ),
                  if (badge != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: TGColors.accent, borderRadius: BorderRadius.circular(999)),
                        child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    [if (item.brand != null) item.brand, if (item.model != null) item.model, '×${item.qty}'].whereType<String>().join(' · '),
                    style: theme.bodySmall.override(color: theme.secondaryText, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(restoConditionLabel(context, item.condition), style: theme.bodySmall.override(fontWeight: FontWeight.w800, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RestoPremisesTable extends StatelessWidget {
  const RestoPremisesTable({super.key, required this.listing});
  final RestaurantListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final yes = context.t('ui_yes');
    final no = context.t('ui_no');
    final rows = <(String, String)>[
      (context.t('ui_total_area'), '${listing.totalAreaM2.toStringAsFixed(0)} m²'),
      if (listing.seats != null) (context.t('ui_seats'), '${listing.seats}'),
      if (listing.terraceM2 != null) (context.t('ui_terrace'), '${listing.terraceM2!.toStringAsFixed(0)} m²'),
      if (listing.floorLevel != null) (context.t('ui_floor'), '${listing.floorLevel}'),
      (context.t('ui_parking'), listing.parking ? yes : no),
      if (listing.powerKw != null) (context.t('ui_electricity'), '${listing.powerKw!.toStringAsFixed(0)} kW'),
      (context.t('ui_gas_connection'), listing.gasConnection ? yes : no),
      (context.t('ui_ventilation'), listing.extractionSystem ? yes : no),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('ui_the_premises'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _kvTable(context, rows),
      ],
    );
  }
}

class RestoLeaseTable extends StatelessWidget {
  const RestoLeaseTable({super.key, required this.listing, required this.money, required this.basisLabel});
  final RestaurantListing listing;
  final String Function(int?) money;
  final String Function(RestaurantVatBasis) basisLabel;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final r = listing;
    final yes = context.t('ui_yes');
    final no = context.t('ui_no');
    final fee = r.transferFee.isNone
        ? context.t('ui_no_transfer_fee')
        : '${money(r.transferFee.amountPln)} · ${basisLabel(r.transferFee.basis)}${r.negotiable ? ' · ${context.t('ui_negotiable')}' : ''}';
    final rows = <(String, String)>[
      (context.t('ui_monthly_rent_label'), '${money(r.rentMonthly)} · ${basisLabel(r.rentBasis)}'),
      if (r.depositPln != null) (context.t('ui_deposit'), money(r.depositPln)),
      (context.t('ui_lease_type'), r.leaseType == RestaurantLeaseType.fixed ? context.t('ui_fixed_term') : context.t('ui_indefinite')),
      if (r.leaseEndsAt != null) (context.t('ui_lease_ends'), DateFormat('d MMM yyyy').format(r.leaseEndsAt!)),
      (
        context.t('ui_landlord_consent'),
        switch (r.landlordConsent) {
          RestaurantLandlordConsent.yes => yes,
          RestaurantLandlordConsent.no => no,
          RestaurantLandlordConsent.toBeArranged => context.t('ui_to_be_arranged'),
        }
      ),
      (context.t('ui_transfer_fee'), fee),
      (
        context.t('ui_staff_takeover'),
        switch (r.staffTakeover) {
          RestaurantStaffTakeover.yes => yes,
          RestaurantStaffTakeover.no => no,
          RestaurantStaffTakeover.negotiable => context.t('ui_negotiable'),
        }
      ),
      (context.t('ui_reason_for_sale'), r.reasonForSale),
      (context.t('ui_available_from_label'), DateFormat('d MMM yyyy').format(r.availableFrom)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('ui_lease_transfer'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _kvTable(context, rows),
      ],
    );
  }
}

class RestoMonthlyCosts extends StatelessWidget {
  const RestoMonthlyCosts({super.key, required this.listing, required this.money});
  final RestaurantListing listing;
  final String Function(int?) money;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final lines = listing.costLines;
    var netTotal = 0.0;
    var unknown = 0;
    for (final l in lines) {
      if (l.basis == RestaurantCostBasis.unspecified) {
        unknown++;
        continue;
      }
      netTotal += l.basis == RestaurantCostBasis.brutto ? l.amountPln / 1.23 : l.amountPln.toDouble();
    }
    String period(RestaurantCostPeriod p) => switch (p) {
          RestaurantCostPeriod.lastBill => context.t('ui_cost_last_bill'),
          RestaurantCostPeriod.avg12m => context.t('ui_cost_avg_12m'),
          RestaurantCostPeriod.estimate => context.t('ui_cost_estimate'),
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('ui_monthly_costs'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(context.t('ui_declared_unverified'), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1.2), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1.4), 4: FlexColumnWidth(1)},
          children: [
            TableRow(children: [
              _th(context, context.t('ui_cost_item')),
              _th(context, context.t('ui_cost_amount')),
              _th(context, context.t('ui_cost_basis')),
              _th(context, context.t('ui_cost_period')),
              _th(context, context.t('ui_cost_in_rent')),
            ]),
            for (final l in lines)
              TableRow(children: [
                _td(l.label),
                _td(money(l.amountPln)),
                _td(l.basis.name),
                _td(period(l.period)),
                _td(l.includedInRent ? '✓' : ''),
              ]),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.t('ui_cost_net_total', {'amount': money(netTotal.round())}),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        if (unknown > 0)
          Text(context.t('ui_cost_unknown_vat', {'n': '$unknown'}), style: theme.bodySmall.override(color: theme.secondaryText)),
      ],
    );
  }
}

class RestoAdditionalInfo extends StatelessWidget {
  const RestoAdditionalInfo({super.key, required this.listing});
  final RestaurantListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final d = listing.details;
    final rows = <(String, String)>[];
    if (d.garden.kind != RestaurantGardenKind.none) {
      final fee = d.garden.lastFeePln != null ? ' · ${context.t('ui_last_fee', {'n': '${d.garden.lastFeePln}'})}' : '';
      rows.add((context.t('ui_garden_terrace'), '${d.garden.kind.name}${d.garden.areaM2 != null ? ' · ${d.garden.areaM2} m²' : ''}$fee'));
    }
    if (d.playArea.kind != RestaurantPlayAreaKind.none) {
      rows.add((context.t('ui_play_area'), '${d.playArea.kind.name}${d.playArea.areaM2 != null ? ' · ${d.playArea.areaM2} m²' : ''}'));
    }
    if (d.conceptMenu != null && d.conceptMenu!.isNotEmpty) rows.add((context.t('ui_concept_menu'), d.conceptMenu!));
    if (d.customersLocation != null && d.customersLocation!.isNotEmpty) rows.add((context.t('ui_customers_location'), d.customersLocation!));
    if (d.hoursSeasonality != null && d.hoursSeasonality!.isNotEmpty) rows.add((context.t('ui_hours_seasonality'), d.hoursSeasonality!));
    if (d.deliveryOnline) rows.add((context.t('ui_delivery_online'), context.t('ui_yes')));
    if (d.staffContracts != null && d.staffContracts!.isNotEmpty) rows.add((context.t('ui_staff_contracts'), d.staffContracts!));
    if (d.systems != null && d.systems!.isNotEmpty) rows.add((context.t('ui_systems'), d.systems!));
    if (d.brandAssets.isNotEmpty) rows.add((context.t('ui_brand_assets'), d.brandAssets.join(', ')));
    if (d.otherInfo != null && d.otherInfo!.isNotEmpty) rows.add((context.t('ui_other'), d.otherInfo!));
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('ui_additional_info'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(context.t('ui_declared_unverified'), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 8),
        _kvTable(context, rows),
      ],
    );
  }
}

class RestoLicencesBlock extends StatelessWidget {
  const RestoLicencesBlock({super.key, required this.listing, required this.money});
  final RestaurantListing listing;
  final String Function(int?) money;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final a = listing.alcoholPermit;
    final classLabel = a.classes.map((c) => switch (c) {
          RestaurantAlcoholClass.upTo45AndBeer => context.t('ui_alcohol_class_low'),
          RestaurantAlcoholClass.from45To18 => context.t('ui_alcohol_class_mid'),
          RestaurantAlcoholClass.over18 => context.t('ui_alcohol_class_high'),
        }).join(', ');
    final scopeLabel = a.scope
        .map((s) => s == RestaurantAlcoholScope.onPremises ? context.t('ui_alcohol_on_premises') : context.t('ui_alcohol_off_premises'))
        .join(', ');
    final revenue = listing.declaredMonthlyRevenue != null
        ? context.t('ui_monthly_revenue_line', {'amount': money(listing.declaredMonthlyRevenue)})
        : '';
    final asOf = listing.declaredAsOf != null ? ' · ${context.t('ui_as_of', {'d': DateFormat('MMM yyyy').format(listing.declaredAsOf!)})}' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('ui_licences_permits'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(context.t('ui_declared_unverified'), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 8),
        _kvTable(context, [
          (context.t('ui_alcohol_permit'), a.status.name),
          if (classLabel.isNotEmpty) (context.t('ui_alcohol_class'), classLabel),
          if (scopeLabel.isNotEmpty) (context.t('ui_scope'), scopeLabel),
          if (a.validUntil != null) (context.t('ui_valid_until'), DateFormat('d MMM yyyy').format(a.validUntil!)),
          (context.t('ui_sanitary_approval'), listing.sanitaryApproval ? context.t('ui_yes') : context.t('ui_no')),
        ]),
        if (listing.declaredMonthlyRevenue != null) ...[
          const SizedBox(height: 16),
          Text(context.t('ui_financials_declared'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(context.t('ui_declared_unverified'), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 6),
          Text('$revenue$asOf', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
        if (listing.documents.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(context.t('ui_documents_seller_can_show'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(context.t('ui_declared_by_seller'), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in listing.documents)
                Chip(label: Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
            ],
          ),
        ],
      ],
    );
  }
}

class RestoLocationBlock extends StatelessWidget {
  const RestoLocationBlock({super.key, required this.listing});
  final RestaurantListing listing;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final r = listing;
    final maps = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(r.fullAddress)}',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t('ui_location'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Container(
          height: 160,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEF2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.alternate),
          ),
          child: Text(context.t('ui_map_city', {'city': r.city}), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        Text(r.fullAddress, style: const TextStyle(fontWeight: FontWeight.w800)),
        TextButton(
          onPressed: () => launchUrl(maps, mode: LaunchMode.externalApplication),
          child: Text(context.t('ui_get_directions'), style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class RestoSafetyTips extends StatelessWidget {
  const RestoSafetyTips({super.key, this.onReport});
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final tips = [
      context.t('ui_resto_safety_1'),
      context.t('ui_resto_safety_2'),
      context.t('ui_resto_safety_3'),
      context.t('ui_resto_safety_4'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.alternate),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('ui_safety_tips'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(context.t('ui_resto_safety_disclaimer'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final t in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('·  '),
                  Expanded(child: Text(t)),
                ],
              ),
            ),
          if (onReport != null)
            TextButton.icon(
              onPressed: onReport,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: Text(context.t('ui_report_listing')),
            ),
        ],
      ),
    );
  }
}

Widget _kvTable(BuildContext context, List<(String, String)> rows) {
  return Table(
    columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(2)},
    children: [
      for (final r in rows)
        TableRow(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Semantics(
              header: true,
              child: Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(r.$2),
          ),
        ]),
    ],
  );
}

Widget _th(BuildContext context, String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Semantics(header: true, child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
    );

Widget _td(String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(t, style: const TextStyle(fontSize: 12)),
    );
