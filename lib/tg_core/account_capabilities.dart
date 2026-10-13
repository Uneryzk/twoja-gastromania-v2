import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_services/deal_service.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';
import 'package:twoja_gastromania/tg_services/priority_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';
import 'package:twoja_gastromania/tg_services/revenue_config_service.dart';
import 'package:twoja_gastromania/tg_models/tg_referral.dart';
import 'package:twoja_gastromania/tg_services/referral_repository.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

/// What the signed-in account can do / has data for. Drives the dashboard
/// sidebar, Overview cards and the Dev Switcher personas.
///
/// Every flag is derived from service data for [FakeAuthState.userId]; nothing
/// is hard-coded per persona. In production mode all mock data is off, so only
/// the role flags survive and the dashboard falls back to its empty states.
@immutable
class AccountCapabilities {
  const AccountCapabilities({
    this.isSeller = false,
    this.hasRestaurantListing = false,
    this.store = false,
    this.manufacturerEligible = false,
    this.hasPriority = false,
    this.founderEnrolled = false,
    this.isBuyerActive = false,
    this.isModerator = false,
    this.isAdmin = false,
    this.hasMessages = false,
    this.isRepresentative = false,
    this.repProfile,
  });

  final bool isSeller;
  final bool hasRestaurantListing;
  final bool store;
  final bool manufacturerEligible;
  final bool hasPriority;
  final bool founderEnrolled;
  final bool isBuyerActive;
  final bool isModerator;
  final bool isAdmin;
  final bool hasMessages;
  final bool isRepresentative;
  final TGRepresentative? repProfile;

  bool get isStaff => isModerator || isAdmin;

  /// No selling, buying or messaging history at all.
  bool get isNewUser =>
      !isStaff && !isSeller && !hasRestaurantListing && !store && !isBuyerActive && !hasMessages;

  static AccountCapabilities of(FakeAuthState auth) {
    if (!auth.isLoggedIn) return const AccountCapabilities();
    final id = auth.userId;
    final isModerator = auth.role == TGUserRole.moderator;
    final isAdmin = auth.role == TGUserRole.admin;
    ReferralRepository.instance.ensureSeeded();
    final rep = ReferralRepository.instance.profileForUser(id);
    if (TGRevenueConfigService.instance.productionMode) {
      return AccountCapabilities(isModerator: isModerator, isAdmin: isAdmin, isRepresentative: rep != null, repProfile: rep);
    }
    final restos = RestaurantService.instance.ownedBy(id).isNotEmpty;
    final store = auth.storePlan != null;
    final sellerRole = auth.role == TGUserRole.seller || auth.role == TGUserRole.storeSeller;
    final isSeller = sellerRole && (auth.ownedListings.isNotEmpty || auth.freeSlotsUsed > 0 || store || restos);
    final profile = TGSellerProfileService.instance.bySellerKey(id);
    final manufacturer = store &&
        profile != null &&
        TGSellerProfileService.instance.specialOrderManufacturers.any((p) => p.sellerKey == id);
    final deals = DealService.instance..ensureSeeded();
    final buyer = deals.forBuyer(id).isNotEmpty ||
        deals.reviewsForBuyer(id).isNotEmpty ||
        TGSpecialOrderService.instance.forBuyer(id).isNotEmpty;
    return AccountCapabilities(
      isSeller: isSeller,
      hasRestaurantListing: restos,
      store: store,
      manufacturerEligible: manufacturer,
      hasPriority: store && TGPriorityService.instance.hasPrioritySeat(id),
      founderEnrolled: store && TGFounderService.instance.founderFor(id).enrolled,
      isBuyerActive: buyer,
      isModerator: isModerator,
      isAdmin: isAdmin,
      hasMessages: MessagingService.instance.inboxFor(id).isNotEmpty,
      isRepresentative: rep != null,
      repProfile: rep,
    );
  }

  Map<String, bool> toMap() => {
        'isSeller': isSeller,
        'hasRestaurantListing': hasRestaurantListing,
        'store': store,
        'manufacturerEligible': manufacturerEligible,
        'hasPriority': hasPriority,
        'founderEnrolled': founderEnrolled,
        'isBuyerActive': isBuyerActive,
        'isModerator': isModerator,
        'isAdmin': isAdmin,
        'isRepresentative': isRepresentative,
      };
}
