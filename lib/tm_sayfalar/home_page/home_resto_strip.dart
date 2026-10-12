import 'dart:async';

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

/// Homepage "Restaurants for Sale" — promoted first, up to 8, horizontal scroll.
class HomeRestaurantsStrip extends StatefulWidget {
  const HomeRestaurantsStrip({super.key});

  @override
  State<HomeRestaurantsStrip> createState() => _HomeRestaurantsStripState();
}

class _HomeRestaurantsStripState extends State<HomeRestaurantsStrip> {
  static const int _limit = 8;
  static const Duration _autoEvery = Duration(seconds: 3);

  final ScrollController _scroll = ScrollController();
  Timer? _timer;
  bool _viewed = false;
  bool _paused = false;
  bool _timerArmed = false;
  static const double _cardW = 280;
  static const double _gap = 14;

  List<RestaurantListing> _pick() {
    final now = TGClock.now();
    final seed = now.day * 17 + now.month;
    final public = RestaurantService.instance.publicListings;
    // Hide the whole strip when there are no active promoted listings.
    return pickPromotedRestaurants(public.where((r) => r.isPromoted), seed: seed, limit: _limit);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _armTimer(bool reduce, int count) {
    if (_timerArmed) return;
    _timerArmed = true;
    _timer?.cancel();
    if (reduce || count <= 3) {
      _timer = null;
      return;
    }
    _timer = Timer.periodic(_autoEvery, (_) => _advance());
  }

  void _advance() {
    if (_paused || !mounted || !_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    var next = _scroll.offset + _cardW + _gap;
    if (next > max + 1) next = 0;
    _scroll.animateTo(next.clamp(0.0, max), duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  void _nudge(double dir) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final next = (_scroll.offset + dir * (_cardW + _gap)).clamp(0.0, max);
    _scroll.animateTo(next, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
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
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _armTimer(reduce, items.length);
    });

    final list = SizedBox(
      height: phone ? 500 : 520,
      child: MouseRegion(
        onEnter: (_) => _paused = true,
        onExit: (_) => _paused = false,
        child: Stack(
          children: [
            ListView.separated(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: _gap),
              itemBuilder: (_, i) => SizedBox(
                width: _cardW,
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
            if (!phone && items.length > 3) ...[
              Positioned(
                left: 0,
                top: 0,
                bottom: 20,
                child: Center(
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _nudge(-1),
                      child: const SizedBox(width: 40, height: 40, child: Icon(Icons.chevron_left_rounded, color: Colors.white)),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 20,
                child: Center(
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _nudge(1),
                      child: const SizedBox(width: 40, height: 40, child: Icon(Icons.chevron_right_rounded, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Padding(
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
          list,
        ],
      ),
    );
  }
}
