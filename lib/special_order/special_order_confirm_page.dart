import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/special_order/so_consent_widgets.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_top_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/special_consent_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

/// `/special-order/new/confirm?draft=ID` — legal consent before distribution.
class SpecialOrderConfirmPage extends StatefulWidget {
  const SpecialOrderConfirmPage({super.key, required this.draftId});

  static const routeName = 'SpecialOrderConfirm';
  static const routePath = '/special-order/new/confirm';

  final String draftId;

  @override
  State<SpecialOrderConfirmPage> createState() => _SpecialOrderConfirmPageState();
}

class _SpecialOrderConfirmPageState extends State<SpecialOrderConfirmPage> {
  bool _accepted = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    TGSpecialOrderService.instance.ensureSeeded();
    TGAnalytics.track('so_consent_view', {'draft': widget.draftId});
  }

  void _confirm(TGSpecialRequest r) {
    if (!_accepted || _sending) return;
    final auth = context.read<FakeAuthState>();
    setState(() => _sending = true);
    try {
      final saved = TGSpecialOrderService.instance.confirmConsent(
        r.id,
        userId: auth.userId,
        locale: FFLocalizations.of(context).languageCode,
      );
      showTGToast(context, context.t('so_consent_sent_toast'));
      context.go('/special-order/success?no=${saved.requestNo}');
    } on StateError catch (e) {
      setState(() => _sending = false);
      showTGToast(context, context.t(e.message));
    }
  }

  void _cancel(TGSpecialRequest r) {
    final auth = context.read<FakeAuthState>();
    TGSpecialOrderService.instance.cancelConsent(r.id, userId: auth.userId);
    showTGToast(context, context.t('so_consent_cancelled', {'days': '${TGSpecialOrderService.draftRetentionDays}'}));
    context.go('/account/requests');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < TGBreakpoints.phone ? 16.0 : 24.0;
    return TGPageScaffold(
      body: Column(
        children: [
          const TGTopNav(activeNavId: 'special_order'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(pad, 24, pad, 24),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: !auth.isLoggedIn
                        ? Center(child: TGButton(onPressed: () => context.goNamed(LoginPageWidget.routeName), label: context.t('ui_login'), height: 48))
                        : ListenableBuilder(
                            listenable: TGSpecialOrderService.instance,
                            builder: (context, _) => _body(context, auth),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                const TGFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, FakeAuthState auth) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGSpecialOrderService.instance;
    final r = svc.pendingConsent(widget.draftId, userId: auth.userId);
    if (r == null) {
      final stored = svc.byId(widget.draftId);
      final timedOut = stored != null && stored.buyerId == auth.userId && stored.status == TGSpecialRequestStatus.draft;
      return Column(
        key: const Key('so-consent-unavailable'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t(timedOut ? 'so_consent_expired' : 'so_consent_not_found'), style: theme.titleMedium.override(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TGFocusRing(
            child: TGButton(
              onPressed: () => context.go(timedOut ? '/special-order/new?draft=${stored.id}' : '/account/requests'),
              label: context.t(timedOut ? 'so_consent_resume_draft' : 'ui_so_my_requests'),
              height: 44,
            ),
          ),
        ],
      );
    }
    final lang = FFLocalizations.of(context).languageCode;
    final deadline = TGSpecialConsentService.stamp(r.consentDeadline ?? TGClock.now());
    final para = theme.bodyMedium.override(lineHeight: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(context.t('so_consent_title'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 6),
        Text(context.t('so_consent_deadline', {'time': deadline}), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 20),
        Container(
          key: const Key('so-consent-summary'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: TGColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: TGColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(context.t('so_consent_summary'), style: theme.titleMedium.override(fontWeight: FontWeight.w900))),
              const SizedBox(height: 10),
              for (final line in TGSpecialConsentService.summaryText(r, lang).split('\n'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line, style: theme.bodySmall.override(lineHeight: 1.4)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(context.t('so_consent_intro'), style: para.override(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        for (final k in const ['so_consent_a', 'so_consent_b', 'so_consent_c', 'so_consent_d']) ...[
          Text(context.t(k), key: Key(k), style: para),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        const SoConsentWarningBox(),
        const SizedBox(height: 16),
        TGFocusRing(
          child: MergeSemantics(
            child: CheckboxListTile(
              key: const Key('so-consent-checkbox'),
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              activeColor: TGColors.cta,
              checkColor: TGColors.onCta,
              title: Text(context.t('so_consent_checkbox'), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        if (!_accepted)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2),
            child: Text(context.t('so_consent_check_required'), style: theme.bodySmall.override(color: theme.secondaryText)),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          children: [
            TGFocusRing(
              radius: TGRadius.pill,
              child: TGButton(
                key: const Key('so-consent-cancel'),
                onPressed: _sending ? null : () => _cancel(r),
                label: context.t('so_consent_cancel_cta'),
                variant: TGButtonVariant.ghost,
                height: 48,
              ),
            ),
            TGFocusRing(
              radius: TGRadius.pill,
              child: Semantics(
                button: true,
                enabled: _accepted,
                child: TGButton(
                  key: const Key('so-consent-confirm'),
                  onPressed: _accepted && !_sending ? () => _confirm(r) : null,
                  label: _sending ? context.t('ui_sending') : context.t('so_consent_confirm_cta'),
                  icon: Icons.send_rounded,
                  height: 48,
                  borderRadius: BorderRadius.circular(TGRadius.pill),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
