import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/flutter_flow/tg_l10n.dart';
import 'package:twoja_gastromania/tg_core/duration_service.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_special_consent.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

/// Bump whenever any key in [TGSpecialConsentService.textKeys] changes wording.
const kSoConsentTextVersion = 'so-consent-1.2';

/// Sends one proof message; returns null on success or an error code.
abstract class TGConsentTransport {
  String? send(TGConsentChannel channel, String to, String subject, String body);
}

/// Mock gateway: recipients in [unreachable] always fail.
class TGMockConsentTransport implements TGConsentTransport {
  TGMockConsentTransport({Set<String>? unreachable}) : unreachable = unreachable ?? {};

  final Set<String> unreachable;
  final List<({TGConsentChannel channel, String to, String subject, String body})> sent = [];

  @override
  String? send(TGConsentChannel channel, String to, String subject, String body) {
    if (to.trim().isEmpty) return 'no_recipient';
    if (unreachable.contains(to)) return channel == TGConsentChannel.sms ? 'sms_gateway_unreachable' : 'smtp_rejected';
    sent.add((channel: channel, to: to, subject: subject, body: body));
    return null;
  }
}

class TGSpecialConsentService extends ChangeNotifier {
  TGSpecialConsentService._();
  static final TGSpecialConsentService instance = TGSpecialConsentService._();

  static const maxAttempts = 3;
  static const siteUrl = 'https://twojagastromania.pl';

  /// Keys whose text forms the legally accepted consent, in display order.
  static const textKeys = [
    'so_consent_title',
    'so_consent_intro',
    'so_consent_a',
    'so_consent_b',
    'so_consent_c',
    'so_consent_d',
    'so_consent_warning_title',
    'so_consent_warning_body',
    'so_consent_checkbox',
  ];

  TGConsentTransport transport = TGMockConsentTransport();
  final List<TGSpecialRequestConsent> consents = [];
  final List<TGConsentDelivery> deliveries = [];
  int _seq = 1;

  void reset() {
    consents.clear();
    deliveries.clear();
    transport = TGMockConsentTransport();
    _seq = 1;
    notifyListeners();
  }

  // ---- text ----

  /// Language code the consent text exists in; falls back to English.
  static String resolveLocale(String locale) {
    final code = locale.split(RegExp('[_-]')).first.toLowerCase();
    return kUiTranslations['so_consent_title']!.containsKey(code) ? code : 'en';
  }

  static String _t(String locale, String key, [Map<String, String>? params]) =>
      FFLocalizations(Locale(resolveLocale(locale))).getText(key, params);

  static String line(String locale, String key) => _t(locale, key);

  /// Full consent text exactly as shown on the confirm page.
  static String consentText(String locale) {
    final l = resolveLocale(locale);
    return [
      _t(l, 'so_consent_title'),
      _t(l, 'so_consent_intro'),
      _t(l, 'so_consent_a'),
      _t(l, 'so_consent_b'),
      _t(l, 'so_consent_c'),
      _t(l, 'so_consent_d'),
      '${_t(l, 'so_consent_warning_title')}\n${_t(l, 'so_consent_warning_body')}',
      '[x] ${_t(l, 'so_consent_checkbox')}',
    ].join('\n\n');
  }

  static String hashOf(String text) => sha256.convert(utf8.encode(text)).toString();

  static String consentPath(String requestNo) => '/account/requests/$requestNo/consent';

  static String consentUrl(String requestNo) => '$siteUrl${consentPath(requestNo)}';

  /// `2026-10-13 14:05 (Europe/Warsaw)` — locale-neutral timestamp for proofs.
  static String stamp(DateTime at) {
    final w = DurationService.toWarsawWall(at);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${w.year}-${two(w.month)}-${two(w.day)} ${two(w.hour)}:${two(w.minute)} (${DurationService.timeZone})';
  }

  /// Plain-text request summary in [locale] (e-mail body and stored copy).
  static String summaryText(TGSpecialRequest r, String locale) {
    final l = resolveLocale(locale);
    final makers = r.selectedSellerIds.isEmpty
        ? _t(l, 'so_consent_sum_makers_team')
        : r.selectedSellerIds.map((id) => TGSellerProfileService.instance.bySellerKey(id)?.name ?? id).join(', ');
    final budget = r.budgetMin == null || r.budgetMax == null ? _t(l, 'so_consent_sum_budget_open') : '${r.budgetMin}–${r.budgetMax} PLN';
    return [
      '${_t(l, 'so_consent_sum_no')}: ${r.requestNo}',
      '${_t(l, 'so_consent_sum_title')}: ${r.title}',
      '${_t(l, 'so_consent_sum_types')}: ${r.projectTypes.map((s) => _t(l, 'ui_so_spec_${s.name}')).join(', ')}',
      if (r.dimensionsText.isNotEmpty) '${_t(l, 'so_consent_sum_size')}: ${r.dimensionsText} × ${r.quantity}',
      '${_t(l, 'so_consent_sum_location')}: ${r.city}, ${r.voivodeship}',
      '${_t(l, 'so_consent_sum_budget')}: $budget',
      '${_t(l, 'so_consent_sum_makers')}: $makers',
    ].join('\n');
  }

  // ---- records ----

  TGSpecialRequestConsent? forRequest(String requestId) => consents.where((c) => c.requestId == requestId).lastOrNull;

  List<TGConsentDelivery> deliveriesFor(String requestId) => deliveries.where((d) => d.requestId == requestId).toList();

  List<TGConsentDelivery> failedFor(String requestId) => deliveriesFor(requestId).where((d) => d.failed).toList();

  bool hasFailedDelivery(String requestId) => failedFor(requestId).isNotEmpty;

  TGSpecialRequestConsent record({required TGSpecialRequest request, required String userId, required String locale}) {
    final l = resolveLocale(locale);
    final text = consentText(l);
    final c = TGSpecialRequestConsent(
      id: 'so-consent-${_seq++}',
      requestId: request.id,
      requestNo: request.requestNo,
      userId: userId,
      version: kSoConsentTextVersion,
      locale: l,
      textHash: hashOf(text),
      text: text,
      approvedAt: TGClock.now(),
    );
    consents.add(c);
    TGAnalytics.track('so_consent_approved', {'requestNo': request.requestNo, 'version': c.version, 'locale': l});
    notifyListeners();
    return c;
  }

  // ---- proof delivery ----

  /// E-mail with the full accepted text + summary, and SMS with the stored-copy link.
  List<TGConsentDelivery> sendProof(TGSpecialRequest r, TGSpecialRequestConsent c) {
    final l = c.locale;
    final link = consentUrl(r.requestNo);
    final email = TGConsentDelivery(
      id: 'so-dlv-${_seq++}',
      consentId: c.id,
      requestId: r.id,
      requestNo: r.requestNo,
      channel: TGConsentChannel.email,
      to: r.email,
      subject: _t(l, 'so_consent_email_subject', {'no': r.requestNo}),
      body: [
        _t(l, 'so_consent_email_intro', {'date': stamp(c.approvedAt), 'version': c.version}),
        c.text,
        '— ${_t(l, 'so_consent_summary')} —\n${summaryText(r, l)}',
        _t(l, 'so_consent_stored_copy', {'link': link}),
        'SHA-256: ${c.textHash}',
      ].join('\n\n'),
    );
    final sms = TGConsentDelivery(
      id: 'so-dlv-${_seq++}',
      consentId: c.id,
      requestId: r.id,
      requestNo: r.requestNo,
      channel: TGConsentChannel.sms,
      to: r.phone,
      subject: '',
      body: _t(l, 'so_consent_sms', {'no': r.requestNo, 'link': link}),
    );
    deliveries.addAll([email, sms]);
    _attempt(email);
    _attempt(sms);
    notifyListeners();
    return [email, sms];
  }

  void _attempt(TGConsentDelivery d) {
    while (d.status != TGConsentDeliveryStatus.sent && d.attempts < maxAttempts) {
      d.attempts++;
      d.lastAttemptAt = TGClock.now();
      final err = transport.send(d.channel, d.to, d.subject, d.body);
      if (err == null) {
        d.status = TGConsentDeliveryStatus.sent;
        d.sentAt = d.lastAttemptAt;
        d.lastError = null;
      } else {
        d.lastError = err;
      }
    }
    if (d.status != TGConsentDeliveryStatus.sent) {
      d.status = TGConsentDeliveryStatus.failed;
      TGAnalytics.track('so_consent_delivery_failed', {'requestNo': d.requestNo, 'channel': d.channel.name, 'error': d.lastError});
    }
  }

  /// Manual "Resend": another round of [maxAttempts] for every failed message.
  /// Returns true when nothing is left failed.
  bool resend(String requestId) {
    for (final d in failedFor(requestId)) {
      d.status = TGConsentDeliveryStatus.pending;
      d.attempts = 0;
      _attempt(d);
    }
    TGAnalytics.track('so_consent_resend', {'requestId': requestId});
    notifyListeners();
    return !hasFailedDelivery(requestId);
  }

  /// Mock seed: a confirmed request whose SMS gateway rejected all attempts.
  void seedFailedDelivery(TGSpecialRequest r, {required DateTime approvedAt}) {
    final text = consentText('pl');
    final c = TGSpecialRequestConsent(
      id: 'so-consent-${_seq++}',
      requestId: r.id,
      requestNo: r.requestNo,
      userId: r.buyerId,
      version: kSoConsentTextVersion,
      locale: 'pl',
      textHash: hashOf(text),
      text: text,
      approvedAt: approvedAt,
    );
    consents.add(c);
    final mock = transport;
    final unreachable = TGMockConsentTransport(unreachable: {r.phone});
    transport = unreachable;
    sendProof(r, c);
    transport = mock;
  }
}
