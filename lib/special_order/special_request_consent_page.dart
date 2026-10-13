import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/special_order/so_consent_widgets.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/special_consent_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

/// `/account/requests/:no/consent` — stored copy of the accepted consent text.
class SpecialRequestConsentPage extends StatelessWidget {
  const SpecialRequestConsentPage({super.key, required this.requestNo});

  static const routeName = 'SpecialRequestConsent';
  static const routePath = '/account/requests/:requestNo/consent';

  final String requestNo;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final request = TGSpecialOrderService.instance.byRequestNo(requestNo);
    final consentSvc = TGSpecialConsentService.instance;
    final consent = request == null ? null : consentSvc.forRequest(request.id);
    final owner = request != null && request.buyerId == auth.userId;
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < TGBreakpoints.phone ? 16.0 : 24.0;

    Widget body;
    if (!auth.isLoggedIn) {
      body = TGButton(onPressed: () => context.goNamed(LoginPageWidget.routeName), label: context.t('ui_login'), height: 48);
    } else if (!owner) {
      body = Text(context.t('ui_so_wrong_account'), style: theme.bodyMedium.override(fontWeight: FontWeight.w700));
    } else if (consent == null) {
      body = Text(context.t('so_consent_none'), key: const Key('so-consent-none'), style: theme.bodyMedium);
    } else {
      final warning = '${TGSpecialConsentService.line(consent.locale, 'so_consent_warning_title')}\n'
          '${TGSpecialConsentService.line(consent.locale, 'so_consent_warning_body')}';
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t('so_consent_meta', {
              'version': consent.version,
              'locale': consent.locale,
              'date': TGSpecialConsentService.stamp(consent.approvedAt),
            }),
            key: const Key('so-consent-meta'),
            style: theme.bodySmall.override(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          SelectableText(context.t('so_consent_hash', {'hash': consent.textHash}), style: theme.bodySmall.override(color: theme.secondaryText)),
          SoConsentDeliveryBanner(requestId: request.id),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: TGColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: TGColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in consent.text.split('\n\n')) ...[
                  if (p == warning) SoConsentWarningBox(locale: consent.locale) else SelectableText(p, style: theme.bodyMedium.override(lineHeight: 1.5)),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(context.t('so_consent_summary'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SelectableText(TGSpecialConsentService.summaryText(request, consent.locale), style: theme.bodySmall.override(lineHeight: 1.5)),
        ],
      );
    }

    return TGPageScaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad, 20, pad, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TGBreadcrumb(
                    items: [
                      TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                      TGBreadcrumbItem(label: context.t('ui_so_my_requests'), onTap: () => context.go('/account/requests')),
                      TGBreadcrumbItem(label: requestNo, onTap: () => context.go('/account/requests/$requestNo')),
                      TGBreadcrumbItem(label: context.t('so_consent_stored_title')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(context.t('so_consent_stored_title'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 12),
                  body,
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const TGFooter(),
        ],
      ),
    );
  }
}
