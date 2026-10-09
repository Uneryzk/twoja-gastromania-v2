import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_deal.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';

String localizedNotificationTitle(BuildContext context, TGAppNotification n) {
  final key = switch (n.type) {
    'deal_reminder' || 'deal_reminder_d3' => 'notif_deal_reminder_title',
    'deal_reminder_d10' => 'notif_deal_reminder_d10_title',
    _ => 'notif_${n.type}_title',
  };
  final text = context.t(key);
  return text.isEmpty ? n.title : text;
}

String localizedNotificationBody(BuildContext context, TGAppNotification n) {
  final params = {
    'title': n.params['title'] ?? n.body,
    'name': n.params['name'] ?? 'Technica',
  };
  final key = switch (n.type) {
    'deal_reminder' || 'deal_reminder_d3' || 'deal_reminder_d10' || 'deal_review_requested' || 'deal_expired' => 'notif_listing_body',
    _ => 'notif_${n.type}_body',
  };
  final text = context.t(key, params);
  return text.isEmpty ? n.body : text;
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static const routeName = 'AccountNotifications';
  static const routePath = '/account/notifications';

  @override
  Widget build(BuildContext context) {
    DealService.instance.ensureSeeded();
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    return TGPageScaffold(
      body: ListenableBuilder(
        listenable: NotificationService.instance,
        builder: (context, _) {
          final items = NotificationService.instance.forUser(auth.userId);
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TGBreadcrumb(items: [
                        TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                        TGBreadcrumbItem(label: context.t('ui_notifications')),
                      ]),
                      const SizedBox(height: 16),
                      Text(context.t('ui_notifications'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        Text(context.t('ui_no_notifications'), style: theme.bodyMedium.override(color: theme.secondaryText))
                      else
                        for (final n in items)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(n.unread ? Icons.notifications_active : Icons.notifications_none, color: n.unread ? theme.primary : theme.secondaryText),
                            title: Text(localizedNotificationTitle(context, n), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
                            subtitle: Text('${localizedNotificationBody(context, n)}\n${DateFormat('d MMM · HH:mm').format(n.createdAt)}'),
                            isThreeLine: true,
                            onTap: () {
                              NotificationService.instance.open(n.id);
                              if (n.deepLink != null) context.go(n.deepLink!);
                            },
                          ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TGNotificationBell extends StatefulWidget {
  const TGNotificationBell({super.key});

  @override
  State<TGNotificationBell> createState() => _TGNotificationBellState();
}

class _TGNotificationBellState extends State<TGNotificationBell> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    DealService.instance.ensureSeeded();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _maybePulse(int unread) {
    if (unread > 0 && NotificationService.instance.shouldPulse(context.read<FakeAuthState>().userId) && !_armed) {
      _armed = true;
      if (!tgReduceMotion(context)) _pulse.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    return ListenableBuilder(
      listenable: NotificationService.instance,
      builder: (context, _) {
        if (!auth.isLoggedIn) return const SizedBox.shrink();
        final unread = NotificationService.instance.unreadCount(auth.userId);
        _maybePulse(unread);
        return SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.18).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeOut)),
                child: TGIconButton(
                  icon: Icons.notifications_none,
                  size: 44,
                  tooltip: context.t('ui_notifications'),
                  onPressed: () => _open(context),
                ),
              ),
              if (unread > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: TGColors.accent, borderRadius: BorderRadius.circular(99)),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _open(BuildContext context) async {
    final auth = context.read<FakeAuthState>();
    final items = NotificationService.instance.forUser(auth.userId).take(10).toList();
    TGAnalytics.track('notification_open', {'count': items.length});
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final origin = box.localToGlobal(Offset.zero);
    final picked = await showMenu<String>(
      context: context,
      color: FlutterFlowTheme.of(context).secondaryBackground,
      position: RelativeRect.fromLTRB(origin.dx, origin.dy + box.size.height + 6, origin.dx + 1, 0),
      items: [
        if (items.isEmpty) PopupMenuItem(enabled: false, child: Text(context.t('ui_no_notifications'))),
        for (final n in items)
          PopupMenuItem(
            value: n.deepLink ?? n.id,
            child: SizedBox(
              width: (MediaQuery.sizeOf(context).width - 32).clamp(200, 280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localizedNotificationTitle(context, n), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(localizedNotificationBody(context, n), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: FlutterFlowTheme.of(context).secondaryText, fontSize: 12)),
                ],
              ),
            ),
          ),
        PopupMenuItem(value: '__all__', child: Text(context.t('ui_see_all'), style: const TextStyle(fontWeight: FontWeight.w800))),
      ],
    );
    if (!context.mounted || picked == null) return;
    if (picked == '__all__') {
      TGNav.accountNotifications(context);
      return;
    }
    final match = items.where((n) => (n.deepLink ?? n.id) == picked).firstOrNull;
    if (match != null) NotificationService.instance.open(match.id);
    if (picked.startsWith('/')) context.go(picked);
  }
}
