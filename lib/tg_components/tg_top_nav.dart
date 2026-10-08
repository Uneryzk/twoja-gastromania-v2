import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_nav_pills.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// The pill navigation shown under the global header on every browse page.
///
/// "Buy" and "Rent" open `/products` pre-filtered; [activeType] highlights the
/// one that is currently applied (none on the home page).
class TGTopNav extends StatelessWidget {
  const TGTopNav({super.key, this.activeType});

  final TGListingType? activeType;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isPhone = MediaQuery.sizeOf(context).width < 700;

    final items = [
      TGNavItem(id: 'buy', label: context.t('ui_buy'), onTap: () => TGNav.buy(context)),
      TGNavItem(id: 'rent', label: context.t('ui_rent'), onTap: () => TGNav.rent(context)),
      TGNavItem(id: 'add_product', label: context.t('ui_add_product_plus'), isPrimary: true, onTap: () => TGNav.addProduct(context)),
      TGNavItem(id: 'restaurants', label: context.t('ui_restaurants'), onTap: () => TGNav.restaurantsForSale(context)),
      TGNavItem(id: 'special_order', label: context.t('ui_special_order'), onTap: () => TGNav.specialOrder(context)),
    ];

    final int? activeIndex = switch (activeType) {
      TGListingType.buy => 0,
      TGListingType.rent => 1,
      null => null,
    };

    return Material(
      color: theme.primaryBackground,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isPhone ? 16 : 24, 12, isPhone ? 16 : 24, 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: TGNavPills(items: items, activeIndex: activeIndex),
          ),
        ),
      ),
    );
  }
}
