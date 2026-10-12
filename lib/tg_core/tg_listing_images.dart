import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// Local FlutterFlow / project assets for listings, category tiles and banners.
///
/// **No Unsplash / Picsum / remote placeholders.** Every path is under `assets/images/`.
///
/// Dynamic title/theme matching for listings is **disabled** ([kDisableDynamicListingImages]).
/// Listing / equipment photos must be set manually in admin or seller panels.
class TGListingImages {
  TGListingImages._();

  /// When true, theme/title auto-matching returns empty (or primary-only).
  /// Off: seed / empty listings get a local asset matched by title + category.
  /// Category covers and hero slides stay available as a fixed asset library.
  static const bool kDisableDynamicListingImages = false;

  // ---------------------------------------------------------------------------
  // Category → local asset (ASCII filenames only — missing/Unicode paths broke Image.asset)
  // ---------------------------------------------------------------------------

  static const String cooking = 'assets/images/mutfak-ekipmanlari.jpg';
  static const String refrigeration = 'assets/images/sogutma-dolaplari.jpg';
  static const String warewashing = 'assets/images/food-prep-table.jpg';
  static const String foodPrep = 'assets/images/food-prep-table.jpg';
  static const String stainless = 'assets/images/paslanmaz-raflar.jpeg';
  static const String barCafe = 'assets/images/bar-beverage-equipment.jpg';

  // Venue / equipment photos (local only).
  static const String pizzaGarden = 'assets/images/pizza-with-garden.jpg';
  static const String pizzaColdTop = 'assets/images/nadstawka-chlodnicza-pizza.jpeg';
  static const String coffeeEspresso = 'assets/images/coffee-espresso-machine.jpg';
  static const String coffeeSetup = 'assets/images/coffee-setup.jpg';
  static const String coffeeShop = 'assets/images/specialty-coffee-shop.jpg';
  static const String coffeeListing = 'assets/images/devren-satilik-coffee.jpg';
  static const String pastryCoffee = 'assets/images/devren-satilik-pastane-coffee.jpg';
  static const String burgerGrill = 'assets/images/hamburger-izgarasi.jpeg';
  static const String burgerListing = 'assets/images/devren-satilik-hamburgerci.jpg';
  static const String burgerCorner = 'assets/images/hamburger-kosesi.jpg';
  static const String burgerPrep = 'assets/images/hamburger-hazirlik-dolabi.jpeg';
  static const String milkshake = 'assets/images/milkshake-makinesi.webp';
  static const String freezerVertical = 'assets/images/dikey-dondurucu.jpeg';
  static const String fridge700 = 'assets/images/szafa-chlodnicza-700l.jpeg';
  static const String beverageFridge = 'assets/images/icecek-dolabi.jpeg';
  static const String combiOven = 'assets/images/piec-konwekcyjno-parowy.jpeg';
  static const String microwave = 'assets/images/endustriyel-mikrodalga.jpeg';
  static const String mixer = 'assets/images/elektrikli-firin.webp';
  static const String vacuum = 'assets/images/pakowarka-prozniowa.jpeg';
  static const String shelves = 'assets/images/paslanmaz-raflar.jpeg';
  static const String pos = 'assets/images/pos-terminali.jpeg';
  static const String barEquip = 'assets/images/bar-equipment.jpg';
  static const String wineBar = 'assets/images/wine-bar.jpg';
  static const String cocktailBar = 'assets/images/devren-satilik-kokteyl-bar.jpeg';
  static const String barTips = 'assets/images/bar-kurulumu-ipuclari.jpg';
  static const String familyResto = 'assets/images/family-restaurant.jpg';
  static const String foodHall = 'assets/images/food-hall-booth.jpg';
  static const String productionKitchen = 'assets/images/production-kitchen.jpg';
  static const String restoKitchen = 'assets/images/restaurant-kitchen.jpg';
  static const String mutfakEquip = 'assets/images/mutfak-ekipmanlari.jpg';
  static const String terraceResto = 'assets/images/devren-terasli-restoran.png';
  static const String bannerKitchen = 'assets/images/banner-mutfak-ekipmanlari.jpg';
  static const String bainMarie = 'assets/images/bain-marie.png';
  static const String blog26 = 'assets/images/banner-mutfak-ekipmanlari.jpg';
  static const String imagesJpeg = 'assets/images/restaurant-kitchen.jpg';
  static const String endustriyel = 'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg';
  static const String img3696 = 'assets/images/szafa-chlodnicza-700l.jpeg';
  static const String thumb405 = 'assets/images/coffee-espresso-machine.jpg';
  static const String imagePng = 'assets/images/image.png';
  static const String hex10 = 'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg';
  static const String paslanmazEquip = 'assets/images/paslanmaz-ekipmanlar.jpg';
  static const String elektrikliFirin = 'assets/images/elektrikli-firin.webp';
  static const String aspirator = 'assets/images/aspirator.jpeg';
  static const String barFridge = 'assets/images/bar-buzdolabi.jpeg';
  static const String iceMachine = 'assets/images/buz-makinesi.jpeg';
  static const String meatSlicer = 'assets/images/et-dilimleyicisi.jpeg';
  static const String planetMixer = 'assets/images/planet-mikser.jpeg';

  /// Paths that exist under `assets/images/` and are safe for [Image.asset].
  /// Unique string literals only (aliases like [warewashing]/[foodPrep] share a path).
  static const Set<String> bundledAssets = {
    'assets/images/mutfak-ekipmanlari.jpg',
    'assets/images/mutfak-ekipmanlari-2.jpg',
    'assets/images/sogutma-dolaplari.jpg',
    'assets/images/food-prep-table.jpg',
    'assets/images/paslanmaz-raflar.jpeg',
    'assets/images/paslanmaz-ekipmanlar.jpg',
    'assets/images/bar-beverage-equipment.jpg',
    'assets/images/pizza-with-garden.jpg',
    'assets/images/nadstawka-chlodnicza-pizza.jpeg',
    'assets/images/coffee-espresso-machine.jpg',
    'assets/images/coffee-setup.jpg',
    'assets/images/specialty-coffee-shop.jpg',
    'assets/images/devren-satilik-coffee.jpg',
    'assets/images/devren-satilik-coffee.webp',
    'assets/images/devren-satilik-pastane-coffee.jpg',
    'assets/images/hamburger-izgarasi.jpeg',
    'assets/images/devren-satilik-hamburgerci.jpg',
    'assets/images/hamburger-kosesi.jpg',
    'assets/images/hamburger-hazirlik-dolabi.jpeg',
    'assets/images/milkshake-makinesi.webp',
    'assets/images/dikey-dondurucu.jpeg',
    'assets/images/szafa-chlodnicza-700l.jpeg',
    'assets/images/icecek-dolabi.jpeg',
    'assets/images/piec-konwekcyjno-parowy.jpeg',
    'assets/images/endustriyel-mikrodalga.jpeg',
    'assets/images/elektrikli-firin.webp',
    'assets/images/pakowarka-prozniowa.jpeg',
    'assets/images/pos-terminali.jpeg',
    'assets/images/bar-equipment.jpg',
    'assets/images/bar-setup.jpg',
    'assets/images/bar-kurulumu-ipuclari.jpg',
    'assets/images/wine-bar.jpg',
    'assets/images/devren-satilik-kokteyl-bar.jpeg',
    'assets/images/family-restaurant.jpg',
    'assets/images/food-hall-booth.jpg',
    'assets/images/production-kitchen.jpg',
    'assets/images/restaurant-kitchen.jpg',
    'assets/images/devren-terasli-restoran.png',
    'assets/images/banner-mutfak-ekipmanlari.jpg',
    'assets/images/bain-marie.png',
    'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg',
    'assets/images/image.png',
    'assets/images/espresso-makinesi.jpeg',
    'assets/images/yemek-isiticlari.jpg',
    'assets/images/aspirator.jpeg',
    'assets/images/bar-buzdolabi.jpeg',
    'assets/images/buz-makinesi.jpeg',
    'assets/images/et-dilimleyicisi.jpeg',
    'assets/images/planet-mikser.jpeg',
  };

  /// Drop missing / renamed assets so galleries never show broken placeholders.
  static String ensureBundled(String path, {String fallback = mutfakEquip}) {
    final p = path.trim();
    if (p.isEmpty) return fallback;
    if (p.startsWith('http://') || p.startsWith('https://') || p.startsWith('data:')) return p;
    if (bundledAssets.contains(p)) return p;
    return fallback;
  }

  static List<String> onlyBundled(Iterable<String> paths, {String fallback = mutfakEquip}) {
    final out = <String>[];
    for (final raw in paths) {
      final p = raw.trim();
      if (p.isEmpty) continue;
      final next = ensureBundled(p, fallback: '');
      if (next.isEmpty) continue;
      if (!out.contains(next)) out.add(next);
    }
    if (out.isEmpty) out.add(fallback);
    return out;
  }

  /// All six category covers (stable order for hero rotation).
  static const List<String> allFixed = [
    cooking,
    refrigeration,
    warewashing,
    foodPrep,
    stainless,
    barCafe,
  ];

  /// Featured Offers / category tiles — fixed local paths only.
  static const Map<TGCategory, String> categoryCoverUrls = {
    TGCategory.cookingEquipment: mutfakEquip,
    TGCategory.refrigerationEquipment: fridge700,
    TGCategory.warewashing: warewashing,
    TGCategory.foodPreparation: foodPrep,
    TGCategory.stainlessSteelFurniture: shelves,
    TGCategory.barAndBeverageEquipment: coffeeEspresso,
  };

  /// Shared local gallery pool (gastronomy assets only).
  static const List<String> listingPool = [
    mutfakEquip,
    restoKitchen,
    combiOven,
    fridge700,
    freezerVertical,
    warewashing,
    foodPrep,
    shelves,
    coffeeEspresso,
    barEquip,
    pizzaGarden,
    burgerGrill,
    productionKitchen,
    bainMarie,
    mixer,
    microwave,
    beverageFridge,
    pos,
    bannerKitchen,
    endustriyel,
  ];

  static const List<String> _poolPizza = [
    pizzaGarden, pizzaColdTop, combiOven, fridge700, freezerVertical, mixer, shelves, warewashing, pos, foodPrep,
  ];
  static const List<String> _poolCafe = [
    coffeeListing, coffeeEspresso, coffeeSetup, coffeeShop, pastryCoffee, beverageFridge, milkshake, freezerVertical, pos, barEquip,
  ];
  static const List<String> _poolBurger = [
    burgerListing, burgerCorner, burgerGrill, burgerPrep, milkshake, freezerVertical, microwave, foodHall, pos, shelves,
  ];
  static const List<String> _poolBar = [
    cocktailBar, wineBar, barEquip, barTips, beverageFridge, coffeeEspresso, freezerVertical, pos, shelves, milkshake,
  ];
  static const List<String> _poolBakery = [
    pastryCoffee, combiOven, mixer, fridge700, freezerVertical, foodPrep, shelves, coffeeEspresso, pos, vacuum,
  ];
  static const List<String> _poolCatering = [
    productionKitchen, restoKitchen, combiOven, fridge700, freezerVertical, mixer, vacuum, shelves, warewashing, mutfakEquip,
  ];
  static const List<String> _poolRestaurant = [
    terraceResto, familyResto, restoKitchen, mutfakEquip, combiOven, fridge700, freezerVertical, warewashing, foodPrep, barEquip,
  ];
  static const List<String> _poolFridge = [fridge700, freezerVertical, beverageFridge, pizzaColdTop, burgerPrep, refrigeration, img3696];
  static const List<String> _poolCooking = [combiOven, mutfakEquip, burgerGrill, restoKitchen, endustriyel, cooking, microwave, bannerKitchen];
  static const List<String> _poolWarewash = [warewashing, foodPrep, shelves, stainless, restoKitchen];
  static const List<String> _poolPrep = [foodPrep, mixer, vacuum, bainMarie, shelves, stainless, microwave];
  static const List<String> _poolInox = [shelves, stainless, foodPrep, restoKitchen, mutfakEquip];

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  static String cover({
    required String id,
    required TGCategory category,
    String? title,
    int width = 1200,
    int height = 800,
  }) {
    if (kDisableDynamicListingImages) return '';
    return _assetFor(category: category, title: title);
  }

  static String coverForTheme({
    required String id,
    required String theme,
    String? title,
    int width = 1200,
    int height = 800,
    int index = 0,
  }) {
    if (kDisableDynamicListingImages) return '';
    return _poolForTheme(_normalizeTheme(theme, title)).first;
  }

  static List<String> gallery({
    required String id,
    required TGCategory category,
    String? title,
    int count = 4,
    int width = 1200,
    int height = 800,
  }) {
    if (kDisableDynamicListingImages) return const [];
    final theme = _themeForCategory(category, title);
    return _galleryFromPool(id: id, pool: _poolForTheme(theme), count: count);
  }

  /// Gallery that keeps an existing seed [primary] as the first photo.
  /// With dynamic matching off, returns only the stored primary (no pool fill).
  static List<String> galleryWithPrimary({
    required String primary,
    required String id,
    required TGCategory category,
    String? title,
    int count = 4,
  }) {
    if (kDisableDynamicListingImages) {
      final p = primary.trim();
      return p.isEmpty ? const [] : [p];
    }
    final theme = _themeForCategory(category, title);
    final pool = _poolForTheme(theme);
    final cover = primary.startsWith('assets/') ? primary : pool.first;
    return _galleryFromPool(id: id, pool: pool, count: count, primary: cover);
  }

  static List<String> galleryForTheme({
    required String id,
    required String theme,
    String? title,
    int count = 4,
    int width = 1200,
    int height = 800,
  }) {
    if (kDisableDynamicListingImages) return const [];
    final key = _normalizeTheme(theme, title);
    return _galleryFromPool(id: id, pool: _poolForTheme(key), count: count);
  }

  static String forIndex({
    required String id,
    required TGCategory category,
    String? title,
    int index = 0,
    int width = 1200,
    int height = 800,
  }) {
    if (kDisableDynamicListingImages) return '';
    final g = gallery(id: id, category: category, title: title, count: (index + 1).clamp(1, 12));
    if (g.isEmpty) return '';
    return g[index.clamp(0, g.length - 1)];
  }

  static String categoryCover(TGCategory category, {int width = 1200, int height = 800}) =>
      categoryCoverUrls[category] ?? cooking;

  /// Home hero slides — local industrial-kitchen / venue assets only.
  static String heroSlide(int index, {int width = 1200, int height = 800}) {
    const heroes = [
      bannerKitchen,
      terraceResto,
      mutfakEquip,
      productionKitchen,
    ];
    return heroes[index.abs() % heroes.length];
  }

  /// Best local photo for a restaurant inventory name key (`resto_eq_...`).
  /// Matches near-named files in `assets/images/` (buz makinesi, planet mikser, …).
  static String forEquipmentKey(String nameKey) {
    final k = nameKey.toLowerCase();
    if (k.contains('espresso') || k.contains('coffee_grinder') || k.contains('coffee_brew')) return coffeeEspresso;
    if (k.contains('ice_machine') || k.endsWith('_ice') || k.contains('kostkarka') || k.contains('buz_makine')) {
      return iceMachine;
    }
    if (k.contains('slicer') || k.contains('dilim') || k.contains('krajalnic')) return meatSlicer;
    if (k.contains('dough_mixer') || k.contains('planet') || k.contains('mixer') || k.contains('sheeter') || k.contains('mikser')) {
      return planetMixer;
    }
    if (k.contains('hood') || k.contains('exhaust') || k.contains('aspirator') || k.contains('okap')) return aspirator;
    if (k.contains('dishwasher') || k.contains('glasswasher') || k.contains('warewash') || k.contains('bulasik') || k.contains('zmywarka')) {
      return warewashing;
    }
    if (k.contains('prep_fridge') || k.contains('burger_prep') || k.contains('warmer')) return burgerPrep;
    if (k.contains('pizza_cold') || k.contains('ingredient_fridge') || k.contains('cold_table')) return pizzaColdTop;
    if (k.contains('freezer') || k.contains('dondurucu') || k.contains('zamraz')) return freezerVertical;
    if (k.contains('bar_fridge') || k.contains('back_bar') || k.contains('resto_bar_fridge')) return barFridge;
    if (k.contains('coffee_fridge') || k.contains('pastry_case') || k.contains('display')) return beverageFridge;
    if (k.contains('fridge') || k.contains('buzdolab') || k.contains('chlodnic') || k.contains('lodowka')) {
      return refrigeration;
    }
    if (k.contains('prep_table') || k.contains('prep_counter') || k.contains('tables') || (k.contains('table') && k.contains('prep'))) {
      return foodPrep;
    }
    if (k.contains('shake') || k.contains('blender') || k.contains('soda')) return milkshake;
    if (k.contains('grill') || k.contains('flat_top') || k.contains('fryer') || k.contains('range')) return burgerGrill;
    if (k.contains('deck_oven') || k.contains('combi') || k.contains('oven') || k.contains('pizza')) return combiOven;
    if (k.contains('shelving') || k.contains('counter') || k.contains('rail') || k.contains('table')) return shelves;
    if (k.contains('microwave')) return microwave;
    if (k.contains('vacuum') || k.contains('packaging')) return vacuum;
    if (k.contains('pos')) return pos;
    if (k.contains('beer') || k.contains('cocktail') || k.contains('bar_')) return barEquip;
    return mutfakEquip;
  }

  /// Prefer stored photos; otherwise pick a bundled asset from the equipment key.
  static List<String> photosForInventory({required String nameKey, List<String> photos = const []}) {
    final cleaned = [for (final p in photos) p.trim()].where((p) => p.isNotEmpty).toList();
    if (cleaned.isNotEmpty) return onlyBundled(cleaned, fallback: forEquipmentKey(nameKey));
    return [forEquipmentKey(nameKey)];
  }

  static String themeKey({TGCategory? category, String? label, String? title}) {
    if (label != null && label.trim().isNotEmpty) return _normalizeTheme(label, title);
    if (category != null) return _themeForCategory(category, title);
    return _normalizeTheme('', title);
  }

  static String normalizeCategory(String category, [String? title]) => _normalizeTheme(category, title);

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static List<String> _galleryFromPool({
    required String id,
    required List<String> pool,
    required int count,
    String? primary,
  }) {
    final safePool = onlyBundled(pool);
    if (safePool.isEmpty) return primary != null && primary.isNotEmpty ? onlyBundled([primary]) : [mutfakEquip];
    final n = count.clamp(1, 12);
    final out = <String>[];
    if (primary != null && primary.isNotEmpty) {
      final cover = ensureBundled(primary);
      out.add(cover);
    }
    final start = id.hashCode.abs();
    for (var i = 0; i < safePool.length && out.length < n; i++) {
      final next = safePool[(start + i) % safePool.length];
      if (!out.contains(next)) out.add(next);
    }
    if (out.isEmpty) out.add(safePool.first);
    return out;
  }

  static List<String> _poolForTheme(String theme) => switch (theme) {
        'pizzeria' || 'pizza' => _poolPizza,
        'cafe' => _poolCafe,
        'bakery_patisserie' || 'bakery' => _poolBakery,
        'fast_food' || 'burger' => _poolBurger,
        'bar' || 'club' => _poolBar,
        'catering_dark_kitchen' || 'catering' => _poolCatering,
        'restaurant' || 'other' => _poolRestaurant,
        'fridge' => _poolFridge,
        'warewash' => _poolWarewash,
        'prep' => _poolPrep,
        'inox' => _poolInox,
        'cooking' || 'oven' || 'default' => _poolCooking,
        _ => listingPool,
      };

  /// Best single asset for a listing title (krajalnica → prep, mikser → mixer, …).
  static String bestForTitle(String? title, {TGCategory? category}) {
    final specific = _titleAsset(title);
    if (specific != null) return specific;
    if (category != null) return _assetFor(category: category, title: title);
    return mutfakEquip;
  }

  static String? _titleAsset(String? title) {
    if (title == null || title.trim().isEmpty) return null;
    final t = _fold(title);
    if (_any(t, const ['mikser', 'mixer', 'planetarn'])) return mixer;
    if (_any(t, const ['bemar', 'bain-marie', 'bain marie', 'wanna bemar'])) return bainMarie;
    if (_any(t, const ['krajalnic', 'slicer', 'dilim'])) return foodPrep;
    if (_any(t, const ['zmywarka', 'dishwasher', 'bulasik', 'bulaşık', 'warewash'])) return warewashing;
    if (_any(t, const ['stol', 'stół', 'table', 'tezgah', 'roboczy'])) return stainless;
    if (_any(t, const ['szafa chlod', 'szafa chłod', 'fridge', 'chlodnic', 'chłodnic', 'freezer', 'dondur'])) {
      return fridge700;
    }
    if (_any(t, const ['piec', 'oven', 'combi', 'firin', 'fırın', 'rational'])) return combiOven;
    if (_any(t, const ['espresso', 'coffee', 'kahve', 'kawa'])) return coffeeEspresso;
    if (_any(t, const ['vacuum', 'pakowarka', 'prozniow', 'próżniow'])) return vacuum;
    if (_any(t, const ['mikrodalga', 'microwave', 'mikrofal'])) return microwave;
    return null;
  }

  static String _assetFor({required TGCategory category, String? title}) {
    final specific = _titleAsset(title);
    if (specific != null) return specific;
    final theme = _themeForCategory(category, title);
    return _poolForTheme(theme).first;
  }

  static String _themeForCategory(TGCategory category, String? title) {
    final fromTitle = _normalizeTheme('', title);
    if (fromTitle != 'default') return fromTitle;
    return _categoryBaseKey(category);
  }

  static String _categoryBaseKey(TGCategory c) => switch (c) {
        TGCategory.cookingEquipment => 'cooking',
        TGCategory.refrigerationEquipment => 'fridge',
        TGCategory.warewashing => 'warewash',
        TGCategory.foodPreparation => 'prep',
        TGCategory.stainlessSteelFurniture => 'inox',
        TGCategory.barAndBeverageEquipment => 'bar',
      };

  static String _normalizeTheme(String category, String? title) {
    final t = _fold('${category.toLowerCase()} ${title?.toLowerCase() ?? ''}');

    // Business-type slugs from restaurant hub (exact).
    final slug = category.toLowerCase().trim();
    if (slug == 'pizzeria' || slug == 'pizza') return 'pizzeria';
    if (slug == 'cafe' || slug == 'café') return 'cafe';
    if (slug == 'fast_food' || slug == 'fastfood') return 'fast_food';
    if (slug == 'bar') return 'bar';
    if (slug == 'bakery_patisserie' || slug == 'bakery') return 'bakery_patisserie';
    if (slug == 'catering_dark_kitchen' || slug == 'catering') return 'catering_dark_kitchen';
    if (slug == 'restaurant') return 'restaurant';
    if (slug == 'club') return 'bar';
    if (slug == 'other') return 'restaurant';

    if (_any(t, const [
      'dishwasher', 'zmywarka', 'bulasik', 'bulaşık', 'warewash', 'sink', 'zlew',
      'hobart', 'oztiryak', 'öztiryak', 'warewashing',
    ])) {
      return 'warewash';
    }
    if (_any(t, const ['pizzer', 'pizza'])) return 'pizzeria';
    if (_any(t, const ['hamburger', 'burger', 'fast food', 'fast_food', 'grill', 'fryer', 'griddle'])) {
      return 'fast_food';
    }
    if (_any(t, const [
      'espresso', 'coffee', 'kahve', 'kawa', 'cafe', 'café', 'kawiarn',
      'barista', 'mlynek', 'młynek', 'kolbowy',
    ])) {
      return 'cafe';
    }
    if (_any(t, const [
      'beverage', 'napoj', 'napój', 'cocktail', 'koktajl', 'wine', 'wino', 'icecek', 'içecek',
    ]) ||
        _hasWord(t, 'bar')) {
      return 'bar';
    }
    if (_any(t, const [
      'bakery', 'piekarnia', 'pastry', 'cukierni', 'patisserie', 'bread', 'chleb', 'pastane',
    ])) {
      return 'bakery_patisserie';
    }
    if (_any(t, const ['catering', 'dark kitchen', 'production kitchen'])) {
      return 'catering_dark_kitchen';
    }
    if (_any(t, const [
      'oven', 'piec', 'firin', 'fırın', 'combi', 'konwekcyj', 'konveksiyon',
      'steam oven', 'piekarnik', 'rational', 'icomb', 'ocak', 'palnik', 'gazowa',
      'cook', 'pisir', 'pişir', 'kuchnia', 'cooking', 'range', 'pisirme', 'pişirme',
    ])) {
      return 'cooking';
    }
    if (_any(t, const [
      'fridge', 'chlod', 'chłod', 'szafa chlod', 'szafa chłod', 'refriger',
      'freezer', 'mrozn', 'mroź', 'witryna', 'sogut', 'soğut', 'buzdol',
      'cold room', 'komora chlod', 'komora chłod', 'nadstawka', 'refrigeration',
      'cooling', 'sogutma', 'soğutma', 'dondurucu',
    ])) {
      return 'fridge';
    }
    if (_any(t, const [
      'stainless', 'inox', 'nierdzew', 'paslanmaz', 'stol', 'stół', 'tezgah',
      'blat', 'regał', 'regal', 'table', 'okap', 'hood', 'furniture', 'mobilya',
      'stainless steel',
    ])) {
      return 'inox';
    }
    if (_any(t, const [
      'bemar', 'bain-marie', 'krajalnic', 'mixer', 'mikser', 'prep',
      'hazirla', 'hazırla', 'przygotow', 'food prep', 'pakowarka', 'vacuum',
      'food preparation', 'preparation', 'hazirlama', 'hazırlama',
    ])) {
      return 'prep';
    }
    if (_any(t, const [
      'restaurant', 'restoran', 'restauracj', 'dining', 'gastro', 'lokale',
      'lokal ', 'cooking equipment',
    ])) {
      return 'restaurant';
    }
    if (_any(t, const ['bar & beverage', 'bar and beverage', 'beverage equipment'])) return 'bar';
    return 'default';
  }

  static bool _any(String haystack, List<String> needles) {
    for (final n in needles) {
      if (haystack.contains(_fold(n))) return true;
    }
    return false;
  }

  static bool _hasWord(String haystack, String word) {
    final w = _fold(word);
    final re = RegExp('(?:^|[^a-z0-9])$w(?:[^a-z0-9]|\$)');
    return re.hasMatch(haystack);
  }

  static String _fold(String input) {
    final lower = input.toLowerCase();
    final buf = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(_diacritics[ch] ?? ch);
    }
    return buf.toString();
  }

  static const Map<String, String> _diacritics = {
    'ą': 'a', 'ć': 'c', 'ę': 'e', 'ł': 'l', 'ń': 'n', 'ó': 'o', 'ś': 's', 'ź': 'z', 'ż': 'z',
    'á': 'a', 'ä': 'a', 'à': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'ë': 'e', 'è': 'e', 'ê': 'e',
    'í': 'i', 'ï': 'i', 'ì': 'i', 'î': 'i',
    'ö': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o',
    'ü': 'u', 'ù': 'u', 'û': 'u',
    'ç': 'c', 'ñ': 'n',
    'ş': 's', 'ğ': 'g', 'ı': 'i',
  };
}
