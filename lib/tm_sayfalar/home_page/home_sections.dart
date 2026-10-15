import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/products/products_results.dart' show kTGGridGutter;
import 'package:twoja_gastromania/tg_components/tg_hover_card.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_components/tg_rating_stars.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_core/tg_plural.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/restaurants/restaurant_l10n.dart';
import 'package:twoja_gastromania/tg_models/tg_ad_slot.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_core/tg_verified_seller.dart';
import 'package:twoja_gastromania/tg_services/ad_slot_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';

/// Section heading used on the home page.
class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({super.key, required this.title, this.subtitle, this.action});

  final String title;
  final String? subtitle;

  /// Optional trailing link, e.g. "View all".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.headlineSmall.override(
                    fontSize: phone ? 24 : 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.40,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: theme.bodyMedium.override(color: theme.secondaryText, lineHeight: 1.45, fontSize: phone ? 14 : 16)),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero carousel (organic ad pages + up to 3 sponsored AdSlots)
// ---------------------------------------------------------------------------

class _HeroSlide {
  const _HeroSlide.organic({required this.image, required this.titleKey, required this.subtitleKey, required this.routeName})
      : sponsored = false,
        ad = null,
        title = null,
        targetUrl = null;

  const _HeroSlide.sponsored({required this.ad, required this.image, required this.title, required this.targetUrl})
      : sponsored = true,
        titleKey = null,
        subtitleKey = null,
        routeName = null;

  final bool sponsored;
  final TGAdSlot? ad;
  final String image;
  final String? titleKey;
  final String? subtitleKey;
  final String? routeName;
  final String? title;
  final String? targetUrl;
}

/// Auto-playing carousel; organic slides open ad pages; sponsored open targetUrl.
class HomeHeroCarousel extends StatefulWidget {
  const HomeHeroCarousel({super.key, required this.slideRouteNames});

  /// Route names of the ad pages, in slide order.
  final List<String> slideRouteNames;

  @override
  State<HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<HomeHeroCarousel> {
  static const Duration _autoPlayEvery = Duration(seconds: 6);

  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _paused = false;
  bool _focusPaused = false;
  final Set<String> _impressed = {};

  List<_HeroSlide> _organic() => [
        _HeroSlide.organic(image: TGListingImages.heroSlide(0), titleKey: 'i8m5wr2h', subtitleKey: '7d6qkq0f', routeName: widget.slideRouteNames[0]),
        _HeroSlide.organic(image: TGListingImages.heroSlide(1), titleKey: '0y0mdwe3', subtitleKey: 'gn0cgz8h', routeName: widget.slideRouteNames[1]),
        _HeroSlide.organic(image: TGListingImages.heroSlide(2), titleKey: 'z2t2enej', subtitleKey: 'yhrj1i0w', routeName: widget.slideRouteNames[2]),
        _HeroSlide.organic(image: TGListingImages.heroSlide(3), titleKey: 'fd2vmdbm', subtitleKey: 'ghe86x4x', routeName: widget.slideRouteNames[3]),
      ];

  /// Organic slides unchanged; sponsored interleaved between them (max 3).
  List<_HeroSlide> _compose() {
    final organic = _organic();
    final ads = AdSlotService.instance.liveSlides;
    final maxAds = AdSlotService.instance.maxPerDay;
    if (ads.isEmpty) return organic;
    final out = <_HeroSlide>[];
    var si = 0;
    for (var i = 0; i < organic.length; i++) {
      out.add(organic[i]);
      if (si < ads.length && si < maxAds) {
        final a = ads[si++];
        out.add(_HeroSlide.sponsored(ad: a, image: a.imageUrl, title: a.title, targetUrl: a.targetUrl));
      }
    }
    while (si < ads.length && si < maxAds) {
      final a = ads[si++];
      out.add(_HeroSlide.sponsored(ad: a, image: a.imageUrl, title: a.title, targetUrl: a.targetUrl));
    }
    return out;
  }

  void _recordImpression(_HeroSlide s) {
    final id = s.ad?.id;
    if (id == null || _impressed.contains(id)) return;
    _impressed.add(id);
    AdSlotService.instance.recordImpression(id);
  }

  @override
  void initState() {
    super.initState();
    AdSlotService.instance.ensureSeeded();
    AdSlotService.instance.addListener(_onAds);
  }

  void _onAds() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the OS "reduce motion" setting: no auto-advance then.
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _timer?.cancel();
    _timer = reduce ? null : Timer.periodic(_autoPlayEvery, (_) => _advance());
  }

  void _advance() {
    if (_paused || _focusPaused || !mounted || !_controller.hasClients) return;
    final n = _compose().length;
    if (n == 0) return;
    _goTo((_index + 1) % n);
  }

  void _goTo(int i) {
    if (!_controller.hasClients) return;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _controller.jumpToPage(i);
    } else {
      _controller.animateToPage(i, duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    AdSlotService.instance.removeListener(_onAds);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _openSlide(_HeroSlide s) {
    if (s.sponsored) {
      final id = s.ad?.id;
      if (id != null) AdSlotService.instance.recordClick(id);
      final url = s.targetUrl;
      if (url != null && url.isNotEmpty) context.go(url);
      return;
    }
    context.goNamed(s.routeName!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final l10n = FFLocalizations.of(context);
    final slides = _compose();
    if (_index >= slides.length) _index = 0;
    if (slides.isNotEmpty) _recordImpression(slides[_index]);

    return LayoutBuilder(
      builder: (context, c) {
        final phone = c.maxWidth < TGBreakpoints.phone;
        final height = (c.maxWidth * (phone ? 0.78 : 0.36)).clamp(280.0, 440.0);
        return Semantics(
          label: context.t('ui_hero_carousel_sem'),
          child: MouseRegion(
            onEnter: (_) => _paused = true,
            onExit: (_) => _paused = false,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TGRadius.card),
              child: SizedBox(
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _controller,
                      itemCount: slides.length,
                      onPageChanged: (i) {
                        setState(() => _index = i);
                        if (i < slides.length) _recordImpression(slides[i]);
                      },
                      itemBuilder: (context, i) {
                        final s = slides[i];
                        String title;
                        if (s.sponsored) {
                          final segment = (s.targetUrl ?? '').split('/').where((e) => e.isNotEmpty).lastOrNull ?? '';
                          final listing = RestaurantService.instance.fromPathSegment(segment);
                          title = listing != null
                              ? restoLocalizedShortTitle(context, listing)
                              : (context.t('ad_title_${s.ad?.id ?? ''}').isNotEmpty
                                  ? context.t('ad_title_${s.ad?.id ?? ''}')
                                  : (s.title ?? ''));
                        } else {
                          title = l10n.getText(s.titleKey!);
                        }
                        final label = s.sponsored ? '${context.t('badge.sponsored')}. $title' : title;
                        return Focus(
                          onFocusChange: (f) => _focusPaused = f,
                          child: Builder(
                            builder: (ctx) {
                              final focused = Focus.of(ctx).hasFocus;
                              return Semantics(
                                button: true,
                                label: label,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    key: s.sponsored ? null : Key('hero-slide-${s.routeName}'),
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _openSlide(s),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: focused ? Border.all(color: TGColors.cta, width: 2) : null,
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          if (s.sponsored)
                                            TGSmartImage(url: s.image, fit: BoxFit.cover, cacheWidth: 1400)
                                          else
                                            Image.asset(
                                              s.image,
                                              fit: BoxFit.cover,
                                              cacheWidth: 1400,
                                              gaplessPlayback: true,
                                              errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate),
                                            ),
                                          if (s.sponsored)
                                            const DecoratedBox(decoration: BoxDecoration(gradient: tgBannerScrim))
                                          else
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [Colors.black.withValues(alpha: 0.82), Colors.black.withValues(alpha: 0.35), Colors.transparent],
                                                  stops: const [0, 0.55, 1],
                                                ),
                                              ),
                                            ),
                                          if (s.sponsored)
                                            Positioned(
                                              left: phone ? 18 : 36,
                                              top: phone ? 16 : 20,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(TGRadius.pill),
                                                  border: Border.all(color: Colors.white70),
                                                ),
                                                child: Text(
                                                  context.t('badge.sponsored'),
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            left: phone ? 18 : 36,
                                            right: phone ? 18 : 120,
                                            bottom: phone ? 48 : 52,
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 680),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    title,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: theme.headlineMedium.override(
                                                      color: Colors.white,
                                                      fontSize: phone ? 24 : 38,
                                                      fontWeight: FontWeight.w700,
                                                      letterSpacing: 0.40,
                                                      lineHeight: 1.15,
                                                    ),
                                                  ),
                                                  if (!s.sponsored) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      l10n.getText(s.subtitleKey!),
                                                      maxLines: phone ? 2 : 3,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: theme.bodyLarge.override(
                                                        color: Colors.white.withValues(alpha: 0.88),
                                                        fontSize: phone ? 13.5 : 17,
                                                        lineHeight: 1.4,
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 14),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: theme.primary,
                                                      borderRadius: BorderRadius.circular(TGRadius.pill),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          s.sponsored ? context.t('ui_view') : context.t('ui_read_more'),
                                                          style: theme.bodySmall.override(color: TGColors.onCta, fontWeight: FontWeight.w900),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        const Icon(Icons.arrow_forward_rounded, size: 16, color: TGColors.onCta),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    if (!phone) ...[
                      Positioned(left: 12, top: 0, bottom: 0, child: Center(child: _ArrowButton(icon: Icons.chevron_left_rounded, label: context.t('ui_hero_prev_sem'), onTap: () => _goTo((_index - 1 + slides.length) % slides.length)))),
                      Positioned(right: 12, top: 0, bottom: 0, child: Center(child: _ArrowButton(icon: Icons.chevron_right_rounded, label: context.t('ui_hero_next_sem'), onTap: () => _goTo((_index + 1) % slides.length)))),
                    ],
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < slides.length; i++)
                            Semantics(
                              button: true,
                              selected: i == _index,
                              label: slides[i].sponsored
                                  ? context.t('ui_hero_slide_sponsored_sem', {'n': '${i + 1}'})
                                  : context.t('ui_hero_slide_sem', {'n': '${i + 1}'}),
                              child: GestureDetector(
                                onTap: () => _goTo(i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ? 0 : 220),
                                    width: i == _index ? 26 : 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: i == _index ? theme.primary : Colors.white.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(TGRadius.pill),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, color: Colors.white, size: 28)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category cards -> /products?cat=...
// ---------------------------------------------------------------------------

class _CategoryData {
  const _CategoryData(this.category, this.titleKey, this.image);

  final TGCategory category;
  final String titleKey;

  /// Local `assets/images/…` path (FlutterFlow originals).
  final String image;
}

/// Featured category tiles — local assets from [TGListingImages.categoryCoverUrls] only.
final List<_CategoryData> _categories = [
  for (final e in TGListingImages.categoryCoverUrls.entries)
    _CategoryData(
      e.key,
      switch (e.key) {
        TGCategory.cookingEquipment => 'ji98dehm',
        TGCategory.refrigerationEquipment => 'swrjjpbp',
        TGCategory.warewashing => 'lcx4dovc',
        TGCategory.foodPreparation => '71nup2wm',
        TGCategory.stainlessSteelFurniture => '56pbhr1s',
        TGCategory.barAndBeverageEquipment => 'viy2skiv',
      },
      e.value,
    ),
];

/// "Featured Offers": one card per category. Tapping a card opens `/products`
/// filtered to that category.
class HomeCategorySection extends StatelessWidget {
  const HomeCategorySection({super.key, required this.listingCounts});

  /// Number of listings per category (empty until the catalogue has loaded).
  final Map<TGCategory, int> listingCounts;

  @override
  Widget build(BuildContext context) {
    final l10n = FFLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(title: context.t('ui_gastronomy_categories'), subtitle: l10n.getText('3u75e0ef')),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 3 : 2;
            final phone = c.maxWidth < 480;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              clipBehavior: Clip.none, // hover glow paints outside the grid
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: phone ? 12 : 20,
                mainAxisSpacing: phone ? 12 : 20,
                childAspectRatio: cols == 3 ? 1.35 : (phone ? 0.95 : 1.3),
              ),
              itemCount: _categories.length,
              itemBuilder: (context, i) {
                final d = _categories[i];
                return _CategoryCard(
                  data: d,
                  title: l10n.getText(d.titleKey),
                  count: listingCounts[d.category],
                  compact: phone,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.data, required this.title, required this.count, required this.compact});

  final _CategoryData data;
  final String title;
  final int? count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return TGHoverCard(
      semanticLabel: context.t('ui_browse_category', {'title': title}),
      onTap: () => TGNav.category(context, data.category),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            data.image,
            fit: BoxFit.cover,
            cacheWidth: 800,
            errorBuilder: (_, __, ___) => ColoredBox(color: theme.alternate),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [Colors.black.withValues(alpha: 0.78), Colors.transparent],
              ),
            ),
          ),
          Positioned(
            left: compact ? 10 : 14,
            right: compact ? 10 : 14,
            bottom: compact ? 10 : 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pink accent badge (design token: accent).
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 6 : 8),
                        decoration: BoxDecoration(color: theme.secondary, borderRadius: BorderRadius.circular(TGRadius.pill)),
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.titleSmall.override(
                            color: Colors.white,
                            fontSize: compact ? 13 : 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.40,
                            lineHeight: 1.2,
                          ),
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          TGPlural.listingsOf(context, count!),
                          style: theme.bodySmall.override(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: compact ? 32 : 38,
                  height: compact ? 32 : 38,
                  decoration: BoxDecoration(color: theme.primary, shape: BoxShape.circle),
                  child: Icon(Icons.arrow_forward_rounded, size: compact ? 18 : 20, color: TGColors.onCta),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Promoted / featured listings (private-seller first catalogue strip)
// ---------------------------------------------------------------------------

/// Homepage featured products (VITRIN-1):
/// Spotlight → Glow only; FEATURED only on Glow / Spotlight; no auto-advance.
/// Desktop: 5 cards wide · ≤5 static · 6–10 two rows · >10 manual carousel.
class HomePromotedSection extends StatefulWidget {
  const HomePromotedSection({super.key, required this.products, this.tiers = const {}});

  final List<TGProduct> products;
  final Map<String, PromotionTier?> tiers;

  @override
  State<HomePromotedSection> createState() => _HomePromotedSectionState();
}

class _HomePromotedSectionState extends State<HomePromotedSection> {
  static const int _desktopVisible = 5;

  final ScrollController _scroll = ScrollController();
  double _cardStep = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _nudge(double dir) {
    if (!_scroll.hasClients || _cardStep <= 0) return;
    final max = _scroll.position.maxScrollExtent;
    final next = (_scroll.offset + dir * _cardStep).clamp(0.0, max);
    _scroll.animateTo(next, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Widget _card(TGProduct p) {
    final promo = PromotionService.instance.effectiveListingPromo(p);
    return TGProductCard(
      product: p,
      promotionTier: widget.tiers[p.id] ?? promo?.tier,
      promotionId: promo?.id,
      forceFeaturedBadge: TGProductCard.showsFeaturedBadge(tier: widget.tiers[p.id] ?? promo?.tier),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.products;
    if (products.isEmpty) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          title: context.t('ui_promoted_listings'),
          subtitle: context.t('ui_promoted_listings_sub'),
          action: TextButton(
            onPressed: () => TGNav.products(context),
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
        LayoutBuilder(
          builder: (context, c) {
            final scaler = MediaQuery.textScalerOf(context);
            final phone = c.maxWidth < TGBreakpoints.phone;
            if (phone) {
              const cardW = 292.0;
              return SizedBox(
                height: TGProductCard.gridExtent(cardW, scaler) + 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.hardEdge,
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (_, i) => SizedBox(width: cardW, child: _card(products[i])),
                ),
              );
            }

            final n = products.length;
            if (n <= 10) {
              final row1 = products.take(_desktopVisible).toList();
              final row2 = n > _desktopVisible ? products.skip(_desktopVisible).take(_desktopVisible).toList() : const <TGProduct>[];
              final cardW = (c.maxWidth - kTGGridGutter * (_desktopVisible - 1)) / _desktopVisible;
              final h = TGProductCard.gridExtent(cardW, scaler);
              Widget row(List<TGProduct> items) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: kTGGridGutter),
                        SizedBox(width: cardW, height: h, child: _card(items[i])),
                      ],
                    ],
                  );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row(row1),
                  if (row2.isNotEmpty) ...[const SizedBox(height: kTGGridGutter), row(row2)],
                ],
              );
            }

            // >10 → manual carousel only (no auto-advance). Arrows outside card text.
            final cardW = (c.maxWidth - kTGGridGutter * (_desktopVisible - 1)) / _desktopVisible;
            _cardStep = cardW + kTGGridGutter;
            final h = TGProductCard.gridExtent(cardW, scaler);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ArrowButton(icon: Icons.chevron_left_rounded, label: 'Previous', onTap: () => _nudge(-1)),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: h + 16,
                    child: ListView.separated(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(width: kTGGridGutter),
                      itemBuilder: (_, i) => SizedBox(width: cardW, height: h, child: _card(products[i])),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ArrowButton(icon: Icons.chevron_right_rounded, label: 'Next', onTap: () => _nudge(1)),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Best sellers
// ---------------------------------------------------------------------------

/// Horizontally scrolling seller cards (VERIFY-1 shield only when earned).
class HomeBestSellers extends StatefulWidget {
  const HomeBestSellers({super.key});

  @override
  State<HomeBestSellers> createState() => _HomeBestSellersState();
}

class _HomeBestSellersState extends State<HomeBestSellers> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([TGSellerProfileService.instance, TGRevenueConfigService.instance]),
      builder: (context, _) {
        final sellers = TGSellerProfileService.instance.bestSellers;
        if (sellers.length < TGSellerProfileService.minBestSellers) return const SizedBox.shrink();
        return _bestSellersBody(context, sellers);
      },
    );
  }

  Widget _bestSellersBody(BuildContext context, List<TGStoreProfile> sellers) {
    final theme = FlutterFlowTheme.of(context);
    final l10n = FFLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;

    Widget arrow(IconData icon, String label, double delta) => Semantics(
          button: true,
          label: label,
          child: IconButton.outlined(
            onPressed: () => _scrollBy(delta),
            icon: Icon(icon, color: theme.primaryText),
            style: IconButton.styleFrom(side: BorderSide(color: theme.tertiary)),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          title: l10n.getText('88t2wvuj'),
          subtitle: l10n.getText('21twf2jq').replaceAll(RegExp(r'\s+'), ' '),
          action: wide
              ? Row(mainAxisSize: MainAxisSize.min, children: [arrow(Icons.chevron_left_rounded, 'Scroll left', -520), const SizedBox(width: 8), arrow(Icons.chevron_right_rounded, 'Scroll right', 520)])
              : null,
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 330,
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: sellers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (context, i) => SizedBox(width: 232, child: _SellerCard(profile: sellers[i])),
          ),
        ),
      ],
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.profile});
  final TGStoreProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final l10n = FFLocalizations.of(context);
    final seller = tgSellerFromProfile(profile);
    final verified = tgShowsVerifiedSellerBadge(seller);
    final listingN = TGProductService.instance.cachedAll.where((p) => p.seller.id == profile.sellerKey).length;
    return TGHoverCard(
      semanticLabel: verified ? '${profile.name}, ${context.t('ui_verified_seller')}, $listingN' : '${profile.name}, $listingN',
      onTap: () => context.push(profile.path),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (verified)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.success.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(TGRadius.input),
                    border: Border.all(color: theme.success.withValues(alpha: 0.55)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, size: 16, color: theme.success),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          context.t('ui_verified_seller'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.labelSmall.override(color: theme.primaryText, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(TGRadius.input)),
                padding: const EdgeInsets.all(10),
                child: profile.logoUrl != null
                    ? Image.asset(profile.logoUrl!, fit: BoxFit.contain, cacheWidth: 400, errorBuilder: (_, __, ___) => Icon(Icons.storefront, color: theme.secondaryText, size: 40))
                    : Icon(Icons.storefront, color: theme.secondaryText, size: 40),
              ),
            ),
            const SizedBox(height: 12),
            TGRatingStars(rating: profile.rating, size: 20),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(l10n.getText('g89e8jcq'), style: theme.bodyMedium.override(color: theme.secondaryText, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('$listingN', style: theme.bodyLarge.override(fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

class _StatData {
  const _StatData(this.image, this.titleKey, this.value);

  final String image;
  final String titleKey;
  final int value;
}

const List<_StatData> _stats = [
  _StatData('assets/images/24_saat.png', 'dkz7hccx', 76),
  _StatData('assets/images/Bussiness.png', 'p15aunky', 465),
  _StatData('assets/images/Product_list.png', 'b81eez74', 1426),
  _StatData('assets/images/24_saat.png', 'eio1zib0', 181),
];

/// Locale-aware grouping (pl-PL: "1 426").
String homeStatNumber(int n, Locale locale) {
  final tag = (locale.countryCode == null || locale.countryCode!.isEmpty) ? locale.languageCode : '${locale.languageCode}_${locale.countryCode}';
  return NumberFormat.decimalPattern(tag).format(n);
}

class HomeStatsSection extends StatelessWidget {
  const HomeStatsSection({super.key, this.debugValues});

  /// Test-only value override. Production UI always uses [_stats].
  @visibleForTesting
  final List<int>? debugValues;

  static const kMinProductionValue = 5;
  static const kMinVisibleCards = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = FFLocalizations.of(context);
    return ListenableBuilder(
      listenable: TGRevenueConfigService.instance,
      builder: (context, _) {
        final prod = TGRevenueConfigService.instance.productionMode;
        final rows = <_StatData>[
          for (var i = 0; i < _stats.length; i++)
            _StatData(_stats[i].image, _stats[i].titleKey, debugValues != null && i < debugValues!.length ? debugValues![i] : _stats[i].value),
        ];
        final shown = [for (final s in rows) if (!prod || s.value >= kMinProductionValue) s];
        if (shown.length < kMinVisibleCards) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 4 : 2;
            final desktop = c.maxWidth >= 900;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: desktop ? 214 : 196,
              ),
              itemCount: shown.length,
              itemBuilder: (context, i) => HomeStatCard(
                key: Key('home-stat-${shown[i].titleKey}'),
                imageAsset: shown[i].image,
                title: l10n.getText(shown[i].titleKey).replaceAll(RegExp(r'\s+'), ' ').trim(),
                playId: shown[i].titleKey,
                targetValue: shown[i].value,
                stagger: Duration(milliseconds: 100 * i),
                large: desktop,
              ),
            );
          },
        );
      },
    );
  }
}

class HomeStatCard extends StatefulWidget {
  const HomeStatCard({
    super.key,
    required this.imageAsset,
    required this.title,
    required this.targetValue,
    this.playId,
    this.stagger = Duration.zero,
    this.large = true,
  });

  final String imageAsset;
  final String title;
  final int? targetValue;
  final String? playId;
  final Duration stagger;
  final bool large;

  @override
  State<HomeStatCard> createState() => _HomeStatCardState();
}

class _HomeStatCardState extends State<HomeStatCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final avatar = widget.large ? 84.0 : 64.0;
    final locale = Localizations.localeOf(context);
    final numberStyle = theme.bodyMedium.override(
      color: theme.primary,
      fontSize: widget.large ? 22 : 18,
      fontWeight: FontWeight.w900,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final target = widget.targetValue;
    final finalLabel = target == null ? widget.title : '${widget.title}. ${homeStatNumber(target, locale)}';
    return _HalfVisibleOnce(
      onHalf: () {
        if (!_revealed) setState(() => _revealed = true);
      },
      child: Semantics(
        container: true,
        label: finalLabel,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(TGRadius.card),
            border: Border.all(color: theme.tertiary),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipOval(
                child: Image.asset(widget.imageAsset, width: avatar, height: avatar, fit: BoxFit.cover, cacheWidth: 260, errorBuilder: (_, __, ___) => SizedBox(width: avatar, height: avatar)),
              ),
              const SizedBox(height: 10),
              ExcludeSemantics(
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleMedium.override(
                    fontSize: widget.large ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.40,
                    lineHeight: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: (widget.large ? 22.0 : 18.0) * 1.2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: HomeStatCountUp(
                    id: widget.playId ?? widget.title,
                    target: target,
                    revealed: _revealed,
                    stagger: widget.stagger,
                    textStyle: numberStyle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Counts 0 → target once the card is ≥50% on screen. One implicit controller per card.
class HomeStatCountUp extends StatefulWidget {
  const HomeStatCountUp({
    super.key,
    required this.id,
    required this.target,
    required this.textStyle,
    this.revealed,
    this.stagger = Duration.zero,
  });

  final String id;
  final int? target;
  final TextStyle textStyle;
  /// When set, the parent owns visibility (card ≥50%). Null = measure this box.
  final bool? revealed;
  final Duration stagger;

  static const firstDuration = Duration(milliseconds: 2000);
  static const liveDuration = Duration(milliseconds: 600);

  @visibleForTesting
  static void resetPlayed() => _HomeStatCountUpState._played.clear();

  @override
  State<HomeStatCountUp> createState() => _HomeStatCountUpState();
}

class _HomeStatCountUpState extends State<HomeStatCountUp> {
  static final Set<String> _played = {};

  int _from = 0;
  int _to = 0;
  int _shown = 0;
  Duration _duration = Duration.zero;
  bool _halfVisible = false;
  bool _started = false;
  Timer? _stagger;

  @override
  void initState() {
    super.initState();
    if (widget.revealed == true) _halfVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryStart();
    });
  }

  @override
  void dispose() {
    _stagger?.cancel();
    super.dispose();
  }

  bool get _reduce => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _run({required int from, required int to, required Duration duration}) {
    _stagger?.cancel();
    final snap = to == 0 || _reduce || duration == Duration.zero;
    setState(() {
      _from = snap ? to : from;
      _to = to;
      _shown = snap ? to : from;
      _duration = snap ? Duration.zero : duration;
    });
    _played.add(widget.id);
  }

  void _tryStart() {
    if (widget.revealed == true) _halfVisible = true;
    final target = widget.target;
    if (!_halfVisible || _started || target == null) return;
    _started = true;
    if (_played.contains(widget.id) || target == 0 || _reduce) {
      _run(from: target, to: target, duration: Duration.zero);
      return;
    }
    final delay = widget.stagger;
    if (delay == Duration.zero) {
      _run(from: 0, to: target, duration: HomeStatCountUp.firstDuration);
      return;
    }
    _stagger = Timer(delay, () {
      if (!mounted || widget.target == null) return;
      _run(from: 0, to: widget.target!, duration: HomeStatCountUp.firstDuration);
    });
  }

  void _onHalfVisible() {
    if (_halfVisible) return;
    _halfVisible = true;
    _tryStart();
  }

  @override
  void didUpdateWidget(covariant HomeStatCountUp old) {
    super.didUpdateWidget(old);
    if (widget.revealed == true) _halfVisible = true;
    if (!_started && widget.target != null) {
      _tryStart();
      return;
    }
    if (_started && old.target != widget.target && widget.target != null) {
      _run(
        from: _shown,
        to: widget.target!,
        duration: _reduce ? Duration.zero : HomeStatCountUp.liveDuration,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final loading = widget.target == null;
    final number = RepaintBoundary(
      child: loading
          ? const _StatNumberSkeleton()
          : ExcludeSemantics(
              child: TweenAnimationBuilder<int>(
                tween: IntTween(begin: _from, end: _to),
                duration: _duration,
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  _shown = value;
                  return Text(
                    homeStatNumber(value, locale),
                    key: Key('home-stat-number-${widget.id}'),
                    style: widget.textStyle,
                  );
                },
              ),
            ),
    );
    if (widget.revealed != null) return number;
    return _HalfVisibleOnce(onHalf: _onHalfVisible, child: number);
  }
}

class _StatNumberSkeleton extends StatelessWidget {
  const _StatNumberSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-stat-skeleton'),
      width: 56,
      height: 18,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).alternate,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Fires [onHalf] once when ≥50% of [child] is in the viewport. No new package.
class _HalfVisibleOnce extends StatefulWidget {
  const _HalfVisibleOnce({required this.onHalf, required this.child});
  final VoidCallback onHalf;
  final Widget child;

  @override
  State<_HalfVisibleOnce> createState() => _HalfVisibleOnceState();
}

class _HalfVisibleOnceState extends State<_HalfVisibleOnce> {
  bool _fired = false;
  final List<ScrollPosition> _positions = [];

  void _detach() {
    for (final p in _positions) {
      p.removeListener(_schedule);
    }
    _positions.clear();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _attach() {
    _detach();
    context.visitAncestorElements((el) {
      if (el is StatefulElement && el.state is ScrollableState) {
        final pos = (el.state as ScrollableState).position;
        _positions.add(pos);
        pos.addListener(_schedule);
      }
      return true;
    });
  }

  void _check() {
    if (_fired || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;
    final size = box.size;
    if (size.isEmpty) return;
    final rect = box.localToGlobal(Offset.zero) & size;
    final view = Offset.zero & MediaQuery.sizeOf(context);
    final overlap = rect.intersect(view);
    final visible = overlap.width > 0 && overlap.height > 0 ? (overlap.width * overlap.height) / (size.width * size.height) : 0.0;
    if (visible >= 0.5) {
      _fired = true;
      widget.onHalf();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach();
    _schedule();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _schedule();
        return false;
      },
      child: LayoutBuilder(
        builder: (context, _) {
          _schedule();
          return widget.child;
        },
      ),
    );
  }
}
