import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_review_verified.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/review_verified_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

/// Single source of truth for the green shield (badge, tooltip, filters).
///
/// Stores: `company_registry` = NIP verified + active plan.
/// Individuals: `buyer_reviews` = [TGReviewVerifiedService] rule (or admin override).
TGVerifiedBasis? tgVerifiedBasis(TGSeller seller) {
  if (seller.type == TGSellerType.store) {
    final profile = TGSellerProfileService.instance.bySellerKey(seller.id);
    if (profile == null || profile.nipVerifiedAt == null || profile.plan == null) return null;
    return TGVerifiedBasis.companyRegistry;
  }
  return TGReviewVerifiedService.instance.isVerified(seller.id) ? TGVerifiedBasis.buyerReviews : null;
}

bool tgShowsVerifiedSellerBadge(TGSeller seller) => tgVerifiedBasis(seller) != null;

/// [seller] with the live `verifiedBasis` / `verifiedSince` / `reviewStats`.
TGSeller tgWithVerification(TGSeller seller) {
  final basis = tgVerifiedBasis(seller);
  final svc = TGReviewVerifiedService.instance;
  final individual = seller.type == TGSellerType.private;
  return seller.copyWith(
    clearVerifiedBasis: basis == null,
    verifiedBasis: basis,
    verifiedSince: basis == TGVerifiedBasis.buyerReviews ? svc.verifiedSince(seller.id) : null,
    reviewStats: individual && svc.isIndividual(seller.id) ? svc.statsFor(seller.id) : null,
  );
}

TGSeller tgSellerFromProfile(TGStoreProfile p) =>
    TGSeller(id: p.sellerKey, name: p.name, type: p.type, verified: false, rating: p.rating);
