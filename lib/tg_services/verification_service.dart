import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_account.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart' show isValidNip;
import 'package:twoja_gastromania/tg_services/account_identity_service.dart';
import 'package:twoja_gastromania/tg_services/admin_console_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

/// DASH-4 verification centre: phone, e-mail and company (NIP).
///
/// Codes are mocked ([mockCode]); the public register lookup is a fixed
/// table standing in for KRS / CEIDG.
class TGVerificationService extends ChangeNotifier {
  TGVerificationService._();
  static final TGVerificationService instance = TGVerificationService._();

  static const mockCode = '123456';

  final Map<String, TGContactState> _phones = {};
  final Map<String, TGContactState> _emails = {};
  final List<TGCompanyApplication> _apps = [];
  bool _seeded = false;
  int _seq = 1;

  bool get _hideMock => TGRevenueConfigService.instance.productionMode;

  void reset() {
    _phones.clear();
    _emails.clear();
    _apps.clear();
    _seeded = false;
    _seq = 1;
  }

  // ---------------------------------------------------------------------------
  // Phone
  // ---------------------------------------------------------------------------

  TGContactState phoneOf(String userId) => _phones.putIfAbsent(userId, TGContactState.new);

  /// Polish numbers: 9 digits, optionally prefixed with +48 / 48.
  static String? normalisePhone(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('48') && d.length == 11) d = d.substring(2);
    if (d.length != 9) return null;
    return '+48 ${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
  }

  /// Sends the SMS code for a new number. Returns an i18n error key.
  String? startPhoneChange(String userId, String raw) {
    final n = normalisePhone(raw);
    if (n == null) return 'ver_err_phone_format';
    final s = phoneOf(userId);
    if (s.value == n && s.verified) return 'ver_err_phone_same';
    if (AccountIdentityService.instance.checkPhone(n) != null && s.value != n) return 'ver_err_phone_taken';
    s.pending = n;
    s.codeSentAt = TGClock.now();
    notifyListeners();
    return null;
  }

  String? confirmPhone(String userId, String code, {FakeAuthState? auth}) {
    final s = phoneOf(userId);
    if (s.pending == null) return 'ver_err_no_pending';
    if (code.trim() != mockCode) return 'ver_err_code';
    final previous = s.value;
    s.value = s.pending;
    s.verifiedAt = TGClock.now();
    s.pending = null;
    AccountIdentityService.instance.claim(phone: s.value);
    if (auth != null && auth.userId == userId) auth.phoneVerified = true;
    TGAnalytics.track('phone_change', {'userId': userId, 'first': previous == null});
    notifyListeners();
    return null;
  }

  // ---------------------------------------------------------------------------
  // E-mail
  // ---------------------------------------------------------------------------

  TGContactState emailOf(String userId, {String? fallback}) {
    final s = _emails.putIfAbsent(userId, TGContactState.new);
    if (s.value == null && fallback != null) s.value = fallback;
    return s;
  }

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  String? sendEmailLink(String userId, String email) {
    final v = email.trim().toLowerCase();
    if (!_email.hasMatch(v)) return 'ver_err_email_format';
    final s = emailOf(userId);
    if (s.value != v && AccountIdentityService.instance.checkEmail(v) != null) return 'ver_err_email_taken';
    s.pending = v;
    s.codeSentAt = TGClock.now();
    notifyListeners();
    return null;
  }

  /// The user opened the link from the e-mail (mock).
  String? confirmEmail(String userId) {
    final s = emailOf(userId);
    if (s.pending == null) return 'ver_err_no_pending';
    s.value = s.pending;
    s.pending = null;
    s.verifiedAt = TGClock.now();
    AccountIdentityService.instance.claim(email: s.value);
    TGAnalytics.track('email_verified', {'userId': userId});
    notifyListeners();
    return null;
  }

  // ---------------------------------------------------------------------------
  // Company (NIP)
  // ---------------------------------------------------------------------------

  static bool nipValid(String nip) => isValidNip(nip);

  static String nipDigits(String nip) => nip.replaceAll(RegExp(r'\D'), '');

  static const Map<String, TGRegistryRecord> _registry = {
    '5260250274': TGRegistryRecord(
      nip: '5260250274',
      name: 'Gastrosilesia.pl Sp. z o.o.',
      address: 'ul. Mariacka 12, 40-014 Katowice',
      register: 'KRS',
      active: true,
      representatives: ['Piotr Nowicki', 'TG Demo'],
    ),
    '7771234567': TGRegistryRecord(
      nip: '7771234567',
      name: 'Bistro Nowak Sp. z o.o.',
      address: 'ul. Wrocławska 4, 45-001 Opole',
      register: 'KRS',
      active: true,
      representatives: ['Ewa Nowak'],
    ),
    '6340012347': TGRegistryRecord(
      nip: '6340012347',
      name: 'Inoxline Sp. z o.o.',
      address: 'ul. Przemysłowa 8, 41-200 Sosnowiec',
      register: 'KRS',
      active: true,
      representatives: ['Krzysztof Lis'],
    ),
    '6761005675': TGRegistryRecord(
      nip: '6761005675',
      name: 'Marek Kowalski Usługi Gastronomiczne',
      address: 'ul. Długa 21, 31-147 Kraków',
      register: 'CEIDG',
      active: true,
      representatives: ['Marek Kowalski'],
    ),
    '8725552104': TGRegistryRecord(
      nip: '8725552104',
      name: 'Stara Kuchnia s.c.',
      address: 'ul. Rynek 2, 33-100 Tarnów',
      register: 'CEIDG',
      active: false,
    ),
  };

  /// Mock KRS / CEIDG query. Null when the NIP is not registered.
  TGRegistryRecord? lookupRegistry(String nip) {
    final d = nipDigits(nip);
    if (!nipValid(d)) return null;
    return _registry[d];
  }

  TGCompanyApplication? companyFor(String userId) {
    final mine = _apps.where((a) => a.userId == userId && !(_hideMock && a.isMock)).toList();
    return mine.isEmpty ? null : mine.last;
  }

  /// NIP confirmed by a moderator, or already verified on the store profile.
  bool isNipVerified(String userId) {
    if (companyFor(userId)?.status == TGVerifyStatus.verified) return true;
    return TGSellerProfileService.instance.bySellerKey(userId)?.nipVerifiedAt != null;
  }

  /// "Verified Seller" (green shield) = NIP verified AND an active store plan.
  bool isVerifiedSeller(FakeAuthState auth) => auth.storePlan != null && isNipVerified(auth.userId);

  ({TGCompanyApplication? app, String? error}) submitCompany({
    required String userId,
    required String nip,
    required String representativeName,
    required bool confirmedRepresentation,
  }) {
    final d = nipDigits(nip);
    if (!nipValid(d)) return (app: null, error: 'ver_err_nip');
    final reg = lookupRegistry(d);
    if (reg == null) return (app: null, error: 'ver_err_registry_not_found');
    if (!reg.active) return (app: null, error: 'ver_err_registry_inactive');
    if (representativeName.trim().length < 3) return (app: null, error: 'ver_err_rep_name');
    if (!confirmedRepresentation) return (app: null, error: 'ver_err_rep_confirm');
    final current = companyFor(userId);
    if (current?.status == TGVerifyStatus.pending) return (app: null, error: 'ver_err_pending');
    if (current?.status == TGVerifyStatus.verified && current!.nip == d) return (app: null, error: 'ver_err_already');
    final app = TGCompanyApplication(
      id: 'VER-${_seq++}',
      userId: userId,
      nip: d,
      registry: reg,
      representativeName: representativeName.trim(),
      submittedAt: TGClock.now(),
    );
    _apps.add(app);
    TGAnalytics.track('verification_submit', {'kind': 'company', 'userId': userId, 'register': reg.register});
    notifyListeners();
    return (app: app, error: null);
  }

  /// NIP verification queue (oldest first).
  List<TGCompanyApplication> queue() => [
        for (final a in _apps)
          if (a.status == TGVerifyStatus.pending && !(_hideMock && a.isMock)) a,
      ]..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));

  List<TGCompanyApplication> all() => [for (final a in _apps) if (!(_hideMock && a.isMock)) a];

  TGCompanyApplication? appById(String id) => _apps.where((a) => a.id == id).firstOrNull;

  /// Moderator / admin decision. Rejections need a note the user will see.
  String? decide(String appId, {required FakeAuthState actor, required bool approve, String? note}) {
    if (!actor.canModerate) return 'adm_err_staff';
    final a = appById(appId);
    if (a == null || a.status != TGVerifyStatus.pending) return 'adm_err_not_found';
    if (!approve && (note ?? '').trim().length < 10) return 'adm_err_reason';
    final now = TGClock.now();
    a.status = approve ? TGVerifyStatus.verified : TGVerifyStatus.rejected;
    a.decidedAt = now;
    a.decidedBy = actor.userId;
    a.decisionNote = note?.trim();
    if (approve) {
      final p = TGSellerProfileService.instance.bySellerKey(a.userId);
      if (p != null) TGSellerProfileService.instance.patch(p.publicId, (x) => x.copyWith(nipVerifiedAt: now, nip: a.nip));
    }
    TGAdminConsoleService.instance.log(
      actor: actor,
      action: 'verification_decision',
      targetId: a.userId,
      reason: note,
      details: {'application': a.id, 'decision': approve ? 'approved' : 'rejected', 'nip': a.nip},
    );
    TGAnalytics.track('verification_decision', {'applicationId': a.id, 'approved': approve, 'role': actor.role.name});
    notifyListeners();
    return null;
  }

  /// Three pending applications (hidden in production mode).
  void seedMocks() {
    if (_seeded) return;
    _seeded = true;
    final now = TGClock.now();
    TGCompanyApplication mk(String user, String nip, String rep, int hoursAgo) => TGCompanyApplication(
          id: 'VER-mock-$user',
          userId: user,
          nip: nip,
          registry: _registry[nip]!,
          representativeName: rep,
          submittedAt: now.subtract(Duration(hours: hoursAgo)),
          isMock: true,
        );
    _apps.addAll([
      mk('usr_bistro', '7771234567', 'Ewa Nowak', 30),
      mk('seller_inoxline', '6340012347', 'Anna Lis', 52),
      mk('usr_marek', '6761005675', 'Marek Kowalski', 6),
    ]);
  }
}
