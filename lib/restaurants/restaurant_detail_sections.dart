import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/restaurants/restaurant_l10n.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
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

String restoConditionLabel(RestaurantInventoryCondition c) => switch (c) {
      RestaurantInventoryCondition.newItem => 'NOWY',
      RestaurantInventoryCondition.used => 'UŻYWANY',
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
        ? (listing.leaseType == RestaurantLeaseType.indefinite ? 'Indefinite' : '—')
        : DateFormat('d MMM yyyy').format(listing.leaseEndsAt!);
    final items = [
      ('Area', '${listing.totalAreaM2.toStringAsFixed(0)} m²'),
      ('Rent', money(listing.rentMonthly)),
      ('Transfer fee', listing.transferFee.isNone ? 'None' : money(listing.transferFee.amountPln)),
      ('Lease until', lease),
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
  const RestoDescription({super.key, required this.listing, required this.open, required this.maxLines, required this.onToggle});
  final RestaurantListing listing;
  final bool open;
  final int maxLines;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Description', style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(listing.description, maxLines: open ? 999 : maxLines, overflow: TextOverflow.ellipsis),
        TextButton(onPressed: onToggle, child: Text(open ? 'Show less' : 'Show more', style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800))),
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
    final active = listing.inventory.where((i) => i.status == RestaurantInventoryStatus.active || i.status == RestaurantInventoryStatus.soldSeparatelyPending).toList();
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
    return Material(
      color: const Color(0xFF1F1F1F),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: item.photos.isEmpty ? null : () => onPhoto(item.photos, 0),
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
                    child: item.photos.isEmpty
                        ? ColoredBox(color: theme.primaryBackground, child: const Icon(Icons.kitchen_outlined))
                        : TGSmartImage(url: item.photos.first, fit: BoxFit.cover),
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
                  Text(restoConditionLabel(item.condition), style: theme.bodySmall.override(fontWeight: FontWeight.w800, fontSize: 11)),
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
    final rows = <(String, String)>[
      ('Total area', '${listing.totalAreaM2.toStringAsFixed(0)} m²'),
      if (listing.seats != null) ('Seats', '${listing.seats}'),
      if (listing.terraceM2 != null) ('Terrace', '${listing.terraceM2!.toStringAsFixed(0)} m²'),
      if (listing.floorLevel != null) ('Floor', '${listing.floorLevel}'),
      ('Parking', listing.parking ? 'Yes' : 'No'),
      if (listing.powerKw != null) ('Electricity', '${listing.powerKw!.toStringAsFixed(0)} kW'),
      ('Gas', listing.gasConnection ? 'Yes' : 'No'),
      ('Ventilation / extraction', listing.extractionSystem ? 'Yes' : 'No'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('The premises', style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
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
    final fee = r.transferFee.isNone
        ? 'No transfer fee'
        : '${money(r.transferFee.amountPln)} · ${basisLabel(r.transferFee.basis)}${r.negotiable ? ' · negotiable' : ''}';
    final rows = <(String, String)>[
      ('Monthly rent', '${money(r.rentMonthly)} · ${basisLabel(r.rentBasis)}'),
      if (r.depositPln != null) ('Deposit', money(r.depositPln)),
      ('Lease type', r.leaseType == RestaurantLeaseType.fixed ? 'Fixed term' : 'Indefinite'),
      if (r.leaseEndsAt != null) ('Lease ends', DateFormat('d MMM yyyy').format(r.leaseEndsAt!)),
      (
        'Landlord consent for transfer',
        switch (r.landlordConsent) {
          RestaurantLandlordConsent.yes => 'Yes',
          RestaurantLandlordConsent.no => 'No',
          RestaurantLandlordConsent.toBeArranged => 'To be arranged',
        }
      ),
      ('Transfer fee', fee),
      (
        'Staff takeover',
        switch (r.staffTakeover) {
          RestaurantStaffTakeover.yes => 'Yes',
          RestaurantStaffTakeover.no => 'No',
          RestaurantStaffTakeover.negotiable => 'Negotiable',
        }
      ),
      ('Reason for sale', r.reasonForSale),
      ('Available from', DateFormat('d MMM yyyy').format(r.availableFrom)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lease & transfer', style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
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
          RestaurantCostPeriod.lastBill => 'last bill',
          RestaurantCostPeriod.avg12m => '12-month average',
          RestaurantCostPeriod.estimate => 'estimate',
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Monthly costs (declared)', style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Declared by the seller · not verified', style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1.2), 2: FlexColumnWidth(1), 3: FlexColumnWidth(1.4), 4: FlexColumnWidth(1)},
          children: [
            TableRow(children: [
              _th(context, 'Item'),
              _th(context, 'Amount'),
              _th(context, 'Basis'),
              _th(context, 'Period'),
              _th(context, 'In rent'),
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
          'Total of items with VAT basis: ${money(netTotal.round())} net',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        if (unknown > 0)
          Text('$unknown items without VAT basis are not included', style: theme.bodySmall.override(color: theme.secondaryText)),
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
      final fee = d.garden.lastFeePln != null ? ' · last fee ${d.garden.lastFeePln} PLN' : '';
      rows.add(('Garden/terrace', '${d.garden.kind.name}${d.garden.areaM2 != null ? ' · ${d.garden.areaM2} m²' : ''}$fee'));
    }
    if (d.playArea.kind != RestaurantPlayAreaKind.none) {
      rows.add(('Play area', '${d.playArea.kind.name}${d.playArea.areaM2 != null ? ' · ${d.playArea.areaM2} m²' : ''}'));
    }
    if (d.conceptMenu != null && d.conceptMenu!.isNotEmpty) rows.add(('Concept & menu', d.conceptMenu!));
    if (d.customersLocation != null && d.customersLocation!.isNotEmpty) rows.add(('Customers & location', d.customersLocation!));
    if (d.hoursSeasonality != null && d.hoursSeasonality!.isNotEmpty) rows.add(('Opening hours & seasonality', d.hoursSeasonality!));
    if (d.deliveryOnline) rows.add(('Delivery & online presence', 'Yes'));
    if (d.staffContracts != null && d.staffContracts!.isNotEmpty) rows.add(('Staff & contracts', d.staffContracts!));
    if (d.systems != null && d.systems!.isNotEmpty) rows.add(('Systems', d.systems!));
    if (d.brandAssets.isNotEmpty) rows.add(('Brand & assets included', d.brandAssets.join(', ')));
    if (d.otherInfo != null && d.otherInfo!.isNotEmpty) rows.add(('Other', d.otherInfo!));
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Additional information', style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Declared by the seller · not verified', style: theme.bodySmall.override(color: theme.secondaryText)),
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
          RestaurantAlcoholClass.upTo45AndBeer => 'up to 4.5% & beer',
          RestaurantAlcoholClass.from45To18 => '4.5–18%',
          RestaurantAlcoholClass.over18 => 'over 18%',
        }).join(', ');
    final scopeLabel = a.scope.map((s) => s == RestaurantAlcoholScope.onPremises ? 'on-premises' : 'off-premises').join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Licences & permits', style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Declared by the seller · not verified', style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 8),
        _kvTable(context, [
          ('Alcohol permit', a.status.name),
          if (classLabel.isNotEmpty) ('Alcohol class', classLabel),
          if (scopeLabel.isNotEmpty) ('Scope', scopeLabel),
          if (a.validUntil != null) ('Valid until', DateFormat('d MMM yyyy').format(a.validUntil!)),
          ('Sanitary approval', listing.sanitaryApproval ? 'Yes' : 'No'),
        ]),
        if (listing.declaredMonthlyRevenue != null) ...[
          const SizedBox(height: 16),
          Text('Financials (declared)', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Declared by the seller · not verified', style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 6),
          Text(
            'Monthly revenue ${money(listing.declaredMonthlyRevenue)}${listing.declaredAsOf != null ? ' · as of ${DateFormat('MMM yyyy').format(listing.declaredAsOf!)}' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
        if (listing.documents.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Documents the seller can show', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Declared by the seller', style: theme.bodySmall.override(color: theme.secondaryText)),
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
        Text('Location', style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
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
          child: Text('Map · ${r.city}', style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        Text(r.fullAddress, style: const TextStyle(fontWeight: FontWeight.w800)),
        TextButton(
          onPressed: () => launchUrl(maps, mode: LaunchMode.externalApplication),
          child: const Text('Get directions', style: TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800)),
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
    const tips = [
      'Inspect the lease, landlord consent and permits yourself before paying anything.',
      'Never send a deposit or advance before you have seen the lease documents.',
      'Confirm who is authorized to transfer the premises.',
      'Meet at the premises and verify utilities and inventory on site.',
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
          Text('Safety tips', style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
            'Twoja Gastromania does not verify leases, permits or finances and never holds funds.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
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
              label: const Text('Report listing'),
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
