import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

class SpecialOrderPlaceholderPage extends StatelessWidget {
  const SpecialOrderPlaceholderPage({super.key, this.sellerId});

  static const routeName = 'SpecialOrder';
  static const routePath = '/special-order';

  final String? sellerId;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final profile = sellerId == null || sellerId!.isEmpty ? null : TGSellerProfileService.instance.resolve(sellerId!);
    return TGPageScaffold(
      body: ListView(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 64),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TGBreadcrumb(
                      items: [
                        TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                        TGBreadcrumbItem(label: context.t('ui_special_order')),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(context.t('ui_special_order_placeholder'), style: theme.headlineMedium.override(fontWeight: FontWeight.w900)),
                    if (profile != null) ...[
                      const SizedBox(height: 10),
                      Text(profile.name, style: theme.titleMedium.override(fontWeight: FontWeight.w800)),
                    ],
                    const SizedBox(height: 16),
                    Text(context.t('ui_coming_next'), style: theme.bodyMedium.override(color: theme.secondaryText)),
                    const SizedBox(height: 24),
                    TGButton(
                      onPressed: () => profile != null ? context.go(profile.path) : TGNav.home(context),
                      label: profile != null ? context.t('ui_visit_store') : context.t('ui_home'),
                      height: 48,
                      borderRadius: BorderRadius.circular(TGRadius.pill),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const TGFooter(),
        ],
      ),
    );
  }
}
