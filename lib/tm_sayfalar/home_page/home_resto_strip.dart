import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/restaurants/restaurant_card.dart';
import 'package:twoja_gastromania/restaurants/restaurant_logic.dart';
import 'package:twoja_gastromania/tm_sayfalar/home_page/home_sections.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

/// Homepage "Restaurants for Sale" — promoted-only strip (hidden if empty).
class HomeRestaurantsStrip extends StatefulWidget {
  const HomeRestaurantsStrip({super.key});

  @override
  State<HomeRestaurantsStrip> createState() => _HomeRestaurantsStripState();
}

class _HomeRestaurantsStripState extends State<HomeRestaurantsStrip> {
  bool _viewed = false;

  List<RestaurantListing> _pick() {
    final now = TGClock.now();
    final seed = now.day * 17 + now.month;
    final candidates = RestaurantService.instance.publicListings.where((r) => r.isPromoted);
    return pickPromotedRestaurants(candidates, seed: seed, limit: 4);
  }

  @override
  Widget build(BuildContext context) {
    final items = _pick();
    if (items.isEmpty) return const SizedBox.shrink();
    if (!_viewed) {
      _viewed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        TGAnalytics.track('home_resto_strip_view', {'n': items.length});
      });
    }
    final theme = FlutterFlowTheme.of(context);
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;

    return Padding(
      // Extra bottom space so hover lift / glow never collide with the next section.
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeSectionTitle(
            title: context.t('ui_restaurants'),
            subtitle: context.t('resto_strip_subtitle'),
            action: TextButton(
              onPressed: () => context.go('/restaurants'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.t('ui_view_all'), style: theme.bodyMedium.override(color: theme.primary, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: theme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (phone)
            SizedBox(
              // Tall enough for full card + hover lift; clip so nothing bleeds below.
              height: 520,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.hardEdge,
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) => SizedBox(
                  width: 280,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: RestaurantCard(
                      listing: items[i],
                      onTap: () {
                        TGAnalytics.track('home_resto_card_click', {'listingNo': items[i].listingNo});
                        context.go(items[i].detailPath);
                      },
                    ),
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth >= 1100 ? 4 : (c.maxWidth >= 800 ? 3 : 2);
                final gap = 16.0;
                final w = (c.maxWidth - gap * (cols - 1)) / cols;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap + 8,
                    children: [
                      for (final item in items)
                        SizedBox(
                          width: w,
                          child: RestaurantCard(
                            listing: item,
                            onTap: () {
                              TGAnalytics.track('home_resto_card_click', {'listingNo': item.listingNo});
                              context.go(item.detailPath);
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
