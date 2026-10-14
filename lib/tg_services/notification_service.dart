import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_services/notification_prefs_service.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final List<TGAppNotification> items = [];
  int _seq = 1;
  int _lastUnreadPulse = 0;

  void reset() {
    items.clear();
    _seq = 1;
    _lastUnreadPulse = 0;
    notifyListeners();
  }

  TGAppNotification add({
    required String userId,
    required String type,
    required String dealId,
    String? title,
    String? body,
    String? titleKey,
    String? bodyKey,
    String? deepLink,
    Map<String, String> params = const {},
  }) {
    final tk = titleKey ?? 'notif_${type}_title';
    final bk = bodyKey ?? 'notif_${type}_body';
    final n = TGAppNotification(
      id: 'n-${_seq++}',
      userId: userId,
      type: type,
      dealId: dealId,
      titleKey: tk,
      bodyKey: bk,
      title: title ?? '',
      body: body ?? '',
      createdAt: TGClock.now(),
      deepLink: deepLink ?? '/account/deals/$dealId?confirm=1',
      params: params,
    );
    items.insert(0, n);
    notifyListeners();
    return n;
  }

  /// Notifications the user sees in-app (their in-app preference is honoured;
  /// locked categories always show).
  List<TGAppNotification> forUser(String userId) => items
      .where((n) => n.userId == userId && TGNotificationPrefsService.instance.showsInApp(userId, n.type))
      .toList();

  int unreadCount(String userId) => forUser(userId).where((n) => n.unread).length;

  bool shouldPulse(String userId) {
    final unread = unreadCount(userId);
    if (unread > _lastUnreadPulse) {
      _lastUnreadPulse = unread;
      return true;
    }
    return false;
  }

  void markRead(String id) {
    final n = items.where((e) => e.id == id).firstOrNull;
    n?.readAt ??= TGClock.now();
    notifyListeners();
  }

  void markAllRead(String userId) {
    for (final n in forUser(userId)) {
      n.readAt ??= TGClock.now();
    }
    notifyListeners();
  }

  void open(String id) {
    markRead(id);
    TGAnalytics.track('notification_open', {'id': id});
  }
}
