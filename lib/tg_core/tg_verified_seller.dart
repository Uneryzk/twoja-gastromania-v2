import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';

/// Green verified shield: NIP-verified store with an active plan only (VITRIN-1).
/// Private sellers never show the shield (VERIFY-1 may restore gated cases later).
bool tgShowsVerifiedSellerBadge(TGSeller seller) {
  if (seller.type != TGSellerType.store) return false;
  final profile = TGSellerProfileService.instance.bySellerKey(seller.id);
  if (profile == null) return false;
  if (profile.nipVerifiedAt == null) return false;
  return profile.plan != null;
}
