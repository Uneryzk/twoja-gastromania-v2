import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/dashboard/dash3_widgets.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_account.dart';
import 'package:twoja_gastromania/tg_models/tg_billing.dart';
import 'package:twoja_gastromania/tg_models/tg_deal_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/admin_console_service.dart';
import 'package:twoja_gastromania/tg_services/billing_service.dart';
import 'package:twoja_gastromania/tg_services/deal_moderation_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
import 'package:twoja_gastromania/tg_services/verification_service.dart';

/// SLA for the NIP and conversation-report queues.
const _nipSla = Duration(hours: 48);
const _convSla = Duration(hours: 24);

String _fmt(DateTime d) => DateFormat('d MMM y HH:mm').format(d);

Listenable get _consoleListenable => Listenable.merge([
      TGAdminConsoleService.instance,
      TGVerificationService.instance,
      TGBillingService.instance,
      TGRevenueConfigService.instance,
    ]);

Widget _title(BuildContext context, String text, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: FlutterFlowTheme.of(context).titleLarge.override(fontWeight: FontWeight.w900)),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );

ButtonStyle get _cta => FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black);

/// Asks for a free-text reason (≥ [TGAdminConsoleService.minReasonLength]).
/// Returns null when cancelled.
Future<String?> showAdminReasonDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String keyPrefix = 'adm-reason',
  bool danger = false,
}) {
  final ctrl = TextEditingController();
  return showAdminDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final ok = ctrl.text.trim().length >= TGAdminConsoleService.minReasonLength;
        return AdminDialogScaffold(
          key: Key('$keyPrefix-dialog'),
          title: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(body, style: FlutterFlowTheme.of(ctx).bodyMedium),
              const SizedBox(height: 10),
              TextField(
                key: Key('$keyPrefix-input'),
                controller: ctrl,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: ctx.t('adm_reason'),
                  helperText: ctx.t('adm_reason_help', {'n': '${TGAdminConsoleService.minReasonLength}'}),
                ),
              ),
              const SizedBox(height: 6),
              Text(ctx.t('adm_logged_note'), style: FlutterFlowTheme.of(ctx).bodySmall.override(color: TGColors.slaAmber)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('ui_cancel'))),
            FilledButton(
              key: Key('$keyPrefix-confirm'),
              style: danger ? FilledButton.styleFrom(backgroundColor: TGColors.error, foregroundColor: Colors.white) : _cta,
              onPressed: ok ? () => Navigator.pop(ctx, ctrl.text.trim()) : null,
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
}

/// E-mail / phone shown masked; "Reveal" needs a reason and is audit-logged.
class AdminMaskedValue extends StatelessWidget {
  const AdminMaskedValue({super.key, required this.userId, required this.field, required this.value, this.style});
  final String userId;
  final TGPiiField field;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final svc = TGAdminConsoleService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final shown = svc.isRevealed(auth, userId, field);
        final id = 'adm-pii-$userId-${field.name}';
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Semantics(
              label: shown ? null : context.t('adm_masked_sr'),
              child: Text(svc.display(auth, userId, field, value), key: Key(id), style: style ?? const TextStyle(fontSize: 12)),
            ),
            if (!shown && value.isNotEmpty)
              TextButton(
                key: Key('$id-reveal'),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(48, 32)),
                onPressed: () async {
                  final reason = await showAdminReasonDialog(
                    context,
                    title: context.t('adm_reveal_title'),
                    body: context.t(field == TGPiiField.email ? 'adm_reveal_body_email' : 'adm_reveal_body_phone'),
                    confirmLabel: context.t('adm_reveal'),
                    keyPrefix: 'adm-reveal',
                  );
                  if (reason == null || !context.mounted) return;
                  final err = svc.reveal(actor: auth, userId: userId, field: field, reason: reason);
                  if (err != null) showTGToast(context, context.t(err));
                },
                child: Text(context.t('adm_reveal'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Today
// =============================================================================

class AdminTodayPage extends StatelessWidget {
  const AdminTodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final mod = context.watch<ModerationService>();
    final deals = context.watch<DealModerationService>();
    final so = TGSpecialOrderService.instance..ensureSeeded();
    final console = TGAdminConsoleService.instance;
    final ver = TGVerificationService.instance;
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    return ListenableBuilder(
      listenable: Listenable.merge([_consoleListenable, so]),
      builder: (context, _) {
        final now = TGClock.now();
        final openCases = mod.cases.values.where((c) => c.status.isOpen).toList();
        final overdueCases = openCases.where((c) => c.slaTone(mod.now) == TGSlaTone.overdue).toList();
        final nip = ver.queue();
        final conv = console.conversationReports(openOnly: true);
        final nipLate = nip.where((a) => now.difference(a.submittedAt) > _nipSla).toList();
        final convLate = conv.where((r) => now.difference(r.createdAt) > _convSla).toList();
        DateTime? oldest(Iterable<DateTime> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a.isBefore(b) ? a : b);
        final cards = <_QueueCardData>[
          _QueueCardData('reports', Icons.flag_outlined, context.t('adm_today_reports'), openCases.length, overdueCases.length,
              oldest(openCases.map((c) => c.firstReportedAt)), () => TGAdminNav.queuePage(context)),
          _QueueCardData('deals', Icons.gavel_outlined, context.t('ui_admin_objections'), deals.count(TGDealQueueKind.objection), 0, null,
              () => TGAdminNav.dealsQueue(context)),
          _QueueCardData('special_orders', Icons.hub_outlined, context.t('ui_so_admin_needs_matching'), so.adminCount(TGSoAdminQueue.needsMatching), 0,
              null, () => TGAdminNav.soQueue(context)),
          _QueueCardData('conversations', Icons.forum_outlined, context.t('adm_nav_conversations'), conv.length, convLate.length,
              oldest(conv.map((r) => r.createdAt)), () => context.go(TGAdminNav.conversations)),
          _QueueCardData('nip', Icons.business_outlined, context.t('adm_nav_nip'), nip.length, nipLate.length, oldest(nip.map((a) => a.submittedAt)),
              () => context.go(TGAdminNav.nip)),
          if (auth.isAdmin)
            _QueueCardData('refunds', Icons.currency_exchange, context.t('adm_today_refunds'), console.pendingRefunds, 0, null,
                () => context.go(TGAdminNav.payments)),
        ];
        return ListView(
          key: const Key('adm-today'),
          padding: EdgeInsets.all(phone ? 12 : 16),
          children: [
            _title(context, context.t('adm_nav_today')),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth < 520 ? 2 : (c.maxWidth < 900 ? 3 : 6);
              final w = (c.maxWidth - (cols - 1) * 8) / cols;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final d in cards) SizedBox(width: w, child: _QueueCard(data: d, compact: phone))],
              );
            }),
            const SizedBox(height: 16),
            _SlaPanel(cases: overdueCases, nipLate: nipLate, convLate: convLate),
            const SizedBox(height: 16),
            const _MarketHealth(),
          ],
        );
      },
    );
  }
}

class _QueueCardData {
  const _QueueCardData(this.id, this.icon, this.label, this.count, this.overdue, this.oldest, this.onTap);
  final String id;
  final IconData icon;
  final String label;
  final int count;
  final int overdue;
  final DateTime? oldest;
  final VoidCallback onTap;
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.data, required this.compact});
  final _QueueCardData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final age = data.oldest == null ? null : TGClock.now().difference(data.oldest!);
    final ageText = age == null ? null : (age.inHours >= 48 ? '${age.inDays} d' : '${age.inHours} h');
    return Semantics(
      button: true,
      label: '${data.label}: ${data.count}${data.overdue > 0 ? ', ${context.t('adm_sla_overdue_n', {'n': '${data.overdue}'})}' : ''}',
      excludeSemantics: true,
      child: Material(
        color: TGColors.surface,
        borderRadius: BorderRadius.circular(TGRadius.card),
        child: InkWell(
          key: Key('adm-today-card-${data.id}'),
          borderRadius: BorderRadius.circular(TGRadius.card),
          onTap: data.onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 76 : 96),
            padding: EdgeInsets.all(compact ? 10 : 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TGRadius.card),
              border: Border.all(color: data.overdue > 0 ? TGColors.error : TGColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(data.icon, size: 16, color: TGColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(data.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.labelMedium.override(fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 6),
                Text('${data.count}', key: Key('adm-today-count-${data.id}'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                if (data.overdue > 0)
                  Text(context.t('adm_sla_overdue_n', {'n': '${data.overdue}'}), style: theme.bodySmall.override(color: TGColors.error, fontWeight: FontWeight.w800))
                else if (ageText != null && !compact)
                  Text(context.t('adm_oldest', {'age': ageText}), style: theme.bodySmall.override(color: theme.secondaryText)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlaPanel extends StatelessWidget {
  const _SlaPanel({required this.cases, required this.nipLate, required this.convLate});
  final List<TGQueueCase> cases;
  final List<TGCompanyApplication> nipLate;
  final List<TGConversationReport> convLate;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final rows = <(String, String, VoidCallback)>[
      for (final c in cases) (c.listingNo, context.t('adm_sla_case', {'due': _fmt(c.slaDeadline)}), () => TGAdminNav.openCase(context, c.listingNo)),
      for (final a in nipLate) (a.id, context.t('adm_sla_nip', {'h': '${_nipSla.inHours}'}), () => context.go(TGAdminNav.nip)),
      for (final r in convLate) (r.id, context.t('adm_sla_conv', {'h': '${_convSla.inHours}'}), () => context.go(TGAdminNav.conversations)),
    ];
    return AdminCard(
      key: const Key('adm-today-sla'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(context.t('adm_sla_title', {'n': '${rows.length}'}), style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            Text(context.t('adm_sla_none'), style: theme.bodySmall.override(color: theme.secondaryText))
          else
            for (final (id, label, onTap) in rows.take(8))
              ListTile(
                key: Key('adm-sla-$id'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_off_outlined, color: TGColors.error, size: 18),
                title: Text(id, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                subtitle: Text(label, style: const TextStyle(fontSize: 12)),
                onTap: onTap,
              ),
        ],
      ),
    );
  }
}

/// Market health from current ledger / profile data only.
class _MarketHealth extends StatelessWidget {
  const _MarketHealth();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final now = TGClock.now();
    final week = now.subtract(const Duration(days: 7));
    final pays = TGBillingService.instance.allPayments();
    final last7 = pays.where((p) => p.createdAt.isAfter(week)).toList();
    final ok7 = last7.where((p) => p.status == TGPaymentStatus.succeeded).toList();
    final failed7 = last7.where((p) => p.status == TGPaymentStatus.failed).length;
    final refunded = pays.where((p) => TGBillingService.instance.refundedPln(p.id) > 0).length;
    final stores = TGSellerProfileService.instance.all.where((p) => p.isStore && p.isLive).toList();
    final verified = stores.where((p) => p.nipVerifiedAt != null && p.plan != null).length;
    final metrics = [
      ('payments', context.t('adm_health_payments'), '${ok7.length} · ${tgPln(ok7.fold<double>(0, (s, p) => s + p.grossPln))}'),
      ('failed', context.t('adm_health_failed'), '$failed7'),
      ('refunded', context.t('adm_health_refunded'), '$refunded / ${pays.length}'),
      ('stores', context.t('adm_health_stores'), '$verified / ${stores.length}'),
      ('production', context.t('adm_health_mode'),
          context.t(TGRevenueConfigService.instance.productionMode ? 'adm_mode_production' : 'adm_mode_demo')),
    ];
    return AdminCard(
      key: const Key('adm-today-health'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(context.t('adm_health_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
          const SizedBox(height: 2),
          Text(context.t('adm_health_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 8),
          for (final (id, label, value) in metrics)
            Padding(
              key: Key('adm-health-$id'),
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text(label, style: theme.bodyMedium)),
                Text(value, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
              ]),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Users
// =============================================================================

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, this.query});
  final String? query;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late final _q = TextEditingController(text: widget.query ?? '');

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = TGAdminConsoleService.instance;
    return ListenableBuilder(
      listenable: _consoleListenable,
      builder: (context, _) {
        final list = svc.searchUsers(_q.text);
        return ListView(
          key: const Key('adm-users'),
          padding: const EdgeInsets.all(16),
          children: [
            _title(context, context.t('adm_nav_users')),
            TextField(
              key: const Key('adm-users-search'),
              controller: _q,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.t('adm_users_search')),
            ),
            const SizedBox(height: 4),
            Text(context.t('adm_users_search_note'), style: FlutterFlowTheme.of(context).bodySmall.override(color: TGColors.textSecondary)),
            const SizedBox(height: 12),
            if (list.isEmpty) Text(context.t('adm_users_empty'), key: const Key('adm-users-empty')),
            for (final u in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AdminCard(
                  child: InkWell(
                    key: Key('adm-user-${u.id}'),
                    onTap: () => context.go(TGAdminNav.userPath(u.id)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text(u.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                          DashPill(label: context.t('adm_kind_${u.kind.name}'), color: TGColors.textSecondary),
                          if (u.status != TGAdminUserStatus.active)
                            DashPill(label: context.t('adm_status_${u.status.name}'), color: TGColors.error),
                        ]),
                        const SizedBox(height: 4),
                        Text(svc.display(context.read<FakeAuthState>(), u.id, TGPiiField.email, u.email), style: const TextStyle(fontSize: 12)),
                        Text(svc.display(context.read<FakeAuthState>(), u.id, TGPiiField.phone, u.phone), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AdminUser360Page extends StatelessWidget {
  const AdminUser360Page({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGAdminConsoleService.instance;
    return ListenableBuilder(
      listenable: _consoleListenable,
      builder: (context, _) {
        final u = svc.userById(userId);
        if (u == null) {
          return Center(child: Text(context.t('adm_user_not_found'), key: const Key('adm-user-missing')));
        }
        final m = svc.metricsFor(u);
        final pays = TGBillingService.instance.paymentsFor(u.id);
        final log = svc.audit.where((e) => e.targetId == u.id).toList();
        final ver = TGVerificationService.instance.companyFor(u.id);
        return ListView(
          key: const Key('adm-user360'),
          padding: const EdgeInsets.all(16),
          children: [
            TextButton.icon(onPressed: () => context.go(TGAdminNav.users), icon: const Icon(Icons.arrow_back, size: 16), label: Text(context.t('adm_nav_users'))),
            _title(context, u.name),
            Wrap(spacing: 8, runSpacing: 6, children: [
              DashPill(label: context.t('adm_kind_${u.kind.name}'), color: TGColors.textSecondary),
              DashPill(label: context.t('adm_status_${u.status.name}'), color: u.status == TGAdminUserStatus.active ? theme.success : TGColors.error),
              DashPill(label: context.t('adm_member_since', {'date': DateFormat('d MMM y').format(u.createdAt)}), color: TGColors.textSecondary),
            ]),
            const SizedBox(height: 12),
            AdminCard(
              key: const Key('adm-user-contact'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(context.t('adm_contact'), style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
                  const SizedBox(height: 6),
                  AdminMaskedValue(userId: u.id, field: TGPiiField.email, value: u.email),
                  AdminMaskedValue(userId: u.id, field: TGPiiField.phone, value: u.phone),
                  const SizedBox(height: 6),
                  Text(context.t('adm_mask_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AdminCard(
              key: const Key('adm-user-metrics'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text(context.t('adm_360_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
                  const SizedBox(height: 6),
                  Text('NIP: ${u.nip ?? '—'} · ${context.t('adm_ver_${m.verification}')}${ver == null ? '' : ' (${ver.registry.register})'}'),
                  Text(context.t('adm_360_payments', {'n': '${m.payments}', 'sum': tgPln(m.grossPln)}), key: const Key('adm-360-payments')),
                  Text(context.t('adm_360_refunds', {'n': '${m.refunds}'})),
                  Text(context.t('adm_360_reports', {'n': '${m.reportsAgainst}'})),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (pays.isNotEmpty)
              AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.t('adm_payments_recent'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
                    for (final p in pays.take(5))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.description, style: const TextStyle(fontSize: 13)),
                        subtitle: Text('${_fmt(p.createdAt)} · ${p.status.name}'),
                        trailing: Text(tgPln(p.grossPln), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            AdminCard(
              key: const Key('adm-reveal-log'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.t('adm_access_log'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  if (log.isEmpty) Text(context.t('adm_access_log_empty'), style: theme.bodySmall.override(color: theme.secondaryText)),
                  for (final e in log)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text('${_fmt(e.at)} · ${e.actorId} (${e.actorRole}) · ${e.action}${e.details['field'] == null ? '' : ' ${e.details['field']}'} — ${e.reason ?? ''}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              key: const Key('adm-no-impersonation'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(TGRadius.card), border: Border.all(color: TGColors.border)),
              child: Row(children: [
                Icon(Icons.no_accounts_outlined, size: 18, color: TGColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(context.t('adm_no_impersonation'), style: theme.bodySmall)),
              ]),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Payments & refunds (admin only)
// =============================================================================

class AdminPaymentsPage extends StatelessWidget {
  const AdminPaymentsPage({super.key});

  Future<void> _refund(BuildContext context, TGPayment p, {TGRefundRequest? req}) async {
    final auth = context.read<FakeAuthState>();
    final left = p.grossPln - TGBillingService.instance.refundedPln(p.id);
    final amount = TextEditingController(text: (req?.amountPln ?? left).toStringAsFixed(2));
    final reason = TextEditingController(text: req?.reason ?? '');
    String? error;
    await showAdminDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AdminDialogScaffold(
          key: const Key('adm-refund-dialog'),
          title: ctx.t('adm_refund_title'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${p.description} · ${p.id}', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(ctx.t('adm_refund_left', {'amount': tgPln(left), 'gross': tgPln(p.grossPln)})),
              const SizedBox(height: 10),
              TextField(
                key: const Key('adm-refund-amount'),
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: ctx.t('adm_refund_amount'), suffixText: 'PLN'),
              ),
              const SizedBox(height: 8),
              TextField(key: const Key('adm-refund-reason'), controller: reason, maxLines: 2, decoration: InputDecoration(labelText: ctx.t('adm_reason'))),
              const SizedBox(height: 6),
              Text(ctx.t('adm_refund_note'), style: FlutterFlowTheme.of(ctx).bodySmall.override(color: TGColors.textSecondary)),
              if (error != null) Text(ctx.t(error!), key: const Key('adm-refund-error'), style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w700)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('ui_cancel'))),
            FilledButton(
              key: const Key('adm-refund-confirm'),
              style: _cta,
              onPressed: () {
                final v = num.tryParse(amount.text.replaceAll(',', '.').trim()) ?? 0;
                final err = TGAdminConsoleService.instance.refund(actor: auth, paymentId: p.id, amountPln: v, reason: reason.text, requestId: req?.id);
                if (err != null) {
                  setState(() => error = err);
                  return;
                }
                Navigator.pop(ctx);
                showTGToast(context, context.t('adm_refund_done'));
              },
              child: Text(ctx.t('adm_refund_confirm')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final svc = TGAdminConsoleService.instance;
    final billing = TGBillingService.instance;
    return ListenableBuilder(
      listenable: _consoleListenable,
      builder: (context, _) {
        final reqs = svc.refunds();
        final pays = billing.allPayments();
        return ListView(
          key: const Key('adm-payments'),
          padding: const EdgeInsets.all(16),
          children: [
            _title(context, context.t('adm_nav_payments')),
            Text(context.t('adm_payments_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
            const SizedBox(height: 12),
            Semantics(header: true, child: Text(context.t('adm_refund_requests', {'n': '${svc.pendingRefunds}'}), style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
            const SizedBox(height: 6),
            if (reqs.isEmpty) Text(context.t('adm_refund_none')),
            for (final r in reqs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AdminCard(
                  key: Key('adm-refund-${r.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text('${r.id} · ${tgPln(r.amountPln)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                        DashPill(
                          label: context.t('adm_refund_${r.status.name}'),
                          color: switch (r.status) {
                            TGRefundStatus.pending => TGColors.slaAmber,
                            TGRefundStatus.approved => theme.success,
                            TGRefundStatus.rejected => TGColors.error,
                          },
                        ),
                      ]),
                      Text('${r.userId} · ${r.paymentId} · ${_fmt(r.requestedAt)}', style: const TextStyle(fontSize: 12)),
                      Text(r.reason, style: const TextStyle(fontSize: 13)),
                      if (r.decisionNote != null) Text('→ ${r.decisionNote}', style: TextStyle(fontSize: 12, color: TGColors.textSecondary)),
                      if (r.status == TGRefundStatus.pending) ...[
                        const SizedBox(height: 6),
                        Wrap(spacing: 8, children: [
                          FilledButton(
                            key: Key('adm-refund-approve-${r.id}'),
                            style: _cta,
                            onPressed: () {
                              final p = billing.paymentById(r.paymentId);
                              if (p != null) _refund(context, p, req: r);
                            },
                            child: Text(context.t('adm_refund_approve')),
                          ),
                          OutlinedButton(
                            key: Key('adm-refund-reject-${r.id}'),
                            onPressed: () async {
                              final note = await showAdminReasonDialog(context,
                                  title: context.t('adm_refund_reject'), body: context.t('adm_refund_reject_body'), confirmLabel: context.t('adm_refund_reject'), danger: true);
                              if (note == null || !context.mounted) return;
                              final err = svc.rejectRefund(actor: auth, requestId: r.id, note: note);
                              if (err != null) showTGToast(context, context.t(err));
                            },
                            child: Text(context.t('adm_refund_reject')),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Semantics(header: true, child: Text(context.t('adm_payments_all'), style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
            for (final p in pays.take(40))
              ListTile(
                key: Key('adm-pay-${p.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${p.description} · ${p.userId}', style: const TextStyle(fontSize: 13)),
                subtitle: Text('${_fmt(p.createdAt)} · ${p.status.name}${billing.refundedPln(p.id) > 0 ? ' · −${tgPln(billing.refundedPln(p.id))}' : ''}'),
                trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                  Text(tgPln(p.grossPln), style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (p.status == TGPaymentStatus.succeeded)
                    IconButton(
                      key: Key('adm-pay-refund-${p.id}'),
                      tooltip: context.t('adm_refund_title'),
                      icon: const Icon(Icons.undo, size: 18),
                      onPressed: () => _refund(context, p),
                    ),
                ]),
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Conversation reports
// =============================================================================

class AdminConversationsPage extends StatelessWidget {
  const AdminConversationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final svc = TGAdminConsoleService.instance;
    return ListenableBuilder(
      listenable: _consoleListenable,
      builder: (context, _) {
        final reports = svc.conversationReports();
        return ListView(
          key: const Key('adm-conversations'),
          padding: const EdgeInsets.all(16),
          children: [
            _title(context, context.t('adm_nav_conversations')),
            Text(context.t('adm_conv_privacy'), key: const Key('adm-conv-privacy'), style: theme.bodySmall.override(color: TGColors.slaAmber)),
            const SizedBox(height: 12),
            if (reports.isEmpty) Text(context.t('adm_conv_none')),
            for (final r in reports) _ConvReportCard(report: r, auth: auth),
          ],
        );
      },
    );
  }
}

class _ConvReportCard extends StatelessWidget {
  const _ConvReportCard({required this.report, required this.auth});
  final TGConversationReport report;
  final FakeAuthState auth;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGAdminConsoleService.instance;
    final thread = svc.openedThread(auth, report.id);
    final open = report.status == TGConvReportStatus.open;
    Future<void> decide(bool actioned) async {
      final note = await showAdminReasonDialog(context,
          title: context.t(actioned ? 'adm_conv_action' : 'adm_conv_dismiss'),
          body: context.t('adm_conv_decide_body'),
          confirmLabel: context.t(actioned ? 'adm_conv_action' : 'adm_conv_dismiss'),
          keyPrefix: 'adm-conv-decide');
      if (note == null || !context.mounted) return;
      final err = svc.decideConversation(actor: auth, reportId: report.id, actioned: actioned, note: note);
      if (err != null) showTGToast(context, context.t(err));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AdminCard(
        key: Key('adm-conv-${report.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(report.id, style: const TextStyle(fontWeight: FontWeight.w900)),
              DashPill(label: context.t('adm_conv_reason_${report.reason}'), color: TGColors.error),
              DashPill(label: context.t('adm_conv_status_${report.status.name}'), color: open ? TGColors.slaAmber : TGColors.textSecondary),
            ]),
            const SizedBox(height: 4),
            Text(context.t('adm_conv_parties', {'reporter': report.reporterId, 'reported': report.reportedUserId, 'date': _fmt(report.createdAt)}),
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text(context.t('adm_conv_excerpt'), style: theme.labelMedium.override(fontWeight: FontWeight.w800)),
            Container(
              key: Key('adm-conv-excerpt-${report.id}'),
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: TGColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: TGColors.error.withValues(alpha: 0.5))),
              child: Text('“${report.reported.text}”', style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 8),
            if (thread == null)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: Key('adm-conv-open-${report.id}'),
                  icon: const Icon(Icons.lock_open, size: 16),
                  onPressed: () async {
                    final reason = await showAdminReasonDialog(context,
                        title: context.t('adm_conv_open'), body: context.t('adm_conv_open_body'), confirmLabel: context.t('adm_conv_open'), keyPrefix: 'adm-conv-open');
                    if (reason == null || !context.mounted) return;
                    final err = svc.openFullConversation(actor: auth, reportId: report.id, reason: reason);
                    if (err != null) showTGToast(context, context.t(err));
                  },
                  label: Text(context.t('adm_conv_open')),
                ),
              )
            else
              Container(
                key: Key('adm-conv-thread-${report.id}'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: TGColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('adm_conv_opened_note'), style: theme.bodySmall.override(color: TGColors.slaAmber)),
                    for (final m in thread)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${m.fromId} · ${_fmt(m.at)}\n${m.text}', style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
            if (open) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                FilledButton(key: Key('adm-conv-action-${report.id}'), style: _cta, onPressed: () => decide(true), child: Text(context.t('adm_conv_action'))),
                OutlinedButton(key: Key('adm-conv-dismiss-${report.id}'), onPressed: () => decide(false), child: Text(context.t('adm_conv_dismiss'))),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// NIP verification queue
// =============================================================================

class AdminNipQueuePage extends StatelessWidget {
  const AdminNipQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final svc = TGVerificationService.instance;
    return ListenableBuilder(
      listenable: _consoleListenable,
      builder: (context, _) {
        final q = svc.queue();
        final now = TGClock.now();
        return ListView(
          key: const Key('adm-nip'),
          padding: const EdgeInsets.all(16),
          children: [
            _title(context, context.t('adm_nav_nip')),
            Text(context.t('adm_nip_note', {'h': '${_nipSla.inHours}'}), style: theme.bodySmall.override(color: theme.secondaryText)),
            const SizedBox(height: 12),
            if (q.isEmpty) Text(context.t('adm_nip_none'), key: const Key('adm-nip-empty')),
            for (final a in q)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AdminCard(
                  key: Key('adm-nip-${a.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text('${a.registry.name} · NIP ${a.nip}', style: const TextStyle(fontWeight: FontWeight.w900)),
                        if (now.difference(a.submittedAt) > _nipSla) DashPill(label: context.t('adm_sla_overdue'), color: TGColors.error),
                      ]),
                      Text('${a.userId} · ${_fmt(a.submittedAt)}', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('${a.registry.register} · ${a.registry.address}', style: const TextStyle(fontSize: 12)),
                      Text(context.t(a.registry.active ? 'vc_registry_active' : 'vc_registry_inactive', {'register': a.registry.register}),
                          style: TextStyle(fontSize: 12, color: a.registry.active ? theme.success : TGColors.error, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(context.t('adm_nip_rep', {'name': a.representativeName}), style: const TextStyle(fontSize: 13)),
                      Text(
                        context.t(a.representativeListed ? 'adm_nip_rep_listed' : 'adm_nip_rep_not_listed'),
                        key: Key('adm-nip-rep-${a.id}'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: a.representativeListed ? theme.success : TGColors.slaAmber),
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        FilledButton(
                          key: Key('adm-nip-approve-${a.id}'),
                          style: _cta,
                          onPressed: () {
                            final err = svc.decide(a.id, actor: auth, approve: true);
                            if (err != null) showTGToast(context, context.t(err));
                          },
                          child: Text(context.t('adm_nip_approve')),
                        ),
                        OutlinedButton(
                          key: Key('adm-nip-reject-${a.id}'),
                          onPressed: () async {
                            final note = await showAdminReasonDialog(context,
                                title: context.t('adm_nip_reject'), body: context.t('adm_nip_reject_body'), confirmLabel: context.t('adm_nip_reject'), danger: true);
                            if (note == null || !context.mounted) return;
                            final err = svc.decide(a.id, actor: auth, approve: false, note: note);
                            if (err != null) showTGToast(context, context.t(err));
                          },
                          child: Text(context.t('adm_nip_reject')),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Go-live (admin only)
// =============================================================================

class AdminGoLivePage extends StatelessWidget {
  const AdminGoLivePage({super.key});

  Future<void> _switch(BuildContext context) async {
    final auth = context.read<FakeAuthState>();
    final svc = TGAdminConsoleService.instance;
    final reason = TextEditingController();
    String? error;
    await showAdminDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        final blockers = svc.goLiveBlockers();
        return AdminDialogScaffold(
          key: const Key('adm-golive-modal'),
          title: ctx.t('adm_golive_switch'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.t('adm_golive_modal_body')),
              const SizedBox(height: 8),
              if (blockers.isNotEmpty) ...[
                Text(ctx.t('adm_golive_blockers', {'n': '${blockers.length}'}),
                    key: const Key('adm-golive-blockers'), style: const TextStyle(color: TGColors.error, fontWeight: FontWeight.w800)),
                for (final b in blockers) Text('• ${_blockerLabel(ctx, b)}', key: Key('adm-golive-blocker-$b'), style: const TextStyle(fontSize: 12)),
              ] else ...[
                TextField(
                  key: const Key('adm-golive-reason'),
                  controller: reason,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: ctx.t('adm_reason')),
                ),
                const SizedBox(height: 6),
                Text(ctx.t('adm_golive_effects'), style: FlutterFlowTheme.of(ctx).bodySmall.override(color: TGColors.slaAmber)),
              ],
              if (error != null) Text(ctx.t(error!), key: const Key('adm-golive-error'), style: const TextStyle(color: TGColors.error)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('ui_cancel'))),
            FilledButton(
              key: const Key('adm-golive-confirm'),
              style: FilledButton.styleFrom(backgroundColor: TGColors.error, foregroundColor: Colors.white),
              onPressed: blockers.isNotEmpty || reason.text.trim().length < TGAdminConsoleService.minReasonLength
                  ? null
                  : () {
                      final err = svc.switchToProduction(actor: auth, reason: reason.text);
                      if (err != null) {
                        setState(() => error = err);
                        return;
                      }
                      Navigator.pop(ctx);
                      showTGToast(context, context.t('adm_golive_done'));
                    },
              child: Text(ctx.t('adm_golive_switch')),
            ),
          ],
        );
      }),
    );
  }

  static String _blockerLabel(BuildContext context, String id) {
    if (id.startsWith('manual_')) return context.t('adm_golive_manual_${id.substring(7)}');
    final c = TGAdminConsoleService.instance.autoChecks().where((c) => c.id == id).firstOrNull;
    return c == null ? id : context.t(c.labelKey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final svc = TGAdminConsoleService.instance;
    return ListenableBuilder(
      listenable: _consoleListenable,
      builder: (context, _) {
        final live = TGRevenueConfigService.instance.productionMode;
        final auto = svc.autoChecks();
        final manual = svc.manualChecks();
        final blockers = svc.goLiveBlockers();
        Widget mark(bool ok, bool blocking) => Icon(
              ok ? Icons.check_circle : (blocking ? Icons.cancel : Icons.info_outline),
              size: 18,
              color: ok ? theme.success : (blocking ? TGColors.error : TGColors.slaAmber),
            );
        return ListView(
          key: const Key('adm-golive'),
          padding: const EdgeInsets.all(16),
          children: [
            _title(context, context.t('adm_nav_golive')),
            Container(
              key: Key(live ? 'adm-golive-live' : 'adm-golive-demo'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TGRadius.card),
                border: Border.all(color: live ? theme.success : TGColors.slaAmber),
              ),
              child: Text(context.t(live ? 'adm_golive_is_live' : 'adm_golive_is_demo'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 12),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(header: true, child: Text(context.t('adm_golive_auto'), style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
                  for (final c in auto)
                    Semantics(
                      container: true,
                      label: '${context.t(c.ok ? 'ver_met' : 'ver_not_met')}: ${context.t(c.labelKey)}',
                      excludeSemantics: true,
                      child: Padding(
                        key: Key('adm-golive-auto-${c.id}'),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          mark(c.ok, c.blocking),
                          const SizedBox(width: 8),
                          Expanded(child: Text(context.t(c.labelKey), style: const TextStyle(fontSize: 13))),
                          if (!c.blocking) Text(context.t('adm_golive_advisory'), style: TextStyle(fontSize: 11, color: TGColors.textSecondary)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(header: true, child: Text(context.t('adm_golive_manual'), style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
                  for (final m in manual)
                    CheckboxListTile(
                      key: Key('adm-golive-manual-${m.id}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: m.done,
                      onChanged: auth.isAdmin && !live ? (v) => svc.setManual(actor: auth, id: m.id, done: v ?? false) : null,
                      title: Text(context.t(m.labelKey), style: const TextStyle(fontSize: 13)),
                      subtitle: m.done ? Text('${m.doneBy} · ${_fmt(m.doneAt!)}', style: const TextStyle(fontSize: 11)) : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!live)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const Key('adm-golive-switch'),
                  style: FilledButton.styleFrom(backgroundColor: blockers.isEmpty ? TGColors.error : TGColors.surfaceHover, foregroundColor: Colors.white),
                  onPressed: () => _switch(context),
                  icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                  label: Text(context.t('adm_golive_switch')),
                ),
              ),
            if (!live && blockers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(context.t('adm_golive_blockers', {'n': '${blockers.length}'}), style: const TextStyle(color: TGColors.error, fontSize: 12)),
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Audit log (append-only)
// =============================================================================

class AdminAuditLogPage extends StatelessWidget {
  const AdminAuditLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    context.watch<ModerationService>();
    final svc = TGAdminConsoleService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final rows = svc.unifiedAudit();
        return Column(
          key: const Key('adm-audit'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: _title(
                context,
                context.t('ui_admin_audit'),
                trailing: auth.isAdmin
                    ? OutlinedButton.icon(
                        key: const Key('adm-audit-csv'),
                        onPressed: () {
                          final csv = svc.exportAuditCsv(auth);
                          if (csv == null) return;
                          showDashTextExport(context, title: context.t('adm_audit_csv'), fileName: 'audit-${DateFormat('yyyyMMdd').format(TGClock.now())}.csv', content: csv);
                        },
                        icon: const Icon(Icons.table_view_outlined, size: 16),
                        label: Text(context.t('adm_audit_csv')),
                      )
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(context.t('adm_audit_append_only'), key: const Key('adm-audit-append-only'), style: theme.bodySmall.override(color: theme.secondaryText)),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Center(child: Text(context.t('ui_no_audit')))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final e = rows[i];
                        return ListTile(
                          key: Key('adm-audit-row-$i'),
                          dense: true,
                          title: Text('${e.action} · ${e.target}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text('${e.actor} · ${e.role} · ${_fmt(e.at)}${e.reason.isEmpty ? '' : ' · ${e.reason}'}${e.details.isEmpty ? '' : '\n${e.details}'}'),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Hosts
// =============================================================================

class AdminTodayHost extends StatelessWidget {
  const AdminTodayHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'today', child: AdminTodayPage());
}

class AdminUsersHost extends StatelessWidget {
  const AdminUsersHost({super.key, this.query});
  final String? query;
  @override
  Widget build(BuildContext context) => AdminShell(section: 'users', child: AdminUsersPage(query: query));
}

class AdminUser360Host extends StatelessWidget {
  const AdminUser360Host({super.key, required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context) => AdminShell(section: 'users', child: AdminUser360Page(userId: userId));
}

class AdminPaymentsHost extends StatelessWidget {
  const AdminPaymentsHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'payments', child: AdminPaymentsPage());
}

class AdminConversationsHost extends StatelessWidget {
  const AdminConversationsHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'conversations', child: AdminConversationsPage());
}

class AdminNipHost extends StatelessWidget {
  const AdminNipHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'nip', child: AdminNipQueuePage());
}

class AdminGoLiveHost extends StatelessWidget {
  const AdminGoLiveHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'golive', child: AdminGoLivePage());
}
