import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_services/promotion_service.dart';

/// Admin-editable [PricingConfig]. Keeps [PromotionService.config] in sync.
class PricingConfigService extends ChangeNotifier {
  PricingConfigService._();
  static final PricingConfigService instance = PricingConfigService._();

  PricingConfig _config = PricingConfig.defaults;

  PricingConfig get config => _config;

  void setConfig(PricingConfig next) {
    _config = next;
    PromotionService.instance.setConfig(next.promotions);
    notifyListeners();
  }

  void resetForTests() {
    _config = PricingConfig.defaults;
    PromotionService.instance.setConfig(_config.promotions);
  }
}
