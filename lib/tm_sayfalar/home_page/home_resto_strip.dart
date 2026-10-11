import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          title: 'Restaurants for Sale',
          subtitle: 'Take over a ready business.',
          action: TextButton(
            onPressed: () => context.go('/restaurants'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('See all', style: theme.bodyMedium.override(color: theme.primary, fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 18, color: theme.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (phone)
          SizedBox(
            height: 360,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => SizedBox(
                width: 280,
                child: RestaurantCard(
                  listing: items[i],
                  onTap: () {
                    TGAnalytics.track('home_resto_card_click', {'listingNo': items[i].listingNo});
                    context.go(items[i].detailPath);
                  },
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 1100 ? 4 : (c.maxWidth >= 800 ? 3 : 2);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                clipBehavior: Clip.none,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => RestaurantCard(
                  listing: items[i],
                  onTap: () {
                    TGAnalytics.track('home_resto_card_click', {'listingNo': items[i].listingNo});
                    context.go(items[i].detailPath);
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}
