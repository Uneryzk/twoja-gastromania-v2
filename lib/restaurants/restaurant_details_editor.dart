import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

enum RestoDetailSectionId {
  garden,
  alcohol,
  playArea,
  conceptMenu,
  customersLocation,
  hoursSeasonality,
  deliveryOnline,
  staffContracts,
  systemsBrand,
  monthlyCosts,
  otherInfo,
}

extension on RestoDetailSectionId {
  String get label => switch (this) {
        RestoDetailSectionId.garden => 'Garden / terrace',
        RestoDetailSectionId.alcohol => 'Alcohol permit',
        RestoDetailSectionId.playArea => 'Children’s play area',
        RestoDetailSectionId.conceptMenu => 'Concept & menu',
        RestoDetailSectionId.customersLocation => 'Customers & location',
        RestoDetailSectionId.hoursSeasonality => 'Opening hours & seasonality',
        RestoDetailSectionId.deliveryOnline => 'Delivery platforms & online presence',
        RestoDetailSectionId.staffContracts => 'Staff & contracts',
        RestoDetailSectionId.systemsBrand => 'Equipment & systems · Brand & assets',
        RestoDetailSectionId.monthlyCosts => 'Monthly costs',
        RestoDetailSectionId.otherInfo => 'Anything else',
      };
}

/// Additional-information editor — section list + full-screen forms, autosaved.
class RestaurantDetailsEditorPage extends StatefulWidget {
  const RestaurantDetailsEditorPage({super.key, required this.listingNo, this.section});

  static const routeName = 'restaurantDetailsEditor';
  static const routePath = '/restaurants/:listingNo/details';

  final String listingNo;
  final String? section;

  @override
  State<RestaurantDetailsEditorPage> createState() => _RestaurantDetailsEditorPageState();
}

class _RestaurantDetailsEditorPageState extends State<RestaurantDetailsEditorPage> {
  Timer? _autosave;
  RestoDetailSectionId? _open;

  RestaurantListing? get _listing => RestaurantService.instance.byListingNo(widget.listingNo);

  @override
  void initState() {
    super.initState();
    RestaurantService.instance.addListener(_onSvc);
    if (widget.section != null) {
      _open = RestoDetailSectionId.values.where((e) => e.name == widget.section).firstOrNull;
    }
  }

  @override
  void dispose() {
    _autosave?.cancel();
    RestaurantService.instance.removeListener(_onSvc);
    super.dispose();
  }

  void _onSvc() {
    if (mounted) setState(() {});
  }

  void _save(RestaurantListing next, {required String section}) {
    RestaurantService.instance.replace(next.copyWith(updatedAt: TGClock.now()));
    TGAnalytics.track('details_section_saved', {'listingNo': next.listingNo, 'section': section});
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 400), () {
      if (mounted) showTGToast(context, 'Saved');
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final r = _listing;
    if (r == null) {
      return TGPageScaffold(
        header: const TGHeader(),
        body: Center(child: TextButton(onPressed: () => context.go('/dashboard/listings'), child: const Text('Back'))),
      );
    }
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final filled = r.detailsFilledCount;

    if (_open != null && phone) {
      return TGPageScaffold(
        header: const TGHeader(),
        body: _SectionForm(
          listing: r,
          section: _open!,
          onBack: () => setState(() => _open = null),
          onSave: (next) => _save(next, section: _open!.name),
        ),
      );
    }

    return TGPageScaffold(
      header: const TGHeader(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Listing details', style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                  ),
                  Semantics(
                    label: '$filled of ${RestaurantListing.detailsSectionTotal} sections filled',
                    child: Text(
                      '$filled/${RestaurantListing.detailsSectionTotal}',
                      style: theme.titleMedium.override(fontWeight: FontWeight.w900, color: TGColors.cta),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('All optional. Autosaved. Declared by you · not verified.', style: theme.bodySmall),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: filled / RestaurantListing.detailsSectionTotal,
                  minHeight: 6,
                  color: TGColors.cta,
                  backgroundColor: theme.alternate,
                ),
              ),
              const SizedBox(height: 16),
              if (_open != null && !phone)
                _SectionForm(
                  listing: r,
                  section: _open!,
                  onBack: () => setState(() => _open = null),
                  onSave: (next) => _save(next, section: _open!.name),
                )
              else
                for (final s in RestoDetailSectionId.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(_filledHint(r, s), style: theme.bodySmall),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _open = s),
                  ),
              const SizedBox(height: 16),
              TGButton(
                onPressed: () => context.go(r.detailPath),
                label: 'View listing',
                height: 44,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _filledHint(RestaurantListing r, RestoDetailSectionId s) {
    final d = r.details;
    return switch (s) {
      RestoDetailSectionId.garden => d.garden.kind == RestaurantGardenKind.none ? 'Not set' : d.garden.kind.name,
      RestoDetailSectionId.alcohol => r.alcoholPermit.status.name,
      RestoDetailSectionId.playArea => d.playArea.kind.name,
      RestoDetailSectionId.conceptMenu => (d.conceptMenu ?? '').isEmpty ? 'Not set' : 'Filled',
      RestoDetailSectionId.customersLocation => (d.customersLocation ?? '').isEmpty ? 'Not set' : 'Filled',
      RestoDetailSectionId.hoursSeasonality => (d.hoursSeasonality ?? '').isEmpty ? 'Not set' : 'Filled',
      RestoDetailSectionId.deliveryOnline => d.deliveryOnline ? 'Yes' : 'Not set',
      RestoDetailSectionId.staffContracts => (d.staffContracts ?? '').isEmpty ? 'Not set' : 'Filled',
      RestoDetailSectionId.systemsBrand =>
        (d.systems ?? '').isEmpty && d.brandAssets.isEmpty ? 'Not set' : 'Filled',
      RestoDetailSectionId.monthlyCosts => r.costLines.isEmpty ? 'Not set' : '${r.costLines.length} items',
      RestoDetailSectionId.otherInfo => (d.otherInfo ?? '').isEmpty ? 'Not set' : 'Filled',
    };
  }
}

class _SectionForm extends StatefulWidget {
  const _SectionForm({
    required this.listing,
    required this.section,
    required this.onBack,
    required this.onSave,
  });
  final RestaurantListing listing;
  final RestoDetailSectionId section;
  final VoidCallback onBack;
  final ValueChanged<RestaurantListing> onSave;

  @override
  State<_SectionForm> createState() => _SectionFormState();
}

class _SectionFormState extends State<_SectionForm> {
  late RestaurantListing _r = widget.listing;
  late final TextEditingController _text = TextEditingController();
  late final TextEditingController _area = TextEditingController();
  late final TextEditingController _fee = TextEditingController();
  late final TextEditingController _brand = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void didUpdateWidget(covariant _SectionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section || oldWidget.listing.id != widget.listing.id) {
      _r = widget.listing;
      _hydrate();
    }
  }

  void _hydrate() {
    final d = _r.details;
    _text.text = switch (widget.section) {
      RestoDetailSectionId.conceptMenu => d.conceptMenu ?? '',
      RestoDetailSectionId.customersLocation => d.customersLocation ?? '',
      RestoDetailSectionId.hoursSeasonality => d.hoursSeasonality ?? '',
      RestoDetailSectionId.staffContracts => d.staffContracts ?? '',
      RestoDetailSectionId.systemsBrand => d.systems ?? '',
      RestoDetailSectionId.otherInfo => d.otherInfo ?? '',
      _ => '',
    };
    _area.text = switch (widget.section) {
      RestoDetailSectionId.garden => d.garden.areaM2?.toString() ?? '',
      RestoDetailSectionId.playArea => d.playArea.areaM2?.toString() ?? '',
      _ => '',
    };
    _fee.text = d.garden.lastFeePln?.toString() ?? '';
    _brand.text = d.brandAssets.join(', ');
  }

  @override
  void dispose() {
    _text.dispose();
    _area.dispose();
    _fee.dispose();
    _brand.dispose();
    super.dispose();
  }

  void _pushDetails(RestaurantDetails details) {
    _r = _r.copyWith(details: details);
    widget.onSave(_r);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final d = _r.details;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back)),
            Expanded(child: Text(widget.section.label, style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...switch (widget.section) {
                RestoDetailSectionId.garden => _garden(theme, d),
                RestoDetailSectionId.alcohol => _alcohol(theme),
                RestoDetailSectionId.playArea => _play(theme, d),
                RestoDetailSectionId.monthlyCosts => _costs(theme),
                RestoDetailSectionId.deliveryOnline => [
                    SwitchListTile(
                      value: d.deliveryOnline,
                      onChanged: (v) => _pushDetails(d.copyWith(deliveryOnline: v)),
                      title: const Text('Listed on delivery platforms / has online presence'),
                    ),
                  ],
                RestoDetailSectionId.systemsBrand => [
                    TextField(
                      controller: _text,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Equipment & systems',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _pushDetails(d.copyWith(systems: v)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _brand,
                      decoration: const InputDecoration(
                        labelText: 'Brand & assets (name, recipes, social, domain)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _pushDetails(
                        d.copyWith(brandAssets: v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()),
                      ),
                    ),
                  ],
                RestoDetailSectionId.otherInfo => [
                    TextField(
                      controller: _text,
                      maxLength: 2000,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Anything else you’d like buyers to know?',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _pushDetails(d.copyWith(otherInfo: v)),
                    ),
                  ],
                _ => [
                    TextField(
                      controller: _text,
                      maxLines: 6,
                      decoration: InputDecoration(labelText: widget.section.label, border: const OutlineInputBorder()),
                      onChanged: (v) {
                        final next = switch (widget.section) {
                          RestoDetailSectionId.conceptMenu => d.copyWith(conceptMenu: v),
                          RestoDetailSectionId.customersLocation => d.copyWith(customersLocation: v),
                          RestoDetailSectionId.hoursSeasonality => d.copyWith(hoursSeasonality: v),
                          RestoDetailSectionId.staffContracts => d.copyWith(staffContracts: v),
                          _ => d,
                        };
                        _pushDetails(next);
                      },
                    ),
                  ],
              },
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _garden(FlutterFlowTheme theme, RestaurantDetails d) {
    return [
      Wrap(
        spacing: 8,
        children: [
          for (final k in RestaurantGardenKind.values)
            ChoiceChip(
              label: Text(switch (k) {
                RestaurantGardenKind.none => 'None',
                RestaurantGardenKind.own => 'Own',
                RestaurantGardenKind.municipalLease => 'Municipal lease',
                RestaurantGardenKind.landlord => "Landlord's",
              }),
              selected: d.garden.kind == k,
              onSelected: (_) => _pushDetails(
                d.copyWith(garden: RestaurantGarden(kind: k, areaM2: d.garden.areaM2, lastFeePln: d.garden.lastFeePln, feeBasis: d.garden.feeBasis, feePeriod: d.garden.feePeriod)),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _area,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Area m²', border: OutlineInputBorder()),
        onChanged: (v) => _pushDetails(
          d.copyWith(garden: RestaurantGarden(kind: d.garden.kind, areaM2: double.tryParse(v), lastFeePln: d.garden.lastFeePln, feeBasis: d.garden.feeBasis, feePeriod: d.garden.feePeriod)),
        ),
      ),
      if (d.garden.kind == RestaurantGardenKind.municipalLease) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _fee,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Last outdoor-seating fee (PLN)', border: OutlineInputBorder()),
          onChanged: (v) => _pushDetails(
            d.copyWith(
              garden: RestaurantGarden(
                kind: d.garden.kind,
                areaM2: d.garden.areaM2,
                lastFeePln: int.tryParse(v),
                feeBasis: d.garden.feeBasis,
                feePeriod: d.garden.feePeriod ?? 'last bill',
              ),
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final b in RestaurantVatBasis.values)
              ChoiceChip(
                label: Text(b.name),
                selected: d.garden.feeBasis == b,
                onSelected: (_) => _pushDetails(
                  d.copyWith(garden: RestaurantGarden(kind: d.garden.kind, areaM2: d.garden.areaM2, lastFeePln: d.garden.lastFeePln, feeBasis: b, feePeriod: d.garden.feePeriod)),
                ),
              ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _alcohol(FlutterFlowTheme theme) {
    final a = _r.alcoholPermit;
    return [
      Text(
        'This is only your statement. Permits are tied to the operator and premises. Buyers should confirm with the local authority.',
        style: theme.bodySmall.override(color: theme.secondaryText),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final s in RestaurantAlcoholPermitStatus.values)
            ChoiceChip(
              label: Text(switch (s) {
                RestaurantAlcoholPermitStatus.hasPermit => 'Has permit',
                RestaurantAlcoholPermitStatus.newApplicationRequired => 'New application required',
                RestaurantAlcoholPermitStatus.none => 'None',
                RestaurantAlcoholPermitStatus.unknown => 'Unknown',
              }),
              selected: a.status == s,
              onSelected: (_) {
                _r = _r.copyWith(alcoholPermit: RestaurantAlcoholPermit(status: s, classes: a.classes, scope: a.scope, validUntil: a.validUntil));
                widget.onSave(_r);
                setState(() {});
              },
            ),
        ],
      ),
      if (a.status == RestaurantAlcoholPermitStatus.hasPermit) ...[
        const SizedBox(height: 12),
        Text('Class', style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
        Wrap(
          spacing: 6,
          children: [
            for (final c in RestaurantAlcoholClass.values)
              FilterChip(
                label: Text(switch (c) {
                  RestaurantAlcoholClass.upTo45AndBeer => 'up to 4.5% & beer',
                  RestaurantAlcoholClass.from45To18 => '4.5–18% excl. beer',
                  RestaurantAlcoholClass.over18 => 'over 18%',
                }),
                selected: a.classes.contains(c),
                onSelected: (on) {
                  final classes = [...a.classes];
                  if (on) {
                    classes.add(c);
                  } else {
                    classes.remove(c);
                  }
                  _r = _r.copyWith(alcoholPermit: RestaurantAlcoholPermit(status: a.status, classes: classes, scope: a.scope, validUntil: a.validUntil));
                  widget.onSave(_r);
                  setState(() {});
                },
              ),
          ],
        ),
        Text('Scope', style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
        Wrap(
          spacing: 6,
          children: [
            for (final s in RestaurantAlcoholScope.values)
              FilterChip(
                label: Text(s == RestaurantAlcoholScope.onPremises ? 'on-premises' : 'off-premises'),
                selected: a.scope.contains(s),
                onSelected: (on) {
                  final scope = [...a.scope];
                  if (on) {
                    scope.add(s);
                  } else {
                    scope.remove(s);
                  }
                  _r = _r.copyWith(alcoholPermit: RestaurantAlcoholPermit(status: a.status, classes: a.classes, scope: scope, validUntil: a.validUntil));
                  widget.onSave(_r);
                  setState(() {});
                },
              ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _play(FlutterFlowTheme theme, RestaurantDetails d) {
    return [
      Wrap(
        spacing: 8,
        children: [
          for (final k in RestaurantPlayAreaKind.values)
            ChoiceChip(
              label: Text(switch (k) {
                RestaurantPlayAreaKind.none => 'No',
                RestaurantPlayAreaKind.indoor => 'Indoor',
                RestaurantPlayAreaKind.outdoor => 'Outdoor',
              }),
              selected: d.playArea.kind == k,
              onSelected: (_) => _pushDetails(d.copyWith(playArea: RestaurantPlayArea(kind: k, areaM2: d.playArea.areaM2))),
            ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _area,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Area m²', border: OutlineInputBorder()),
        onChanged: (v) => _pushDetails(d.copyWith(playArea: RestaurantPlayArea(kind: d.playArea.kind, areaM2: double.tryParse(v)))),
      ),
    ];
  }

  List<Widget> _costs(FlutterFlowTheme theme) {
    const presets = <(RestaurantCostKey, String)>[
      (RestaurantCostKey.rent, 'Rent'),
      (RestaurantCostKey.serviceCharges, 'Service charges'),
      (RestaurantCostKey.electricity, 'Electricity'),
      (RestaurantCostKey.waterSewage, 'Water & sewage'),
      (RestaurantCostKey.gas, 'Gas'),
      (RestaurantCostKey.heating, 'Heating'),
      (RestaurantCostKey.internetPhone, 'Internet & phone'),
      (RestaurantCostKey.waste, 'Waste'),
      (RestaurantCostKey.propertyTax, 'Property tax'),
      (RestaurantCostKey.insurance, 'Insurance'),
      (RestaurantCostKey.musicLicence, 'Music licence'),
      (RestaurantCostKey.alarmMonitoring, 'Alarm/monitoring'),
      (RestaurantCostKey.cleaningPest, 'Cleaning & pest control'),
      (RestaurantCostKey.greaseTrap, 'Grease trap'),
      (RestaurantCostKey.accounting, 'Accounting'),
      (RestaurantCostKey.posSoftware, 'POS/software'),
    ];
    final lines = [..._r.costLines];
    final present = lines.map((e) => e.key).toSet();
    final netKnown = lines.where((l) => l.basis == RestaurantCostBasis.netto && !l.includedInRent).fold<int>(0, (a, b) => a + b.amountPln);
    return [
      Text('No tax advice. Total shown is net only from items with a known netto basis.', style: theme.bodySmall),
      Text('Known net total: $netKnown PLN', style: const TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      for (final (key, label) in presets)
        if (!present.contains(key))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('+ $label'),
            onTap: () {
              lines.add(RestaurantCostLine(key: key, label: label, amountPln: 0));
              _r = _r.copyWith(costLines: lines);
              widget.onSave(_r);
              setState(() {});
            },
          ),
      TextButton(
        onPressed: () {
          lines.add(RestaurantCostLine(key: RestaurantCostKey.custom, label: 'Custom', amountPln: 0));
          _r = _r.copyWith(costLines: lines);
          widget.onSave(_r);
          setState(() {});
        },
        child: const Text('+ Add custom item'),
      ),
      for (var i = 0; i < lines.length; i++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lines[i].label, style: const TextStyle(fontWeight: FontWeight.w800)),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount PLN', isDense: true),
                  controller: TextEditingController(text: '${lines[i].amountPln}')
                    ..selection = TextSelection.collapsed(offset: '${lines[i].amountPln}'.length),
                  onChanged: (v) {
                    lines[i] = RestaurantCostLine(
                      key: lines[i].key,
                      label: lines[i].label,
                      amountPln: int.tryParse(v) ?? 0,
                      basis: lines[i].basis,
                      period: lines[i].period,
                      includedInRent: lines[i].includedInRent,
                    );
                    _r = _r.copyWith(costLines: [...lines]);
                    widget.onSave(_r);
                  },
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final b in RestaurantCostBasis.values)
                      ChoiceChip(
                        label: Text(b.name),
                        selected: lines[i].basis == b,
                        onSelected: (_) {
                          lines[i] = RestaurantCostLine(
                            key: lines[i].key,
                            label: lines[i].label,
                            amountPln: lines[i].amountPln,
                            basis: b,
                            period: lines[i].period,
                            includedInRent: lines[i].includedInRent,
                          );
                          _r = _r.copyWith(costLines: [...lines]);
                          widget.onSave(_r);
                          setState(() {});
                        },
                      ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final p in RestaurantCostPeriod.values)
                      ChoiceChip(
                        label: Text(switch (p) {
                          RestaurantCostPeriod.lastBill => 'Last bill',
                          RestaurantCostPeriod.avg12m => '12-month average',
                          RestaurantCostPeriod.estimate => 'Estimate',
                        }),
                        selected: lines[i].period == p,
                        onSelected: (_) {
                          lines[i] = RestaurantCostLine(
                            key: lines[i].key,
                            label: lines[i].label,
                            amountPln: lines[i].amountPln,
                            basis: lines[i].basis,
                            period: p,
                            includedInRent: lines[i].includedInRent,
                          );
                          _r = _r.copyWith(costLines: [...lines]);
                          widget.onSave(_r);
                          setState(() {});
                        },
                      ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: lines[i].includedInRent,
                  onChanged: (v) {
                    lines[i] = RestaurantCostLine(
                      key: lines[i].key,
                      label: lines[i].label,
                      amountPln: lines[i].amountPln,
                      basis: lines[i].basis,
                      period: lines[i].period,
                      includedInRent: v ?? false,
                    );
                    _r = _r.copyWith(costLines: [...lines]);
                    widget.onSave(_r);
                    setState(() {});
                  },
                  title: const Text('Included in rent'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),
    ];
  }
}
