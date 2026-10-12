import 'dart:math';

import 'package:twoja_gastromania/tg_models/tg_promotion.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';

/// Single placement engine for homepage, /products, /restaurants (VITRIN-1).
class PromotionEngine {
  PromotionEngine._();

  /// Fair rotation within a tier: session-seeded shuffle, fewer impressions first.
  static List<Promotion> rotateTier(List<Promotion> sameTier, int sessionSeed) {
    if (sameTier.isEmpty) return const [];
    final scored = [...sameTier];
    scored.sort((a, b) {
      final ia = PromotionService.instance.statFor(a.id)?.impressions ?? 0;
      final ib = PromotionService.instance.statFor(b.id)?.impressions ?? 0;
      final c = ia.compareTo(ib);
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });
    // Stable shuffle within equal-impression bands using session seed.
    final rng = Random(sessionSeed ^ sameTier.length * 31);
    final out = <Promotion>[];
    var i = 0;
    while (i < scored.length) {
      var j = i + 1;
      final imp = PromotionService.instance.statFor(scored[i].id)?.impressions ?? 0;
      while (j < scored.length && (PromotionService.instance.statFor(scored[j].id)?.impressions ?? 0) == imp) {
        j++;
      }
      final band = scored.sublist(i, j)..shuffle(rng);
      out.addAll(band);
      i = j;
    }
    return out;
  }

  /// Homepage equipment strip: Spotlight → Glow only, max [homeFeaturedMax]. No Bold.
  static List<PromotionSlot<T>> composeHomeFeatured<T>({
    required List<T> candidates,
    required String Function(T item) idOf,
    required Promotion? Function(T item) promoOf,
    required int sessionSeed,
    int? max,
  }) {
    final cfg = PromotionService.instance.config;
    final limit = max ?? cfg.homeFeaturedMax;
    final byId = {for (final c in candidates) idOf(c): c};
    final promos = <Promotion>[
      for (final c in candidates)
        if (promoOf(c) case final p?)
          if (p.tier == PromotionTier.spotlight || p.tier == PromotionTier.glow) p,
    ];
    final spots = rotateTier([for (final p in promos) if (p.tier == PromotionTier.spotlight) p], sessionSeed);
    final glows = rotateTier([for (final p in promos) if (p.tier == PromotionTier.glow) p], sessionSeed ^ 17);
    final ordered = [...spots, ...glows];
    final out = <PromotionSlot<T>>[];
    final seen = <String>{};
    for (final p in ordered) {
      if (out.length >= limit) break;
      if (!seen.add(p.targetRef)) continue;
      final item = byId[p.targetRef];
      if (item == null) continue;
      out.add(PromotionSlot(item: item, promotion: p));
    }
    return out;
  }

  /// Homepage restaurant strip: Spotlight → Glow, max [homeRestaurantMax].
  static List<PromotionSlot<T>> composeHomeRestaurant<T>({
    required List<T> candidates,
    required String Function(T item) idOf,
    required Promotion? Function(T item) promoOf,
    required int sessionSeed,
    int? max,
  }) =>
      composeHomeFeatured(
        candidates: candidates,
        idOf: idOf,
        promoOf: promoOf,
        sessionSeed: sessionSeed,
        max: max ?? PromotionService.instance.config.homeRestaurantMax,
      );

  /// Catalogue compose for /products and /restaurants.
  ///
  /// Recommended: Spotlight → Glow → Bold (pinned header) → organic, with spotlight repeats.
  /// Other sorts: Spotlight+Glow pinned (max [pinnedMaxOnSort]); Bold stays in organic order.
  static ({List<PromotionSlot<T>> pinned, List<PromotionSlot<T>> feed, List<Promotion> spotlights}) composeCatalogue<T>({
    required List<T> filteredOrganic,
    required String Function(T item) idOf,
    required Promotion? Function(T item) promoOf,
    required PromotionComposeContext context,
  }) {
    final cfg = PromotionService.instance.config;
    final byId = {for (final c in filteredOrganic) idOf(c): c};
    final promos = <Promotion>[
      for (final c in filteredOrganic)
        if (promoOf(c) case final p?) p,
    ];

    final spots = rotateTier([for (final p in promos) if (p.tier == PromotionTier.spotlight) p], context.sessionSeed);
    final glows = rotateTier([for (final p in promos) if (p.tier == PromotionTier.glow) p], context.sessionSeed ^ 41);
    final bolds = rotateTier([for (final p in promos) if (p.tier == PromotionTier.bold) p], context.sessionSeed ^ 73);

    final pinned = <PromotionSlot<T>>[];
    final pinnedIds = <String>{};

    void pushPinned(Promotion p) {
      final item = byId[p.targetRef];
      if (item == null || !pinnedIds.add(p.targetRef)) return;
      pinned.add(PromotionSlot(item: item, promotion: p));
    }

    if (context.sort == PromotionSortMode.recommended) {
      for (final p in spots) {
        pushPinned(p);
      }
      for (final p in glows) {
        pushPinned(p);
      }
      for (final p in bolds) {
        pushPinned(p);
      }
    } else {
      final cap = cfg.pinnedMaxOnSort;
      for (final p in [...spots, ...glows]) {
        if (pinned.length >= cap) break;
        pushPinned(p);
      }
    }

    final organic = <PromotionSlot<T>>[];
    for (final c in filteredOrganic) {
      final id = idOf(c);
      if (pinnedIds.contains(id)) continue;
      final promo = promoOf(c);
      // On non-recommended sorts Bold may appear in organic with title weight only.
      if (context.sort == PromotionSortMode.recommended && promo != null) continue;
      if (context.sort != PromotionSortMode.recommended &&
          promo != null &&
          (promo.tier == PromotionTier.spotlight || promo.tier == PromotionTier.glow)) {
        continue;
      }
      organic.add(PromotionSlot(item: c, promotion: promo?.tier == PromotionTier.bold ? promo : null));
    }

    // Repeats are injected per page at render time so they do not affect page counts.
    final spotOut = context.sort == PromotionSortMode.recommended ? spots : const <Promotion>[];
    return (pinned: pinned, feed: organic, spotlights: spotOut);
  }

  /// Injects Spotlight repeats into one page of organic slots.
  /// Repeats do not count toward pagination totals (call on an already-sliced page).
  static List<PromotionSlot<T>> withSpotlightRepeats<T>({
    required List<PromotionSlot<T>> pageOrganic,
    required List<Promotion> spotlights,
    required Map<String, T> byId,
    required Set<String> alreadyShownOnPage,
    required int page,
    required int sessionSeed,
    int? every,
    int? maxRepeats,
  }) {
    final cfg = PromotionService.instance.config;
    return _injectSpotlightRepeats(
      organic: pageOrganic,
      spotlights: spotlights,
      byId: byId,
      alreadyShown: alreadyShownOnPage,
      every: every ?? cfg.spotlightRepeatEvery,
      maxRepeats: maxRepeats ?? cfg.spotlightRepeatMax,
      page: page,
      sessionSeed: sessionSeed,
    );
  }

  static List<PromotionSlot<T>> _injectSpotlightRepeats<T>({
    required List<PromotionSlot<T>> organic,
    required List<Promotion> spotlights,
    required Map<String, T> byId,
    required Set<String> alreadyShown,
    required int every,
    required int maxRepeats,
    required int page,
    required int sessionSeed,
  }) {
    if (organic.isEmpty || spotlights.isEmpty || every < 1 || maxRepeats < 1) return organic;
    final out = <PromotionSlot<T>>[];
    var standardSince = 0;
    var repeats = 0;
    var cursor = (sessionSeed + page * 7) % spotlights.length;
    String? lastId;
    final shown = {...alreadyShown};

    for (final slot in organic) {
      out.add(slot);
      lastId = slot.promotion?.targetRef ?? lastId;
      if (slot.promotion != null) continue;
      standardSince++;
      if (standardSince < every || repeats >= maxRepeats) continue;
      Promotion? pick;
      for (var n = 0; n < spotlights.length; n++) {
        final cand = spotlights[(cursor + n) % spotlights.length];
        if (cand.targetRef == lastId) continue;
        if (!byId.containsKey(cand.targetRef)) continue;
        // Prefer spotlights not already shown on this page.
        if (shown.contains(cand.targetRef) && n + 1 < spotlights.length) continue;
        pick = cand;
        cursor = (cursor + n + 1) % spotlights.length;
        break;
      }
      pick ??= () {
        for (var n = 0; n < spotlights.length; n++) {
          final cand = spotlights[(cursor + n) % spotlights.length];
          if (cand.targetRef == lastId) continue;
          if (!byId.containsKey(cand.targetRef)) continue;
          cursor = (cursor + n + 1) % spotlights.length;
          return cand;
        }
        return null;
      }();
      if (pick == null) continue;
      final item = byId[pick.targetRef];
      if (item == null) continue;
      out.add(PromotionSlot(item: item, promotion: pick, isRepeat: true));
      lastId = pick.targetRef;
      shown.add(pick.targetRef);
      standardSince = 0;
      repeats++;
    }
    return out;
  }
}
