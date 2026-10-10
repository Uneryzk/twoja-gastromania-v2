import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/add_product/add_product_fields.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/product_detail/report_listing_sheet.dart';
import 'package:twoja_gastromania/special_order/so_status_chip.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_contact.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

class SellerLeadsPage extends StatefulWidget {
  const SellerLeadsPage({super.key, this.tab, this.requestNo, this.directedOnly = false});

  static const routeName = 'SellerLeads';
  static const routePath = '/dashboard/leads';

  final String? tab;
  final String? requestNo;
  final bool directedOnly;

  @override
  State<SellerLeadsPage> createState() => _SellerLeadsPageState();
}

class _SellerLeadsPageState extends State<SellerLeadsPage> {
  late String _tab;
  late bool _directed;

  @override
  void initState() {
    super.initState();
    _tab = widget.tab ?? 'new';
    _directed = widget.directedOnly;
    TGSpecialOrderService.instance.ensureSeeded();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final svc = TGSpecialOrderService.instance;
    final profile = TGSellerProfileService.instance.bySellerKey(auth.userId);
    final plan = auth.storePlan ?? profile?.plan;
    final detail = widget.requestNo == null ? null : svc.byRequestNo(widget.requestNo!);

    return TGPageScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.sizeOf(context).width < TGBreakpoints.phone ? 16 : (MediaQuery.sizeOf(context).width < TGBreakpoints.desktop ? 24 : 80),
                  20,
                  MediaQuery.sizeOf(context).width < TGBreakpoints.phone ? 16 : (MediaQuery.sizeOf(context).width < TGBreakpoints.desktop ? 24 : 80),
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TGBreadcrumb(
                      items: [
                        TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                        TGBreadcrumbItem(label: context.t('ui_so_leads')),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(context.t('ui_so_leads'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    if (plan == null || plan == TGStorePlanKind.basic)
                      _BasicLocked()
                    else ...[
                      if (plan == TGStorePlanKind.enterprise) ...[
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text(context.t('ui_so_all_leads')),
                              selected: !_directed,
                              onSelected: (_) => setState(() => _directed = false),
                            ),
                            ChoiceChip(
                              label: Text(context.t('ui_so_directed_to_me')),
                              selected: _directed,
                              onSelected: (_) => setState(() => _directed = true),
                            ),
                            TextButton(
                              onPressed: () => _openAlertSettings(context, auth.userId),
                              child: Text(context.t('ui_so_lead_alerts')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final t in [('new', context.t('ui_new')), ('quoted', context.t('ui_so_quoted')), ('won', context.t('ui_so_won')), ('closed', context.t('ui_closed'))])
                            ChoiceChip(
                              label: Text(t.$2),
                              selected: _tab == t.$1,
                              onSelected: (_) => setState(() => _tab = t.$1),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (detail != null)
                        _LeadDetail(request: detail, sellerId: auth.userId, plan: plan)
                      else
                        ..._list(context, auth.userId, plan),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const TGFooter(),
        ],
      ),
    );
  }

  List<Widget> _list(BuildContext context, String sellerId, TGStorePlanKind plan) {
    final svc = TGSpecialOrderService.instance;
    final leads = svc.leadsForSeller(sellerId, directedOnly: _directed || plan == TGStorePlanKind.pro);
    final filtered = leads.where((r) {
      final mine = svc.quotesFor(r.id).where((q) => q.sellerId == sellerId).toList();
      return switch (_tab) {
        'quoted' => mine.isNotEmpty && r.status != TGSpecialRequestStatus.awarded && r.status != TGSpecialRequestStatus.closed,
        'won' => r.status == TGSpecialRequestStatus.awarded && r.awardedSellerId == sellerId,
        'closed' => r.status == TGSpecialRequestStatus.closed || r.status == TGSpecialRequestStatus.expired || (r.status == TGSpecialRequestStatus.awarded && r.awardedSellerId != sellerId),
        _ => mine.isEmpty && (r.status == TGSpecialRequestStatus.open || r.status == TGSpecialRequestStatus.quoted || r.status == TGSpecialRequestStatus.held),
      };
    }).toList();
    if (filtered.isEmpty) return [Text(context.t('ui_so_no_leads'))];
    return [
      for (final r in filtered)
        _LeadCard(
          request: r,
          quoteCount: svc.activeQuoteCount(r.id),
          onTap: () => context.go('/dashboard/leads?id=${r.requestNo}&tab=$_tab${_directed ? '&directed=1' : ''}'),
        ),
    ];
  }

  Future<void> _openAlertSettings(BuildContext context, String sellerId) async {
    final svc = TGSpecialOrderService.instance;
    var settings = svc.alertSettings(sellerId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TGColors.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + MediaQuery.paddingOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.t('ui_so_lead_alerts'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 12),
              Text(context.t('ui_project_type'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in TGStoreSpecialty.values.where((e) => e != TGStoreSpecialty.other))
                    FilterChip(
                      selected: settings.categories.contains(s),
                      label: Text(context.t('ui_so_spec_${s.name}')),
                      onSelected: (v) {
                        final next = {...settings.categories};
                        v ? next.add(s) : next.remove(s);
                        setLocal(() => settings = settings.copyWith(categories: next));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(context.t('ui_so_regions'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final region in const ['Śląskie', 'Małopolskie', 'Mazowieckie', 'Dolnośląskie', 'Wielkopolskie', 'Pomorskie'])
                    FilterChip(
                      selected: settings.regions.contains(region),
                      label: Text(region),
                      onSelected: (v) {
                        final next = {...settings.regions};
                        v ? next.add(region) : next.remove(region);
                        setLocal(() => settings = settings.copyWith(regions: next));
                      },
                    ),
                ],
              ),
              SwitchListTile(
                title: Text(context.t('ui_so_instant_email')),
                value: settings.instantEmail,
                onChanged: (v) => setLocal(() => settings = settings.copyWith(instantEmail: v)),
              ),
              SwitchListTile(
                title: Text(context.t('ui_so_daily_digest')),
                value: settings.dailyDigest,
                onChanged: (v) => setLocal(() => settings = settings.copyWith(dailyDigest: v)),
              ),
              TGButton(
                onPressed: () {
                  svc.saveAlertSettings(sellerId, settings);
                  Navigator.pop(ctx);
                  showTGToast(context, context.t('ui_so_alerts_saved'));
                },
                label: context.t('ui_save'),
                height: 44,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BasicLocked extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Opacity(
            opacity: 0.45,
            child: Column(
              children: List.generate(3, (_) => Container(
                    height: 88,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: TGColors.surface, borderRadius: BorderRadius.circular(12)),
                  )),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.t('ui_so_upgrade_pro'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TGButton(onPressed: () => TGNav.plans(context), label: context.t('ui_see_plans'), height: 44),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.request, required this.quoteCount, required this.onTap});
  final TGSpecialRequest request;
  final int quoteCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final age = TGClock.now().difference(request.createdAt);
    final ageLabel = age.inDays > 0 ? '${age.inDays}d' : '${age.inHours}h';
    final budget = request.budgetMin == null ? context.t('ui_so_budget_none') : '${request.budgetMin}–${request.budgetMax} PLN';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: TGColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(request.requestNo, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const Spacer(),
                    Text(ageLabel, style: TextStyle(color: FlutterFlowTheme.of(context).secondaryText, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(request.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in request.projectTypes.take(3))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: TGColors.accent, borderRadius: BorderRadius.circular(TGRadius.pill)),
                        child: Text(context.t('ui_so_spec_${s.name}'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${request.city}, ${request.voivodeship} · $budget · ${request.deadline.name} · $quoteCount / ${request.quoteLimit} quotes'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeadDetail extends StatelessWidget {
  const _LeadDetail({required this.request, required this.sellerId, required this.plan});
  final TGSpecialRequest request;
  final String sellerId;
  final TGStorePlanKind plan;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGSpecialOrderService.instance;
    svc.markLeadViewed(request.id, sellerId);
    final myQuote = svc.quotesFor(request.id).where((q) => q.sellerId == sellerId).firstOrNull;
    final canQuote = svc.canSubmitQuote(request.id, sellerId);
    final via = svc.viaFor(request.id, sellerId);
    final poolBlocked = via == TGLeadAccessVia.enterprisePool && svc.poolQuoteCount(request.id) >= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(request.requestNo, style: theme.titleLarge.override(fontWeight: FontWeight.w900)),
            const SizedBox(width: 12),
            SoStatusChip(status: request.status, quoteCount: svc.quotesFor(request.id).length),
          ],
        ),
        const SizedBox(height: 8),
        Text(request.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        const SizedBox(height: 8),
        Text(request.description, style: const TextStyle(height: 1.45)),
        const SizedBox(height: 12),
        Text('${request.city}, ${request.voivodeship}'),
        Text(request.budgetMin == null ? context.t('ui_so_budget_none') : '${request.budgetMin}–${request.budgetMax} PLN netto'),
        const SizedBox(height: 16),
        Text(context.t('ui_so_step_files'), style: const TextStyle(fontWeight: FontWeight.w900)),
        for (final f in request.files)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: Text(f.name),
            onTap: () => showTGToast(context, context.t('ui_so_download_mock')),
          ),
        const SizedBox(height: 12),
        Text(context.t('ui_contact'), style: const TextStyle(fontWeight: FontWeight.w900)),
        if (request.shareContact) ...[
          Text(request.buyerName, style: const TextStyle(fontWeight: FontWeight.w800)),
          Row(
            children: [
              Text(request.phone, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              IconButton(onPressed: () => copyPhoneNumber(context, request.phone), icon: const Icon(Icons.copy, size: 18)),
            ],
          ),
          Row(
            children: [
              Text(request.email),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: request.email));
                  showTGToast(context, context.t('ui_copied_check'));
                },
                icon: const Icon(Icons.copy, size: 18),
              ),
            ],
          ),
        ] else
          Text(context.t('ui_so_contact_platform'), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => showReportFlow(context, TGReportSubject.request(request)),
          child: Text(context.t('ui_so_report_request')),
        ),
        const SizedBox(height: 16),
        if (myQuote != null) ...[
          Text(context.t('ui_so_your_quote'), style: const TextStyle(fontWeight: FontWeight.w900)),
          Text('${myQuote.priceNet} PLN netto · ${myQuote.status.name}'),
          if (request.status != TGSpecialRequestStatus.awarded)
            TextButton(
              onPressed: () {
                svc.withdrawQuote(myQuote.id, sellerId);
                showTGToast(context, context.t('ui_so_quote_withdrawn'));
              },
              child: Text(context.t('ui_so_withdraw')),
            ),
        ] else
          TGButton(
            onPressed: !canQuote
                ? null
                : () => showQuoteDrawer(context, request: request, sellerId: sellerId, plan: plan),
            label: poolBlocked ? context.t('ui_so_quote_limit_pool') : context.t('ui_so_submit_quote'),
            height: 48,
          ),
        Text(context.t('ui_so_quote_disclaimer'), style: theme.bodySmall.override(color: theme.secondaryText)),
      ],
    );
  }
}

Future<void> showQuoteDrawer(
  BuildContext context, {
  required TGSpecialRequest request,
  required String sellerId,
  required TGStorePlanKind plan,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.t('ui_close'),
    barrierColor: Colors.black54,
    transitionDuration: TGMotion.of(context, const Duration(milliseconds: 220)),
    pageBuilder: (ctx, _, __) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: TGColors.surface,
        child: SizedBox(
          width: 560,
          height: MediaQuery.sizeOf(ctx).height,
          child: FocusScope(
            autofocus: true,
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(ctx).maybePop(),
              },
              child: _QuoteForm(request: request, sellerId: sellerId, plan: plan),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved), child: child);
    },
  );
}

class _QuoteForm extends StatefulWidget {
  const _QuoteForm({required this.request, required this.sellerId, required this.plan});
  final TGSpecialRequest request;
  final String sellerId;
  final TGStorePlanKind plan;

  @override
  State<_QuoteForm> createState() => _QuoteFormState();
}

class _QuoteFormState extends State<_QuoteForm> {
  final _price = TextEditingController();
  final _weeks = TextEditingController(text: '5');
  final _warranty = TextEditingController(text: '24');
  final _terms = TextEditingController(text: '40% advance, balance on delivery');
  final _note = TextEditingController();
  TGQuotePriceType _type = TGQuotePriceType.fixed;
  bool _install = true;
  bool _delivery = true;
  bool _remind = false;

  @override
  void dispose() {
    _price.dispose();
    _weeks.dispose();
    _warranty.dispose();
    _terms.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _net => int.tryParse(_price.text);
  int get _gross => _net == null ? 0 : (_net! * 1.23).round();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final templates = TGSpecialOrderService.instance.templatesFor(widget.sellerId);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(child: Text(context.t('ui_so_submit_quote'), style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 12),
            WizardLabel(context.t('ui_so_price_netto')),
            WizardField(controller: _price, keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
            if (_net != null) Text('${context.t('ui_so_price_brutto')}: $_gross PLN', style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final t in TGQuotePriceType.values)
                  ChoiceChip(label: Text(t.name), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
              ],
            ),
            const SizedBox(height: 10),
            WizardLabel(context.t('ui_so_lead_weeks')),
            WizardField(controller: _weeks, keyboardType: TextInputType.number),
            WizardLabel(context.t('ui_warranty')),
            WizardField(controller: _warranty, keyboardType: TextInputType.number),
            WizardLabel(context.t('ui_so_payment_terms')),
            WizardField(controller: _terms, maxLines: 2),
            WizardLabel(context.t('ui_note')),
            WizardField(controller: _note, maxLines: 3),
            CheckboxListTile(value: _install, onChanged: (v) => setState(() => _install = v ?? false), title: Text(context.t('ui_so_install')), activeColor: TGColors.cta, contentPadding: EdgeInsets.zero),
            CheckboxListTile(value: _delivery, onChanged: (v) => setState(() => _delivery = v ?? false), title: Text(context.t('ui_so_delivery')), activeColor: TGColors.cta, contentPadding: EdgeInsets.zero),
            if (widget.plan == TGStorePlanKind.pro || widget.plan == TGStorePlanKind.enterprise) ...[
              CheckboxListTile(value: _remind, onChanged: (v) => setState(() => _remind = v ?? false), title: Text(context.t('ui_so_remind_followup')), activeColor: TGColors.cta, contentPadding: EdgeInsets.zero),
              if (templates.isNotEmpty)
                DropdownButton<TGQuoteTemplate>(
                  hint: Text(context.t('ui_so_load_template')),
                  items: [for (final t in templates) DropdownMenuItem(value: t, child: Text(t.name))],
                  onChanged: (t) {
                    if (t == null) return;
                    setState(() {
                      _type = t.priceType;
                      _weeks.text = '${t.leadTimeWeeks}';
                      _warranty.text = '${t.warrantyMonths}';
                      _terms.text = t.paymentTerms;
                      _note.text = t.note;
                      _install = t.installationIncluded;
                      _delivery = t.deliveryIncluded;
                    });
                  },
                ),
              TextButton(
                onPressed: () {
                  TGSpecialOrderService.instance.saveTemplate(TGQuoteTemplate(
                    id: 'tpl-${DateTime.now().millisecondsSinceEpoch}',
                    sellerId: widget.sellerId,
                    name: 'Saved ${TGClock.now().toIso8601String().substring(0, 10)}',
                    priceType: _type,
                    leadTimeWeeks: int.tryParse(_weeks.text) ?? 5,
                    warrantyMonths: int.tryParse(_warranty.text) ?? 24,
                    paymentTerms: _terms.text,
                    note: _note.text,
                    installationIncluded: _install,
                    deliveryIncluded: _delivery,
                  ));
                  showTGToast(context, context.t('ui_so_template_saved'));
                },
                child: Text(context.t('ui_so_save_template')),
              ),
            ],
            const SizedBox(height: 8),
            Text(context.t('ui_so_quote_disclaimer'), style: theme.bodySmall.override(color: theme.secondaryText)),
            if (widget.plan == TGStorePlanKind.pro || widget.plan == TGStorePlanKind.enterprise)
              TextButton(
                onPressed: _net == null
                    ? null
                    : () => showTGToast(context, context.t('ui_so_pdf_exported')),
                child: Text(context.t('ui_so_export_pdf')),
              ),
            const SizedBox(height: 16),
            TGButton(
              onPressed: _net == null
                  ? null
                  : () {
                      TGSpecialOrderService.instance.submitQuote(
                        requestId: widget.request.id,
                        sellerId: widget.sellerId,
                        priceNet: _net!,
                        priceType: _type,
                        leadTimeWeeks: int.tryParse(_weeks.text) ?? 5,
                        validUntil: TGClock.now().add(const Duration(days: 14)),
                        installationIncluded: _install,
                        deliveryIncluded: _delivery,
                        warrantyMonths: int.tryParse(_warranty.text) ?? 24,
                        paymentTerms: _terms.text,
                        note: _note.text,
                      );
                      Navigator.pop(context);
                      showTGToast(context, context.t('ui_so_quote_sent'));
                    },
              label: context.t('ui_so_submit_quote'),
              height: 48,
            ),
          ],
        ),
      ),
    );
  }
}
