import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:twoja_gastromania/dashboard/dash2_widgets.dart' show DashTh;
import 'package:twoja_gastromania/dashboard/dash3_widgets.dart';
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
import 'package:twoja_gastromania/tg_models/tg_notification_prefs.dart';
import 'package:twoja_gastromania/tg_services/notification_prefs_service.dart';
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
    'n': n.params['n'] ?? n.dealId,
  };
  final key = switch (n.type) {
    'deal_reminder' || 'deal_reminder_d3' || 'deal_reminder_d10' || 'deal_review_requested' || 'deal_expired' => 'notif_listing_body',
    _ => 'notif_${n.type}_body',
  };
  final text = context.t(key, params);
  return text.isEmpty ? n.body : text;
}

/// `/account/notifications?tab=all|action|updates|prefs`.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, this.tab});

  static const routeName = 'AccountNotifications';
  static const routePath = '/account/notifications';
  static const tabs = ['all', 'action', 'updates', 'prefs'];

  final String? tab;

  @override
  Widget build(BuildContext context) {
    DealService.instance.ensureSeeded();
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final current = tabs.contains(tab) ? tab! : 'all';
    return TGPageScaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([NotificationService.instance, TGNotificationPrefsService.instance]),
        builder: (context, _) {
          final all = NotificationService.instance.forUser(auth.userId);
          final items = switch (current) {
            'action' => all.where((n) => tgNotifNeedsAction(n.type)).toList(),
            'updates' => all.where((n) => !tgNotifNeedsAction(n.type)).toList(),
            _ => all,
          };
          final actionCount = all.where((n) => n.unread && tgNotifNeedsAction(n.type)).length;
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    key: const Key('notif-page'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TGBreadcrumb(items: [
                        TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                        TGBreadcrumbItem(label: context.t('ui_notifications')),
                      ]),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(context.t('ui_notifications'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                            ),
                          ),
                          if (current != 'prefs' && all.any((n) => n.unread))
                            TextButton(
                              key: const Key('notif-mark-all'),
                              onPressed: () => NotificationService.instance.markAllRead(auth.userId),
                              child: Text(context.t('notif_mark_all')),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DashTabBar(
                        keyPrefix: 'notif',
                        semanticsLabel: context.t('ui_notifications'),
                        current: current,
                        tabs: [
                          for (final t in tabs)
                            (t, t == 'action' && actionCount > 0 ? '${context.t('notif_tab_action')} ($actionCount)' : context.t('notif_tab_$t')),
                        ],
                        onSelect: (t) => context.go(t == 'all' ? routePath : '$routePath?tab=$t'),
                      ),
                      const SizedBox(height: 12),
                      if (current == 'prefs')
                        NotificationPrefsMatrix(userId: auth.userId)
                      else if (items.isEmpty)
                        Text(
                          context.t(current == 'action' ? 'notif_action_empty' : 'ui_no_notifications'),
                          key: const Key('notif-empty'),
                          style: theme.bodyMedium.override(color: theme.secondaryText),
                        )
                      else
                        for (final n in items)
                          ListTile(
                            key: Key('notif-item-${n.id}'),
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              tgNotifNeedsAction(n.type)
                                  ? Icons.priority_high
                                  : (n.unread ? Icons.notifications_active : Icons.notifications_none),
                              color: n.unread ? theme.primary : theme.secondaryText,
                            ),
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

/// Category × channel matrix. Moderation and billing are locked on;
/// marketing is opt-in and shows the stored consent timestamp.
class NotificationPrefsMatrix extends StatelessWidget {
  const NotificationPrefsMatrix({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGNotificationPrefsService.instance;
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final fmt = DateFormat('d MMM y · HH:mm', Localizations.localeOf(context).languageCode);
    String ch(TGNotifChannel c) => context.t('notif_ch_${c.name}');
    String cat(TGNotifCategory c) => context.t('notif_cat_${c.name}');

    Widget toggle(TGNotifCategory c, TGNotifChannel k) => Semantics(
          label: '${cat(c)} · ${ch(k)}',
          hint: c.locked ? context.t('notif_locked_hint') : null,
          child: Switch(
            key: Key('notif-pref-${c.name}-${k.name}'),
            value: svc.isOn(userId, c, k),
            onChanged: c.locked ? null : (v) => svc.set(userId, c, k, v),
          ),
        );

    Widget label(TGNotifCategory c) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(child: Text(cat(c), style: theme.bodyMedium.override(fontWeight: FontWeight.w800))),
                if (c.locked) ...[
                  const SizedBox(width: 6),
                  ExcludeSemantics(child: Icon(Icons.lock_outline, key: Key('notif-pref-lock-${c.name}'), size: 16, color: theme.secondaryText)),
                ],
              ],
            ),
            Text(
              context.t(c.locked ? 'notif_locked_hint' : 'notif_cat_${c.name}_sub'),
              style: theme.bodySmall.override(color: theme.secondaryText),
            ),
          ],
        );

    final consent = Column(
      key: const Key('notif-consent'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final k in TGNotifChannel.values)
          Builder(builder: (context) {
            final r = svc.marketingConsent(userId, k);
            return Text(
              r == null
                  ? context.t('notif_consent_none', {'ch': ch(k)})
                  : context.t(r.granted ? 'notif_consent_granted' : 'notif_consent_withdrawn', {'ch': ch(k), 'd': fmt.format(r.at)}),
              key: Key('notif-consent-${k.name}'),
              style: theme.bodySmall.override(color: theme.secondaryText),
            );
          }),
      ],
    );

    final Widget matrix;
    if (phone) {
      matrix = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in TGNotifCategory.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DashBox(
                key: Key('notif-pref-card-${c.name}'),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    label(c),
                    for (final k in TGNotifChannel.values)
                      Row(children: [Expanded(child: Text(ch(k))), toggle(c, k)]),
                    if (c.optIn) consent,
                  ],
                ),
              ),
            ),
        ],
      );
    } else {
      matrix = DashBox(
        padding: const EdgeInsets.all(12),
        child: Table(
          key: const Key('notif-pref-table'),
          columnWidths: const {0: FlexColumnWidth(3)},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(children: [
              DashTh(context.t('notif_col_category')),
              for (final k in TGNotifChannel.values) Center(child: DashTh(ch(k))),
            ]),
            for (final c in TGNotifCategory.values)
              TableRow(
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: TGColors.border))),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, hint: 'row header', child: label(c)),
                        if (c.optIn) ...[const SizedBox(height: 4), consent],
                      ],
                    ),
                  ),
                  for (final k in TGNotifChannel.values) Center(child: toggle(c, k)),
                ],
              ),
          ],
        ),
      );
    }

    return Column(
      key: const Key('notif-prefs'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('notif_prefs_intro'), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 12),
        matrix,
      ],
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
