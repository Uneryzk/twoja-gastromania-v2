import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_notification_prefs.dart';

/// Category × channel matrix per user. Locked categories are always on;
/// marketing starts off and records every opt-in / opt-out with a timestamp.
class TGNotificationPrefsService extends ChangeNotifier {
  TGNotificationPrefsService._();
  static final TGNotificationPrefsService instance = TGNotificationPrefsService._();

  final Map<String, Map<TGNotifCategory, Set<TGNotifChannel>>> _prefs = {};
  final List<TGConsentRecord> consentLog = [];

  static Set<TGNotifChannel> defaultsFor(TGNotifCategory c) => switch (c) {
        TGNotifCategory.marketing => const {},
        TGNotifCategory.messages => const {TGNotifChannel.inApp, TGNotifChannel.email, TGNotifChannel.push},
        TGNotifCategory.billing || TGNotifCategory.moderation => TGNotifChannel.values.toSet(),
        _ => const {TGNotifChannel.inApp, TGNotifChannel.email},
      };

  void reset() {
    _prefs.clear();
    consentLog.clear();
    notifyListeners();
  }

  Map<TGNotifCategory, Set<TGNotifChannel>> _of(String userId) =>
      _prefs.putIfAbsent(userId, () => {for (final c in TGNotifCategory.values) c: {...defaultsFor(c)}});

  bool isOn(String userId, TGNotifCategory c, TGNotifChannel ch) {
    if (c.locked) return true;
    return _prefs[userId]?[c]?.contains(ch) ?? defaultsFor(c).contains(ch);
  }

  bool showsInApp(String userId, String type) => isOn(userId, tgNotifCategoryOf(type), TGNotifChannel.inApp);

  /// Latest marketing consent for [ch], or null when never given.
  TGConsentRecord? marketingConsent(String userId, TGNotifChannel ch) {
    for (final r in consentLog.reversed) {
      if (r.userId == userId && r.channel == ch) return r;
    }
    return null;
  }

  /// Returns false for locked categories (nothing changes).
  bool set(String userId, TGNotifCategory c, TGNotifChannel ch, bool on) {
    if (c.locked) return false;
    final row = _of(userId)[c]!;
    if (on == row.contains(ch)) return true;
    on ? row.add(ch) : row.remove(ch);
    final now = TGClock.now();
    if (c.optIn) consentLog.add(TGConsentRecord(userId: userId, channel: ch, granted: on, at: now));
    TGAnalytics.track('notification_pref_change', {
      'category': c.name,
      'channel': ch.name,
      'on': on,
      if (c.optIn) 'consentAt': now.toIso8601String(),
    });
    notifyListeners();
    return true;
  }
}
