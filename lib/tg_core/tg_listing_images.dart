import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// Local FlutterFlow / project assets for listings, category tiles and banners.
///
/// **No Unsplash / Picsum / remote placeholders.** Every path is under `assets/images/`.
class TGListingImages {
  TGListingImages._();

  // ---------------------------------------------------------------------------
  // Category → original local asset (FlutterFlow marketplace art)
  // ---------------------------------------------------------------------------

  static const String cooking = 'assets/images/bartscher_2002170.webp';
  static const String refrigeration = 'assets/images/IMG_20200120_131650.jpg';
  static const String warewashing =
      'assets/images/oztiryakiler-sanayi-tipi-bulasik-yikama-makinesitouch-ekran-oby-50t-tahliye-pompali-tezgah-alti-bulasik-makineleri-oztiryakiler-52978-19-B.webp';
  static const String foodPrep = 'assets/images/Food_Prepering_table.jpg';
  static const String stainless = 'assets/images/stainless_steel_table_Food_Preparation_table_gastronomi.jpg';
  static const String barCafe = 'assets/images/Bar_&_Beverage_Equipment.jpg';

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
    TGCategory.cookingEquipment: cooking,
    TGCategory.refrigerationEquipment: refrigeration,
    TGCategory.warewashing: warewashing,
    TGCategory.foodPreparation: foodPrep,
    TGCategory.stainlessSteelFurniture: stainless,
    TGCategory.barAndBeverageEquipment: barCafe,
  };

  /// Shared local gallery pool (gastronomy assets only).
  static const List<String> listingPool = [
    cooking,
    stainless,
    warewashing,
    refrigeration,
    'assets/images/pol_pm_Wanna-bemarowa-3X-GN-1-1-Komat-KCB-001-031-2808_2.png',
    'assets/images/blog-26.jpg',
    'assets/images/images.jpeg',
    'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg',
    'assets/images/IMG_3696-scaled.webp',
    'assets/images/17594161762353ebc282350944289b81f72b29ad94_square_thumbnail_405x552.jpg',
    foodPrep,
    'assets/images/image.png',
    'assets/images/10befb6d92142e17d926d07d605d82d8.jpg',
    barCafe,
  ];

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  static String cover({
    required String id,
    required TGCategory category,
    String? title,
    int width = 1200,
    int height = 800,
  }) =>
      _assetFor(category: category, title: title);

  static String coverForTheme({
    required String id,
    required String theme,
    String? title,
    int width = 1200,
    int height = 800,
    int index = 0,
  }) =>
      _assetForTheme(_normalizeTheme(theme, title));

  static List<String> gallery({
    required String id,
    required TGCategory category,
    String? title,
    int count = 4,
    int width = 1200,
    int height = 800,
  }) {
    final n = count.clamp(1, 12);
    final cover = _assetFor(category: category, title: title);
    final out = <String>[cover];
    final start = id.hashCode.abs();
    for (var i = 0; i < listingPool.length && out.length < n; i++) {
      final next = listingPool[(start + i) % listingPool.length];
      if (!out.contains(next)) out.add(next);
    }
    while (out.length < n) {
      out.add(cover);
    }
    // Prefer listing-specific seed cover when caller already set imageUrl via gallery[0]=cover.
    return out;
  }

  /// Gallery that keeps an existing seed [primary] as the first photo.
  static List<String> galleryWithPrimary({
    required String primary,
    required String id,
    required TGCategory category,
    String? title,
    int count = 4,
  }) {
    final n = count.clamp(1, 12);
    final out = <String>[if (primary.startsWith('assets/')) primary else _assetFor(category: category, title: title)];
    final start = id.hashCode.abs();
    for (var i = 0; i < listingPool.length && out.length < n; i++) {
      final next = listingPool[(start + i) % listingPool.length];
      if (!out.contains(next)) out.add(next);
    }
    while (out.length < n) {
      out.add(out.first);
    }
    return out;
  }

  static List<String> galleryForTheme({
    required String id,
    required String theme,
    String? title,
    int count = 4,
    int width = 1200,
    int height = 800,
  }) {
    final key = _normalizeTheme(theme, title);
    // Map theme → nearest TGCategory for gallery fill.
    final cat = switch (key) {
      'fridge' => TGCategory.refrigerationEquipment,
      'warewash' => TGCategory.warewashing,
      'prep' || 'bakery' => TGCategory.foodPreparation,
      'inox' => TGCategory.stainlessSteelFurniture,
      'bar' || 'cafe' => TGCategory.barAndBeverageEquipment,
      _ => TGCategory.cookingEquipment,
    };
    return gallery(id: id, category: cat, title: title, count: count);
  }

  static String forIndex({
    required String id,
    required TGCategory category,
    String? title,
    int index = 0,
    int width = 1200,
    int height = 800,
  }) {
    final g = gallery(id: id, category: category, title: title, count: (index + 1).clamp(1, 12));
    return g[index.clamp(0, g.length - 1)];
  }

  static String categoryCover(TGCategory category, {int width = 1200, int height = 800}) =>
      categoryCoverUrls[category] ?? cooking;

  /// Home hero slides — local industrial-kitchen assets only.
  static String heroSlide(int index, {int width = 1200, int height = 800}) {
    const heroes = [
      'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg',
      'assets/images/blog-26.jpg',
      'assets/images/17594161762353ebc282350944289b81f72b29ad94_square_thumbnail_405x552.jpg',
      'assets/images/IMG_3696-scaled.webp',
    ];
    return heroes[index.abs() % heroes.length];
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

  static String _assetFor({required TGCategory category, String? title}) {
    final theme = _themeForCategory(category, title);
    return _assetForTheme(theme);
  }

  static String _assetForTheme(String theme) => switch (theme) {
        'cooking' || 'oven' || 'pizza' || 'restaurant' || 'default' => cooking,
        'fridge' => refrigeration,
        'warewash' => warewashing,
        'prep' || 'bakery' => foodPrep,
        'inox' => stainless,
        'bar' || 'cafe' => barCafe,
        _ => cooking,
      };

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

    if (_any(t, const [
      'dishwasher', 'zmywarka', 'bulasik', 'bulaşık', 'warewash', 'sink', 'zlew',
      'hobart', 'oztiryak', 'öztiryak', 'warewashing',
    ])) {
      return 'warewash';
    }
    if (_any(t, const [
      'oven', 'piec', 'firin', 'fırın', 'combi', 'konwekcyj', 'konveksiyon',
      'steam oven', 'piekarnik', 'rational', 'icomb', 'ocak', 'palnik', 'gazowa',
      'fryer', 'frytown', 'griddle', 'grill', 'cook', 'pisir', 'pişir', 'kuchnia',
      'cooking', 'range', 'pisirme', 'pişirme', 'pizza', 'pizzer',
    ])) {
      return 'cooking';
    }
    if (_any(t, const [
      'espresso', 'coffee', 'kahve', 'kawa', 'cafe', 'café', 'kawiarn',
      'barista', 'mlynek', 'młynek', 'kolbowy', 'beverage', 'napoj',
      'napój', 'cocktail', 'koktajl', 'wine', 'wino', 'icecek', 'içecek',
    ]) ||
        _hasWord(t, 'bar')) {
      return 'bar';
    }
    if (_any(t, const [
      'fridge', 'chlod', 'chłod', 'szafa chlod', 'szafa chłod', 'refriger',
      'freezer', 'mrozn', 'mroź', 'witryna', 'sogut', 'soğut', 'buzdol',
      'cold room', 'komora chlod', 'komora chłod', 'nadstawka', 'refrigeration',
      'cooling', 'sogutma', 'soğutma',
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
      'bakery', 'piekarnia', 'pastry', 'cukierni', 'patisserie', 'bread', 'chleb',
    ])) {
      return 'prep';
    }
    if (_any(t, const [
      'restaurant', 'restoran', 'restauracj', 'dining', 'gastro', 'lokale',
      'lokal ', 'club', 'catering', 'dark kitchen', 'fast food', 'fast_food',
      'cooking equipment',
    ])) {
      return 'cooking';
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
