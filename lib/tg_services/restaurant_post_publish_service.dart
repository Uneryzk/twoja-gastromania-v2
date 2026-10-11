import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/notification_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

/// Next-steps sheet dismissals + day-1 / day-3 detail reminders.
class RestaurantPostPublishService extends ChangeNotifier {
  RestaurantPostPublishService._();
  static final RestaurantPostPublishService instance = RestaurantPostPublishService._();

  /// listingId → times the next-steps sheet was shown (max 2).
  final Map<String, int> _sheetShows = {};
  /// listingId → dismissed card ids that become permanent dashboard cards.
  final Map<String, Set<String>> _dismissedCards = {};
  final Map<String, Set<String>> _reminded = {};

  int sheetShows(String listingId) => _sheetShows[listingId] ?? 0;

  bool canShowNextSteps(String listingId) => sheetShows(listingId) < 2;

  void recordSheetView(String listingId) {
    _sheetShows[listingId] = sheetShows(listingId) + 1;
    TGAnalytics.track('nextsteps_view', {'listingId': listingId, 'n': sheetShows(listingId)});
    notifyListeners();
  }

  void dismissSheet(String listingId, {required bool foreverCards}) {
    TGAnalytics.track('nextsteps_dismiss', {'listingId': listingId, 'foreverCards': foreverCards});
    if (foreverCards) {
      final r = RestaurantService.instance.byId(listingId);
      if (r != null) {
        _dismissedCards.putIfAbsent(listingId, () => {}).add('details');
        if (r.inventory.isNotEmpty) {
          _dismissedCards[listingId]!.add('equipment');
        }
      }
    }
    notifyListeners();
  }

  void dismissCard(String listingId, String cardId) {
    _dismissedCards.putIfAbsent(listingId, () => {}).add(cardId);
    notifyListeners();
  }

  Set<String> dashboardCards(String listingId) => Set.unmodifiable(_dismissedCards[listingId] ?? const {});

  String equipmentCardCopy(RestaurantListing r, {required int freeLeft}) {
    if (r.equipmentIncluded == RestaurantEquipmentIncluded.all) {
      return 'Selling some items separately?';
    }
    if (freeLeft > 0) {
      return 'Your first 3 listings are free. $freeLeft left.';
    }
    return '${TGPricing.listingFeePln} PLN / 30 days each, or Basic Store 199 PLN for up to 15 listings';
  }

  void onClockAdvanced() {
    final now = TGClock.now();
    for (final r in RestaurantService.instance.all) {
      if (r.status != RestaurantListingStatus.active || r.publishedAt == null) continue;
      final age = now.difference(r.publishedAt!).inDays;
      if (age == 1 || age == 3) {
        final key = 'details_$age';
        final seen = _reminded.putIfAbsent(r.id, () => {});
        if (!seen.add(key)) continue;
        if (r.detailsFilledCount >= RestaurantListing.detailsSectionTotal) continue;
        NotificationService.instance.add(
          userId: r.ownerId,
          type: 'resto_details_reminder',
          dealId: r.id,
          title: age == 1 ? 'Add listing details' : 'Still missing listing details?',
          body:
              'Buyers use filters for garden, alcohol permit and play area. Your listing is at ${r.detailsFilledCount}/${RestaurantListing.detailsSectionTotal}.',
          deepLink: '/dashboard/listings?details=${r.id}',
        );
      }
    }
    notifyListeners();
  }

  void reset() {
    _sheetShows.clear();
    _dismissedCards.clear();
    _reminded.clear();
    notifyListeners();
  }

  void ensureSeeded() {
    // Permanent dashboard cards for demo resto with pending sync.
    final r014 = RestaurantService.instance.byId('r014');
    if (r014 != null) {
      _dismissedCards.putIfAbsent('r014', () => {'details', 'equipment'});
      _sheetShows['r014'] = 2;
    }
  }
}
