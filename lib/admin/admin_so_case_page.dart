import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/admin/admin_so_modals.dart';
import 'package:twoja_gastromania/admin/admin_so_queue_page.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/special_order/so_status_chip.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

class AdminSoCasePage extends StatefulWidget {
  const AdminSoCasePage({super.key, required this.requestNo});
  final String requestNo;

  @override
  State<AdminSoCasePage> createState() => _AdminSoCasePageState();
}

class _AdminSoCasePageState extends State<AdminSoCasePage> {
  @override
  void initState() {
    super.initState();
    TGSpecialOrderService.instance.ensureSeeded();
    TGAnalytics.track('so_admin_open', {'requestNo': widget.requestNo});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final svc = TGSpecialOrderService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final request = svc.byRequestNo(widget.requestNo);
        if (request == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('404', style: FlutterFlowTheme.of(context).headlineMedium.override(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(context.t('ui_so_admin_not_found')),
                const SizedBox(height: 12),
                TGButton(onPressed: () => TGAdminNav.soQueue(context), label: context.t('ui_back'), height: 40),
              ],
            ),
          );
        }
        final w = MediaQuery.sizeOf(context).width;
        final twoCol = w >= TGBreakpoints.desktop;
        final phone = w < TGBreakpoints.phone;
        final left = _LeftPane(request: request);
        final right = _RightPane(request: request, isAdmin: auth.isAdmin);
        if (phone) {
          return Column(
            children: [
              Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [left, const SizedBox(height: 16), right])),
              _MobileActionBar(request: request, isAdmin: auth.isAdmin),
            ],
          );
        }
        if (!twoCol) {
          return ListView(padding: const EdgeInsets.all(16), children: [left, const SizedBox(height: 16), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 845),
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 8, 24), children: [left]),
                ),
              ),
            ),
            SizedBox(
              width: 411,
              child: ListView(padding: const EdgeInsets.fromLTRB(8, 16, 16, 24), children: [right]),
            ),
          ],
        );
      },
    );
  }
}

class _LeftPane extends StatelessWidget {
  const _LeftPane({required this.request});
  final TGSpecialRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGSpecialOrderService.instance;
    final quotes = svc.quotesFor(request.id);
    final audit = svc.auditFor(request.id);
    final sla = svc.slaFor(request);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(request.requestNo, style: theme.titleLarge.override(fontWeight: FontWeight.w900))),
            SoAdminSlaChip(tone: sla.$1, label: sla.$2),
            const SizedBox(width: 8),
            SoStatusChip(status: request.status, quoteCount: quotes.length, rejectReason: request.rejectReason),
          ],
        ),
        const SizedBox(height: 8),
        Text(request.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 8),
        Text(request.description, style: const TextStyle(height: 1.45)),
        const SizedBox(height: 8),
        Text('${request.city}, ${request.voivodeship} · ${request.material} · ${request.deadline.name}'),
        const SizedBox(height: 16),
        Text(context.t('ui_so_step_files'), style: const TextStyle(fontWeight: FontWeight.w900)),
        for (final f in request.files)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: Text(f.name),
            onTap: () {
              final auth = context.read<FakeAuthState>();
              svc.logFileView(request.id, f.id, actorId: auth.userId);
              showTGToast(context, context.t('ui_so_download_mock'));
            },
          ),
        if (request.files.isEmpty) Text(context.t('ui_so_no_files'), style: theme.bodySmall),
        const SizedBox(height: 16),
        Text(context.t('ui_timeline'), style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        for (var i = 0; i < audit.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: TGMotion.of(context, Duration(milliseconds: 40 * (i + 1))),
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${audit[i].at.toIso8601String().substring(0, 16)} · ${audit[i].actorId} · ${audit[i].action}${audit[i].reason == null ? '' : ' — ${audit[i].reason}'}',
                style: theme.bodySmall.override(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (audit.isEmpty) Text(context.t('ui_so_admin_no_audit'), style: theme.bodySmall),
        const SizedBox(height: 16),
        Text(context.t('ui_so_quotes'), style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (quotes.isEmpty)
          Text(context.t('ui_so_no_quotes_yet'))
        else
          for (final q in quotes)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: TGColors.border), borderRadius: BorderRadius.circular(10)),
              child: Text(
                '${TGSellerProfileService.instance.bySellerKey(q.sellerId)?.name ?? q.sellerId}: ${q.priceNet} PLN netto · ${q.leadTimeWeeks}w · ${q.status.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
      ],
    );
  }
}

class _RightPane extends StatelessWidget {
  const _RightPane({required this.request, required this.isAdmin});
  final TGSpecialRequest request;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGSpecialOrderService.instance;
    final age = request.buyerAccountAgeDays(TGClock.now());
    final flags = svc.spamFlagsFor(request);
    final access = svc.accessFor(request.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('ui_buyer'), style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(request.buyerName, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(request.email),
              Text(request.phone, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(context.t('ui_so_admin_account_age', {'n': '$age'})),
              Text(request.phoneVerified ? context.t('ui_verified') : context.t('ui_so_admin_phone_unverified')),
              Text(context.t('ui_so_admin_buyer_requests', {'n': '${svc.forBuyer(request.buyerId).length}'})),
              if (flags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('${context.t('ui_flags')}: ${flags.join(', ')}', style: theme.bodySmall.override(color: TGColors.slaAmber, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('ui_so_admin_routing'), style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              for (final a in access)
                Text(
                  '${TGSellerProfileService.instance.bySellerKey(a.sellerId)?.name ?? a.sellerId} · ${a.via.name}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              if (access.isEmpty) Text(context.t('ui_so_admin_no_access'), style: theme.bodySmall),
              const SizedBox(height: 8),
              TGButton(onPressed: () => showSoMatchModal(context, request), label: context.t('ui_so_admin_match'), height: 40),
            ],
          ),
        ),
        if (request.reportedAt != null) ...[
          const SizedBox(height: 12),
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('ui_so_admin_reported'), style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(request.reportReason ?? '', style: const TextStyle(height: 1.35)),
                Text('${context.t('ui_reporter')}: ${TGSellerProfileService.instance.bySellerKey(request.reporterSellerId ?? '')?.name ?? request.reporterSellerId}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TGButton(
                      onPressed: () {
                        final auth = context.read<FakeAuthState>();
                        svc.dismissReport(request.id, actorId: auth.userId, actorRole: auth.role.name);
                      },
                      label: context.t('ui_dismiss'),
                      height: 36,
                      variant: TGButtonVariant.outline,
                    ),
                    TGButton(onPressed: () => showSoRejectModal(context, request), label: context.t('ui_so_admin_reject'), height: 36),
                    TGButton(
                      onPressed: () {
                        final auth = context.read<FakeAuthState>();
                        svc.contactReporter(request.id, actorId: auth.userId, actorRole: auth.role.name);
                      },
                      label: context.t('ui_so_admin_contact_reporter'),
                      height: 36,
                      variant: TGButtonVariant.ghost,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _Actions(request: request, isAdmin: isAdmin, dense: false),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.request, required this.isAdmin, required this.dense});
  final TGSpecialRequest request;
  final bool isAdmin;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<FakeAuthState>();
    final svc = TGSpecialOrderService.instance;
    final buttons = <Widget>[
      if (request.status == TGSpecialRequestStatus.held)
        TGButton(
          onPressed: () => svc.approveAndRoute(request.id, actorId: auth.userId, actorRole: auth.role.name),
          label: context.t('ui_so_admin_approve_route'),
          height: dense ? 40 : 44,
        ),
      TGButton(onPressed: () => showSoMatchModal(context, request), label: context.t('ui_so_admin_match'), height: dense ? 40 : 44, variant: TGButtonVariant.outline),
      TGButton(
        onPressed: () {
          final preview = svc.previewEmail('nudge', request);
          showAdminDialog<void>(
            context: context,
            builder: (ctx) => AdminDialogScaffold(
              title: ctx.t('ui_so_admin_nudge'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('ui_cancel'))),
                TGButton(
                  onPressed: () {
                    svc.nudgeManufacturers(request.id, actorId: auth.userId, actorRole: auth.role.name);
                    Navigator.pop(ctx);
                  },
                  label: ctx.t('ui_send'),
                  height: 40,
                ),
              ],
              child: EmailPreviewBlock(
                email: TGQueuedEmail(
                  id: 'nudge',
                  to: 'manufacturers',
                  subject: preview.subject,
                  body: preview.body,
                  templateId: 'so_nudge',
                  createdAt: TGClock.now(),
                ),
              ),
            ),
          );
        },
        label: context.t('ui_so_admin_nudge'),
        height: dense ? 40 : 44,
        variant: TGButtonVariant.ghost,
      ),
      TGButton(onPressed: () => showSoContactBuyerModal(context, request), label: context.t('ui_so_admin_contact_buyer'), height: dense ? 40 : 44, variant: TGButtonVariant.ghost),
      TGButton(onPressed: () => showSoRejectModal(context, request), label: context.t('ui_so_admin_reject'), height: dense ? 40 : 44, variant: TGButtonVariant.outline),
      TGButton(
        onPressed: () => svc.closeAdmin(request.id, actorId: auth.userId, actorRole: auth.role.name),
        label: context.t('ui_so_close_request'),
        height: dense ? 40 : 44,
        variant: TGButtonVariant.ghost,
      ),
      if (isAdmin)
        TGButton(
          onPressed: () => svc.reopenAdmin(request.id, actorId: auth.userId, actorRole: auth.role.name),
          label: context.t('ui_so_admin_reopen'),
          height: dense ? 40 : 44,
          variant: TGButtonVariant.ghost,
        ),
      if (isAdmin) TGButton(onPressed: () => showSoDeleteFilesModal(context, request), label: context.t('ui_so_admin_delete_files'), height: dense ? 40 : 44, variant: TGButtonVariant.ghost),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }
}

class _MobileActionBar extends StatelessWidget {
  const _MobileActionBar({required this.request, required this.isAdmin});
  final TGSpecialRequest request;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: TGColors.surface,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + pad),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF3A3A3A)))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _Actions(request: request, isAdmin: isAdmin, dense: true),
        ),
      ),
    );
  }
}
