import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';
import 'package:twoja_gastromania/tg_models/tg_invoice.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/pricing_config_service.dart';
import 'package:twoja_gastromania/tg_services/priority_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';

/// DASH-3 billing ledger: every successful service-fee payment, invoices,
/// subscriptions with `past_due` dunning, saved cards and account credits.
class TGBillingService extends ChangeNotifier {
  TGBillingService._();
  static final TGBillingService instance = TGBillingService._();

  /// Automatic retries after a failed renewal: day 0, +3, +7.
  static const List<int> dunningDays = [0, 3, 7];

  /// An invoice for a receipt can be requested until the end of the third
  /// month after the payment month.
  static const int invoiceRequestMonths = 3;

  final List<TGPayment> _payments = [];
  final List<TGInvoice> _invoices = [];
  final Map<String, TGInvoiceProfile> _profiles = {};
  final List<TGSubscription> _subs = [];
  final List<TGPaymentMethod> _methods = [];
  final List<TGCredit> _credits = [];
  final Map<String, int> _invoiceSeq = {};
  int _seq = 1;

  /// Set by [PaymentForm] right before `onPaid`, read by [recordPayment].
  TGPayMethod? lastMethod;
  String? lastMethodLabel;

  bool get _hideMock => TGRevenueConfigService.instance.productionMode;

  void reset() {
    _payments.clear();
    _refundedGr.clear();
    _invoices.clear();
    _profiles.clear();
    _subs.clear();
    _methods.clear();
    _credits.clear();
    _invoiceSeq.clear();
    _seq = 1;
    lastMethod = null;
    lastMethodLabel = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Payments
  // ---------------------------------------------------------------------------

  List<TGPayment> paymentsFor(String userId) {
    final out = [
      for (final p in _payments)
        if (p.userId == userId && !(_hideMock && p.isMock)) p,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  TGPayment? paymentById(String id) => _payments.where((p) => p.id == id).firstOrNull;

  /// Admin ledger view across all users (newest first).
  List<TGPayment> allPayments() => [
        for (final p in _payments)
          if (!(_hideMock && p.isMock)) p,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final Map<String, int> _refundedGr = {};

  /// Total refunded on [paymentId] so far.
  double refundedPln(String paymentId) => (_refundedGr[paymentId] ?? 0) / 100;

  /// Records a (partial) refund of our own service fee. The payment flips to
  /// `refunded` once the full gross amount has been returned.
  void markRefunded(String paymentId, num amountPln, {bool notify = true}) {
    final i = _payments.indexWhere((p) => p.id == paymentId);
    if (i < 0) return;
    final p = _payments[i];
    final total = (_refundedGr[paymentId] ?? 0) + (amountPln * 100).round();
    _refundedGr[paymentId] = total;
    if (total >= p.amount.grossGr) _payments[i] = p.copyWith(status: TGPaymentStatus.refunded);
    if (notify) notifyListeners();
  }

  /// Writes the ledger row for a successful charge. When [buyer] is a
  /// complete B2B snapshot an invoice is issued straight away.
  TGPayment recordPayment({
    required String userId,
    required TGPaymentKind kind,
    required String description,
    required num grossPln,
    TGPayMethod? method,
    String? methodLabel,
    TGPaymentStatus status = TGPaymentStatus.succeeded,
    DateTime? at,
    String? listingId,
    String? listingNo,
    String? subscriptionId,
    TGInvoiceBuyer? buyer,
    bool isMock = false,
    bool notify = true,
  }) {
    final m = method ?? lastMethod;
    final payment = TGPayment(
      id: 'PAY-${(at ?? TGClock.now()).millisecondsSinceEpoch}-${_seq++}',
      userId: userId,
      kind: kind,
      description: description,
      amount: TGVatSplit.fromGross(grossPln),
      createdAt: at ?? TGClock.now(),
      method: m,
      methodLabel: methodLabel ?? lastMethodLabel ?? _methodName(m),
      status: status,
      listingId: listingId,
      listingNo: listingNo,
      subscriptionId: subscriptionId,
      isMock: isMock,
    );
    _payments.add(payment);
    lastMethod = null;
    lastMethodLabel = null;
    if (!isMock) {
      TGAnalytics.track('payment_recorded', {
        'paymentId': payment.id,
        'kind': kind.name,
        'grossPln': payment.grossPln,
        'netPln': payment.netPln,
        'vatPln': payment.vatPln,
      });
    }
    if (buyer != null && buyer.isComplete && status == TGPaymentStatus.succeeded) {
      _issue(userId, [payment], _profileFromBuyer(userId, buyer), isMock: isMock);
    }
    if (notify) notifyListeners();
    return payment;
  }

  static String? _methodName(TGPayMethod? m) => switch (m) {
        TGPayMethod.blik => 'BLIK',
        TGPayMethod.przelewy24 => 'Przelewy24',
        TGPayMethod.card => 'Card',
        null => null,
      };

  TGInvoiceProfile _profileFromBuyer(String userId, TGInvoiceBuyer b) => TGInvoiceProfile(
        userId: userId,
        companyName: b.companyName,
        nip: b.nip,
        street: b.address,
        postalCode: '',
        city: '',
      );

  // ---------------------------------------------------------------------------
  // Invoices
  // ---------------------------------------------------------------------------

  List<TGInvoice> invoicesFor(String userId) => [
        for (final i in _invoices)
          if (i.userId == userId && !(_hideMock && i.isMock)) i,
      ]..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

  TGInvoice? invoiceById(String id) => _invoices.where((i) => i.id == id).firstOrNull;

  TGInvoiceProfile? profileFor(String userId) => _profiles[userId];

  /// Returns field → error key; empty map when saved.
  Map<String, String> saveProfile(TGInvoiceProfile profile) {
    final errors = profile.validate();
    if (errors.isNotEmpty) return errors;
    _profiles[profile.userId] = TGInvoiceProfile(
      userId: profile.userId,
      companyName: profile.companyName.trim(),
      nip: profile.nipDigits,
      street: profile.street.trim(),
      postalCode: profile.postalCode.trim(),
      city: profile.city.trim(),
      email: profile.email.trim(),
      updatedAt: TGClock.now(),
    );
    TGAnalytics.track('billing_profile_save', {'userId': profile.userId});
    notifyListeners();
    return const {};
  }

  DateTime invoiceDeadline(TGPayment p) => DateTime(p.createdAt.year, p.createdAt.month + invoiceRequestMonths + 1, 1);

  bool canRequestInvoice(TGPayment p, {DateTime? now}) =>
      p.status == TGPaymentStatus.succeeded && p.invoiceId == null && (now ?? TGClock.now()).isBefore(invoiceDeadline(p));

  /// "Request invoice": one invoice for the picked receipts. Returns the
  /// invoice or an i18n error key.
  ({TGInvoice? invoice, String? error}) requestInvoice(String userId, List<String> paymentIds, {DateTime? now}) {
    if (paymentIds.isEmpty) return (invoice: null, error: 'bill_err_pick_payment');
    final profile = _profiles[userId];
    if (profile == null || !profile.isValid) return (invoice: null, error: 'bill_err_profile');
    final picked = <TGPayment>[];
    for (final id in paymentIds) {
      final p = paymentById(id);
      if (p == null || p.userId != userId) return (invoice: null, error: 'bill_err_pick_payment');
      if (p.invoiceId != null) return (invoice: null, error: 'bill_err_already');
      if (!canRequestInvoice(p, now: now)) return (invoice: null, error: 'bill_err_deadline');
      picked.add(p);
    }
    final inv = _issue(userId, picked, profile, isMock: picked.every((p) => p.isMock));
    TGAnalytics.track('billing_invoice_request', {'invoiceId': inv.id, 'payments': picked.length});
    notifyListeners();
    return (invoice: inv, error: null);
  }

  TGInvoice _issue(String userId, List<TGPayment> payments, TGInvoiceProfile buyer, {bool isMock = false, DateTime? at}) {
    final issued = at ?? TGClock.now();
    final month = '${issued.year}/${issued.month.toString().padLeft(2, '0')}';
    final n = (_invoiceSeq[month] ?? 0) + 1;
    _invoiceSeq[month] = n;
    final inv = TGInvoice(
      id: 'INV-${issued.millisecondsSinceEpoch}-$n',
      number: 'FV/$month/${n.toString().padLeft(4, '0')}',
      userId: userId,
      paymentIds: [for (final p in payments) p.id],
      issuedAt: issued,
      amount: payments.fold(TGVatSplit.zero, (a, p) => a + p.amount),
      buyer: buyer,
      isMock: isMock,
    );
    _invoices.add(inv);
    for (final p in payments) {
      final i = _payments.indexWhere((e) => e.id == p.id);
      if (i >= 0) _payments[i] = _payments[i].copyWith(invoiceId: inv.id);
    }
    return inv;
  }

  /// Plain-text invoice document (the mock provider's PDF body).
  String invoiceDocument(TGInvoice inv) {
    String pln(int gr) => (gr / 100).toStringAsFixed(2);
    final lines = [
      'Faktura VAT ${inv.number}',
      'Data wystawienia: ${_date(inv.issuedAt)}',
      'Sprzedawca: Twoja Gastromania sp. z o.o.',
      'Nabywca: ${inv.buyer.companyName}, NIP ${inv.buyer.nipDigits}',
      'Adres: ${inv.buyer.address}',
      '',
      'Pozycja;Netto PLN;VAT 23% PLN;Brutto PLN',
      for (final id in inv.paymentIds)
        if (paymentById(id) case final p?) '${p.description};${pln(p.amount.netGr)};${pln(p.amount.vatGr)};${pln(p.amount.grossGr)}',
      'Razem;${pln(inv.amount.netGr)};${pln(inv.amount.vatGr)};${pln(inv.amount.grossGr)}',
    ];
    return lines.join('\n');
  }

  void trackInvoiceDownload(TGInvoice inv) {
    TGAnalytics.track('billing_invoice_download', {'invoiceId': inv.id, 'number': inv.number});
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _csvCell(String v) => v.contains(RegExp(r'[;"\n]')) ? '"${v.replaceAll('"', '""')}"' : v;

  /// `;`-separated (Polish Excel default), amounts with 2 decimals.
  String paymentsCsv(List<TGPayment> rows) {
    final out = StringBuffer('Date;Payment ID;Description;Kind;Net PLN;VAT PLN;Gross PLN;Method;Status;Invoice\n');
    for (final p in rows) {
      final inv = p.invoiceId == null ? '' : (invoiceById(p.invoiceId!)?.number ?? '');
      out.writeln([
        _date(p.createdAt),
        p.id,
        _csvCell(p.description),
        p.kind.name,
        p.netPln.toStringAsFixed(2),
        p.vatPln.toStringAsFixed(2),
        p.grossPln.toStringAsFixed(2),
        _csvCell(p.methodLabel ?? ''),
        p.status.name,
        inv,
      ].join(';'));
    }
    return out.toString();
  }

  String invoicesCsv(List<TGInvoice> rows) {
    final out = StringBuffer('Number;Issued;Buyer;NIP;Net PLN;VAT PLN;Gross PLN\n');
    for (final i in rows) {
      out.writeln([
        i.number,
        _date(i.issuedAt),
        _csvCell(i.buyer.companyName),
        i.buyer.nipDigits,
        i.amount.netPln.toStringAsFixed(2),
        i.amount.vatPln.toStringAsFixed(2),
        i.amount.grossPln.toStringAsFixed(2),
      ].join(';'));
    }
    return out.toString();
  }

  // ---------------------------------------------------------------------------
  // Subscriptions
  // ---------------------------------------------------------------------------

  static String planLabel(String planId) => switch (planId) {
        'pro' => 'Pro Store',
        'enterprise' => 'Enterprise Store',
        'priority' => 'Priority Manufacturer',
        _ => 'Basic Store',
      };

  static int storePrice(String planId, TGBillingPeriod period) {
    final cfg = PricingConfigService.instance.config;
    final monthly = cfg.storeMonthlyPln(planId) ?? cfg.basicStoreMonthlyPln;
    return TGPricing.storePrice(monthly, period).round();
  }

  static DateTime addPeriod(DateTime from, TGBillingPeriod period) => switch (period) {
        TGBillingPeriod.monthly => DateTime(from.year, from.month + 1, from.day, from.hour, from.minute),
        TGBillingPeriod.sixMonths => DateTime(from.year, from.month + 6, from.day, from.hour, from.minute),
        TGBillingPeriod.yearly => DateTime(from.year + 1, from.month, from.day, from.hour, from.minute),
      };

  static String _planIdOf(TGStorePlanKind k) => switch (k) {
        TGStorePlanKind.basic => 'basic',
        TGStorePlanKind.pro => 'pro',
        TGStorePlanKind.enterprise => 'enterprise',
      };

  /// Store subscription (from the account) plus the Priority add-on.
  List<TGSubscription> subscriptionsFor(FakeAuthState auth) {
    final id = auth.userId;
    final plan = auth.storePlan;
    if (plan != null && !_subs.any((s) => s.userId == id && s.kind == TGSubscriptionKind.store)) {
      final end = auth.storeRenewsOn;
      _subs.add(TGSubscription(
        id: 'SUB-store-$id',
        userId: id,
        kind: TGSubscriptionKind.store,
        planId: _planIdOf(plan),
        label: auth.storePlanLabel,
        period: TGBillingPeriod.monthly,
        pricePln: storePrice(_planIdOf(plan), TGBillingPeriod.monthly),
        startedAt: DateTime(end.year, end.month - 1, end.day),
        currentPeriodStart: DateTime(end.year, end.month - 1, end.day),
        currentPeriodEnd: end,
      ));
    }
    final out = [
      for (final s in _subs)
        if (s.userId == id && !(_hideMock && s.isMock)) s,
    ];
    final pr = TGPriorityService.instance.priorityFor(id);
    if (pr.isActive && pr.source == TGPrioritySource.addon && pr.nextBillingAt != null) {
      out.add(TGSubscription(
        id: 'SUB-priority-$id',
        userId: id,
        kind: TGSubscriptionKind.priority,
        planId: 'priority',
        label: planLabel('priority'),
        period: TGBillingPeriod.monthly,
        pricePln: TGRevenueConfigService.instance.config.priority.priceMonthly,
        startedAt: pr.activeSince ?? TGClock.now(),
        currentPeriodStart: pr.activeSince ?? TGClock.now(),
        currentPeriodEnd: pr.nextBillingAt!,
        cancelAtPeriodEnd: pr.cancelAtPeriodEnd,
      ));
    }
    return out;
  }

  TGSubscription? _sub(String id) => _subs.where((s) => s.id == id).firstOrNull;

  /// Called after a paid store checkout.
  TGSubscription startStoreSubscription({
    required String userId,
    required String planId,
    required TGBillingPeriod period,
    required int pricePln,
    DateTime? at,
  }) {
    final now = at ?? TGClock.now();
    _subs.removeWhere((s) => s.userId == userId && s.kind == TGSubscriptionKind.store);
    final sub = TGSubscription(
      id: 'SUB-store-$userId',
      userId: userId,
      kind: TGSubscriptionKind.store,
      planId: planId,
      label: planLabel(planId),
      period: period,
      pricePln: pricePln,
      startedAt: now,
      currentPeriodStart: now,
      currentPeriodEnd: addPeriod(now, period),
    );
    _subs.add(sub);
    notifyListeners();
    return sub;
  }

  /// Cancels at period end: the plan stays usable until [TGSubscription.currentPeriodEnd].
  void cancelAtPeriodEnd(String subscriptionId, {required String userId, String? reason}) {
    if (subscriptionId == 'SUB-priority-$userId') {
      TGPriorityService.instance.cancelAtPeriodEnd(userId);
    } else {
      final s = _sub(subscriptionId);
      if (s == null || !s.isLive) return;
      s.cancelAtPeriodEnd = true;
      s.cancelReason = reason;
    }
    TGAnalytics.track('subscription_cancel', {'subscriptionId': subscriptionId, 'atPeriodEnd': true, 'reason': reason ?? ''});
    notifyListeners();
  }

  void resume(String subscriptionId) {
    final s = _sub(subscriptionId);
    if (s == null || !s.cancelAtPeriodEnd) return;
    s.cancelAtPeriodEnd = false;
    s.cancelReason = null;
    TGAnalytics.track('subscription_change', {'subscriptionId': subscriptionId, 'action': 'resume'});
    notifyListeners();
  }

  /// Plan / period change applies from the next period; nothing is prorated.
  String? changePlan(String subscriptionId, {String? planId, TGBillingPeriod? period}) {
    final s = _sub(subscriptionId);
    if (s == null || s.kind != TGSubscriptionKind.store) return 'bill_err_sub_missing';
    if (s.isPastDue) return 'bill_err_sub_past_due';
    final from = '${s.nextPlanId ?? s.planId}/${s.period.name}';
    if (planId != null && planId != s.planId) {
      s.nextPlanId = planId;
    } else if (planId == s.planId) {
      s.nextPlanId = null;
    }
    if (period != null) s.period = period;
    s.pricePln = storePrice(s.nextPlanId ?? s.planId, s.period);
    s.cancelAtPeriodEnd = false;
    TGAnalytics.track('subscription_change', {
      'subscriptionId': subscriptionId,
      'action': 'change_plan',
      'from': from,
      'to': '${s.nextPlanId ?? s.planId}/${s.period.name}',
    });
    notifyListeners();
    return null;
  }

  /// A renewal charge failed: enters `past_due` and schedules retries.
  void markPastDue(String subscriptionId, {DateTime? at, String? methodLabel}) {
    final s = _sub(subscriptionId);
    if (s == null) return;
    final t = at ?? TGClock.now();
    s.status = TGSubscriptionStatus.pastDue;
    s.failedAt = t;
    s.attempts
      ..clear()
      ..add(TGDunningAttempt(dayOffset: 0, at: t, ok: false, methodLabel: methodLabel));
    _payments.add(TGPayment(
      id: 'PAY-${t.millisecondsSinceEpoch}-${_seq++}',
      userId: s.userId,
      kind: s.kind == TGSubscriptionKind.store ? TGPaymentKind.store : TGPaymentKind.priority,
      description: '${s.label} · renewal',
      amount: TGVatSplit.fromGross(s.pricePln),
      createdAt: t,
      method: TGPayMethod.card,
      methodLabel: methodLabel,
      status: TGPaymentStatus.failed,
      subscriptionId: s.id,
      isMock: s.isMock,
    ));
    NotificationService.instance.add(
      userId: s.userId,
      type: 'billing_payment_failed',
      dealId: s.id,
      title: 'Payment failed',
      body: s.label,
      deepLink: '/dashboard/billing?tab=subscriptions',
      params: {'title': s.label},
    );
    notifyListeners();
  }

  /// Next automatic retry, or null when the schedule is used up.
  DateTime? nextRetryAt(TGSubscription s) {
    final f = s.failedAt;
    if (!s.isPastDue || f == null) return null;
    for (final d in dunningDays) {
      if (!s.attempts.any((a) => a.dayOffset == d)) return DateTime(f.year, f.month, f.day + d, f.hour, f.minute);
    }
    return null;
  }

  TGPaymentMethod? defaultMethod(String userId) =>
      methodsFor(userId).where((m) => m.isDefault).firstOrNull ?? methodsFor(userId).firstOrNull;

  /// Runs due automatic retries (day 0 / +3 / +7). A retry succeeds only with
  /// a non-expired default card; after the last failure the plan ends.
  void processDunning({DateTime? now}) {
    final t = now ?? TGClock.now();
    var changed = false;
    for (final s in _subs.where((s) => s.isPastDue).toList()) {
      final f = s.failedAt!;
      for (final d in dunningDays) {
        if (s.attempts.any((a) => a.dayOffset == d)) continue;
        final due = DateTime(f.year, f.month, f.day + d, f.hour, f.minute);
        if (due.isAfter(t)) break;
        final m = defaultMethod(s.userId);
        final ok = m != null && !m.isExpired(due);
        s.attempts.add(TGDunningAttempt(dayOffset: d, at: due, ok: ok, methodLabel: m?.label));
        changed = true;
        if (ok) {
          _recover(s, m, at: due);
          break;
        }
      }
      if (s.isPastDue && nextRetryAt(s) == null) {
        s.status = TGSubscriptionStatus.cancelled;
        s.cancelReason = 'dunning_exhausted';
        NotificationService.instance.add(
          userId: s.userId,
          type: 'billing_subscription_ended',
          dealId: s.id,
          title: 'Subscription ended',
          body: s.label,
          deepLink: '/dashboard/billing?tab=subscriptions',
          params: {'title': s.label},
        );
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Manual "Pay now" during `past_due`.
  String? retryNow(String subscriptionId, {String? methodId}) {
    final s = _sub(subscriptionId);
    if (s == null || !s.isPastDue) return 'bill_err_sub_missing';
    final m = methodId == null ? defaultMethod(s.userId) : _methods.where((e) => e.id == methodId).firstOrNull;
    final now = TGClock.now();
    if (m == null) return 'bill_err_no_method';
    if (m.isExpired(now)) return 'bill_err_method_expired';
    _recover(s, m, at: now);
    TGAnalytics.track('billing_retry', {'subscriptionId': s.id, 'ok': true});
    notifyListeners();
    return null;
  }

  void _recover(TGSubscription s, TGPaymentMethod m, {required DateTime at}) {
    recordPayment(
      userId: s.userId,
      kind: s.kind == TGSubscriptionKind.store ? TGPaymentKind.store : TGPaymentKind.priority,
      description: '${s.label} · renewal',
      grossPln: s.pricePln,
      method: m.type,
      methodLabel: m.label,
      at: at,
      subscriptionId: s.id,
      isMock: s.isMock,
    );
    s.status = TGSubscriptionStatus.active;
    s.failedAt = null;
    s.attempts.clear();
    s.currentPeriodStart = at;
    s.currentPeriodEnd = addPeriod(at, s.period);
    NotificationService.instance.add(
      userId: s.userId,
      type: 'billing_payment_recovered',
      dealId: s.id,
      title: 'Payment received',
      body: s.label,
      deepLink: '/dashboard/billing?tab=subscriptions',
      params: {'title': s.label},
    );
  }

  List<TGSubscription> pastDueFor(String userId) => [
        for (final s in _subs)
          if (s.userId == userId && s.isPastDue && !(_hideMock && s.isMock)) s,
      ];

  // ---------------------------------------------------------------------------
  // Payment methods
  // ---------------------------------------------------------------------------

  List<TGPaymentMethod> methodsFor(String userId) => [
        for (final m in _methods)
          if (m.userId == userId && !(_hideMock && m.isMock)) m,
      ];

  /// Saved from the card form ("Save card"). Only brand, last 4 and expiry are kept.
  TGPaymentMethod saveCard({
    required String userId,
    required String number,
    required int expMonth,
    required int expYear,
    String holder = '',
    bool isMock = false,
  }) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final first = !methodsFor(userId).any((m) => m.isDefault);
    final m = TGPaymentMethod(
      id: 'PM-${_seq++}',
      userId: userId,
      type: TGPayMethod.card,
      createdAt: TGClock.now(),
      brand: cardBrand(digits),
      last4: digits.length >= 4 ? digits.substring(digits.length - 4) : digits,
      expMonth: expMonth,
      expYear: expYear < 100 ? 2000 + expYear : expYear,
      holder: holder,
      isDefault: first,
      isMock: isMock,
    );
    _methods.removeWhere((e) => e.userId == userId && e.last4 == m.last4 && e.brand == m.brand && e.expiry == m.expiry);
    _methods.add(m);
    notifyListeners();
    return m;
  }

  void setDefaultMethod(String userId, String methodId) {
    for (var i = 0; i < _methods.length; i++) {
      if (_methods[i].userId == userId) _methods[i] = _methods[i].copyWith(isDefault: _methods[i].id == methodId);
    }
    TGAnalytics.track('billing_method_default', {'methodId': methodId});
    notifyListeners();
  }

  void removeMethod(String userId, String methodId) {
    final wasDefault = _methods.any((m) => m.id == methodId && m.isDefault);
    _methods.removeWhere((m) => m.id == methodId && m.userId == userId);
    if (wasDefault) {
      final next = _methods.indexWhere((m) => m.userId == userId);
      if (next >= 0) _methods[next] = _methods[next].copyWith(isDefault: true);
    }
    TGAnalytics.track('billing_method_remove', {'methodId': methodId});
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Credits
  // ---------------------------------------------------------------------------

  List<TGCredit> creditsFor(String userId) => [
        for (final c in _credits)
          if (c.userId == userId && !(_hideMock && c.isMock)) c,
      ];

  void addCredit(TGCredit c) {
    _credits.add(c);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Mock data (Dev Switcher "Billing · past_due"). Off in Production Mode.
  // ---------------------------------------------------------------------------

  /// 12 payments (11 paid + the failed renewal), 3 invoices, 1 `past_due`
  /// store subscription and 2 saved cards (the default one expired).
  void seedMocks(FakeAuthState auth) {
    if (_hideMock) return;
    final id = auth.userId;
    if (_payments.any((p) => p.userId == id && p.isMock)) return;
    final now = TGClock.now();
    final cfg = PricingConfigService.instance.config;
    final planId = _planIdOf(auth.storePlan ?? TGStorePlanKind.pro);
    final storeFee = storePrice(planId, TGBillingPeriod.monthly);
    final label = planLabel(planId);

    _methods.removeWhere((m) => m.userId == id && m.isMock);
    final expired = DateTime(now.year, now.month - 1);
    _methods.addAll([
      TGPaymentMethod(
        id: 'PM-mock-visa-$id',
        userId: id,
        type: TGPayMethod.card,
        createdAt: now.subtract(const Duration(days: 400)),
        brand: TGCardBrand.visa,
        last4: '4242',
        expMonth: expired.month,
        expYear: expired.year,
        holder: auth.displayName,
        isDefault: true,
        isMock: true,
      ),
      TGPaymentMethod(
        id: 'PM-mock-mc-$id',
        userId: id,
        type: TGPayMethod.card,
        createdAt: now.subtract(const Duration(days: 60)),
        brand: TGCardBrand.mastercard,
        last4: '5454',
        expMonth: 8,
        expYear: now.year + 2,
        holder: auth.displayName,
        isMock: true,
      ),
    ]);

    final short = cfg.promotions.durations.first;
    final long = cfg.promotions.durations.last;
    final listDays = cfg.defaultListingDays;
    final restoDays = cfg.defaultRestaurantDays;
    final bannerDays = cfg.banner.durations.first;
    final rows = <(int, TGPaymentKind, String, num, String)>[
      (5, TGPaymentKind.promotion, tgPromoBillingLabel(PromotionTier.glow, short), cfg.promoFeePln(PromotionTier.glow, short), 'BLIK'),
      (12, TGPaymentKind.listing, 'Listing fee · $listDays days', cfg.listingFeePln(listDays), 'BLIK'),
      (33, TGPaymentKind.store, '$label · monthly', storeFee, 'Visa •••• 4242'),
      (40, TGPaymentKind.promotion, tgPromoBillingLabel(PromotionTier.bold, long), cfg.promoFeePln(PromotionTier.bold, long), 'Przelewy24'),
      (51, TGPaymentKind.renew, 'Renew · $listDays days', cfg.listingFeePln(listDays), 'BLIK'),
      (63, TGPaymentKind.store, '$label · monthly', storeFee, 'Visa •••• 4242'),
      (75, TGPaymentKind.banner, 'Hero banner · $bannerDays days', cfg.banner.pricePln(bannerDays), 'Visa •••• 4242'),
      (93, TGPaymentKind.store, '$label · monthly', storeFee, 'Visa •••• 4242'),
      (110, TGPaymentKind.restaurant, 'Restaurant listing · $restoDays days', cfg.restaurantFeePln(restoDays), 'Przelewy24'),
      (124, TGPaymentKind.store, '$label · monthly', storeFee, 'Visa •••• 4242'),
      (140, TGPaymentKind.promotion, tgPromoBillingLabel(PromotionTier.spotlight, short), cfg.promoFeePln(PromotionTier.spotlight, short), 'BLIK'),
    ];
    final created = <TGPayment>[];
    for (final r in rows) {
      final p = TGPayment(
        id: 'PAY-mock-${r.$1}-$id',
        userId: id,
        kind: r.$2,
        description: r.$3,
        amount: TGVatSplit.fromGross(r.$4),
        createdAt: now.subtract(Duration(days: r.$1)),
        method: r.$5 == 'BLIK' ? TGPayMethod.blik : (r.$5 == 'Przelewy24' ? TGPayMethod.przelewy24 : TGPayMethod.card),
        methodLabel: r.$5,
        isMock: true,
      );
      _payments.add(p);
      created.add(p);
    }

    final profile = TGInvoiceProfile(
      userId: id,
      companyName: '${auth.displayName} sp. z o.o.',
      nip: '5260250274',
      street: 'ul. Mariacka 12',
      postalCode: '40-014',
      city: 'Katowice',
      email: 'faktury@example.pl',
      updatedAt: now.subtract(const Duration(days: 160)),
    );
    _profiles.putIfAbsent(id, () => profile);
    for (final i in [2, 5, 7]) {
      _issue(id, [created[i]], profile, isMock: true, at: created[i].createdAt);
    }

    _subs.removeWhere((s) => s.userId == id && s.kind == TGSubscriptionKind.store);
    final periodEnd = DateTime(now.year, now.month, now.day - 3, 9);
    final sub = TGSubscription(
      id: 'SUB-store-$id',
      userId: id,
      kind: TGSubscriptionKind.store,
      planId: planId,
      label: label,
      period: TGBillingPeriod.monthly,
      pricePln: storeFee,
      startedAt: now.subtract(const Duration(days: 160)),
      currentPeriodStart: DateTime(periodEnd.year, periodEnd.month - 1, periodEnd.day, 9),
      currentPeriodEnd: periodEnd,
      isMock: true,
    );
    _subs.add(sub);
    markPastDue(sub.id, at: periodEnd, methodLabel: 'Visa •••• 4242');
    sub.attempts.add(TGDunningAttempt(dayOffset: 3, at: periodEnd.add(const Duration(days: 3)), ok: false, methodLabel: 'Visa •••• 4242'));
    notifyListeners();
  }
}
