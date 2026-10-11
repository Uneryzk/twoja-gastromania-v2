import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';

/// Localized restaurant listing title (falls back to stored English seed title).
String restoLocalizedTitle(BuildContext context, RestaurantListing r) {
  final t = context.t('resto_title_${r.listingNo}');
  return t.isEmpty ? r.title : t;
}

/// Short hero/ad title (city-focused).
String restoLocalizedShortTitle(BuildContext context, RestaurantListing r) {
  final t = context.t('resto_title_short_${r.listingNo}');
  if (t.isNotEmpty) return t;
  return restoLocalizedTitle(context, r);
}

String restoLocalizedBusinessType(BuildContext context, RestaurantBusinessType t) {
  final key = switch (t) {
    RestaurantBusinessType.restaurant => 'resto_type_restaurant',
    RestaurantBusinessType.cafe => 'resto_type_cafe',
    RestaurantBusinessType.bar => 'resto_type_bar',
    RestaurantBusinessType.pizzeria => 'resto_type_pizzeria',
    RestaurantBusinessType.fastFood => 'resto_type_fast_food',
    RestaurantBusinessType.bakeryPatisserie => 'resto_type_bakery',
    RestaurantBusinessType.cateringDarkKitchen => 'resto_type_catering',
    RestaurantBusinessType.club => 'resto_type_club',
    RestaurantBusinessType.other => 'resto_type_other',
  };
  final label = context.t(key);
  return label.isEmpty ? RestaurantListing.businessTypeLabel(t) : label;
}

String restoLocalizedInventoryName(BuildContext context, RestaurantInventoryItem item) {
  final t = context.t(item.name);
  return t.isEmpty ? item.name : t;
}

/// Equipment name keys per business type (10–18 items). Values are l10n keys.
List<String> restoEquipmentNameKeys(RestaurantBusinessType type) => switch (type) {
      RestaurantBusinessType.pizzeria => const [
            'resto_eq_pizza_deck_oven',
            'resto_eq_pizza_dough_mixer',
            'resto_eq_pizza_dough_proofer',
            'resto_eq_pizza_cold_table',
            'resto_eq_pizza_ingredient_fridge',
            'resto_eq_pizza_prep_counter',
            'resto_eq_pizza_slicer',
            'resto_eq_pizza_delivery_bags',
            'resto_eq_pizza_exhaust_hood',
            'resto_eq_pizza_dishwasher',
            'resto_eq_pizza_scale',
            'resto_eq_pizza_shelving',
            'resto_eq_pizza_pos',
            'resto_eq_pizza_freezer',
          ],
      RestaurantBusinessType.cafe => const [
            'resto_eq_coffee_espresso',
            'resto_eq_coffee_grinder',
            'resto_eq_coffee_brewers',
            'resto_eq_coffee_fridge_display',
            'resto_eq_coffee_pastry_case',
            'resto_eq_coffee_blender',
            'resto_eq_coffee_ice_machine',
            'resto_eq_coffee_dishwasher',
            'resto_eq_coffee_water_filter',
            'resto_eq_coffee_bar_fridge',
            'resto_eq_coffee_tables',
            'resto_eq_coffee_pos',
          ],
      RestaurantBusinessType.fastFood => const [
            'resto_eq_burger_grill',
            'resto_eq_burger_fryer',
            'resto_eq_burger_flat_top',
            'resto_eq_burger_warmer',
            'resto_eq_burger_prep_fridge',
            'resto_eq_burger_shake_machine',
            'resto_eq_burger_freezer',
            'resto_eq_burger_hood',
            'resto_eq_burger_dishwasher',
            'resto_eq_burger_packaging',
            'resto_eq_burger_pos',
            'resto_eq_burger_soda_fountain',
            'resto_eq_burger_shelving',
            'resto_eq_burger_microwave',
          ],
      RestaurantBusinessType.bar => const [
            'resto_eq_bar_cocktail_station',
            'resto_eq_bar_back_bar_fridge',
            'resto_eq_bar_ice_machine',
            'resto_eq_bar_glasswasher',
            'resto_eq_bar_beer_tap',
            'resto_eq_bar_blender',
            'resto_eq_bar_speed_rail',
            'resto_eq_bar_pos',
            'resto_eq_bar_shelving',
            'resto_eq_bar_freezer',
          ],
      RestaurantBusinessType.bakeryPatisserie => const [
            'resto_eq_bakery_deck_oven',
            'resto_eq_bakery_mixer',
            'resto_eq_bakery_proofer',
            'resto_eq_bakery_display',
            'resto_eq_bakery_fridge',
            'resto_eq_bakery_sheeter',
            'resto_eq_bakery_tables',
            'resto_eq_bakery_dishwasher',
            'resto_eq_bakery_scale',
            'resto_eq_bakery_freezer',
            'resto_eq_bakery_pos',
          ],
      _ => const [
            'resto_eq_resto_combi',
            'resto_eq_resto_range',
            'resto_eq_resto_fryer',
            'resto_eq_resto_fridge',
            'resto_eq_resto_freezer',
            'resto_eq_resto_dishwasher',
            'resto_eq_resto_prep_table',
            'resto_eq_resto_hood',
            'resto_eq_resto_mixer',
            'resto_eq_resto_slicer',
            'resto_eq_resto_ice',
            'resto_eq_resto_shelving',
            'resto_eq_resto_pos',
            'resto_eq_resto_bar_fridge',
          ],
    };

RestaurantInventoryCategory restoEquipmentCategory(String nameKey) {
  if (nameKey.contains('fridge') || nameKey.contains('freezer') || nameKey.contains('cold') || nameKey.contains('display') || nameKey.contains('case') || nameKey.contains('warmer')) {
    return RestaurantInventoryCategory.refrigeration;
  }
  if (nameKey.contains('dishwasher') || nameKey.contains('glasswasher') || nameKey.contains('warewash')) {
    return RestaurantInventoryCategory.warewashing;
  }
  if (nameKey.contains('table') || nameKey.contains('shelving') || nameKey.contains('counter') || nameKey.contains('rail')) {
    return RestaurantInventoryCategory.stainlessFurniture;
  }
  if (nameKey.contains('espresso') || nameKey.contains('coffee') || nameKey.contains('beer') || nameKey.contains('soda') || nameKey.contains('shake') || nameKey.contains('ice') || nameKey.contains('blender') || nameKey.contains('bar_')) {
    return RestaurantInventoryCategory.barBeverage;
  }
  if (nameKey.contains('mixer') || nameKey.contains('slicer') || nameKey.contains('sheeter') || nameKey.contains('scale') || nameKey.contains('dough') || nameKey.contains('prep')) {
    return RestaurantInventoryCategory.foodPrep;
  }
  if (nameKey.contains('pos') || nameKey.contains('bags') || nameKey.contains('packaging') || nameKey.contains('filter')) {
    return RestaurantInventoryCategory.other;
  }
  return RestaurantInventoryCategory.cooking;
}
