import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/dashboard_nav.dart';
import 'package:twoja_gastromania/dashboard/verification_cards.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_verified_info.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_verified_seller.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_review_verified.dart';
import 'package:twoja_gastromania/tg_services/review_verified_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

class SellerVerificationPage extends StatelessWidget {
  const SellerVerificationPage({super.key, this.sellerId});

  static const routeName = 'DashboardVerification';
  static const routePath = '/dashboard/verification';

  /// Demo preview of another seller (`?seller=`), ignored in production mode.
  final String? sellerId;

  @override
  Widget build(BuildContext context) {
    final svc = TGReviewVerifiedService.instance..ensureSeeded();
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final preview = TGRevenueConfigService.instance.productionMode ? null : sellerId;
    final seller = _resolve(preview, auth);
    return TGPageScaffold(
      body: ListenableBuilder(
        listenable: svc,
        builder: (context, _) => SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Padding(
                padding: EdgeInsets.fromLTRB(phone ? 16 : 24, 20, phone ? 16 : 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TGBreadcrumb(items: [
                      TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                      TGBreadcrumbItem(label: context.t('ui_dashboard_verification')),
                    ]),
                    const SizedBox(height: 16),
                    const TGDashboardNav(current: TGDashboardSection.verification),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(context.t('ui_dashboard_verification'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 16),
                    if (preview == null) ...[
                      const VerificationCenter(),
                      const SizedBox(height: 12),
                    ],
                    if (seller.type == TGSellerType.store) _CompanyCard(seller: seller) else _ReviewsCard(seller: seller),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TGSeller _resolve(String? preview, FakeAuthState auth) {
    if (preview != null) {
      for (final s in TGReviewVerifiedService.mockSellers) {
        if (s.id == preview) return s;
      }
      final p = TGSellerProfileService.instance.bySellerKey(preview);
      if (p != null) return tgSellerFromProfile(p);
      return TGSeller(id: preview, name: preview, type: TGSellerType.private, verified: false, rating: 0);
    }
    return TGSeller(id: auth.userId, name: auth.displayName, type: auth.sellerType, verified: false, rating: 0);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TGColors.surface,
          borderRadius: BorderRadius.circular(TGRadius.card),
          border: Border.all(color: TGColors.border),
        ),
        child: child,
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final color = on ? theme.success : theme.secondaryText;
    return Container(
      key: Key(on ? 'ver-status-on' : 'ver-status-off'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(TGRadius.pill), border: Border.all(color: color)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(on ? Icons.verified_user : Icons.shield_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(context.t(on ? 'ver_status_on' : 'ver_status_off'), style: theme.labelMedium.override(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({required this.seller});
  final TGSeller seller;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final on = tgVerifiedBasis(seller) == TGVerifiedBasis.companyRegistry;
    return _Card(
      key: const Key('ver-company-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.t('ver_company_card_title'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
              _StatusChip(on: on),
            ],
          ),
          const SizedBox(height: 8),
          Text(context.t(on ? 'ver_company_card_on' : 'ver_company_card_off'), style: theme.bodyMedium.override(color: theme.secondaryText)),
          const SizedBox(height: 6),
          Text(context.t('ver_not_purchasable'), style: theme.bodySmall.override(color: theme.secondaryText)),
        ],
      ),
    );
  }
}

class _ReviewsCard extends StatelessWidget {
  const _ReviewsCard({required this.seller});
  final TGSeller seller;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final svc = TGReviewVerifiedService.instance;
    final on = svc.isVerified(seller.id);
    final stats = svc.statsFor(seller.id);
    final reqs = svc.requirements(seller.id);
    final since = svc.verifiedSince(seller.id);
    final ov = svc.overrideFor(seller.id);
    return _Card(
      key: const Key('ver-reviews-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.t('ver_reviews_card_title'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
              _StatusChip(on: on),
            ],
          ),
          const SizedBox(height: 8),
          Text(context.t('ver_reviews_card_sub'), style: theme.bodyMedium.override(color: theme.secondaryText)),
          const SizedBox(height: 10),
          Text(tgReviewStatsLine(context, stats), key: const Key('ver-stats-line'), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
          if (since != null) ...[
            const SizedBox(height: 4),
            Text(context.t('ver_since', {'date': DateFormat('d MMM yyyy', FFLocalizations.of(context).languageCode).format(since)}),
                style: theme.bodySmall.override(color: theme.secondaryText)),
          ],
          if (ov != null) ...[
            const SizedBox(height: 4),
            Text(context.t('ver_override_note'), style: theme.bodySmall.override(color: TGColors.slaAmber, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 14),
          Semantics(header: true, child: Text(context.t('ver_checklist_title'), style: theme.titleSmall.override(fontWeight: FontWeight.w800))),
          const SizedBox(height: 6),
          for (final r in reqs) _ReqRow(req: r),
          const SizedBox(height: 10),
          Text(context.t('ver_counted_note'), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 4),
          Text(context.t('ver_not_purchasable'), style: theme.bodySmall.override(color: theme.secondaryText)),
        ],
      ),
    );
  }
}

class _ReqRow extends StatelessWidget {
  const _ReqRow({required this.req});
  final TGVerifiedRequirement req;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final label = context.t(req.labelKey, req.params);
    return Semantics(
      container: true,
      label: '${context.t(req.met ? 'ver_met' : 'ver_not_met')}: $label',
      excludeSemantics: true,
      child: Padding(
        key: Key('ver-req-${req.id}'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                req.met ? '✓' : '—',
                style: theme.bodyMedium.override(color: req.met ? theme.success : theme.secondaryText, fontWeight: FontWeight.w900),
              ),
            ),
            Expanded(child: Text(label, style: theme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}
