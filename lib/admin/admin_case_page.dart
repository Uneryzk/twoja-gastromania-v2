import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/admin/admin_modals.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_components/tg_inline_translate.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final mod = context.watch<ModerationService>();
    final w = MediaQuery.sizeOf(context).width;
    final phone = w < TGBreakpoints.phone;
    final twoCol = w >= 1280;
    final product = _product;
    final kase = mod.caseFor(widget.listingNo);
    final sellerId = kase?.sellerId ?? product?.seller.id ?? '';
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

    final left = _LeftColumn(
      listingNo: widget.listingNo,
      product: product,
      reports: reports,
      events: events,
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
  const _LeftColumn({required this.listingNo, required this.product, required this.reports, required this.events});
  final String listingNo;
  final TGProduct? product;
  final List<TGModerationReport> reports;
  final List<TGCaseEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final fmt = DateFormat('d MMM yyyy · HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product != null) ...[
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
              TextButton.icon(
                key: const Key('admin-open-public'),
                onPressed: product == null ? null : () => context.go(product!.detailPath),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(context.t('ui_open_public_page')),
              ),
            ],
          ),
        ),
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
                  TGInlineTranslate(text: r.text, enKey: Key('admin-report-translate-en-${r.reportNo}')),
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
              Text(seller == null ? '' : adminSellerKindL10n(context, seller.type, verified: seller.verified), style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(context.t('ui_account_age', {'n': '$age'}), style: const TextStyle(fontSize: 12, color: TGColors.textSecondary)),
              Text('${context.t('ui_phone')} · ${profile?.phone ?? product?.phone ?? '—'}', style: const TextStyle(fontSize: 12)),
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
                    subtitle: Text('${s.phone} · ${s.nip ?? context.t('ui_no_nip')}', style: const TextStyle(fontSize: 11)),
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
