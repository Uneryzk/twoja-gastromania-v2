import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/special_order/so_status_chip.dart';
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
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: phone && !_sideBySide ? const PageScrollPhysics() : null,
            child: _QuoteCompareTable(
              quotes: qs.take(5).toList(),
              request: request,
              lowestId: lowest?.id,
              fastestId: fastest?.id,
            ),
          ),
      ],
    );
  }
}

class _QuoteCompareTable extends StatelessWidget {
  const _QuoteCompareTable({
    required this.quotes,
    required this.request,
    required this.lowestId,
    required this.fastestId,
  });

  final List<TGQuote> quotes;
  final TGSpecialRequest request;
  final String? lowestId;
  final String? fastestId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: context.t('ui_so_quotes'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final q in quotes) ...[
            _QuoteColumn(
              quote: q,
              request: request,
              lowest: lowestId == q.id,
              fastest: fastestId == q.id,
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _QuoteColumn extends StatelessWidget {
  const _QuoteColumn({required this.quote, required this.request, required this.lowest, required this.fastest});
  final TGQuote quote;
  final TGSpecialRequest request;
  final bool lowest;
  final bool fastest;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final store = TGSellerProfileService.instance.bySellerKey(quote.sellerId);
    final highlight = quote.isNew;
    final makerName = store?.name ?? quote.sellerId;
    return AnimatedContainer(
      duration: TGMotion.of(context, const Duration(milliseconds: 200)),
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TGColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? TGColors.cta : TGColors.border, width: highlight ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                Expanded(child: Text(makerName, style: const TextStyle(fontWeight: FontWeight.w900))),
                if (highlight) Text(context.t('ui_new'), style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w900, fontSize: 11)),
              ],
            ),
          ),
          if (store != null) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: [
              if (store.verified) const TGVerifiedSellerBadge(),
              TGRatingBadge(rating: store.rating),
            ]),
            Text(context.t('ui_so_replies_in', {'n': '${store.responseHours ?? 24}'}), style: theme.bodySmall),
            TextButton(
              onPressed: () => context.go('${store.path}?tab=about'),
              child: Text(context.t('ui_so_view_projects')),
            ),
          ],
          if (lowest) _tag(context.t('ui_so_lowest_price')),
          if (fastest) _tag(context.t('ui_so_fastest')),
          const SizedBox(height: 8),
          _row(context.t('ui_price'), '${quote.priceNet} PLN netto\n${quote.priceGross} PLN brutto (${quote.vatRate}% VAT)'),
          _row(context.t('ui_so_price_type'), quote.priceType.name),
          _row(context.t('ui_so_lead_weeks'), '${quote.leadTimeWeeks}'),
          _row(context.t('ui_so_valid_until'), quote.validUntil.toIso8601String().substring(0, 10)),
          _row(context.t('ui_so_install'), quote.installationIncluded ? context.t('ui_yes') : context.t('ui_no')),
          _row(context.t('ui_so_delivery'), quote.deliveryIncluded ? context.t('ui_yes') : context.t('ui_no')),
          _row(context.t('ui_warranty'), '${quote.warrantyMonths}'),
          _row(context.t('ui_so_payment_terms'), quote.paymentTerms),
          const SizedBox(height: 10),
          if (store != null) ...[
            Text(store.phone, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                TGButton(
                  onPressed: () async {
                    await launchUrl(Uri(scheme: 'tel', path: store.phone.replaceAll(RegExp(r'[^0-9+]'), '')));
                    if (context.mounted) await copyPhoneNumber(context, store.phone);
                  },
                  label: '${context.t('ui_call_now')} ${store.phone}',
                  height: 36,
                ),
                TGButton(
                  onPressed: () => MessagingService.instance.openDock(inbox: true, draft: 'Re ${request.requestNo}'),
                  label: context.t('ui_message'),
                  variant: TGButtonVariant.outline,
                  height: 36,
                ),
                TGButton(
                  onPressed: () {
                    TGSpecialOrderService.instance.shortlistQuote(quote.id);
                    TGSpecialOrderService.instance.clearQuoteNew(quote.id);
                  },
                  label: context.t('ui_so_shortlist'),
                  variant: TGButtonVariant.ghost,
                  height: 36,
                ),
                TGButton(
                  onPressed: () => TGSpecialOrderService.instance.declineQuote(quote.id),
                  label: context.t('ui_so_decline'),
                  variant: TGButtonVariant.ghost,
                  height: 36,
                ),
                if (request.status != TGSpecialRequestStatus.awarded)
                  TGButton(
                    onPressed: () => _choose(context, store),
                    label: context.t('ui_so_choose_maker'),
                    height: 36,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String label) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(border: Border.all(color: TGColors.cta), borderRadius: BorderRadius.circular(TGRadius.pill)),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: TGColors.cta)),
      );

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white54)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
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
