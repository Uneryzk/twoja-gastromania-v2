/// Registry of e-mail, phone and social logins that already belong to an
/// account. One identity can only open one membership.
class AccountIdentityService {
  AccountIdentityService._();
  static final AccountIdentityService instance = AccountIdentityService._();

  static const demoEmail = 'tg.demo@twojagastromania.pl';
  static const demoPhone = '+48 532 784 074';
  static const demoGoogleId = 'google:demo';
  static const demoFacebookId = 'facebook:demo';

  final emails = <String>{};
  final phones = <String>{};
  final googleIds = <String>{};
  final facebookIds = <String>{};
  bool _seeded = false;

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    emails.addAll(_seedEmails.map(_normEmail));
    phones.addAll(_seedPhones.map(_canonPhone).where((d) => d.length >= 9));
    googleIds.addAll({demoGoogleId, 'google:$demoEmail'});
    facebookIds.addAll({demoFacebookId});
  }

  void reset() {
    emails.clear();
    phones.clear();
    googleIds.clear();
    facebookIds.clear();
    _seeded = false;
    ensureSeeded();
  }

  TGIdentityConflict? checkEmail(String email) {
    ensureSeeded();
    final v = _normEmail(email);
    if (v.isEmpty) return null;
    if (emails.contains(v)) return TGIdentityConflict(TGIdentityKind.email, email.trim());
    return null;
  }

  TGIdentityConflict? checkPhone(String phone) {
    ensureSeeded();
    final d = _canonPhone(phone);
    if (d.length < 9) return null;
    if (phones.contains(d)) return TGIdentityConflict(TGIdentityKind.phone, phone.trim());
    return null;
  }

  TGIdentityConflict? checkSocial(TGIdentityKind kind) {
    ensureSeeded();
    if (kind == TGIdentityKind.google && googleIds.isNotEmpty) {
      return const TGIdentityConflict(TGIdentityKind.google, demoGoogleId);
    }
    if (kind == TGIdentityKind.facebook && facebookIds.isNotEmpty) {
      return const TGIdentityConflict(TGIdentityKind.facebook, demoFacebookId);
    }
    return null;
  }

  /// Sign-up gate: returns the first identity that is already taken.
  TGIdentityConflict? checkRegister({required String email, String phone = ''}) {
    return checkEmail(email) ?? checkPhone(phone);
  }

  void claim({String? email, String? phone, TGIdentityKind? social}) {
    ensureSeeded();
    if (email != null && email.trim().isNotEmpty) emails.add(_normEmail(email));
    if (phone != null && _canonPhone(phone).length >= 9) phones.add(_canonPhone(phone));
    if (social == TGIdentityKind.google) googleIds.add(demoGoogleId);
    if (social == TGIdentityKind.facebook) facebookIds.add(demoFacebookId);
  }

  static String _normEmail(String v) => v.trim().toLowerCase();

  static String _digits(String v) => v.replaceAll(RegExp(r'\D'), '');

  /// Polish mobiles are stored as the last 9 digits so +48 532… and 532… match.
  static String _canonPhone(String v) {
    var d = _digits(v);
    if (d.startsWith('48') && d.length >= 11) d = d.substring(d.length - 9);
    return d;
  }

  static const _seedEmails = {
    demoEmail,
    'hello@gastropl.pl',
    'biuro@primegastro.pl',
    'mateusz.k@example.com',
    'office@technica.pro',
    'anna.p@example.com',
  };

  static const _seedPhones = {
    demoPhone,
    '+48 601 222 111',
    '+48 698 111 222',
  };
}

enum TGIdentityKind { email, phone, google, facebook }

class TGIdentityConflict {
  const TGIdentityConflict(this.kind, this.value);
  final TGIdentityKind kind;
  final String value;

  String get titleKey => switch (kind) {
        TGIdentityKind.google => 'ui_identity_taken_google',
        TGIdentityKind.facebook => 'ui_identity_taken_facebook',
        _ => 'ui_identity_taken',
      };
}
