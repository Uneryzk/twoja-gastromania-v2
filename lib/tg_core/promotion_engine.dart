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

  /// Cards per paid tier (and organic fillers) on homepage category strips.
  static const int homeStripPerGroup = 3;

  /// Dispatches by [surface]. Homepage strips: 3 Spotlight, 3 Glow, 3 Bold, 3 standard.
  static List<PromotionSlot<T>> compose<T>({
    required PromotionSurface surface,
    required List<T> candidates,
    required String Function(T item) idOf,
    required Promotion? Function(T item) promoOf,
    required int sessionSeed,
    PromotionSortMode sort = PromotionSortMode.recommended,
    int page = 1,
  }) {
    switch (surface) {
      case PromotionSurface.home:
      case PromotionSurface.homeFeatured:
        return composeHomeFeatured(candidates: candidates, idOf: idOf, promoOf: promoOf, sessionSeed: sessionSeed);
      case PromotionSurface.homeRestaurant:
        return composeHomeRestaurant(candidates: candidates, idOf: idOf, promoOf: promoOf, sessionSeed: sessionSeed);
      case PromotionSurface.products:
      case PromotionSurface.restaurants:
        return composeCatalogue(
          filteredOrganic: candidates,
          idOf: idOf,
          promoOf: promoOf,
          context: PromotionComposeContext(surface: surface, sort: sort, page: page, sessionSeed: sessionSeed),
        ).pinned;
    }
  }

  /// Homepage category strip: 3 Spotlight, 3 Glow, 3 Bold, then 3 organic/standard.
  static List<PromotionSlot<T>> composeHomeFeatured<T>({
    required List<T> candidates,
    required String Function(T item) idOf,
    required Promotion? Function(T item) promoOf,
    required int sessionSeed,
    int? max,
  }) {
    const per = homeStripPerGroup;
    final limit = max ?? (per * 4);
    final byId = {for (final c in candidates) idOf(c): c};
    final promoOfId = <String, Promotion>{};
    for (final c in candidates) {
      final p = promoOf(c);
      if (p != null) promoOfId[idOf(c)] = p;
    }
    final spots = rotateTier([for (final p in promoOfId.values) if (p.tier == PromotionTier.spotlight) p], sessionSeed);
    final glows = rotateTier([for (final p in promoOfId.values) if (p.tier == PromotionTier.glow) p], sessionSeed ^ 17);
    final bolds = rotateTier([for (final p in promoOfId.values) if (p.tier == PromotionTier.bold) p], sessionSeed ^ 29);
    final out = <PromotionSlot<T>>[];
    final seen = <String>{};

    void takePaid(List<Promotion> list) {
      var n = 0;
      for (final p in list) {
        if (n >= per || out.length >= limit) break;
        if (!seen.add(p.targetRef)) continue;
        final item = byId[p.targetRef];
        if (item == null) continue;
        out.add(PromotionSlot(item: item, promotion: p));
        n++;
      }
    }

    takePaid(spots);
    takePaid(glows);
    takePaid(bolds);

    var organicTaken = 0;
    for (final c in candidates) {
      if (organicTaken >= per || out.length >= limit) break;
      final id = idOf(c);
      if (!seen.add(id)) continue;
      if (promoOfId[id] != null) continue;
      out.add(PromotionSlot(item: c));
      organicTaken++;
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
        max: max ?? (homeStripPerGroup * 4),
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
      var n = 0;
      for (final p in spots) {
        if (n >= homeStripPerGroup) break;
        final before = pinned.length;
        pushPinned(p);
        if (pinned.length > before) n++;
      }
      n = 0;
      for (final p in glows) {
        if (n >= homeStripPerGroup) break;
        final before = pinned.length;
        pushPinned(p);
        if (pinned.length > before) n++;
      }
      n = 0;
      for (final p in bolds) {
        if (n >= homeStripPerGroup) break;
        final before = pinned.length;
        pushPinned(p);
        if (pinned.length > before) n++;
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
      if (context.sort != PromotionSortMode.recommended &&
          promo != null &&
          (promo.tier == PromotionTier.spotlight || promo.tier == PromotionTier.glow)) {
        continue;
      }
      organic.add(PromotionSlot(item: c, promotion: promo));
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
