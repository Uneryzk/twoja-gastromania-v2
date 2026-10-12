import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/special_order/so_status_chip.dart';
import 'package:twoja_gastromania/special_order/special_order_hub_widgets.dart' show SoRecentProjects;
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_badges.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_contact.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/special_order/special_review_composer.dart';
import 'package:twoja_gastromania/tg_components/audited_badge.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
import 'package:twoja_gastromania/tg_services/special_review_service.dart';
import 'package:url_launcher/url_launcher.dart';

class BuyerRequestsPage extends StatefulWidget {
  const BuyerRequestsPage({super.key, this.tab, this.requestNo});

  static const routeName = 'BuyerRequests';
  static const routePath = '/account/requests';

  final String? tab;
  final String? requestNo;

  @override
  State<BuyerRequestsPage> createState() => _BuyerRequestsPageState();
}

class _BuyerRequestsPageState extends State<BuyerRequestsPage> {
  late String _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.tab ?? 'all';
    TGSpecialOrderService.instance.ensureSeeded();
    if (widget.requestNo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        TGAnalytics.track('so_quote_compare_view', {'requestNo': widget.requestNo});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final svc = TGSpecialOrderService.instance;
    final all = svc.forBuyer(auth.userId);
    final filtered = all.where((r) {
      return switch (_tab) {
        'open' => r.status == TGSpecialRequestStatus.open || r.status == TGSpecialRequestStatus.quoted || r.status == TGSpecialRequestStatus.held,
        'awarded' => r.status == TGSpecialRequestStatus.awarded,
        'closed' => r.status == TGSpecialRequestStatus.closed || r.status == TGSpecialRequestStatus.expired || r.status == TGSpecialRequestStatus.rejected,
        _ => true,
      };
    }).toList();
    final detail = widget.requestNo == null ? null : svc.byRequestNo(widget.requestNo!);
    final blocked = detail != null && detail.buyerId != auth.userId;

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
                        TGBreadcrumbItem(label: context.t('ui_so_my_requests'), onTap: detail == null ? null : () => context.go('/account/requests')),
                        if (detail != null) TGBreadcrumbItem(label: detail.requestNo),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(detail == null ? context.t('ui_so_my_requests') : detail.requestNo, style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    if (blocked)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: theme.alternate, borderRadius: BorderRadius.circular(12), border: Border.all(color: TGColors.border)),
                        child: Text(context.t('ui_so_wrong_account'), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                      )
                    else if (detail == null) ...[
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final t in [('all', context.t('ui_all')), ('open', context.t('ui_open')), ('awarded', context.t('ui_so_awarded')), ('closed', context.t('ui_closed'))])
                            ChoiceChip(
                              label: Text(t.$2),
                              selected: _tab == t.$1,
                              onSelected: (_) {
                                setState(() => _tab = t.$1);
                                context.go('/account/requests?tab=${t.$1}');
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (filtered.isEmpty)
                        Text(context.t('ui_so_no_requests'), style: theme.bodyLarge)
                      else
                        for (final r in filtered)
                          _RequestListTile(
                            request: r,
                            quoteCount: svc.quotesFor(r.id).length,
                            onTap: () => context.go('/account/requests/${r.requestNo}'),
                          ),
                    ] else
                      _RequestDetail(request: detail),
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
}

class _RequestListTile extends StatelessWidget {
  const _RequestListTile({required this.request, required this.quoteCount, required this.onTap});
  final TGSpecialRequest request;
  final int quoteCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.requestNo, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(request.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                SoStatusChip(status: request.status, quoteCount: quoteCount, rejectReason: request.rejectReason),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestDetail extends StatefulWidget {
  const _RequestDetail({required this.request});
  final TGSpecialRequest request;

  @override
  State<_RequestDetail> createState() => _RequestDetailState();
}

class _RequestDetailState extends State<_RequestDetail> {
  bool _sideBySide = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGSpecialOrderService.instance;
    final request = widget.request;
    final qs = svc.quotesFor(request.id);
    final days = request.daysUntilClose(TGClock.now());
    final lowest = qs.isEmpty ? null : qs.reduce((a, b) => a.priceNet <= b.priceNet ? a : b);
    final fastest = qs.isEmpty ? null : qs.reduce((a, b) => a.leadTimeWeeks <= b.leadTimeWeeks ? a : b);
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(child: SoStatusChip(status: request.status, quoteCount: qs.length, rejectReason: request.rejectReason)),
            const SizedBox(width: 12),
            Text(context.t('ui_so_closes_in', {'n': '$days'}), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (request.status != TGSpecialRequestStatus.awarded && request.status != TGSpecialRequestStatus.closed)
              TextButton(
                onPressed: () {
                  svc.closeRequest(request.id);
                  showTGToast(context, context.t('ui_so_request_closed'));
                },
                child: Text(context.t('ui_so_close_request')),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(request.title, style: theme.titleLarge.override(fontWeight: FontWeight.w900)),
        Text('${request.city} · ${request.voivodeship}', style: theme.bodyMedium.override(color: theme.secondaryText)),
        if (request.dimensionsText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(request.dimensionsText, style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700)),
        ],
        if (request.description.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(request.description, style: theme.bodyMedium),
        ],
        const SizedBox(height: 16),
        Text(context.t('ui_so_attachments'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        if (request.files.isEmpty)
          Text(context.t('ui_so_no_attachments'), style: theme.bodySmall.override(color: theme.secondaryText))
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: request.files.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final f = request.files[i];
                final isImage = f.assetPath.toLowerCase().contains('.jpg') ||
                    f.assetPath.toLowerCase().contains('.jpeg') ||
                    f.assetPath.toLowerCase().contains('.png') ||
                    f.assetPath.toLowerCase().contains('.webp');
                return InkWell(
                  onTap: () => _openAttachment(context, request.files, i),
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 160,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (isImage)
                            Image.asset(f.assetPath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate, child: const Icon(Icons.insert_drive_file_outlined)))
                          else
                            ColoredBox(
                              color: theme.alternate,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.picture_as_pdf_outlined, size: 36),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(f.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black87],
                                ),
                              ),
                              child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (request.status == TGSpecialRequestStatus.awarded) ...[
          const SizedBox(height: 16),
          Text(context.t('ui_so_project_completion'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          Text(
            context.t('ui_so_completion_status', {'s': context.t('ui_so_completion_${request.completionStatus.name}')}),
            style: theme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (request.completionStatus != TGProjectCompletionStatus.completed)
                TGButton(
                  onPressed: () {
                    final auth = context.read<FakeAuthState>();
                    TGSpecialReviewService.instance.markCompleted(request.id, buyerId: auth.userId);
                    setState(() {});
                    showSpecialReviewComposer(context, request: svc.byId(request.id)!);
                  },
                  label: context.t('ui_so_mark_completed'),
                  height: 40,
                ),
              if (request.completionStatus == TGProjectCompletionStatus.inProgress)
                TGButton(
                  onPressed: () {
                    final auth = context.read<FakeAuthState>();
                    TGSpecialReviewService.instance.markStillInProgress(request.id, buyerId: auth.userId);
                    setState(() {});
                    showTGToast(context, context.t('ui_so_ask_again_14d'));
                  },
                  label: context.t('ui_so_still_in_progress'),
                  variant: TGButtonVariant.outline,
                  height: 40,
                ),
              if (request.completionStatus == TGProjectCompletionStatus.completed)
                TGButton(
                  onPressed: () => showSpecialReviewComposer(context, request: request),
                  label: context.t('ui_so_write_project_review'),
                  height: 40,
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text(context.t('ui_so_quotes'), style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
            if (qs.length > 1 && phone)
              FilterChip(
                label: Text(context.t('ui_so_compare_side')),
                selected: _sideBySide,
                onSelected: (v) => setState(() => _sideBySide = v),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (qs.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(border: Border.all(color: TGColors.border), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('ui_so_no_quotes_yet'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TGButton(
                  onPressed: () {
                    svc.matchMore(request.id);
                    showTGToast(context, context.t('ui_so_team_matching'));
                  },
                  label: context.t('ui_so_ask_match'),
                  height: 44,
                ),
              ],
            ),
          )
        else
          _QuoteCompareTable(
            quotes: qs.take(5).toList(),
            request: request,
            lowestId: lowest?.id,
            fastestId: fastest?.id,
            sideBySide: !phone || _sideBySide,
          ),
        const SizedBox(height: 28),
        Text(context.t('ui_so_featured_makers'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(context.t('ui_so_featured_makers_sub'), style: theme.bodyMedium.override(color: theme.secondaryText)),
        const SizedBox(height: 14),
        SoRecentProjects(entries: svc.recentProjectEntries()),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.go('/special-order'),
            child: Text(context.t('ui_browse_manufacturers'), style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Future<void> _openAttachment(BuildContext context, List<TGSpecialFile> files, int index) async {
    final theme = FlutterFlowTheme.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var i = index;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final f = files[i];
            return Dialog(
              backgroundColor: theme.secondaryBackground,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w900))),
                          if (files.length > 1) ...[
                            IconButton(
                              onPressed: i > 0 ? () => setLocal(() => i--) : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            IconButton(
                              onPressed: i < files.length - 1 ? () => setLocal(() => i++) : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                          IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            f.assetPath,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => SizedBox(
                              height: 200,
                              child: Center(child: Text(ctx.t('ui_so_open_file'))),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _QuoteCompareTable extends StatelessWidget {
  const _QuoteCompareTable({
    required this.quotes,
    required this.request,
    required this.lowestId,
    required this.fastestId,
    required this.sideBySide,
  });

  final List<TGQuote> quotes;
  final TGSpecialRequest request;
  final String? lowestId;
  final String? fastestId;
  final bool sideBySide;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final phone = screenW < TGBreakpoints.phone;
    final desktop = screenW >= TGBreakpoints.desktop;

    // Mobile stack: full-width cards. Side-by-side / desktop: wider cards (~300–340).
    final cardW = phone
        ? (screenW - 40).clamp(300.0, 420.0)
        : desktop
            ? 340.0
            : 300.0;

    if (!sideBySide && phone) {
      return Column(
        children: [
          for (var i = 0; i < quotes.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _QuoteColumn(
              quote: quotes[i],
              request: request,
              lowest: lowestId == quotes[i].id,
              fastest: fastestId == quotes[i].id,
              width: double.infinity,
            ),
          ],
        ],
      );
    }

    const gap = 12.0;
    final needed = quotes.length * cardW + (quotes.length - 1) * gap;
    final canFit = !phone && needed <= screenW - 48;

    Widget card(TGQuote q, {required double? w}) => _QuoteColumn(
          quote: q,
          request: request,
          lowest: lowestId == q.id,
          fastest: fastestId == q.id,
          width: w,
        );

    if (canFit) {
      return Semantics(
        container: true,
        label: context.t('ui_so_quotes'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < quotes.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(child: card(quotes[i], w: null)),
              ],
            ],
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: context.t('ui_so_quotes'),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: phone ? const PageScrollPhysics() : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < quotes.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                card(quotes[i], w: cardW),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteColumn extends StatelessWidget {
  const _QuoteColumn({
    required this.quote,
    required this.request,
    required this.lowest,
    required this.fastest,
    this.width = 320,
  });
  final TGQuote quote;
  final TGSpecialRequest request;
  final bool lowest;
  final bool fastest;
  final double? width;

  String _priceTypeLabel(BuildContext context) => switch (quote.priceType) {
        TGQuotePriceType.fixed => context.t('ui_so_price_fixed'),
        TGQuotePriceType.from => context.t('ui_so_price_from'),
        TGQuotePriceType.estimate => context.t('ui_so_price_estimate'),
      };

  String _paymentTermsLabel(BuildContext context) {
    final raw = quote.paymentTerms.trim();
    if (raw == '40% advance, balance on delivery') return context.t('ui_so_pay_40_advance');
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final store = TGSellerProfileService.instance.bySellerKey(quote.sellerId);
    final highlight = quote.isNew;
    final makerName = store?.name ?? quote.sellerId;
    final priceLine = context.t('ui_so_price_line', {
      'net': '${quote.priceNet}',
      'gross': '${quote.priceGross}',
      'vat': '${quote.vatRate}',
      'netto': context.t('ui_netto'),
      'brutto': context.t('ui_brutto'),
      'vatLabel': context.t('ui_vat_short'),
    });
    return AnimatedContainer(
      duration: TGMotion.of(context, const Duration(milliseconds: 200)),
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TGColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? TGColors.cta : TGColors.border, width: highlight ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                Expanded(child: Text(makerName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                if (highlight) Text(context.t('ui_new'), style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w900, fontSize: 11)),
              ],
            ),
          ),
          if (store != null) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (store.verified) const TGVerifiedSellerBadge(),
              AuditedManufacturerBadge(sellerId: store.sellerKey, compact: true),
              TGRatingBadge(rating: store.rating),
            ]),
            const SizedBox(height: 4),
            CustomProjectsRatingLine(sellerId: store.sellerKey),
            Text(context.t('ui_so_replies_in', {'n': '${store.responseHours ?? 24}'}), style: theme.bodySmall),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.go('${store.path}?tab=about'),
                child: Text(context.t('ui_so_view_projects')),
              ),
            ),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (lowest) _tag(context.t('ui_so_lowest_price')),
              if (quote.isRevised) _tag(context.t('ui_so_revised')),
              if (fastest) _tag(context.t('ui_so_fastest')),
            ],
          ),
          const SizedBox(height: 10),
          _row(context.t('ui_price'), priceLine),
          _row(context.t('ui_so_price_type'), _priceTypeLabel(context)),
          _row(context.t('ui_so_lead_weeks'), '${quote.leadTimeWeeks}'),
          _row(context.t('ui_so_valid_until'), quote.validUntil.toIso8601String().substring(0, 10)),
          _row(context.t('ui_so_install'), quote.installationIncluded ? context.t('ui_yes') : context.t('ui_no')),
          _row(context.t('ui_so_delivery'), quote.deliveryIncluded ? context.t('ui_yes') : context.t('ui_no')),
          _row(context.t('ui_warranty'), '${quote.warrantyMonths}'),
          _row(context.t('ui_so_payment_terms'), _paymentTermsLabel(context)),
          const SizedBox(height: 12),
          if (store != null) ...[
            Text(store.phone, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TGButton(
              onPressed: () async {
                await launchUrl(Uri(scheme: 'tel', path: store.phone.replaceAll(RegExp(r'[^0-9+]'), '')));
                if (context.mounted) await copyPhoneNumber(context, store.phone);
              },
              label: context.t('ui_call_now'),
              height: 44,
            ),
            const SizedBox(height: 8),
            TGButton(
              onPressed: () => MessagingService.instance.openDock(inbox: true, draft: 'Re ${request.requestNo}'),
              label: context.t('ui_message'),
              variant: TGButtonVariant.outline,
              height: 44,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      TGSpecialOrderService.instance.shortlistQuote(quote.id);
                      TGSpecialOrderService.instance.clearQuoteNew(quote.id);
                    },
                    child: Text(context.t('ui_so_shortlist')),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => _decline(context),
                    child: Text(context.t('ui_so_decline')),
                  ),
                ),
              ],
            ),
            if (request.status != TGSpecialRequestStatus.awarded) ...[
              const SizedBox(height: 4),
              TGButton(
                onPressed: () => _choose(context, store),
                label: context.t('ui_so_choose_maker'),
                height: 44,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _decline(BuildContext context) async {
    final reason = await showModalBottomSheet<TGQuoteDeclineReason>(
      context: context,
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.t('ui_so_decline'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 8),
              Text(context.t('ui_so_decline_optional'), style: TextStyle(color: FlutterFlowTheme.of(ctx).secondaryText, fontSize: 12)),
              const SizedBox(height: 12),
              for (final e in TGQuoteDeclineReason.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, e),
                    child: Text(context.t('ui_so_decline_${e.name}')),
                  ),
                ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('ui_skip'))),
            ],
          ),
        ),
      ),
    );
    TGSpecialOrderService.instance.declineQuote(quote.id, reason: reason);
  }

  Widget _tag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(border: Border.all(color: TGColors.cta), borderRadius: BorderRadius.circular(TGRadius.pill)),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: TGColors.cta)),
      );

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white54)),
            const SizedBox(height: 2),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
          ],
        ),
      );

  Future<void> _choose(BuildContext context, TGStoreProfile store) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('ui_so_choose_maker')),
        content: Text(context.t('ui_so_award_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('ui_cancel'))),
          TGButton(onPressed: () => Navigator.pop(ctx, true), label: context.t('ui_confirm'), height: 40),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      TGSpecialOrderService.instance.award(request.id, store.sellerKey);
      showTGToast(context, context.t('ui_so_awarded_toast'));
    }
  }
}
