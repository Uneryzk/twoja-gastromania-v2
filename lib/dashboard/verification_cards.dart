import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/dash3_widgets.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_account.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/review_verified_service.dart';
import 'package:twoja_gastromania/tg_services/verification_service.dart';

/// DASH-4 verification centre: Verified Seller shield + phone, e-mail and
/// company (NIP) cards for the signed-in account.
class VerificationCenter extends StatelessWidget {
  const VerificationCenter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final svc = TGVerificationService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ShieldCard(auth: auth),
          const SizedBox(height: 12),
          _PhoneCard(auth: auth),
          const SizedBox(height: 12),
          _EmailCard(auth: auth),
          const SizedBox(height: 12),
          _NipCard(auth: auth),
        ],
      ),
    );
  }
}

String _date(BuildContext context, DateTime d) =>
    DateFormat('d MMM y, HH:mm', FFLocalizations.of(context).languageCode).format(d);

class _CardHead extends StatelessWidget {
  const _CardHead({required this.icon, required this.title, required this.status});
  final IconData icon;
  final String title;
  final TGVerifyStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final (label, color) = switch (status) {
      TGVerifyStatus.verified => (context.t('vc_status_verified'), theme.success),
      TGVerifyStatus.pending => (context.t('vc_status_pending'), TGColors.slaAmber),
      TGVerifyStatus.rejected => (context.t('vc_status_rejected'), TGColors.error),
      TGVerifyStatus.none => (context.t('vc_status_none'), theme.secondaryText),
    };
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(icon, size: 20, color: theme.secondaryText),
        Semantics(header: true, child: Text(title, style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
        DashPill(label: label, color: color),
      ],
    );
  }
}

class _ShieldCard extends StatelessWidget {
  const _ShieldCard({required this.auth});
  final FakeAuthState auth;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGVerificationService.instance;
    final reviews = TGReviewVerifiedService.instance..ensureSeeded();
    final nip = svc.isNipVerified(auth.userId);
    final plan = auth.storePlan != null;
    final store = auth.sellerType == TGSellerType.store || plan;
    final on = store ? nip && plan : reviews.isVerified(auth.userId);
    Widget row(String key, bool ok, String label) => Semantics(
          container: true,
          label: '${context.t(ok ? 'ver_met' : 'ver_not_met')}: $label',
          excludeSemantics: true,
          child: Padding(
            key: Key(key),
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: ok ? theme.success : theme.secondaryText),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: theme.bodyMedium)),
            ]),
          ),
        );
    return DashBox(
      key: const Key('vc-shield-card'),
      borderColor: on ? theme.success : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Semantics(
              label: context.t(on ? 'vc_shield_on' : 'vc_shield_off'),
              child: Icon(
                on ? Icons.verified_user : Icons.shield_outlined,
                key: Key(on ? 'vc-shield-on' : 'vc-shield-off'),
                color: on ? theme.success : theme.secondaryText,
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(context.t(on ? 'vc_shield_on' : 'vc_shield_off'),
                  style: theme.titleMedium.override(fontWeight: FontWeight.w900, color: on ? theme.success : null)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(context.t('uyum_shield_two_ways'), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 10),
          _ShieldOption(
            key: const Key('vc-shield-opt-store'),
            title: context.t('uyum_shield_opt_store'),
            mine: store,
            children: [
              Text(context.t('vc_shield_rule'), style: theme.bodySmall.override(color: theme.secondaryText)),
              const SizedBox(height: 4),
              row('vc-shield-req-nip', nip, context.t('vc_shield_req_nip')),
              row('vc-shield-req-plan', plan, context.t('vc_shield_req_plan')),
            ],
          ),
          const SizedBox(height: 10),
          _ShieldOption(
            key: const Key('vc-shield-opt-reviews'),
            title: context.t('uyum_shield_opt_reviews'),
            mine: !store,
            children: [
              for (final r in reviews.requirements(auth.userId)) row('vc-shield-req-${r.id}', r.met, context.t(r.labelKey, r.params)),
            ],
          ),
        ],
      ),
    );
  }
}

/// One basis for the shield: stores (NIP + plan) or individuals (reviews).
class _ShieldOption extends StatelessWidget {
  const _ShieldOption({super.key, required this.title, required this.mine, required this.children});
  final String title;
  final bool mine;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: mine ? theme.primary : TGColors.border, width: mine ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                header: true,
                label: mine ? '$title. ${context.t('uyum_shield_your_path')}' : title,
                excludeSemantics: true,
                child: Text(title, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
              ),
              if (mine) ExcludeSemantics(child: DashPill(label: context.t('uyum_shield_your_path'), color: theme.primary)),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Phone
// -----------------------------------------------------------------------------

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({required this.auth});
  final FakeAuthState auth;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final s = TGVerificationService.instance.phoneOf(auth.userId);
    return DashBox(
      key: const Key('vc-phone-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHead(icon: Icons.phone_iphone, title: context.t('vc_phone_title'), status: s.verified ? TGVerifyStatus.verified : TGVerifyStatus.none),
          const SizedBox(height: 8),
          Text(s.value ?? context.t('vc_phone_empty'), key: const Key('vc-phone-value'), style: theme.bodyLarge.override(fontWeight: FontWeight.w700)),
          if (s.verifiedAt != null)
            Text(context.t('vc_verified_at', {'date': _date(context, s.verifiedAt!)}), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 4),
          Text(context.t('vc_phone_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('vc-phone-change'),
            onPressed: () => showDashSheet<void>(
              context,
              key: const Key('vc-phone-sheet'),
              title: context.t(s.value == null ? 'vc_phone_add' : 'vc_phone_change'),
              builder: (_) => _PhoneFlow(userId: auth.userId, auth: auth),
            ),
            icon: const Icon(Icons.edit, size: 18),
            label: Text(context.t(s.value == null ? 'vc_phone_add' : 'vc_phone_change')),
          ),
        ],
      ),
    );
  }
}

class _PhoneFlow extends StatefulWidget {
  const _PhoneFlow({required this.userId, required this.auth});
  final String userId;
  final FakeAuthState auth;

  @override
  State<_PhoneFlow> createState() => _PhoneFlowState();
}

class _PhoneFlowState extends State<_PhoneFlow> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _send() {
    final err = TGVerificationService.instance.startPhoneChange(widget.userId, _phone.text);
    setState(() {
      _error = err;
      _sent = err == null;
    });
  }

  void _confirm() {
    final err = TGVerificationService.instance.confirmPhone(widget.userId, _code.text, auth: widget.auth);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context);
    showTGToast(context, context.t('vc_phone_done'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final pending = TGVerificationService.instance.phoneOf(widget.userId).pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('vc-phone-input'),
          controller: _phone,
          enabled: !_sent,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: context.t('vc_phone_label'), hintText: '+48 600 000 000'),
        ),
        const SizedBox(height: 10),
        if (!_sent)
          FilledButton(
            key: const Key('vc-phone-send'),
            style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
            onPressed: _send,
            child: Text(context.t('vc_send_code')),
          )
        else ...[
          Text(context.t('vc_code_sent', {'to': pending ?? ''}), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('vc-phone-code'),
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(labelText: context.t('vc_code_label'), helperText: context.t('vc_code_demo')),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('vc-phone-confirm'),
            style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
            onPressed: _confirm,
            child: Text(context.t('vc_confirm')),
          ),
        ],
        if (_error != null) _ErrorText(_error!),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.keyName);
  final String keyName;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Semantics(
          liveRegion: true,
          child: Text(context.t(keyName),
              key: const Key('vc-error'), style: FlutterFlowTheme.of(context).bodySmall.override(color: TGColors.error, fontWeight: FontWeight.w700)),
        ),
      );
}

// -----------------------------------------------------------------------------
// E-mail
// -----------------------------------------------------------------------------

class _EmailCard extends StatelessWidget {
  const _EmailCard({required this.auth});
  final FakeAuthState auth;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGVerificationService.instance;
    final s = svc.emailOf(auth.userId, fallback: auth.mockEmail);
    return DashBox(
      key: const Key('vc-email-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHead(
            icon: Icons.alternate_email,
            title: context.t('vc_email_title'),
            status: s.verified ? TGVerifyStatus.verified : (s.pending != null ? TGVerifyStatus.pending : TGVerifyStatus.none),
          ),
          const SizedBox(height: 8),
          Text(s.value ?? '—', key: const Key('vc-email-value'), style: theme.bodyLarge.override(fontWeight: FontWeight.w700)),
          if (s.pending != null) ...[
            const SizedBox(height: 4),
            Text(context.t('vc_email_pending', {'email': s.pending!}), style: theme.bodySmall.override(color: TGColors.slaAmber)),
            const SizedBox(height: 6),
            TextButton(
              key: const Key('vc-email-open-link'),
              onPressed: () {
                svc.confirmEmail(auth.userId);
                showTGToast(context, context.t('vc_email_done'));
              },
              child: Text(context.t('vc_email_open_link')),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('vc-email-change'),
            onPressed: () => showDashSheet<void>(
              context,
              key: const Key('vc-email-sheet'),
              title: context.t('vc_email_title'),
              builder: (_) => _EmailFlow(userId: auth.userId, initial: s.verified ? '' : (s.value ?? '')),
            ),
            icon: const Icon(Icons.mark_email_read_outlined, size: 18),
            label: Text(context.t(s.verified ? 'vc_email_change' : 'vc_email_verify')),
          ),
        ],
      ),
    );
  }
}

class _EmailFlow extends StatefulWidget {
  const _EmailFlow({required this.userId, required this.initial});
  final String userId;
  final String initial;

  @override
  State<_EmailFlow> createState() => _EmailFlowState();
}

class _EmailFlowState extends State<_EmailFlow> {
  late final _email = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('vc-email-input'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: context.t('vc_email_label')),
          ),
          const SizedBox(height: 6),
          Text(context.t('vc_email_link_note'), style: FlutterFlowTheme.of(context).bodySmall.override(color: FlutterFlowTheme.of(context).secondaryText)),
          const SizedBox(height: 10),
          FilledButton(
            key: const Key('vc-email-send'),
            style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
            onPressed: () {
              final err = TGVerificationService.instance.sendEmailLink(widget.userId, _email.text);
              if (err != null) {
                setState(() => _error = err);
                return;
              }
              Navigator.pop(context);
              showTGToast(context, context.t('vc_email_sent'));
            },
            child: Text(context.t('vc_email_send')),
          ),
          if (_error != null) _ErrorText(_error!),
        ],
      );
}

// -----------------------------------------------------------------------------
// Company (NIP)
// -----------------------------------------------------------------------------

class _NipCard extends StatelessWidget {
  const _NipCard({required this.auth});
  final FakeAuthState auth;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGVerificationService.instance;
    final app = svc.companyFor(auth.userId);
    final verified = svc.isNipVerified(auth.userId);
    final status = verified ? TGVerifyStatus.verified : (app?.status ?? TGVerifyStatus.none);
    return DashBox(
      key: const Key('vc-nip-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHead(icon: Icons.business, title: context.t('vc_nip_title'), status: status),
          const SizedBox(height: 8),
          if (app != null) ...[
            Text('${app.registry.name} · NIP ${app.nip}', key: const Key('vc-nip-company'), style: theme.bodyLarge.override(fontWeight: FontWeight.w700)),
            Text(context.t('vc_submitted_at', {'date': _date(context, app.submittedAt)}), style: theme.bodySmall.override(color: theme.secondaryText)),
            if (app.status == TGVerifyStatus.pending)
              Text(context.t('vc_nip_pending_note'), style: theme.bodySmall.override(color: TGColors.slaAmber)),
            if (app.status == TGVerifyStatus.rejected && app.decisionNote != null)
              Text(context.t('vc_nip_rejected_note', {'note': app.decisionNote!}), key: const Key('vc-nip-rejected'), style: theme.bodySmall.override(color: TGColors.error)),
          ] else
            Text(context.t('vc_nip_intro'), style: theme.bodyMedium.override(color: theme.secondaryText)),
          const SizedBox(height: 10),
          if (app?.status != TGVerifyStatus.pending && !verified)
            FilledButton.icon(
              key: const Key('vc-nip-start'),
              style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
              onPressed: () => showDashSheet<void>(
                context,
                key: const Key('vc-nip-sheet'),
                title: context.t('vc_nip_title'),
                builder: (_) => _NipFlow(userId: auth.userId),
              ),
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: Text(context.t('vc_nip_start')),
            ),
        ],
      ),
    );
  }
}

class _NipFlow extends StatefulWidget {
  const _NipFlow({required this.userId});
  final String userId;

  @override
  State<_NipFlow> createState() => _NipFlowState();
}

class _NipFlowState extends State<_NipFlow> {
  final _nip = TextEditingController();
  final _rep = TextEditingController();
  TGRegistryRecord? _record;
  bool _looked = false;
  bool _confirm = false;
  String? _error;

  @override
  void dispose() {
    _nip.dispose();
    _rep.dispose();
    super.dispose();
  }

  void _lookup() {
    final d = TGVerificationService.nipDigits(_nip.text);
    if (!TGVerificationService.nipValid(d)) {
      setState(() {
        _error = 'ver_err_nip';
        _looked = false;
        _record = null;
      });
      return;
    }
    setState(() {
      _record = TGVerificationService.instance.lookupRegistry(d);
      _looked = true;
      _error = _record == null ? 'ver_err_registry_not_found' : (_record!.active ? null : 'ver_err_registry_inactive');
    });
  }

  void _submit() {
    final r = TGVerificationService.instance.submitCompany(
      userId: widget.userId,
      nip: _nip.text,
      representativeName: _rep.text,
      confirmedRepresentation: _confirm,
    );
    if (r.error != null) {
      setState(() => _error = r.error);
      return;
    }
    Navigator.pop(context);
    showTGToast(context, context.t('vc_nip_submitted'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final digits = TGVerificationService.nipDigits(_nip.text);
    final checksumOk = digits.length == 10 && TGVerificationService.nipValid(digits);
    final rec = _record;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('vc_nip_step1'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        TextField(
          key: const Key('vc-nip-input'),
          controller: _nip,
          keyboardType: TextInputType.number,
          maxLength: 13,
          onChanged: (_) => setState(() {
            _looked = false;
            _record = null;
            _error = null;
          }),
          decoration: const InputDecoration(labelText: 'NIP', hintText: '000-000-00-00'),
        ),
        if (digits.length == 10)
          Semantics(
            liveRegion: true,
            child: Text(
              context.t(checksumOk ? 'vc_nip_checksum_ok' : 'vc_nip_checksum_bad'),
              key: Key(checksumOk ? 'vc-nip-checksum-ok' : 'vc-nip-checksum-bad'),
              style: theme.bodySmall.override(color: checksumOk ? theme.success : TGColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('vc-nip-lookup'),
          onPressed: _lookup,
          icon: const Icon(Icons.search, size: 18),
          label: Text(context.t('vc_nip_lookup')),
        ),
        if (_looked && rec != null) ...[
          const SizedBox(height: 10),
          Container(
            key: const Key('vc-registry-result'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TGColors.background,
              borderRadius: BorderRadius.circular(TGRadius.card),
              border: Border.all(color: rec.active ? theme.success : TGColors.error),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec.name, style: theme.bodyLarge.override(fontWeight: FontWeight.w800)),
                Text(rec.address, style: theme.bodySmall),
                Text(context.t(rec.active ? 'vc_registry_active' : 'vc_registry_inactive', {'register': rec.register}),
                    style: theme.bodySmall.override(color: rec.active ? theme.success : TGColors.error, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(context.t('vc_registry_mock'), style: theme.bodySmall.override(color: theme.secondaryText)),
              ],
            ),
          ),
          if (rec.active) ...[
            const SizedBox(height: 14),
            Text(context.t('vc_nip_step2'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            TextField(
              key: const Key('vc-rep-name'),
              controller: _rep,
              decoration: InputDecoration(labelText: context.t('vc_rep_name')),
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              key: const Key('vc-rep-confirm'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirm,
              onChanged: (v) => setState(() => _confirm = v ?? false),
              title: Text(context.t('vc_rep_confirm'), style: theme.bodyMedium),
            ),
            Text(context.t('vc_rep_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
            const SizedBox(height: 10),
            FilledButton(
              key: const Key('vc-nip-submit'),
              style: FilledButton.styleFrom(backgroundColor: TGColors.cta, foregroundColor: Colors.black),
              onPressed: _submit,
              child: Text(context.t('vc_nip_submit')),
            ),
          ],
        ],
        if (_error != null) _ErrorText(_error!),
      ],
    );
  }
}
