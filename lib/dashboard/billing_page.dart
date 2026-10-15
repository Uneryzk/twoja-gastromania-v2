import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/dash2_widgets.dart';
import 'package:twoja_gastromania/dashboard/dash3_widgets.dart';
import 'package:twoja_gastromania/dashboard/dashboard_shell.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/priority_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';

/// `/dashboard/billing?tab=payments|invoices|subscriptions|methods|credits`.
class BillingPage extends StatefulWidget {
  const BillingPage({super.key, this.tab});

  static const routeName = 'DashboardBilling';
  static const routePath = '/dashboard/billing';
  static const tabs = ['payments', 'invoices', 'subscriptions', 'methods', 'credits'];

  final String? tab;

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  String get _tab => BillingPage.tabs.contains(widget.tab) ? widget.tab! : 'payments';

  @override
  void initState() {
    super.initState();
    TGAnalytics.track('billing_view', {'tab': _tab});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TGBillingService.instance.processDunning();
    });
  }

  @override
  void didUpdateWidget(covariant BillingPage old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab) TGAnalytics.track('billing_view', {'tab': _tab});
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      current: 'billing',
      child: ListenableBuilder(
        listenable: Listenable.merge([TGBillingService.instance, PromotionService.instance, TGPriorityService.instance, TGFounderService.instance]),
        builder: (context, _) {
          final theme = FlutterFlowTheme.of(context);
          final auth = context.watch<FakeAuthState>();
          final pastDue = TGBillingService.instance.pastDueFor(auth.userId);
          return Column(
            key: const Key('billing-page'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(context.t('bill_title'), style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 4),
              Text(context.t('bill_vat_note'), key: const Key('billing-vat-note'), style: theme.bodySmall.override(color: theme.secondaryText)),
              const SizedBox(height: 12),
              for (final s in pastDue) ...[
                _PastDueBanner(sub: s),
                const SizedBox(height: 12),
              ],
              DashTabBar(
                keyPrefix: 'billing',
                semanticsLabel: context.t('bill_title'),
                current: _tab,
                tabs: [for (final t in BillingPage.tabs) (t, context.t('bill_tab_$t'))],
                onSelect: (t) => context.go('${BillingPage.routePath}?tab=$t'),
              ),
              const SizedBox(height: 16),
              switch (_tab) {
                'invoices' => _InvoicesTab(userId: auth.userId),
                'subscriptions' => _SubscriptionsTab(auth: auth),
                'methods' => _MethodsTab(userId: auth.userId),
                'credits' => DashCreditsPanel(userId: auth.userId),
                _ => _PaymentsTab(userId: auth.userId),
              },
            ],
          );
        },
      ),
    );
  }
}

bool _isPhone(BuildContext context) => MediaQuery.sizeOf(context).width < TGBreakpoints.phone;

String _dateFmt(BuildContext context, DateTime d) => DateFormat('d MMM y', Localizations.localeOf(context).languageCode).format(d);

String _kindLabel(BuildContext context, TGPaymentKind k) => context.t('bill_kind_${k.name}');

String _periodLabel(BuildContext context, TGBillingPeriod p) => context.t('bill_period_${p.name}');

class _PastDueBanner extends StatelessWidget {
  const _PastDueBanner({required this.sub});
  final TGSubscription sub;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final next = TGBillingService.instance.nextRetryAt(sub);
    return Semantics(
      liveRegion: true,
      child: DashBox(
        key: Key('billing-pastdue-banner-${sub.id}'),
        borderColor: TGColors.error,
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const ExcludeSemantics(child: Icon(Icons.error_outline, color: TGColors.error)),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                next == null
                    ? context.t('bill_pastdue_body_last', {'title': sub.label})
                    : context.t('bill_pastdue_body', {'title': sub.label, 'd': _dateFmt(context, next)}),
                style: theme.bodyMedium.override(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton(
              key: Key('billing-pastdue-pay-${sub.id}'),
              style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
              onPressed: () => context.go('${BillingPage.routePath}?tab=subscriptions'),
              child: Text(context.t('dash_cta_pay')),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Payments
// -----------------------------------------------------------------------------

class _PaymentsTab extends StatefulWidget {
  const _PaymentsTab({required this.userId});
  final String userId;

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  TGPaymentKind? _kind;
  TGPaymentStatus? _status;
  int _days = 0;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<TGPayment> _filtered(List<TGPayment> all) {
    final now = TGClock.now();
    final q = _search.text.trim().toLowerCase();
    return [
      for (final p in all)
        if ((_kind == null || p.kind == _kind) &&
            (_status == null || p.status == _status) &&
            (_days == 0 || p.createdAt.isAfter(now.subtract(Duration(days: _days)))) &&
            (q.isEmpty || p.description.toLowerCase().contains(q) || p.id.toLowerCase().contains(q) || (p.listingNo ?? '').toLowerCase().contains(q)))
          p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGBillingService.instance;
    final all = svc.paymentsFor(widget.userId);
    final rows = _filtered(all);
    final total = rows.where((p) => p.status == TGPaymentStatus.succeeded).fold(TGVatSplit.zero, (a, p) => a + p.amount);
    final kinds = {for (final p in all) p.kind}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final phone = _isPhone(context);

    final filters = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: phone ? double.infinity : 240,
          child: TextField(
            key: const Key('billing-search'),
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              labelText: context.t('bill_search'),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        _Drop<TGPaymentKind?>(
          key: const Key('billing-filter-kind'),
          label: context.t('bill_f_kind'),
          value: _kind,
          items: [(null, context.t('bill_f_all')), for (final k in kinds) (k, _kindLabel(context, k))],
          onChanged: (v) => setState(() => _kind = v),
        ),
        _Drop<TGPaymentStatus?>(
          key: const Key('billing-filter-status'),
          label: context.t('bill_f_status'),
          value: _status,
          items: [(null, context.t('bill_f_all')), for (final s in TGPaymentStatus.values) (s, context.t('bill_status_${s.name}'))],
          onChanged: (v) => setState(() => _status = v),
        ),
        _Drop<int>(
          key: const Key('billing-filter-period'),
          label: context.t('bill_f_period'),
          value: _days,
          items: [(0, context.t('bill_f_all')), (30, context.t('bill_f_days', {'n': '30'})), (90, context.t('bill_f_days', {'n': '90'})), (365, context.t('bill_f_days', {'n': '365'}))],
          onChanged: (v) => setState(() => _days = v ?? 0),
        ),
      ],
    );

    return Column(
      key: const Key('billing-payments'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        filters,
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              context.t('bill_totals', {'gross': tgPln(total.grossPln), 'net': tgPln(total.netPln), 'vat': tgPln(total.vatPln)}),
              key: const Key('billing-totals'),
              style: theme.bodyMedium.override(fontWeight: FontWeight.w800),
            ),
            OutlinedButton.icon(
              key: const Key('billing-export-csv'),
              onPressed: rows.isEmpty
                  ? null
                  : () {
                      TGAnalytics.track('billing_export', {'tab': 'payments', 'rows': rows.length});
                      showDashTextExport(context, title: context.t('bill_export_csv'), fileName: 'payments.csv', content: svc.paymentsCsv(rows));
                    },
              icon: const Icon(Icons.download, size: 18),
              label: Text(context.t('bill_export_csv')),
            ),
            FilledButton.icon(
              key: const Key('billing-request-invoice'),
              style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
              onPressed: () => showRequestInvoiceSheet(context, widget.userId),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: Text(context.t('bill_request_invoice')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Text(context.t(all.isEmpty ? 'bill_payments_empty' : 'bill_no_match'), key: const Key('billing-payments-empty'), style: theme.bodyMedium.override(color: theme.secondaryText))
        else if (phone)
          for (final p in rows) Padding(padding: const EdgeInsets.only(bottom: 10), child: _PaymentCard(p: p))
        else
          _PaymentsTable(rows: rows),
      ],
    );
  }
}

class _Drop<T> extends StatelessWidget {
  const _Drop({super.key, required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: DropdownButton<T>(
        value: value,
        hint: Text(label),
        underline: const SizedBox.shrink(),
        dropdownColor: TGColors.surface,
        items: [for (final i in items) DropdownMenuItem<T>(value: i.$1, child: Text('$label: ${i.$2}'))],
        onChanged: onChanged,
      ),
    );
  }
}

class _PaymentsTable extends StatelessWidget {
  const _PaymentsTable({required this.rows});
  final List<TGPayment> rows;

  @override
  Widget build(BuildContext context) {
    final svc = TGBillingService.instance;
    Widget cell(Widget c) => Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6), child: c);
    return DashBox(
      padding: const EdgeInsets.all(8),
      child: Table(
        key: const Key('billing-payments-table'),
        columnWidths: const {1: FlexColumnWidth(2.4)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [
            for (final h in ['bill_col_date', 'bill_col_desc', 'bill_col_net', 'bill_col_vat', 'bill_col_gross', 'bill_col_method', 'bill_col_status', 'bill_col_invoice'])
              cell(DashTh(context.t(h))),
          ]),
          for (final p in rows)
            TableRow(
              key: ValueKey('billing-payment-${p.id}'),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: TGColors.border))),
              children: [
                cell(Text(_dateFmt(context, p.createdAt))),
                cell(Semantics(header: true, hint: 'row header', child: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis))),
                cell(Text(tgPln(p.netPln))),
                cell(Text(tgPln(p.vatPln))),
                cell(Text(tgPln(p.grossPln), style: const TextStyle(fontWeight: FontWeight.w800))),
                cell(Text(p.methodLabel ?? '—')),
                cell(Align(alignment: Alignment.centerLeft, child: DashPill(label: context.t('bill_status_${p.status.name}'), color: tgPaymentStatusColor(p.status)))),
                cell(Text(p.invoiceId == null ? '—' : (svc.invoiceById(p.invoiceId!)?.number ?? '—'))),
              ],
            ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.p});
  final TGPayment p;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final inv = p.invoiceId == null ? null : TGBillingService.instance.invoiceById(p.invoiceId!);
    return Semantics(
      container: true,
      child: DashBox(
        key: Key('billing-payment-${p.id}'),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(p.description, style: theme.bodyMedium.override(fontWeight: FontWeight.w800))),
                DashPill(label: context.t('bill_status_${p.status.name}'), color: tgPaymentStatusColor(p.status)),
              ],
            ),
            const SizedBox(height: 6),
            Text(tgPln(p.grossPln), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
            Text(
              context.t('bill_net_vat', {'net': tgPln(p.netPln), 'vat': tgPln(p.vatPln)}),
              style: theme.bodySmall.override(color: theme.secondaryText),
            ),
            const SizedBox(height: 4),
            Text(
              [_dateFmt(context, p.createdAt), if (p.methodLabel != null) p.methodLabel!, if (inv != null) inv.number].join(' · '),
              style: theme.bodySmall.override(color: theme.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Request invoice + profile
// -----------------------------------------------------------------------------

Future<void> showRequestInvoiceSheet(BuildContext context, String userId) {
  return showDashSheet<void>(
    context,
    key: const Key('billing-request-sheet'),
    title: context.t('bill_request_invoice'),
    builder: (ctx) => _RequestInvoiceForm(userId: userId),
  );
}

class _RequestInvoiceForm extends StatefulWidget {
  const _RequestInvoiceForm({required this.userId});
  final String userId;

  @override
  State<_RequestInvoiceForm> createState() => _RequestInvoiceFormState();
}

class _RequestInvoiceFormState extends State<_RequestInvoiceForm> {
  final Set<String> _picked = {};
  String? _error;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TGBillingService.instance,
      builder: (context, _) {
        final theme = FlutterFlowTheme.of(context);
        final svc = TGBillingService.instance;
        final eligible = svc.paymentsFor(widget.userId).where((p) => svc.canRequestInvoice(p)).toList();
        final profile = svc.profileFor(widget.userId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('bill_invoice_deadline_note', {'n': '${TGBillingService.invoiceRequestMonths}'}), style: theme.bodySmall.override(color: theme.secondaryText)),
            const SizedBox(height: 12),
            DashBox(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      profile == null ? context.t('bill_profile_missing') : '${profile.companyName} · NIP ${profile.nipDigits}\n${profile.address}',
                      key: const Key('billing-request-profile'),
                    ),
                  ),
                  TextButton(
                    key: const Key('billing-request-edit-profile'),
                    onPressed: () => showInvoiceProfileSheet(context, widget.userId),
                    child: Text(context.t(profile == null ? 'bill_profile_add' : 'bill_profile_edit')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (eligible.isEmpty)
              Text(context.t('bill_request_none'), key: const Key('billing-request-none'), style: theme.bodyMedium.override(color: theme.secondaryText))
            else
              for (final p in eligible)
                CheckboxListTile(
                  key: Key('billing-request-pick-${p.id}'),
                  contentPadding: EdgeInsets.zero,
                  value: _picked.contains(p.id),
                  onChanged: (v) => setState(() => v == true ? _picked.add(p.id) : _picked.remove(p.id)),
                  title: Text(p.description),
                  subtitle: Text('${_dateFmt(context, p.createdAt)} · ${tgPln(p.grossPln)} · ${context.t('bill_until', {'d': _dateFmt(context, svc.invoiceDeadline(p).subtract(const Duration(days: 1)))})}'),
                ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(liveRegion: true, child: Text(context.t(_error!), key: const Key('billing-request-error'), style: const TextStyle(color: TGColors.error))),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('billing-request-submit'),
              style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
              onPressed: () {
                final r = svc.requestInvoice(widget.userId, _picked.toList());
                if (r.error != null) {
                  setState(() => _error = r.error);
                  return;
                }
                showTGToast(context, context.t('bill_request_done', {'no': r.invoice!.number}));
                Navigator.of(context).pop();
              },
              child: Text(context.t('bill_request_submit')),
            ),
          ],
        );
      },
    );
  }
}

Future<void> showInvoiceProfileSheet(BuildContext context, String userId) {
  return showDashSheet<void>(
    context,
    key: const Key('billing-profile-sheet'),
    title: context.t('bill_profile_title'),
    builder: (ctx) => _ProfileForm(userId: userId),
  );
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm({required this.userId});
  final String userId;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final Map<String, TextEditingController> _c;
  Map<String, String> _errors = const {};

  @override
  void initState() {
    super.initState();
    final p = TGBillingService.instance.profileFor(widget.userId);
    _c = {
      'company': TextEditingController(text: p?.companyName ?? ''),
      'nip': TextEditingController(text: p?.nip ?? ''),
      'street': TextEditingController(text: p?.street ?? ''),
      'postal': TextEditingController(text: p?.postalCode ?? ''),
      'city': TextEditingController(text: p?.city ?? ''),
      'email': TextEditingController(text: p?.email ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget field(String id) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            key: Key('billing-profile-$id'),
            controller: _c[id],
            keyboardType: id == 'nip' || id == 'postal' ? TextInputType.number : (id == 'email' ? TextInputType.emailAddress : TextInputType.text),
            decoration: InputDecoration(
              labelText: context.t('bill_pf_$id'),
              border: const OutlineInputBorder(),
              errorText: _errors[id] == null ? null : context.t(_errors[id]!),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in ['company', 'nip', 'street', 'postal', 'city', 'email']) field(f),
        FilledButton(
          key: const Key('billing-profile-save'),
          style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
          onPressed: () {
            final errors = TGBillingService.instance.saveProfile(TGInvoiceProfile(
              userId: widget.userId,
              companyName: _c['company']!.text.trim(),
              nip: _c['nip']!.text.trim(),
              street: _c['street']!.text.trim(),
              postalCode: _c['postal']!.text.trim(),
              city: _c['city']!.text.trim(),
              email: _c['email']!.text.trim(),
              updatedAt: TGClock.now(),
            ));
            if (errors.isNotEmpty) {
              setState(() => _errors = errors);
              return;
            }
            showTGToast(context, context.t('bill_profile_saved'));
            Navigator.of(context).pop();
          },
          child: Text(context.t('ui_save')),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Invoices
// -----------------------------------------------------------------------------

class _InvoicesTab extends StatelessWidget {
  const _InvoicesTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGBillingService.instance;
    final rows = svc.invoicesFor(userId);
    final profile = svc.profileFor(userId);
    final phone = _isPhone(context);

    void download(TGInvoice inv) {
      svc.trackInvoiceDownload(inv);
      showDashTextExport(context, title: inv.number, fileName: '${inv.number.replaceAll('/', '_')}.txt', content: svc.invoiceDocument(inv));
    }

    Widget actions(TGInvoice inv) => TextButton.icon(
          key: Key('billing-invoice-download-${inv.id}'),
          onPressed: () => download(inv),
          icon: const Icon(Icons.download, size: 18),
          label: Text(context.t('bill_download')),
        );

    return Column(
      key: const Key('billing-invoices'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashBox(
          key: const Key('billing-profile-card'),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(context.t('bill_profile_title'), style: theme.bodyMedium.override(fontWeight: FontWeight.w900))),
                  const SizedBox(height: 4),
                  Text(profile == null ? context.t('bill_profile_missing') : '${profile.companyName} · NIP ${profile.nipDigits}\n${profile.address}'),
                ],
              ),
              OutlinedButton(
                key: const Key('billing-profile-edit'),
                onPressed: () => showInvoiceProfileSheet(context, userId),
                child: Text(context.t(profile == null ? 'bill_profile_add' : 'bill_profile_edit')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('billing-invoices-csv'),
              onPressed: rows.isEmpty
                  ? null
                  : () {
                      TGAnalytics.track('billing_export', {'tab': 'invoices', 'rows': rows.length});
                      showDashTextExport(context, title: context.t('bill_export_csv'), fileName: 'invoices.csv', content: svc.invoicesCsv(rows));
                    },
              icon: const Icon(Icons.download, size: 18),
              label: Text(context.t('bill_export_csv')),
            ),
            FilledButton.icon(
              key: const Key('billing-invoices-request'),
              style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
              onPressed: () => showRequestInvoiceSheet(context, userId),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: Text(context.t('bill_request_invoice')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Text(context.t('bill_invoices_empty'), key: const Key('billing-invoices-empty'), style: theme.bodyMedium.override(color: theme.secondaryText))
        else if (phone)
          for (final inv in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DashBox(
                key: Key('billing-invoice-${inv.id}'),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.number, style: theme.bodyMedium.override(fontWeight: FontWeight.w900)),
                    Text(tgPln(inv.amount.grossPln), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
                    Text(context.t('bill_net_vat', {'net': tgPln(inv.amount.netPln), 'vat': tgPln(inv.amount.vatPln)}), style: theme.bodySmall.override(color: theme.secondaryText)),
                    Text(_dateFmt(context, inv.issuedAt), style: theme.bodySmall.override(color: theme.secondaryText)),
                    actions(inv),
                  ],
                ),
              ),
            )
        else
          DashBox(
            padding: const EdgeInsets.all(8),
            child: Table(
              key: const Key('billing-invoices-table'),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(children: [
                  for (final h in ['bill_col_number', 'bill_col_date', 'bill_col_net', 'bill_col_vat', 'bill_col_gross', 'bill_col_actions'])
                    Padding(padding: const EdgeInsets.all(6), child: DashTh(context.t(h))),
                ]),
                for (final inv in rows)
                  TableRow(
                    key: ValueKey('billing-invoice-${inv.id}'),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: TGColors.border))),
                    children: [
                      for (final w in <Widget>[
                        Semantics(header: true, hint: 'row header', child: Text(inv.number, style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text(_dateFmt(context, inv.issuedAt)),
                        Text(tgPln(inv.amount.netPln)),
                        Text(tgPln(inv.amount.vatPln)),
                        Text(tgPln(inv.amount.grossPln)),
                        Align(alignment: Alignment.centerLeft, child: actions(inv)),
                      ])
                        Padding(padding: const EdgeInsets.all(6), child: w),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Subscriptions
// -----------------------------------------------------------------------------

class _SubscriptionsTab extends StatelessWidget {
  const _SubscriptionsTab({required this.auth});
  final FakeAuthState auth;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final subs = TGBillingService.instance.subscriptionsFor(auth);
    if (subs.isEmpty) {
      return Column(
        key: const Key('billing-subscriptions'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('bill_subs_empty'), key: const Key('billing-subs-empty'), style: theme.bodyMedium.override(color: theme.secondaryText)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => context.go('/plans'), child: Text(context.t('dash_nav_plans'))),
        ],
      );
    }
    return Column(
      key: const Key('billing-subscriptions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in subs) Padding(padding: const EdgeInsets.only(bottom: 12), child: _SubCard(sub: s, userId: auth.userId)),
      ],
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({required this.sub, required this.userId});
  final TGSubscription sub;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGBillingService.instance;
    final (statusKey, color) = switch (sub.status) {
      TGSubscriptionStatus.pastDue => ('bill_sub_past_due', TGColors.error),
      TGSubscriptionStatus.cancelled => ('bill_sub_cancelled', theme.secondaryText),
      TGSubscriptionStatus.active when sub.cancelAtPeriodEnd => ('bill_sub_cancel_scheduled', TGColors.slaAmber),
      TGSubscriptionStatus.active => ('bill_sub_active', TGColors.cta),
    };
    final isStore = sub.kind == TGSubscriptionKind.store;
    return DashBox(
      key: Key('billing-sub-${sub.id}'),
      borderColor: sub.isPastDue ? TGColors.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(header: true, child: Text(sub.label, style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
              DashPill(key: Key('billing-sub-status-${sub.id}'), label: context.t(statusKey), color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.t('bill_sub_price', {'price': tgPln(sub.pricePln), 'period': _periodLabel(context, sub.period)}),
            style: theme.bodyMedium.override(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            context.t(
              sub.status == TGSubscriptionStatus.cancelled
                  ? 'bill_sub_ended_on'
                  : sub.cancelAtPeriodEnd
                      ? 'bill_sub_ends_on'
                      : 'bill_sub_renews_on',
              {'d': _dateFmt(context, sub.currentPeriodEnd)},
            ),
            key: Key('billing-sub-dates-${sub.id}'),
            style: theme.bodySmall.override(color: theme.secondaryText),
          ),
          if (sub.nextPlanId != null && sub.nextPlanId != sub.planId)
            Text(
              context.t('bill_sub_next_plan', {'plan': TGBillingService.planLabel(sub.nextPlanId!), 'd': _dateFmt(context, sub.currentPeriodEnd)}),
              key: Key('billing-sub-next-${sub.id}'),
              style: theme.bodySmall.override(color: theme.secondaryText),
            ),
          if (sub.isPastDue) ...[
            const SizedBox(height: 12),
            _DunningTimeline(sub: sub),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (sub.isPastDue)
                FilledButton(
                  key: Key('billing-retry-${sub.id}'),
                  style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
                  onPressed: () {
                    final err = svc.retryNow(sub.id);
                    showTGToast(context, context.t(err ?? 'bill_retry_ok'));
                  },
                  child: Text(context.t('dash_cta_pay')),
                ),
              if (sub.isPastDue)
                OutlinedButton(
                  key: Key('billing-sub-methods-${sub.id}'),
                  onPressed: () => context.go('${BillingPage.routePath}?tab=methods'),
                  child: Text(context.t('bill_update_method')),
                ),
              if (isStore && sub.status == TGSubscriptionStatus.active)
                OutlinedButton(
                  key: Key('billing-change-${sub.id}'),
                  onPressed: () => _showChangePlan(context, sub),
                  child: Text(context.t('bill_change_plan')),
                ),
              if (sub.isLive && !sub.cancelAtPeriodEnd)
                TextButton(
                  key: Key('billing-cancel-${sub.id}'),
                  onPressed: () => showCancelSubscriptionSheet(context, sub, userId: userId),
                  child: Text(context.t('bill_cancel_sub'), style: const TextStyle(color: TGColors.error)),
                ),
              if (isStore && sub.cancelAtPeriodEnd && sub.isLive)
                OutlinedButton(
                  key: Key('billing-resume-${sub.id}'),
                  onPressed: () => svc.resume(sub.id),
                  child: Text(context.t('bill_resume')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DunningTimeline extends StatelessWidget {
  const _DunningTimeline({required this.sub});
  final TGSubscription sub;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final f = sub.failedAt;
    if (f == null) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: context.t('bill_dunning_title'),
      child: Column(
        key: Key('billing-dunning-${sub.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('bill_dunning_title'), style: theme.bodySmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          for (final d in TGBillingService.dunningDays)
            Builder(builder: (context) {
              final a = sub.attempts.where((e) => e.dayOffset == d).firstOrNull;
              final at = DateTime(f.year, f.month, f.day + d, f.hour, f.minute);
              final (icon, color, key) = a == null
                  ? (Icons.schedule, theme.secondaryText, 'bill_dunning_scheduled')
                  : a.ok
                      ? (Icons.check_circle, TGColors.cta, 'bill_dunning_ok')
                      : (Icons.cancel, TGColors.error, 'bill_dunning_failed');
              return Padding(
                key: Key('billing-dunning-$d'),
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${d == 0 ? context.t('bill_dunning_day0') : context.t('bill_dunning_dayn', {'n': '$d'})} · ${_dateFmt(context, at)} · ${context.t(key)}',
                        style: theme.bodySmall,
                      ),
                    ),
                  ],
                ),
              );
            }),
          Text(context.t('bill_dunning_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
        ],
      ),
    );
  }
}

Future<void> _showChangePlan(BuildContext context, TGSubscription sub) {
  return showDashSheet<void>(
    context,
    key: const Key('billing-change-sheet'),
    title: context.t('bill_change_plan'),
    builder: (ctx) => _ChangePlanForm(sub: sub),
  );
}

class _ChangePlanForm extends StatefulWidget {
  const _ChangePlanForm({required this.sub});
  final TGSubscription sub;

  @override
  State<_ChangePlanForm> createState() => _ChangePlanFormState();
}

class _ChangePlanFormState extends State<_ChangePlanForm> {
  late String _plan = widget.sub.nextPlanId ?? widget.sub.planId;
  late TGBillingPeriod _period = widget.sub.period;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('bill_change_note', {'d': _dateFmt(context, widget.sub.currentPeriodEnd)}), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _plan,
          onChanged: (v) => setState(() => _plan = v ?? _plan),
          child: Column(
            children: [
              for (final id in const ['basic', 'pro', 'enterprise'])
                RadioListTile<String>(
                  key: Key('billing-plan-$id'),
                  contentPadding: EdgeInsets.zero,
                  value: id,
                  title: Text(TGBillingService.planLabel(id)),
                  subtitle: Text(tgPln(TGBillingService.storePrice(id, _period))),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final p in TGBillingPeriod.values)
              ChoiceChip(
                key: Key('billing-period-${p.name}'),
                label: Text(_periodLabel(context, p)),
                selected: _period == p,
                onSelected: (_) => setState(() => _period = p),
              ),
          ],
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.t(_error!), style: const TextStyle(color: TGColors.error))),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('billing-change-confirm'),
          style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
          onPressed: () {
            final err = TGBillingService.instance.changePlan(widget.sub.id, planId: _plan, period: _period);
            if (err != null) {
              setState(() => _error = err);
              return;
            }
            showTGToast(context, context.t('bill_change_done'));
            Navigator.of(context).pop();
          },
          child: Text(context.t('bill_change_confirm')),
        ),
      ],
    );
  }
}

/// "Cancel at period end": full-screen on phones, dialog on larger screens.
Future<void> showCancelSubscriptionSheet(BuildContext context, TGSubscription sub, {required String userId}) {
  return showDashSheet<void>(
    context,
    key: const Key('billing-cancel-sheet'),
    title: context.t('bill_cancel_title'),
    builder: (ctx) => _CancelForm(sub: sub, userId: userId),
  );
}

class _CancelForm extends StatefulWidget {
  const _CancelForm({required this.sub, required this.userId});
  final TGSubscription sub;
  final String userId;

  @override
  State<_CancelForm> createState() => _CancelFormState();
}

class _CancelFormState extends State<_CancelForm> {
  String? _reason;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t('bill_cancel_body', {'title': widget.sub.label, 'd': _dateFmt(context, widget.sub.currentPeriodEnd)}),
          key: const Key('billing-cancel-body'),
          style: theme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Text(context.t('bill_cancel_reason'), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
        RadioGroup<String>(
          groupValue: _reason,
          onChanged: (v) => setState(() => _reason = v),
          child: Column(
            children: [
              for (final r in const ['price', 'not_needed', 'results', 'other'])
                RadioListTile<String>(
                  key: Key('billing-cancel-reason-$r'),
                  contentPadding: EdgeInsets.zero,
                  value: r,
                  title: Text(context.t('bill_cancel_r_$r')),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('billing-cancel-confirm'),
          style: FilledButton.styleFrom(backgroundColor: TGColors.error, foregroundColor: Colors.white),
          onPressed: () {
            TGBillingService.instance.cancelAtPeriodEnd(widget.sub.id, userId: widget.userId, reason: _reason);
            showTGToast(context, context.t('bill_cancel_done', {'d': _dateFmt(context, widget.sub.currentPeriodEnd)}));
            Navigator.of(context).pop();
          },
          child: Text(context.t('bill_cancel_confirm')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('billing-cancel-keep'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.t('bill_cancel_keep')),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Payment methods
// -----------------------------------------------------------------------------

class _MethodsTab extends StatelessWidget {
  const _MethodsTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGBillingService.instance;
    final methods = svc.methodsFor(userId);
    final now = TGClock.now();
    return Column(
      key: const Key('billing-methods'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('bill_methods_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 12),
        if (methods.isEmpty)
          Text(context.t('bill_methods_empty'), key: const Key('billing-methods-empty'), style: theme.bodyMedium.override(color: theme.secondaryText)),
        for (final m in methods)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DashBox(
              key: Key('billing-method-${m.id}'),
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ExcludeSemantics(child: Icon(Icons.credit_card, color: theme.secondaryText)),
                  Text(m.label, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                  Text(context.t('bill_method_exp', {'d': m.expiry}), style: theme.bodySmall.override(color: theme.secondaryText)),
                  if (m.isDefault) DashPill(label: context.t('bill_method_default'), color: TGColors.cta),
                  if (m.isExpired(now)) DashPill(key: Key('billing-method-expired-${m.id}'), label: context.t('bill_method_expired'), color: TGColors.error),
                  if (!m.isDefault)
                    TextButton(
                      key: Key('billing-method-default-${m.id}'),
                      onPressed: () => svc.setDefaultMethod(userId, m.id),
                      child: Text(context.t('bill_method_make_default')),
                    ),
                  TextButton(
                    key: Key('billing-method-remove-${m.id}'),
                    onPressed: () => svc.removeMethod(userId, m.id),
                    child: Text(context.t('ui_remove'), style: const TextStyle(color: TGColors.error)),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('billing-method-add'),
            onPressed: () => showDashSheet<void>(context, key: const Key('billing-card-sheet'), title: context.t('bill_method_add'), builder: (_) => _AddCardForm(userId: userId)),
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.t('bill_method_add')),
          ),
        ),
      ],
    );
  }
}

class _AddCardForm extends StatefulWidget {
  const _AddCardForm({required this.userId});
  final String userId;

  @override
  State<_AddCardForm> createState() => _AddCardFormState();
}

class _AddCardFormState extends State<_AddCardForm> {
  final _number = TextEditingController();
  final _exp = TextEditingController();
  final _holder = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    _exp.dispose();
    _holder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('billing-card-number'),
          controller: _number,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: context.t('bill_card_number'), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('billing-card-exp'),
          controller: _exp,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(labelText: context.t('bill_card_exp'), hintText: 'MM/YY', border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('billing-card-holder'),
          controller: _holder,
          decoration: InputDecoration(labelText: context.t('bill_card_holder'), border: const OutlineInputBorder()),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(liveRegion: true, child: Text(context.t(_error!), key: const Key('billing-card-error'), style: const TextStyle(color: TGColors.error))),
          ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('billing-card-save'),
          style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
          onPressed: () {
            final m = RegExp(r'^(\d{2})\s*/\s*(\d{2})$').firstMatch(_exp.text.trim());
            final mm = m == null ? 0 : int.parse(m.group(1)!);
            if (!luhnValid(_number.text)) return setState(() => _error = 'bill_err_card_number');
            if (m == null || mm < 1 || mm > 12) return setState(() => _error = 'bill_err_card_exp');
            final yy = 2000 + int.parse(m.group(2)!);
            if (!DateTime(yy, mm + 1).isAfter(TGClock.now())) return setState(() => _error = 'bill_method_expired');
            TGBillingService.instance.saveCard(userId: widget.userId, number: _number.text, expMonth: mm, expYear: yy, holder: _holder.text.trim());
            TGAnalytics.track('billing_method_add', {'type': 'card'});
            Navigator.of(context).pop();
          },
          child: Text(context.t('ui_save')),
        ),
      ],
    );
  }
}
