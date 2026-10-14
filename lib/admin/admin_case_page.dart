import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/admin/admin_console_pages.dart';
import 'package:twoja_gastromania/tg_models/tg_account.dart';
import 'package:twoja_gastromania/admin/admin_modals.dart';
import 'package:twoja_gastromania/admin/listing_images_editor.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_core/tg_verified_seller.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_components/tg_inline_translate.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_inventory_sync_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';

class AdminCasePage extends StatefulWidget {
  const AdminCasePage({super.key, required this.listingNo});
  final String listingNo;

  static const routeName = 'AdminCase';
  static const routePath = '/admin/l/:listingNo';

  @override
  State<AdminCasePage> createState() => _AdminCasePageState();
}

class _AdminCasePageState extends State<AdminCasePage> {
  List<TGProduct> _all = const [];
  int _relatedTab = 0;

  @override
  void initState() {
    super.initState();
    ModerationService.instance.ensureSeeded();
    ModerationService.instance.openCaseTracked(widget.listingNo);
    TGProductService.instance.getAll().then((all) {
      if (mounted) setState(() => _all = all);
    });
  }

  TGProduct? get _product {
    for (final p in _all) {
      if (p.listingNo == widget.listingNo) return p;
    }
    return null;
  }

  RestaurantListing? get _restaurant => RestaurantService.instance.byListingNo(widget.listingNo);

  @override
  Widget build(BuildContext context) {
    final mod = context.watch<ModerationService>();
    final w = MediaQuery.sizeOf(context).width;
    final phone = w < TGBreakpoints.phone;
    final twoCol = w >= 1280;
    final product = _product;
    final restaurant = _restaurant;
    final kase = mod.caseFor(widget.listingNo);
    final sellerId = kase?.sellerId ?? product?.seller.id ?? restaurant?.seller.id ?? '';
    final profile = mod.sellerById(sellerId);
    final reports = mod.reportsFor(widget.listingNo);
    final matches = mod.matchesFor(widget.listingNo);
    final sameSeller = product == null ? <TGProduct>[] : mod.sameSellerListings(product.seller.id, widget.listingNo, _all);
    final sameContact = profile == null ? <TGModerationSeller>[] : mod.samePhoneOrNip(profile);
    final events = <TGCaseEvent>[
      ...(mod.events[widget.listingNo] ?? const <TGCaseEvent>[]),
      ...mod.auditFor(listingNo: widget.listingNo).map((e) => TGCaseEvent(at: e.at, label: e.summary, detail: e.reason)),
    ];
    events.sort((a, b) => b.at.compareTo(a.at));

    final flags = <String>[
      ...?kase?.flags,
      if (restaurant != null && restaurant.status == RestaurantListingStatus.pendingAuthorization)
        'Possible duplicate (same premises)',
    ];

    final descCases = RestaurantInventorySyncService.instance
      ..ensureSeeded();
    final openDesc = descCases.descriptionCases
        .where((c) => c.listingNo == widget.listingNo && !c.resolved)
        .toList();

    final left = _LeftColumn(
      listingNo: widget.listingNo,
      product: product,
      restaurant: restaurant,
      reports: reports,
      events: events,
      flags: flags,
      descCases: openDesc,
    );
    final right = _RightColumn(
      listingNo: widget.listingNo,
      product: product,
      profile: profile,
      tab: _relatedTab,
      onTab: (i) => setState(() => _relatedTab = i),
      sameSeller: sameSeller,
      sameContact: sameContact,
      matches: matches,
      catalogue: _all,
    );

    final body = twoCol
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              SizedBox(width: 411, child: right),
            ],
          )
        : Column(children: [left, const SizedBox(height: 16), right]);

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: twoCol ? body : body,
                ),
              ),
              const SliverToBoxAdapter(child: AdminPrinciplesFooter()),
            ],
          ),
        ),
        if (phone) AdminActionBar(listingNo: widget.listingNo, sellerId: sellerId, dense: true),
      ],
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({
    required this.listingNo,
    required this.product,
    required this.reports,
    required this.events,
    this.restaurant,
    this.flags = const [],
    this.descCases = const [],
  });
  final String listingNo;
  final TGProduct? product;
  final RestaurantListing? restaurant;
  final List<TGModerationReport> reports;
  final List<TGCaseEvent> events;
  final List<String> flags;
  final List<RestoDescriptionCheckCase> descCases;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final fmt = DateFormat('d MMM yyyy · HH:mm');
    final r = restaurant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(border: Border.all(color: TGColors.cta), borderRadius: BorderRadius.circular(99)),
                  child: Text(context.t('ui_admin_restaurant'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: TGColors.cta)),
                ),
                const SizedBox(height: 8),
                if (r.images.isNotEmpty)
                  SizedBox(
                    height: 160,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final img in r.images)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(img, width: 200, height: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 200, height: 160, child: ColoredBox(color: TGColors.surfaceHover))),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Text(r.title, style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                Text('No. ${r.listingNo} · ${r.status.name}', style: const TextStyle(color: TGColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Text(r.fullAddress, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  context.t('ui_admin_unit_label', {
                    'u': r.unitNo?.isNotEmpty == true ? r.unitNo! : context.t('ui_admin_no_unit'),
                  }),
                  style: const TextStyle(fontSize: 12, color: TGColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Views ${r.engagement.views} · Contacts ${r.engagement.uniqueContacts} · Favorites ${r.engagement.uniqueFavorites}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
                if (r.documents.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(context.t('ui_admin_auth_document'), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
                  for (final d in r.documents) Text('· $d', style: const TextStyle(fontSize: 12)),
                ] else if (r.status == RestaurantListingStatus.pendingAuthorization) ...[
                  const SizedBox(height: 8),
                  Text(context.t('ui_admin_auth_doc_missing'), style: theme.bodySmall.override(color: TGColors.slaAmber, fontWeight: FontWeight.w700)),
                ],
              ] else if (product != null) ...[
                SizedBox(
                  height: 160,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final img in product!.gallery)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(img, width: 200, height: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 200, height: 160, child: ColoredBox(color: TGColors.surfaceHover))),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TGInlineTranslate(text: product!.title, style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                if ((product!.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  TGInlineTranslate(text: product!.description!, style: const TextStyle(fontSize: 13, height: 1.35)),
                ],
                Text(product!.price == null ? context.t('ui_ask_price') : '${product!.price} PLN', style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800)),
                Text('${product!.condition.name} · ${product!.city} · ${product!.powerType.name}', style: const TextStyle(color: TGColors.textSecondary, fontSize: 12)),
              ] else
                Text(context.t('ui_listing_no', {'n': listingNo}), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    key: const Key('admin-open-public'),
                    onPressed: r != null
                        ? () => context.go(r.detailPath)
                        : product == null
                            ? null
                            : () => context.go(product!.detailPath),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(context.t('ui_open_public_page')),
                  ),
                  if (r != null || product != null)
                    TextButton.icon(
                      key: const Key('admin-manage-images'),
                      onPressed: () => showListingImagesEditor(context, product: product, restaurant: r),
                      icon: const Icon(Icons.image_outlined, size: 16),
                      label: Text(context.t('ui_image_manage')),
                    ),
                ],
              ),
              if (flags.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final f in flags)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      f,
                      style: theme.bodySmall.override(color: TGColors.slaAmber, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (descCases.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final c in descCases) _DescriptionCheckCard(kase: c, restaurant: restaurant),
        ],
        const SizedBox(height: 12),
        Text(context.t('ui_reports'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final r in reports)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AdminReasonChip(reason: r.reason),
                      const SizedBox(width: 8),
                      Text(r.reportNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      const Spacer(),
                      Text(fmt.format(r.createdAt), style: const TextStyle(fontSize: 11, color: TGColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TGInlineTranslate(
                    text: r.text == 'Item appears on the prohibited equipment list.'
                        ? context.t('ui_admin_report_prohibited_seed')
                        : r.text,
                    enKey: Key('admin-report-translate-en-${r.reportNo}'),
                  ),
                  const SizedBox(height: 6),
                  Text(r.reporterEmail, style: const TextStyle(fontSize: 12, color: TGColors.textSecondary)),
                  if (r.evidenceUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 56,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final e in r.evidenceUrls)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(e, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 56, height: 56, child: ColoredBox(color: TGColors.surfaceHover))),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(context.t('ui_event_log'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        AdminCard(
          child: Column(
            children: [
              if (events.isEmpty) Text(context.t('ui_no_events'), style: const TextStyle(color: TGColors.textSecondary)),
              for (final e in events.take(20))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: Text('${fmt.format(e.at)}${e.detail == null ? '' : ' · ${e.detail}'}', style: const TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn({
    required this.listingNo,
    required this.product,
    required this.profile,
    required this.tab,
    required this.onTab,
    required this.sameSeller,
    required this.sameContact,
    required this.matches,
    required this.catalogue,
  });

  final String listingNo;
  final TGProduct? product;
  final TGModerationSeller? profile;
  final int tab;
  final ValueChanged<int> onTab;
  final List<TGProduct> sameSeller;
  final List<TGModerationSeller> sameContact;
  final List<TGPhotoMatch> matches;
  final List<TGProduct> catalogue;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final seller = profile?.seller ?? product?.seller;
    final age = profile?.accountAgeDays() ?? 0;
    return Column(
      children: [
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(seller?.name ?? context.t('ui_seller'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(seller == null ? '' : adminSellerKindL10n(context, seller.type, verified: seller != null && tgShowsVerifiedSellerBadge(seller)), style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(context.t('ui_account_age', {'n': '$age'}), style: const TextStyle(fontSize: 12, color: TGColors.textSecondary)),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text('${context.t('ui_phone')} · ', style: const TextStyle(fontSize: 12)),
                AdminMaskedValue(userId: seller?.id ?? '', field: TGPiiField.phone, value: profile?.phone ?? product?.phone ?? ''),
              ]),
              Text('NIP · ${profile?.nip ?? '—'}', style: const TextStyle(fontSize: 12)),
              Text(context.t('ui_past_reports', {'r': '${profile?.pastReports ?? 0}', 'm': '${profile?.pastRemovals ?? 0}'}), style: const TextStyle(fontSize: 12)),
              if (profile?.suspended == true) Text(context.t('ui_suspended'), style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AdminCard(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  _tabBtn(context, 0, context.t('ui_same_seller', {'n': '${sameSeller.length}'})),
                  _tabBtn(context, 1, context.t('ui_same_phone_nip', {'n': '${sameContact.length}'})),
                  _tabBtn(context, 2, context.t('ui_matching_photos', {'n': '${matches.length}'})),
                ],
              ),
              const SizedBox(height: 8),
              if (tab == 0)
                for (final p in sameSeller.take(6))
                  ListTile(
                    dense: true,
                    title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    subtitle: Text(p.listingNo ?? p.id, style: const TextStyle(fontSize: 11, color: TGColors.cta)),
                    onTap: () => TGAdminNav.openCase(context, p.listingNo ?? p.id),
                  )
              else if (tab == 1)
                for (final s in sameContact)
                  ListTile(
                    dense: true,
                    title: Text(s.seller.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    subtitle: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                      AdminMaskedValue(userId: s.seller.id, field: TGPiiField.phone, value: s.phone, style: const TextStyle(fontSize: 11)),
                      Text(' · ${s.nip ?? context.t('ui_no_nip')}', style: const TextStyle(fontSize: 11)),
                    ]),
                  )
              else
                for (final m in matches)
                  ListTile(
                    dense: true,
                    title: Text('${context.t('ui_similar_percent', {'n': '${m.similarityPercent}'})} · ${m.otherListing(listingNo)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    trailing: TextButton(
                      key: Key('admin-compare-${m.listingNoA}-${m.listingNoB}'),
                      onPressed: () {
                        TGProduct? find(String no) {
                          for (final p in catalogue) {
                            if (p.listingNo == no) return p;
                          }
                          return null;
                        }
                        showPhotoCompare(context, m, find(m.listingNoA), find(m.listingNoB));
                      },
                      child: Text(context.t('ui_compare')),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (MediaQuery.sizeOf(context).width >= TGBreakpoints.phone)
          AdminActionBar(listingNo: listingNo, sellerId: seller?.id ?? ''),
      ],
    );
  }

  Widget _tabBtn(BuildContext context, int i, String label) {
    final on = tab == i;
    return Expanded(
      child: InkWell(
        onTap: () => onTab(i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: on ? TGColors.cta : TGColors.border, width: on ? 2 : 1)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: on ? TGColors.cta : TGColors.textSecondary)),
        ),
      ),
    );
  }
}

class _DescriptionCheckCard extends StatefulWidget {
  const _DescriptionCheckCard({required this.kase, this.restaurant});
  final RestoDescriptionCheckCase kase;
  final RestaurantListing? restaurant;

  @override
  State<_DescriptionCheckCard> createState() => _DescriptionCheckCardState();
}

class _DescriptionCheckCardState extends State<_DescriptionCheckCard> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.read<FakeAuthState>();
    final sync = RestaurantInventorySyncService.instance;
    final r = widget.restaurant;
    final before = r?.description ?? '';
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('ui_admin_desc_check_title', {'name': widget.kase.itemName}), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          Text(context.t('ui_admin_target_2bd'), style: theme.bodySmall.override(color: TGColors.slaAmber, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final s in widget.kase.matchedSentences)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _selected == s,
              onChanged: (_) => setState(() => _selected = s),
              title: Text(s, style: const TextStyle(backgroundColor: Color(0x33E6B800), fontSize: 12)),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TGButton(
                onPressed: () => _act(context, auth, sync, r, before, RestoDescriptionCheckAction.removeSentence),
                label: context.t('ui_admin_remove_sentence'),
                height: 36,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
              TGButton(
                onPressed: () => _act(context, auth, sync, r, before, RestoDescriptionCheckAction.editMinimally),
                label: context.t('ui_admin_edit_minimally'),
                variant: TGButtonVariant.outline,
                height: 36,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
              TGButton(
                onPressed: () => _act(context, auth, sync, r, before, RestoDescriptionCheckAction.dismiss),
                label: context.t('ui_admin_dismiss_no_conflict'),
                variant: TGButtonVariant.ghost,
                height: 36,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _act(
    BuildContext context,
    FakeAuthState auth,
    RestaurantInventorySyncService sync,
    RestaurantListing? r,
    String before,
    RestoDescriptionCheckAction action,
  ) async {
    if (r == null) return;
    var after = before;
    String? minimal;
    if (action == RestoDescriptionCheckAction.removeSentence) {
      if (_selected == null) {
        showTGToast(context, context.t('ui_admin_select_sentence'));
        return;
      }
      after = before.replaceFirst(_selected!, '').trim();
    } else if (action == RestoDescriptionCheckAction.editMinimally) {
      minimal = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final c = TextEditingController(text: before);
          return AlertDialog(
            title: Text(ctx.t('ui_admin_edit_minimally')),
            content: TextField(controller: c, maxLines: 8),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(ctx.t('ui_preview')))],
          );
        },
      );
      if (minimal == null) return;
      after = minimal;
    }
    final email = sync.previewDescriptionEmail(listing: r, before: before, after: after, action: action);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == RestoDescriptionCheckAction.dismiss ? ctx.t('ui_admin_dismiss_q') : ctx.t('ui_admin_diff_email')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ctx.t('ui_admin_before'), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(before, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Text(ctx.t('ui_admin_after'), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(after, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Text(ctx.t('ui_admin_email_to', {'to': email.to}), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(email.subject, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(email.body, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.t('ui_confirm'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = sync.applyDescriptionAction(
      caseId: widget.kase.id,
      action: action,
      actorId: auth.userId,
      actorRole: auth.role.name,
      sentence: _selected,
      minimalEdit: minimal,
    );
    if (!context.mounted) return;
    showTGToast(
      context,
      err ?? context.t('ui_admin_done_undo'),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: context.t('ui_undo'),
        onPressed: () => sync.undoDescriptionCase(widget.kase.id),
      ),
    );
    setState(() {});
  }
}
