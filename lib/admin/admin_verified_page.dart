import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_verified_info.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/review_verified_service.dart';

class AdminVerifiedHost extends StatelessWidget {
  const AdminVerifiedHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'verified', child: AdminVerifiedPage());
}

/// Review-based Verified: editable rules + per-seller override (reason required, audited).
class AdminVerifiedPage extends StatefulWidget {
  const AdminVerifiedPage({super.key});

  static const routeName = 'AdminVerified';
  static const routePath = '/admin/verified';

  @override
  State<AdminVerifiedPage> createState() => _AdminVerifiedPageState();
}

class _AdminVerifiedPageState extends State<AdminVerifiedPage> {
  final _svc = TGReviewVerifiedService.instance..ensureSeeded();
  late bool _enabled;
  late bool _phone;
  late final Map<String, TextEditingController> _num;

  static const _fields = [
    ('minCountedReviews', 'ver_admin_min_counted'),
    ('minDistinctBuyers', 'ver_admin_min_distinct'),
    ('maxNegativePct', 'ver_admin_max_neg'),
    ('negativeStarsMax', 'ver_admin_neg_stars'),
    ('windowMonths', 'ver_admin_window'),
    ('minAccountAgeDays', 'ver_admin_account_age'),
    ('blockedAfterUpheldReportDays', 'ver_admin_blocked'),
  ];

  @override
  void initState() {
    super.initState();
    final c = _svc.config;
    _enabled = c.enabled;
    _phone = c.requirePhoneVerified;
    _num = {
      'minCountedReviews': TextEditingController(text: '${c.minCountedReviews}'),
      'minDistinctBuyers': TextEditingController(text: '${c.minDistinctBuyers}'),
      'maxNegativePct': TextEditingController(text: '${(c.maxNegativeShare * 100).round()}'),
      'negativeStarsMax': TextEditingController(text: '${c.negativeStarsMax}'),
      'windowMonths': TextEditingController(text: '${c.windowMonths}'),
      'minAccountAgeDays': TextEditingController(text: '${c.minAccountAgeDays}'),
      'blockedAfterUpheldReportDays': TextEditingController(text: '${c.blockedAfterUpheldReportDays}'),
    };
  }

  @override
  void dispose() {
    for (final c in _num.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(String k, int fallback) => int.tryParse(_num[k]!.text.trim()) ?? fallback;

  void _save() {
    final c = _svc.config;
    _svc.setConfig(
      c.copyWith(
        enabled: _enabled,
        requirePhoneVerified: _phone,
        minCountedReviews: _int('minCountedReviews', c.minCountedReviews),
        minDistinctBuyers: _int('minDistinctBuyers', c.minDistinctBuyers),
        maxNegativeShare: _int('maxNegativePct', (c.maxNegativeShare * 100).round()).clamp(0, 100) / 100,
        negativeStarsMax: _int('negativeStarsMax', c.negativeStarsMax).clamp(1, 4),
        windowMonths: _int('windowMonths', c.windowMonths),
        minAccountAgeDays: _int('minAccountAgeDays', c.minAccountAgeDays),
        blockedAfterUpheldReportDays: _int('blockedAfterUpheldReportDays', c.blockedAfterUpheldReportDays),
      ),
      actorId: context.read<FakeAuthState>().userId,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('ui_admin_saved'))));
  }

  Future<void> _override(String sellerId, bool? verified) async {
    final title = context.t(verified == null ? 'ver_admin_clear' : (verified ? 'ver_admin_grant' : 'ver_admin_revoke'));
    final reason = await showDialog<String>(context: context, builder: (_) => _ReasonDialog(title: title));
    if (reason == null || !mounted) return;
    _svc.setOverride(sellerId, verified: verified, reason: reason, actorId: context.read<FakeAuthState>().userId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ListenableBuilder(
      listenable: _svc,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Semantics(header: true, child: Text(context.t('ver_admin_title'), style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
          const SizedBox(height: 4),
          Text(context.t('ver_not_purchasable'), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 12),
          Text(context.t('ver_admin_config'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
          SwitchListTile(
            key: const Key('ver-admin-enabled'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('ver_admin_enabled')),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('ver_admin_phone')),
            value: _phone,
            onChanged: (v) => setState(() => _phone = v),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (k, label) in _fields)
                SizedBox(
                  width: 220,
                  child: TextField(
                    key: Key('ver-admin-$k'),
                    controller: _num[k],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: context.t(label), isDense: true),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TGButton(key: const Key('ver-admin-save'), onPressed: _save, label: context.t('ver_admin_save'), height: 44),
          ),
          const SizedBox(height: 24),
          Text(context.t('ver_admin_sellers'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final id in _svc.trackedSellerIds) _row(context, theme, id),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, FlutterFlowTheme theme, String id) {
    final on = _svc.isVerified(id);
    final ov = _svc.overrideFor(id);
    final name = TGReviewVerifiedService.mockSellers.where((s) => s.id == id).firstOrNull?.name ?? id;
    return Container(
      key: Key('ver-admin-row-$id'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TGColors.surface,
        borderRadius: BorderRadius.circular(TGRadius.input),
        border: Border.all(color: on ? theme.success.withValues(alpha: 0.5) : TGColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(on ? Icons.verified_user : Icons.shield_outlined, color: on ? theme.success : theme.secondaryText, size: 18),
          Text(name, style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
          Text(tgReviewStatsLine(context, _svc.statsFor(id)), style: theme.bodySmall.override(color: theme.secondaryText)),
          if (ov != null)
            Text(context.t('ver_admin_override_badge', {'v': ov.verified ? '✓' : '—', 'reason': ov.reason}),
                style: theme.bodySmall.override(color: TGColors.slaAmber, fontWeight: FontWeight.w700)),
          TextButton(key: Key('ver-admin-grant-$id'), onPressed: () => _override(id, true), child: Text(context.t('ver_admin_grant'))),
          TextButton(key: Key('ver-admin-revoke-$id'), onPressed: () => _override(id, false), child: Text(context.t('ver_admin_revoke'))),
          if (ov != null) TextButton(key: Key('ver-admin-clear-$id'), onPressed: () => _override(id, null), child: Text(context.t('ver_admin_clear'))),
        ],
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});
  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _reason.text.trim();
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('ver-admin-reason'),
        controller: _reason,
        autofocus: true,
        maxLines: 3,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: context.t('ver_admin_reason'), hintText: context.t('ver_admin_reason_hint')),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t('ui_cancel'))),
        FilledButton(
          key: const Key('ver-admin-apply'),
          onPressed: text.isEmpty ? null : () => Navigator.of(context).pop(text),
          child: Text(context.t('ver_admin_apply')),
        ),
      ],
    );
  }
}
