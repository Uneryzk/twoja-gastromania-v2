import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/dashboard/ads_center_tabs.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';

/// `/dashboard/listings?tab=promotions` — same records, counters and credits
/// as the Promotions tab of `/dashboard/advertising`.
class TGPromotionsPanel extends StatefulWidget {
  const TGPromotionsPanel({super.key});

  @override
  State<TGPromotionsPanel> createState() => _TGPromotionsPanelState();
}

class _TGPromotionsPanelState extends State<TGPromotionsPanel> {
  Map<String, TGProduct> _catalogue = const {};

  @override
  void initState() {
    super.initState();
    TGProductService.instance.getAll().then((all) {
      if (mounted) setState(() => _catalogue = {for (final p in all) p.id: p});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final svc = PromotionService.instance..ensureSeeded();
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('ui_reach_disclaimer'), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 12),
          AdsPromotionsTab(targets: AdsTargets(auth, _catalogue)),
        ],
      ),
    );
  }
}
