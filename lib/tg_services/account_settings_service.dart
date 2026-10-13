import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_account.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/verification_service.dart';

/// Profile name, password, mock 2FA and session list for one account.
class TGAccountProfile {
  TGAccountProfile({required this.firstName, required this.lastName, this.city = '', this.language = 'pl'});
  String firstName;
  String lastName;
  String city;
  String language;
  String get publicName => tgPublicName(firstName, lastName);
}

@immutable
class TGSession {
  const TGSession({required this.id, required this.device, required this.city, required this.lastSeen, this.current = false});
  final String id;
  final String device;
  final String city;
  final DateTime lastSeen;
  final bool current;
}

/// One prerequisite for account deletion. [ok] false blocks the request.
typedef TGDeleteCheck = ({String id, String labelKey, bool ok, int count});

/// DASH-4 settings: profile, security, language, blocked users, privacy & data.
class TGAccountSettingsService extends ChangeNotifier {
  TGAccountSettingsService._();
  static final TGAccountSettingsService instance = TGAccountSettingsService._();

  static const mockPassword = 'Demo2026pass';
  static const deletionGrace = Duration(days: 7);
  static const exportCooldown = Duration(hours: 24);

  final Map<String, TGAccountProfile> _profiles = {};
  final Map<String, String> _passwords = {};
  final Map<String, DateTime> _passwordChangedAt = {};
  final Map<String, bool> _twoFa = {};
  final Map<String, String> _twoFaPending = {};
  final Map<String, List<String>> _backupCodes = {};
  final Map<String, List<TGSession>> _sessions = {};
  final Map<String, List<TGDataExport>> _exports = {};
  final Map<String, TGDeletionRequest> _deletions = {};
  final Map<String, String> _names = {'usr_tomasz': 'Tomasz B.', 'usr_spam_42': 'Kupię Tanio 42'};

  void reset() {
    _profiles.clear();
    _passwords.clear();
    _passwordChangedAt.clear();
    _twoFa.clear();
    _twoFaPending.clear();
    _backupCodes.clear();
    _sessions.clear();
    _exports.clear();
    _deletions.clear();
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  TGAccountProfile profileOf(FakeAuthState auth) => _profiles.putIfAbsent(auth.userId, () {
        final parts = auth.displayName.trim().split(RegExp(r'\s+'));
        return TGAccountProfile(firstName: parts.first, lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '');
      });

  /// Saves first / last name and updates the public "Marek K." form on [auth].
  String? saveProfile(FakeAuthState auth, {required String first, required String last, String city = ''}) {
    if (first.trim().length < 2) return 'set_err_first';
    if (last.trim().isEmpty) return 'set_err_last';
    final p = profileOf(auth)
      ..firstName = first.trim()
      ..lastName = last.trim()
      ..city = city.trim();
    final initials = '${p.firstName[0]}${p.lastName[0]}'.toUpperCase();
    TGAnalytics.track('profile_update', {'userId': auth.userId});
    auth.updatePublicName(p.publicName, initials);
    notifyListeners();
    return null;
  }

  void setLanguage(FakeAuthState auth, String lang) {
    profileOf(auth).language = lang;
    TGAnalytics.track('language_change', {'lang': lang});
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Security
  // ---------------------------------------------------------------------------

  DateTime? passwordChangedAt(String userId) => _passwordChangedAt[userId];

  static bool strongPassword(String p) =>
      p.length >= 10 && p.contains(RegExp(r'[A-Za-z]')) && p.contains(RegExp(r'\d'));

  String? changePassword(String userId, {required String current, required String next, required String confirm}) {
    final cur = _passwords[userId] ?? mockPassword;
    if (current != cur) return 'set_err_pw_current';
    if (!strongPassword(next)) return 'set_err_pw_weak';
    if (next == cur) return 'set_err_pw_same';
    if (next != confirm) return 'set_err_pw_match';
    _passwords[userId] = next;
    _passwordChangedAt[userId] = TGClock.now();
    TGAnalytics.track('password_change', {'userId': userId});
    notifyListeners();
    return null;
  }

  bool twoFaEnabled(String userId) => _twoFa[userId] ?? false;

  /// Mock authenticator setup key shown as text (no QR rendering).
  String startTwoFa(String userId) {
    final key = 'TGMA ${userId.hashCode.abs().toRadixString(36).toUpperCase().padLeft(6, '7').substring(0, 6)} DEMO';
    _twoFaPending[userId] = key;
    notifyListeners();
    return key;
  }

  String? twoFaSetupKey(String userId) => _twoFaPending[userId];

  String? confirmTwoFa(String userId, String code) {
    if (_twoFaPending[userId] == null) return 'ver_err_no_pending';
    if (code.trim() != TGVerificationService.mockCode) return 'ver_err_code';
    _twoFaPending.remove(userId);
    _twoFa[userId] = true;
    _backupCodes[userId] = [for (var i = 0; i < 8; i++) '${(userId.hashCode.abs() + i * 7919) % 90000 + 10000}-${(i * 4513 + 1201) % 9000 + 1000}'];
    TGAnalytics.track('twofa_enable', {'userId': userId});
    notifyListeners();
    return null;
  }

  List<String> backupCodes(String userId) => List.unmodifiable(_backupCodes[userId] ?? const []);

  String? disableTwoFa(String userId, String password) {
    if (password != (_passwords[userId] ?? mockPassword)) return 'set_err_pw_current';
    _twoFa[userId] = false;
    _backupCodes.remove(userId);
    TGAnalytics.track('twofa_disable', {'userId': userId});
    notifyListeners();
    return null;
  }

  List<TGSession> sessionsOf(String userId) => _sessions.putIfAbsent(userId, () {
        final now = TGClock.now();
        return [
          TGSession(id: 's1', device: 'Chrome · macOS', city: 'Kraków', lastSeen: now, current: true),
          if (!TGRevenueConfigService.instance.productionMode) ...[
            TGSession(id: 's2', device: 'Safari · iPhone', city: 'Kraków', lastSeen: now.subtract(const Duration(hours: 5))),
            TGSession(id: 's3', device: 'Firefox · Windows', city: 'Katowice', lastSeen: now.subtract(const Duration(days: 9))),
          ],
        ];
      });

  void signOutOthers(String userId) {
    _sessions[userId] = sessionsOf(userId).where((s) => s.current).toList();
    TGAnalytics.track('sessions_signout_others', {'userId': userId});
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Blocked users
  // ---------------------------------------------------------------------------

  List<({String id, String name})> blockedUsers(String userId) {
    final names = <String, String>{..._names};
    for (final archived in const [false, true]) {
      for (final t in MessagingService.instance.inboxFor(userId, archived: archived)) {
        final other = t.buyerId == userId ? t.sellerId : t.buyerId;
        names[other] = t.otherPartyName(userId);
      }
    }
    return [for (final id in MessagingService.instance.blockedOf(userId)) (id: id, name: names[id] ?? id)];
  }

  void unblock(String userId, String otherId) => MessagingService.instance.setBlocked(userId, otherId, false);

  /// One blocked account for the demo (not in production mode).
  void seedMocks(String userId) {
    if (TGRevenueConfigService.instance.productionMode) return;
    if (MessagingService.instance.blockedOf(userId).isNotEmpty) return;
    MessagingService.instance.setBlocked(userId, 'usr_spam_42', true);
  }

  // ---------------------------------------------------------------------------
  // Privacy & data
  // ---------------------------------------------------------------------------

  List<TGDataExport> exportsOf(String userId) => List.unmodifiable(_exports[userId] ?? const []);

  DateTime? nextExportAt(String userId) {
    final last = _exports[userId]?.lastOrNull;
    return last?.requestedAt.add(exportCooldown);
  }

  /// Builds the GDPR art. 15/20 export as JSON (one request per 24 h).
  ({TGDataExport? export, String? error}) requestExport(FakeAuthState auth) {
    final next = nextExportAt(auth.userId);
    if (next != null && TGClock.now().isBefore(next)) return (export: null, error: 'set_err_export_cooldown');
    final p = profileOf(auth);
    final ver = TGVerificationService.instance;
    final billing = TGBillingService.instance;
    final data = {
      'generatedAt': TGClock.now().toIso8601String(),
      'account': {
        'userId': auth.userId,
        'publicName': p.publicName,
        'firstName': p.firstName,
        'lastName': p.lastName,
        'city': p.city,
        'language': p.language,
        'email': ver.emailOf(auth.userId, fallback: auth.mockEmail).value,
        'phone': ver.phoneOf(auth.userId).value,
        'twoFactor': twoFaEnabled(auth.userId),
      },
      'company': switch (ver.companyFor(auth.userId)) {
        final c? => {'nip': c.nip, 'name': c.registry.name, 'status': c.status.name},
        null => null,
      },
      'payments': [for (final x in billing.paymentsFor(auth.userId)) x.toJson()],
      'invoices': [for (final i in billing.invoicesFor(auth.userId)) i.number],
      'deals': [
        for (final d in [...DealService.instance.forSeller(auth.userId), ...DealService.instance.forBuyer(auth.userId)])
          {'id': d.id, 'status': d.status.name},
      ],
      'blockedUsers': MessagingService.instance.blockedOf(auth.userId).toList(),
      'sessions': [for (final s in sessionsOf(auth.userId)) {'device': s.device, 'lastSeen': s.lastSeen.toIso8601String()}],
    };
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final e = TGDataExport(id: 'EXP-${TGClock.now().millisecondsSinceEpoch}', userId: auth.userId, requestedAt: TGClock.now(), json: json);
    (_exports[auth.userId] ??= []).add(e);
    TGAnalytics.track('data_export_request', {'userId': auth.userId, 'bytes': json.length});
    notifyListeners();
    return (export: e, error: null);
  }

  static const _openDeal = {
    TGDealStatus.pendingBuyer,
    TGDealStatus.pendingSeller,
    TGDealStatus.inModeration,
  };

  /// Everything that must be settled before an account can be closed.
  List<TGDeleteCheck> deleteChecks(FakeAuthState auth) {
    final billing = TGBillingService.instance;
    final subs = billing.subscriptionsFor(auth).where((s) => s.isLive && !s.cancelAtPeriodEnd).length;
    final pastDue = billing.pastDueFor(auth.userId).length;
    final deals = [
      ...DealService.instance.forSeller(auth.userId),
      ...DealService.instance.forBuyer(auth.userId),
    ].where((d) => _openDeal.contains(d.status)).length;
    return [
      (id: 'subscriptions', labelKey: 'set_del_check_subs', ok: subs == 0, count: subs),
      (id: 'past_due', labelKey: 'set_del_check_pastdue', ok: pastDue == 0, count: pastDue),
      (id: 'deals', labelKey: 'set_del_check_deals', ok: deals == 0, count: deals),
    ];
  }

  TGDeletionRequest? deletionOf(String userId) {
    final d = _deletions[userId];
    return d != null && d.active ? d : null;
  }

  String? requestDeletion(FakeAuthState auth, {required String confirmText}) {
    if (deletionOf(auth.userId) != null) return 'set_err_del_pending';
    if (deleteChecks(auth).any((c) => !c.ok)) return 'set_err_del_blocked';
    if (confirmText.trim() != 'DELETE' && confirmText.trim() != 'USUŃ' && confirmText.trim() != 'SİL') {
      return 'set_err_del_confirm';
    }
    final now = TGClock.now();
    _deletions[auth.userId] = TGDeletionRequest(userId: auth.userId, requestedAt: now, effectiveAt: now.add(deletionGrace));
    TGAnalytics.track('account_delete_request', {'userId': auth.userId, 'graceDays': deletionGrace.inDays});
    notifyListeners();
    return null;
  }

  void cancelDeletion(String userId) {
    final d = _deletions[userId];
    if (d == null || !d.active) return;
    _deletions[userId] = TGDeletionRequest(
      userId: userId,
      requestedAt: d.requestedAt,
      effectiveAt: d.effectiveAt,
      cancelledAt: TGClock.now(),
    );
    TGAnalytics.track('account_delete_cancel', {'userId': userId});
    notifyListeners();
  }
}
