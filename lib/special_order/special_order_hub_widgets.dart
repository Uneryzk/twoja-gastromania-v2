import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/seller/seller_profile_panels.dart' show showStoreProjectLightbox;
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_badges.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_contact.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SoHero extends StatelessWidget {
  const SoHero({super.key, required this.onRequest, required this.onBrowse});
  final VoidCallback onRequest;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    return ClipRRect(
      borderRadius: BorderRadius.circular(phone ? 0 : 16),
      child: SizedBox(
        height: phone ? 220 : 360,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg', fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xE0121212), Color(0x00000000)],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(phone ? 16 : 40, phone ? 20 : 40, phone ? 16 : 40, phone ? 16 : 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t('ui_special_order'), style: theme.displaySmall.override(fontSize: phone ? 28 : 40, lineHeight: phone ? 1.15 : 48 / 40, fontWeight: FontWeight.w800)),
                  SizedBox(height: phone ? 8 : 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Text(
                      context.t('ui_so_hero_sub'),
                      maxLines: phone ? 2 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyLarge.override(color: Colors.white.withValues(alpha: 0.9), lineHeight: 1.4, fontSize: phone ? 13 : null),
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      TGButton(onPressed: onRequest, label: context.t('ui_request_quotes'), height: 48, borderRadius: BorderRadius.circular(TGRadius.pill)),
                      if (!phone) TGButton(onPressed: onBrowse, label: context.t('ui_browse_manufacturers'), variant: TGButtonVariant.outline, height: 48, borderRadius: BorderRadius.circular(TGRadius.pill)),
                    ],
                  ),
                  if (!phone) ...[
                    const SizedBox(height: 14),
                    Text(context.t('ui_so_trust_line'), style: theme.bodySmall.override(color: Colors.white70, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(context.t('ui_so_no_payments'), style: theme.bodySmall.override(color: Colors.white54)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SoStatsRow extends StatelessWidget {
  const SoStatsRow({super.key, required this.played, required this.manufacturers, required this.projects});
  final bool played;
  final int manufacturers;
  final int projects;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    Widget card({required String label, required Widget value}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: TGColors.surface, borderRadius: BorderRadius.circular(TGRadius.card), border: Border.all(color: TGColors.border)),
          child: Column(
            children: [
              value,
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        card(
          label: context.t('ui_so_stat_makers'),
          value: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: played ? manufacturers.toDouble() : 0),
            duration: tgAnim(context, const Duration(milliseconds: 400)),
            builder: (_, v, __) => Text('${v.round()}', style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 16),
        card(
          label: context.t('ui_so_stat_projects'),
          value: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: played ? projects.toDouble() : 0),
            duration: tgAnim(context, const Duration(milliseconds: 400)),
            builder: (_, v, __) => Text('${v.round()}', style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 16),
        card(
          label: context.t('ui_so_stat_quote'),
          value: AnimatedOpacity(
            opacity: played ? 1 : 0,
            duration: tgAnim(context, const Duration(milliseconds: 400)),
            child: Text(context.t('ui_so_median_quote'), style: theme.titleLarge.override(fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

class SoHowItWorks extends StatelessWidget {
  const SoHowItWorks({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      context.t('ui_so_step_1'),
      context.t('ui_so_step_2'),
      context.t('ui_so_step_3'),
      context.t('ui_so_step_4'),
    ];
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    Widget card(int i, String text) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: tgAnim(context, Duration(milliseconds: 200 + 40 * i)),
          builder: (_, v, child) => Opacity(opacity: v, child: child),
          child: Container(
            width: phone ? 260 : null,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: TGColors.surface, borderRadius: BorderRadius.circular(TGRadius.card), border: Border.all(color: TGColors.border)),
            child: Text('${i + 1}. $text', style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35)),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (phone)
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const PageScrollPhysics(),
              itemCount: steps.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => card(i, steps[i]),
            ),
          )
        else
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: card(i, steps[i])),
              ],
            ],
          ),
        const SizedBox(height: 10),
        Text(context.t('ui_so_step_pay_note'), style: TextStyle(color: FlutterFlowTheme.of(context).secondaryText, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class SoWhatWeMake extends StatelessWidget {
  const SoWhatWeMake({super.key, required this.onType});
  final ValueChanged<TGStoreSpecialty> onType;

  static const _tiles = <(TGStoreSpecialty, String)>[
    (TGStoreSpecialty.worktopsTables, 'assets/images/stainless_steel_table_Food_Preparation_table_gastronomi.jpg'),
    (TGStoreSpecialty.extractionHoods, 'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg'),
    (TGStoreSpecialty.barCounters, 'assets/images/blog-26.jpg'),
    (TGStoreSpecialty.fullFitout, 'assets/images/10befb6d92142e17d926d07d605d82d8.jpg'),
    (TGStoreSpecialty.coldRooms, 'assets/images/IMG_3696-scaled.webp'),
    (TGStoreSpecialty.sinksWashing, 'assets/images/Food_Prepering_table.jpg'),
    (TGStoreSpecialty.shelvingStorage, 'assets/images/image.png'),
    (TGStoreSpecialty.laserBending, 'assets/images/bartscher_2002170.webp'),
  ];

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final desktop = MediaQuery.sizeOf(context).width >= TGBreakpoints.desktop;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tiles.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: phone ? 2 : (desktop ? 4 : 3),
        crossAxisSpacing: phone ? 10 : 16,
        mainAxisSpacing: phone ? 10 : 16,
        childAspectRatio: phone ? 1.05 : 1.25,
      ),
      itemBuilder: (context, i) {
        final (type, img) = _tiles[i];
        final label = context.t('ui_so_spec_${type.name}');
        return Material(
          color: TGColors.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onType(type),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(img, fit: BoxFit.cover),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center, colors: [Color(0xCC000000), Color(0x00000000)]))),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(color: TGColors.accent, borderRadius: BorderRadius.circular(TGRadius.pill)),
                        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => context.go('/special-order/new?type=${specialtyKey(type)}'),
                        child: Text(context.t('ui_request_quotes'), style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800, decoration: TextDecoration.underline, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SoFilterBar extends StatelessWidget {
  const SoFilterBar({
    super.key,
    required this.search,
    required this.types,
    required this.region,
    required this.install,
    required this.hasProjects,
    required this.rated,
    required this.sort,
    required this.onSearch,
    required this.onTypes,
    required this.onRegion,
    required this.onInstall,
    required this.onHasProjects,
    required this.onRated,
    required this.onSort,
    required this.onClear,
  });

  final TextEditingController search;
  final Set<TGStoreSpecialty> types;
  final String? region;
  final bool install;
  final bool hasProjects;
  final bool rated;
  final TGSpecialSort sort;
  final ValueChanged<String> onSearch;
  final ValueChanged<Set<TGStoreSpecialty>> onTypes;
  final ValueChanged<String?> onRegion;
  final ValueChanged<bool> onInstall;
  final ValueChanged<bool> onHasProjects;
  final ValueChanged<bool> onRated;
  final ValueChanged<TGSpecialSort> onSort;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const regions = ['nationwide', 'Śląskie', 'Małopolskie', 'Mazowieckie', 'Dolnośląskie', 'Opolskie', 'Łódzkie'];
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: search,
                  decoration: InputDecoration(hintText: context.t('ui_so_search_name'), prefixIcon: const Icon(Icons.search), isDense: true),
                  onSubmitted: onSearch,
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<TGStoreSpecialty?>(
                  value: types.length == 1 ? types.first : null,
                  hint: Text(context.t('ui_project_type')),
                  items: [
                    DropdownMenuItem(value: null, child: Text(context.t('ui_all'))),
                    for (final s in TGStoreSpecialty.values.where((e) => e != TGStoreSpecialty.other))
                      DropdownMenuItem(value: s, child: Text(context.t('ui_so_spec_${s.name}'))),
                  ],
                  onChanged: (v) => onTypes(v == null ? {} : {v}),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: region,
                  hint: Text(context.t('ui_region')),
                  items: [
                    DropdownMenuItem(value: null, child: Text(context.t('ui_all'))),
                    for (final r in regions) DropdownMenuItem(value: r, child: Text(r == 'nationwide' ? context.t('ui_nationwide') : r)),
                  ],
                  onChanged: onRegion,
                ),
              ),
              FilterChip(label: Text(context.t('ui_so_install')), selected: install, onSelected: onInstall),
              FilterChip(label: Text(context.t('ui_so_has_projects')), selected: hasProjects, onSelected: onHasProjects),
              FilterChip(label: Text(context.t('ui_so_rated_4')), selected: rated, onSelected: onRated),
              DropdownButtonHideUnderline(
                child: DropdownButton<TGSpecialSort>(
                  value: sort,
                  items: [
                    DropdownMenuItem(value: TGSpecialSort.recommended, child: Text(context.t('ui_sort_recommended'))),
                    DropdownMenuItem(value: TGSpecialSort.highestRated, child: Text(context.t('ui_sort_highest'))),
                    DropdownMenuItem(value: TGSpecialSort.mostProjects, child: Text(context.t('ui_so_sort_projects'))),
                    DropdownMenuItem(value: TGSpecialSort.fastestResponse, child: Text(context.t('ui_so_sort_response'))),
                  ],
                  onChanged: (v) {
                    if (v != null) onSort(v);
                  },
                ),
              ),
              TextButton(onPressed: onClear, child: Text(context.t('ui_clear'))),
            ],
          ),
          if (types.isNotEmpty || region != null || install || hasProjects || rated)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in types)
                    Chip(label: Text(context.t('ui_so_spec_${t.name}')), onDeleted: () => onTypes({...types}..remove(t))),
                  if (region != null) Chip(label: Text(region == 'nationwide' ? context.t('ui_nationwide') : region!), onDeleted: () => onRegion(null)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SoManufacturerGrid extends StatelessWidget {
  const SoManufacturerGrid({super.key, required this.items, required this.selected, required this.onToggle, this.sponsored});
  final List<TGStoreProfile> items;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final TGStoreProfile? sponsored;

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.desktop;
    final rows = <Widget>[];
    if (phone) {
      for (var i = 0; i < items.length; i++) {
        if (i == 2 && sponsored != null) {
          rows.add(SoSponsoredBanner(profile: sponsored!));
          rows.add(const SizedBox(height: 16));
        }
        final p = items[i];
        rows.add(SoManufacturerCard(profile: p, selected: selected.contains(p.publicId), onToggle: () => onToggle(p.publicId)));
        rows.add(const SizedBox(height: 16));
      }
      return Column(children: rows);
    }
    for (var i = 0; i < items.length; i += 2) {
      if (i == 4 && sponsored != null) {
        rows.add(SoSponsoredBanner(profile: sponsored!));
        rows.add(const SizedBox(height: 24));
      }
      final left = items[i];
      final right = i + 1 < items.length ? items[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SoManufacturerCard(profile: left, selected: selected.contains(left.publicId), onToggle: () => onToggle(left.publicId))),
            const SizedBox(width: 24),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : SoManufacturerCard(profile: right, selected: selected.contains(right.publicId), onToggle: () => onToggle(right.publicId)),
            ),
          ],
        ),
      );
      rows.add(const SizedBox(height: 24));
    }
    return Column(children: rows);
  }
}

class SoManufacturerCard extends StatefulWidget {
  const SoManufacturerCard({super.key, required this.profile, required this.selected, required this.onToggle});
  final TGStoreProfile profile;
  final bool selected;
  final VoidCallback onToggle;

  @override
  State<SoManufacturerCard> createState() => _SoManufacturerCardState();
}

class _SoManufacturerCardState extends State<SoManufacturerCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final p = widget.profile;
    final photos = p.projects.expand((e) => e.photos).take(4).toList();
    final specs = p.specialties.take(4).toList();
    final moreSpecs = p.specialties.length - specs.length;
    final lead = p.leadTimeWeeks;
    final regionLabel = p.serviceRegions.contains('nationwide') ? context.t('ui_nationwide') : p.serviceRegions.take(2).join(', ');
    final callLabel = '${context.t('ui_call_now')} ${p.phone}';

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: tgAnim(context, const Duration(milliseconds: 180)),
        transform: Matrix4.translationValues(0, _hover ? -4 : 0, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hover ? TGColors.cta.withValues(alpha: 0.55) : TGColors.border),
          boxShadow: _hover ? [BoxShadow(color: TGColors.cta.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 6))] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: p.logoUrl != null ? Image.asset(p.logoUrl!, fit: BoxFit.cover) : ColoredBox(color: theme.alternate, child: Center(child: Text(p.name[0]))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => context.go(p.path),
                        child: Text(p.name, style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (p.verified) const TGVerifiedSellerBadge(),
                          TGRatingBadge(rating: p.rating),
                          Text(context.t('ui_reviews_n', {'n': '${p.reviewsCount}'}), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    AnimatedScale(
                      scale: widget.selected ? 1.08 : 1,
                      duration: tgAnim(context, const Duration(milliseconds: 150)),
                      child: Checkbox(
                        value: widget.selected,
                        onChanged: (_) => widget.onToggle(),
                        activeColor: TGColors.cta,
                      ),
                    ),
                    Text(context.t('ui_so_add_to_request'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${p.city} · ${context.t('ui_member_since', {'y': '${p.memberSince.year}'})} · ${context.t('ui_so_replies_in', {'n': '${p.responseHours ?? 24}'})}',
              style: theme.bodySmall.override(color: theme.secondaryText),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in specs)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: TGColors.accent, borderRadius: BorderRadius.circular(TGRadius.pill)),
                    child: Text(context.t('ui_so_spec_${s.name}'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                if (moreSpecs > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: theme.alternate, borderRadius: BorderRadius.circular(TGRadius.pill)),
                    child: Text('+$moreSpecs', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (photos.isEmpty)
              Text(context.t('ui_so_no_projects'), style: theme.bodySmall.override(color: theme.secondaryText))
            else if (MediaQuery.sizeOf(context).width < TGBreakpoints.phone)
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length + (p.projects.length > 4 ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    if (i >= photos.length) {
                      return AspectRatio(
                        aspectRatio: 4 / 3,
                        child: InkWell(
                          onTap: () => context.go('${p.path}?tab=about'),
                          child: Container(
                            width: 120,
                            decoration: BoxDecoration(color: theme.alternate, borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: Text('+${p.projects.length - 4}', style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      );
                    }
                    return AspectRatio(
                      aspectRatio: 4 / 3,
                      child: InkWell(
                        onTap: () {
                          TGAnalytics.track('so_gallery_open', {'sellerId': p.sellerKey});
                          showStoreProjectLightbox(context, p.projects, 0);
                        },
                        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset(photos[i], fit: BoxFit.cover, width: 120)),
                      ),
                    );
                  },
                ),
              )
            else
              Row(
                children: [
                  for (var i = 0; i < photos.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: InkWell(
                          onTap: () {
                            TGAnalytics.track('so_gallery_open', {'sellerId': p.sellerKey});
                            showStoreProjectLightbox(context, p.projects, 0);
                          },
                          child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset(photos[i], fit: BoxFit.cover)),
                        ),
                      ),
                    ),
                  ],
                  if (p.projects.length > 4) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: InkWell(
                          onTap: () => context.go('${p.path}?tab=about'),
                          child: Container(
                            decoration: BoxDecoration(color: theme.alternate, borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: Text('+${p.projects.length - 4} ${context.t('ui_projects')}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 12),
            Text(
              '${context.t('ui_so_delivers')}: $regionLabel · ${p.installation ? context.t('ui_so_install') : context.t('ui_so_no_install')}${lead == null ? '' : ' · ${context.t('ui_so_lead_time', {'min': '${lead.min}', 'max': '${lead.max}'})}'}',
              style: theme.bodySmall.override(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(p.phone, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                IconButton(
                  tooltip: context.t('ui_copy_link'),
                  onPressed: () => copyPhoneNumber(context, p.phone),
                  icon: const Icon(Icons.copy, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Semantics(
                  button: true,
                  label: callLabel,
                  child: TGButton(
                    onPressed: () async {
                      final dial = p.phone.replaceAll(RegExp(r'[^0-9+]'), '');
                      await launchUrl(Uri(scheme: 'tel', path: dial));
                      if (context.mounted) await copyPhoneNumber(context, p.phone);
                    },
                    label: callLabel,
                    height: 44,
                  ),
                ),
                TGButton(
                  onPressed: () {
                    final auth = context.read<FakeAuthState>();
                    if (!auth.isLoggedIn) {
                      context.goNamed(LoginPageWidget.routeName);
                      return;
                    }
                    MessagingService.instance.openDock(inbox: true, draft: 'Special Order · ${p.name}');
                  },
                  label: context.t('ui_message'),
                  variant: TGButtonVariant.outline,
                  height: 44,
                ),
                TGButton(
                  onPressed: () => context.go('/special-order/new?seller=${p.publicId}'),
                  label: context.t('ui_request_quote'),
                  variant: TGButtonVariant.ghost,
                  height: 44,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SoSponsoredBanner extends StatelessWidget {
  const SoSponsoredBanner({super.key, required this.profile});
  final TGStoreProfile profile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(profile.coverUrl ?? 'assets/images/blog-26.jpg', fit: BoxFit.cover),
            Container(color: Colors.black.withValues(alpha: 0.55)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(TGRadius.pill), border: Border.all(color: Colors.white70)),
                    child: Text(context.t('ui_sponsored'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                  const Spacer(),
                  Text(profile.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  Text(profile.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SoRecentProjects extends StatelessWidget {
  const SoRecentProjects({super.key, required this.entries});
  final List<({TGStoreProfile store, TGStoreProject project})> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final e = entries[i];
          final photo = e.project.photos.isEmpty ? 'assets/images/blog-26.jpg' : e.project.photos.first;
          return SizedBox(
            width: 260,
            child: InkWell(
              onTap: () {
                TGAnalytics.track('so_gallery_open', {'sellerId': e.store.sellerKey});
                final idx = e.store.projects.indexOf(e.project).clamp(0, e.store.projects.length - 1);
                showStoreProjectLightbox(context, e.store.projects, idx);
              },
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(aspectRatio: 4 / 3, child: Image.asset(photo, fit: BoxFit.cover)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(e.project.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${e.project.city} · ${e.project.year} · ${e.store.name}', style: TextStyle(color: FlutterFlowTheme.of(context).secondaryText, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SoFaq extends StatelessWidget {
  const SoFaq({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('ui_so_faq_q1', 'ui_so_faq_a1'),
      ('ui_so_faq_q2', 'ui_so_faq_a2'),
      ('ui_so_faq_q3', 'ui_so_faq_a3'),
      ('ui_so_faq_q4', 'ui_so_faq_a4'),
      ('ui_so_faq_q5', 'ui_so_faq_a5'),
      ('ui_so_faq_q6', 'ui_so_faq_a6'),
    ];
    return Column(
      children: [
        for (final item in items)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: Text(context.t(item.$1), style: const TextStyle(fontWeight: FontWeight.w800)),
              children: [Align(alignment: Alignment.centerLeft, child: Text(context.t(item.$2), style: const TextStyle(height: 1.45)))],
            ),
          ),
      ],
    );
  }
}

class SoCtaBand extends StatelessWidget {
  const SoCtaBand({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: TGColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: TGColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('ui_so_team_cta'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TGButton(onPressed: () => context.go('/special-order/new'), label: context.t('ui_request_quotes'), height: 48),
              const Text('+48 (532) 784-074', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              IconButton(onPressed: () => copyPhoneNumber(context, '+48 (532) 784-074'), icon: const Icon(Icons.copy, size: 18)),
            ],
          ),
        ],
      ),
    );
  }
}

class SoMakerBand extends StatelessWidget {
  const SoMakerBand({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: TGColors.cta.withValues(alpha: 0.45))),
      child: Row(
        children: [
          Expanded(child: Text(context.t('ui_so_maker_cta'), style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35))),
          TGButton(onPressed: () => TGNav.plans(context), label: context.t('ui_see_plans'), variant: TGButtonVariant.outline, height: 44),
        ],
      ),
    );
  }
}

class SoSelectionBar extends StatelessWidget {
  const SoSelectionBar({
    super.key,
    required this.count,
    required this.onClear,
    required this.onRequest,
    this.onCallTeam,
    this.alwaysVisible = false,
  });
  final int count;
  final VoidCallback onClear;
  final VoidCallback onRequest;
  final VoidCallback? onCallTeam;
  final bool alwaysVisible;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).bottom;
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final teamPhone = '+48 (532) 784-074';
    return Material(
      color: const Color(0xFF1F1F1F),
      elevation: 12,
      child: Container(
        constraints: BoxConstraints(minHeight: 72 + (phone ? pad : 0)),
        padding: EdgeInsets.fromLTRB(phone ? 16 : 24, 12, phone ? 16 : 24, 12 + (phone ? pad : 0)),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF3A3A3A)))),
        child: phone || alwaysVisible
            ? Row(
                children: [
                  Expanded(
                    flex: 16,
                    child: TGButton(
                      onPressed: onRequest,
                      label: count == 0 ? context.t('ui_request_quotes') : context.t('ui_so_selected_request', {'n': '$count'}),
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 10,
                    child: TGButton(
                      onPressed: onCallTeam ??
                          () async {
                            await launchUrl(Uri(scheme: 'tel', path: teamPhone.replaceAll(RegExp(r'[^0-9+]'), '')));
                          },
                      label: '${context.t('ui_so_call_team')} $teamPhone',
                      variant: TGButtonVariant.outline,
                      height: 48,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Text(context.t('ui_so_selected_n', {'n': '$count'}), style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(width: 16),
                  TextButton(onPressed: onClear, child: Text(context.t('ui_clear'))),
                  const Spacer(),
                  TGButton(onPressed: onRequest, label: context.t('ui_request_quotes'), height: 44),
                ],
              ),
      ),
    );
  }
}

class SoEmptyMfg extends StatelessWidget {
  const SoEmptyMfg({super.key, required this.onTeam});
  final VoidCallback onTeam;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(context.t('ui_so_no_match'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 12),
          TGButton(onPressed: onTeam, label: context.t('ui_so_send_team'), height: 44),
        ],
      ),
    );
  }
}

class SoGridSkeleton extends StatelessWidget {
  const SoGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            children: [
              Expanded(child: _box()),
              const SizedBox(width: 24),
              Expanded(child: _box()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box() => Container(
        height: 320,
        decoration: BoxDecoration(color: TGColors.surface, borderRadius: BorderRadius.circular(16)),
      );
}

class SoPager extends StatelessWidget {
  const SoPager({super.key, required this.page, required this.pages, required this.onPage});
  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= pages; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextButton(
              onPressed: () => onPage(i),
              child: Text('$i', style: TextStyle(fontWeight: FontWeight.w900, color: i == page ? TGColors.cta : null)),
            ),
          ),
      ],
    );
  }
}
