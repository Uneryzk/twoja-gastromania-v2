import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:url_launcher/url_launcher.dart';

String restoInvCatLabel(RestaurantInventoryCategory c) => switch (c) {
      RestaurantInventoryCategory.cooking => 'Cooking',
      RestaurantInventoryCategory.refrigeration => 'Refrigeration',
      RestaurantInventoryCategory.warewashing => 'Warewashing',
      RestaurantInventoryCategory.foodPrep => 'Food prep',
      RestaurantInventoryCategory.stainlessFurniture => 'Furniture',
      RestaurantInventoryCategory.barBeverage => 'Bar',
      RestaurantInventoryCategory.other => 'Other',
    };

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
            Expanded(child: Text('Inside the business', style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
            Text('$total items', style: theme.bodySmall.override(fontWeight: FontWeight.w700, color: theme.secondaryText)),
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
                    label: Text('${restoInvCatLabel(e.key)} ${e.value}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
        Text('Key figures', style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
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

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    if (listing.equipmentIncluded == RestaurantEquipmentIncluded.none) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Equipment & inventory', style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Equipment is not included in the transfer.'),
        ],
      );
    }
    final active = listing.inventory.where((i) => i.status == RestaurantInventoryStatus.active).toList();
    final included = active.where((i) => i.availability != RestaurantInventoryAvailability.excluded).toList();
    final excluded = active.where((i) => i.availability == RestaurantInventoryAvailability.excluded).toList();

    Widget group(String title, List<RestaurantInventoryItem> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      final byCat = <RestaurantInventoryCategory, List<RestaurantInventoryItem>>{};
      for (final i in items) {
        byCat.putIfAbsent(i.category, () => []).add(i);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final e in byCat.entries) ...[
            Text(restoInvCatLabel(e.key), style: theme.bodyMedium.override(fontWeight: FontWeight.w800, color: TGColors.cta)),
            const SizedBox(height: 6),
            for (final item in e.value) _item(context, item),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Equipment & inventory', style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        group('Included', included),
        if (excluded.isNotEmpty) ...[
          const SizedBox(height: 8),
          group('Not included in the transfer', excluded),
        ],
      ],
    );
  }

  Widget _item(BuildContext context, RestaurantInventoryItem item) {
    final theme = FlutterFlowTheme.of(context);
    TGProduct? linked;
    if (item.availability == RestaurantInventoryAvailability.maySellSeparately && item.linkedListingNo != null) {
      for (final p in catalogue) {
        if (p.listingNo == item.linkedListingNo && p.isPubliclyVisible) {
          linked = p;
          break;
        }
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.photos.isNotEmpty)
                GestureDetector(
                  onTap: () => onPhoto(item.photos, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(width: 56, height: 56, child: TGSmartImage(url: item.photos.first, fit: BoxFit.cover)),
                  ),
                )
              else
                Container(width: 56, height: 56, color: theme.primaryBackground, child: const Icon(Icons.kitchen_outlined, size: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.name} · ×${item.qty}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      [if (item.brand != null) item.brand, if (item.model != null) item.model].whereType<String>().join(' · '),
                      style: theme.bodySmall.override(color: theme.secondaryText),
                    ),
                    Text(restoConditionLabel(item.condition), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          if (item.availability == RestaurantInventoryAvailability.maySellSeparately) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: TGColors.rating.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'Also listed separately · may be sold before the transfer',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            if (linked != null) ...[
              const SizedBox(height: 8),
              SizedBox(width: 260, child: TGProductCard(product: linked)),
            ],
          ],
        ],
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
