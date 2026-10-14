import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/special_order/special_order_hub_widgets.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';
import 'package:twoja_gastromania/tm_sayfalar/home_page/home_sections.dart';

/// Home "Featured Manufacturers" strip — sits directly under restaurant transfers.
class HomeManufacturersStrip extends StatelessWidget {
  const HomeManufacturersStrip({super.key});

  static const maxCards = 6;
  static const minRealManufacturers = 3;

  /// Promotion-layered list; empty when fewer than [minRealManufacturers]
  /// (mock manufacturers are already excluded in production mode).
  static List<TGStoreProfile> items() {
    final all = TGSpecialOrderService.instance.manufacturers();
    if (all.length < minRealManufacturers) return const [];
    return all.take(maxCards).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        TGSpecialOrderService.instance,
        TGSellerProfileService.instance,
        PromotionService.instance,
      ]),
      builder: (context, _) {
        final list = items();
        if (list.isEmpty) return const SizedBox.shrink();
        final theme = FlutterFlowTheme.of(context);
        final textGrow = (MediaQuery.textScalerOf(context).scale(16) / 16 - 1).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeSectionTitle(
                title: context.t('ui_home_mfr_title'),
                subtitle: context.t('ui_home_mfr_sub'),
                action: TextButton(
                  onPressed: () {
                    TGAnalytics.track('home_mfr_see_all', {'n': list.length});
                    context.go('/special-order');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.t('ui_view_all'),
                          style: theme.bodyMedium.override(color: theme.primary, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 4),
                      ExcludeSemantics(child: Icon(Icons.arrow_forward_rounded, size: 18, color: theme.primary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 340 + textGrow * 160,
                child: ListView.separated(
                  key: const ValueKey('home_mfr_strip'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, i) => SizedBox(
                    width: 260,
                    child: SoManufacturerCard.compact(profile: list[i]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
