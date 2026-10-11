import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// Curated gastronomy / industrial-kitchen images for listings and category tiles.
///
/// Every URL is a stable Unsplash CDN photo from an on-theme pool (HTTP 200 verified).
/// Selection is deterministic from id + title + category + index — never Picsum / random stock.
class TGListingImages {
  TGListingImages._();

  // ---------------------------------------------------------------------------
  // Curated Unsplash photo IDs (industrial kitchen, restaurant, café equipment)
  // All IDs below return HTTP 200 from images.unsplash.com.
  // ---------------------------------------------------------------------------

  /// Theme key → photo ids (without `photo-` prefix).
  static const Map<String, List<String>> _pools = {
    'cooking': [
      '1556910103-1c02745aae4d', // professional kitchen appliances
      '1556909114-f6e7ad7d3136', // cooking on range
      '1547592180-85f173990554', // pasta / hot line
      '1600565193348-f74bd3c7ccdf', // modern kitchen range
      '1559339352-11d035aa65de', // restaurant kitchen pass
      '1414235077428-338989a2e8c0', // plated hospitality service
      '1556911220-e15b29be8c8f', // kitchen work surface
      '1555939594-58d7cb561ad1', // burger / grill line
    ],
    'oven': [
      '1556910103-1c02745aae4d',
      '1600565193348-f74bd3c7ccdf',
      '1556909114-f6e7ad7d3136',
      '1547592180-85f173990554',
      '1559339352-11d035aa65de',
    ],
    'pizza': [
      '1513104890138-7c749659a591',
      '1565299624946-b28f40a0ae38',
      '1574071318508-1cdbab80d002',
      '1593560704563-f176a2eb61db',
      '1565299585323-38d6b0865b47',
    ],
    'fridge': [
      '1571171637578-41bc2dd41cd2', // open fridge with food
      '1723641276188-98eed2b81486', // kitchen with fridge / dishwasher
      '1601004890684-d8cbf643f5f2', // cold plated food
      '1498837167922-ddd27525d352', // fresh cold produce
      '1542838132-92c53300491e', // grocery / cold display
      '1606787366850-de6330128bfc', // fresh ingredients storage
    ],
    'warewash': [
      '1723641276188-98eed2b81486', // dishwasher + sink kitchen
      '1556912172-45b7abe8b7e1', // kitchen sink / wash-up
      '1581578731548-c64695cc6952', // clean kitchen surfaces
      '1600585152220-90363fe7e115', // sink / wet area
      '1556911220-e15b29be8c8f', // prep sink line
    ],
    'prep': [
      '1556909114-f6e7ad7d3136',
      '1507048331197-7d4ac70811cf', // food preparation
      '1478144592103-25e218a04891', // chef prep board
      '1556911220-e15b29be8c8f',
      '1498654200943-1088dd4438ae', // appetizer prep
      '1473093295043-cdd812d0e601', // plated prep / pasta
      '1540189549336-e6e99c3679fe', // fresh produce prep
    ],
    'inox': [
      '1556912173-46c336c7fd55', // stainless kitchen
      '1600585154340-be6161a56a0c', // modern kitchen furniture
      '1600565193348-f74bd3c7ccdf',
      '1556910103-1c02745aae4d',
      '1723641276188-98eed2b81486',
      '1600585152220-90363fe7e115',
    ],
    'bar': [
      '1572116469696-31de0f17cc34', // cocktails / bar
      '1517248135467-4c7edcad34c4', // restaurant / bar interior
      '1552566626-52f8b828add9', // dining bar area
      '1428515613728-6b4607e44363', // restaurant seating
      '1501339847302-ac426a4a7cbb', // café / bar counter
    ],
    'cafe': [
      '1495474472287-4d71bcdd2085', // coffee service
      '1509042239860-f550ce710b93', // coffee cup
      '1514432324607-a09d9b4aefdd', // café interior
      '1442512595331-e89e73853f31', // pour-over coffee
      '1511920170033-f8396924c348', // espresso / coffee
      '1498804103079-a6351b050096', // latte art
      '1702293798790-6673b8c982a2', // coffee machine on café counter
    ],
    'restaurant': [
      '1517248135467-4c7edcad34c4',
      '1552566626-52f8b828add9',
      '1428515613728-6b4607e44363',
      '1414235077428-338989a2e8c0',
      '1466978913421-dad2ebd01d17',
      '1559339352-11d035aa65de',
      '1482049016688-2d3e1b311543', // plated restaurant dish
    ],
    'bakery': [
      '1509440159596-0249088772ff', // bread bakery
      '1549931319-a545dcf3bc73', // baked goods
      '1555507036-ab1f4038808a', // bakery display
      '1578985545062-69928b1d9587', // pastries / cake
      '1565958011703-44f9829ba187', // layered cake
    ],
    'default': [
      '1556910103-1c02745aae4d',
      '1556909114-f6e7ad7d3136',
      '1517248135467-4c7edcad34c4',
      '1559339352-11d035aa65de',
    ],
  };

  /// Primary cover for a marketplace listing.
  static String cover({
    required String id,
    required TGCategory category,
    String? title,
    int width = 800,
    int height = 600,
  }) =>
      forIndex(id: id, category: category, title: title, index: 0, width: width, height: height);

  /// Cover from an explicit theme key (e.g. restaurant business type).
  static String coverForTheme({
    required String id,
    required String theme,
    String? title,
    int width = 800,
    int height = 600,
    int index = 0,
  }) {
    final key = _normalizeTheme(theme, title);
    return _urlFromPool(key, id: id, index: index, width: width, height: height);
  }

  /// Gallery URLs (cover first). Count clamped to 1–12.
  static List<String> gallery({
    required String id,
    required TGCategory category,
    String? title,
    int count = 4,
    int width = 800,
    int height = 600,
  }) {
    final n = count.clamp(1, 12);
    return [
      for (var i = 0; i < n; i++)
        forIndex(id: id, category: category, title: title, index: i, width: width, height: height),
    ];
  }

  static List<String> galleryForTheme({
    required String id,
    required String theme,
    String? title,
    int count = 4,
    int width = 800,
    int height = 600,
  }) {
    final n = count.clamp(1, 12);
    final key = _normalizeTheme(theme, title);
    return [
      for (var i = 0; i < n; i++) _urlFromPool(key, id: id, index: i, width: width, height: height),
    ];
  }

  static String forIndex({
    required String id,
    required TGCategory category,
    String? title,
    int index = 0,
    int width = 800,
    int height = 600,
  }) {
    final key = _themeForCategory(category, title);
    return _urlFromPool(key, id: id, index: index, width: width, height: height);
  }

  /// Stable category-tile / browse image (first hero shot of the pool).
  static String categoryCover(TGCategory category, {int width = 640, int height = 480}) {
    final key = _categoryBaseKey(category);
    return _urlFromPool(key, id: 'cat-$key', index: 0, width: width, height: height);
  }

  /// Hero / banner slide image for home (gastronomy only).
  static String heroSlide(int index, {int width = 1600, int height = 900}) {
    const heroes = ['cooking', 'restaurant', 'cafe', 'inox'];
    final key = heroes[index.abs() % heroes.length];
    return _urlFromPool(key, id: 'hero-$key', index: index, width: width, height: height);
  }

  /// Exposed for tests / diagnostics.
  static String themeKey({TGCategory? category, String? label, String? title}) {
    if (label != null && label.trim().isNotEmpty) return _normalizeTheme(label, title);
    if (category != null) return _themeForCategory(category, title);
    return _normalizeTheme('', title);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static String _urlFromPool(
    String themeKey, {
    required String id,
    required int index,
    required int width,
    required int height,
  }) {
    final pool = _pools[themeKey] ?? _pools['default']!;
    final hash = Object.hash(id, themeKey, index).abs();
    final photoId = pool[(hash + index) % pool.length];
    return 'https://images.unsplash.com/photo-$photoId'
        '?auto=format&fit=crop&w=$width&h=$height&q=80';
  }

  static String _categoryBaseKey(TGCategory c) => switch (c) {
        TGCategory.cookingEquipment => 'cooking',
        TGCategory.refrigerationEquipment => 'fridge',
        TGCategory.warewashing => 'warewash',
        TGCategory.foodPreparation => 'prep',
        TGCategory.stainlessSteelFurniture => 'inox',
        TGCategory.barAndBeverageEquipment => 'bar',
      };

  /// Prefer title-driven themes (oven, pizza, espresso…) then fall back to category.
  static String _themeForCategory(TGCategory category, String? title) {
    final fromTitle = _normalizeTheme('', title);
    if (fromTitle != 'default') return fromTitle;
    return _categoryBaseKey(category);
  }

  /// Maps free-text category / title (TR / PL / EN) onto a curated pool key.
  static String _normalizeTheme(String category, String? title) {
    final combined = '${category.toLowerCase()} ${title?.toLowerCase() ?? ''}';
    final t = _fold(combined);

    if (_any(t, const ['pizza', 'pizzer', 'piec pizza', 'wood-fired'])) return 'pizza';

    if (_any(t, const [
      'oven', 'piec', 'firin', 'fırın', 'combi', 'konwekcyj', 'konveksiyon',
      'steam oven', 'piekarnik', 'rational', 'icomb',
    ])) {
      return 'oven';
    }

    if (_any(t, const [
      'espresso', 'coffee', 'kahve', 'kawa', 'cafe', 'café', 'kawiarn',
      'barista', 'mlynek', 'młynek', 'kolbowy',
    ])) {
      return 'cafe';
    }

    if (_any(t, const [
      'bakery', 'piekarnia', 'pastry', 'cukierni', 'patisserie', 'bread', 'chleb', 'boulang',
    ])) {
      return 'bakery';
    }

    if (_any(t, const [
      'dishwasher', 'zmywarka', 'bulasik', 'bulaşık', 'warewash', 'sink', 'zlew',
      'wash', 'hobart', 'oztiryak', 'öztiryak',
    ])) {
      return 'warewash';
    }

    if (_any(t, const [
      'fridge', 'chlod', 'chłod', 'szafa chlod', 'szafa chłod', 'refriger',
      'freezer', 'mrozn', 'mroź', 'witryna', 'sogut', 'soğut', 'buzdol',
      'cold room', 'komora chlod', 'komora chłod', 'nadstawka',
    ])) {
      return 'fridge';
    }

    if (_any(t, const [
      'bemar', 'bain-marie', 'krajalnic', 'mixer', 'mikser', 'prep',
      'hazirla', 'hazırla', 'przygotow', 'food prep', 'pakowarka', 'vacuum',
    ])) {
      return 'prep';
    }

    if (_any(t, const [
      'stainless', 'inox', 'nierdzew', 'paslanmaz', 'stol', 'stół', 'tezgah',
      'blat', 'regał', 'regal', 'table', 'okap', 'hood', 'furniture', 'mobilya',
    ])) {
      return 'inox';
    }

    if (_any(t, const [
      'bar', 'beverage', 'napoj', 'napój', 'cocktail', 'koktajl', 'wine', 'wino',
      'icecek', 'içecek',
    ])) {
      return 'bar';
    }

    if (_any(t, const [
      'restaurant', 'restoran', 'restauracj', 'dining', 'gastro', 'lokale', 'lokal ',
      'club', 'catering', 'dark kitchen', 'fast food', 'fast_food',
    ])) {
      return 'restaurant';
    }

    if (_any(t, const [
      'cook', 'pisir', 'pişir', 'kuchnia', 'cooking', 'range', 'palnik',
      'gazowa', 'fryer', 'frytown', 'griddle', 'grill',
    ])) {
      return 'cooking';
    }

    // Slug / enum-style labels
    if (_any(t, const ['warewashing', 'warewash'])) return 'warewash';
    if (_any(t, const ['refrigeration', 'fridge', 'cooling', 'sogutma', 'soğutma'])) return 'fridge';
    if (_any(t, const ['food preparation', 'preparation', 'hazirlama', 'hazırlama'])) return 'prep';
    if (_any(t, const ['stainless steel', 'inox', 'paslanmaz'])) return 'inox';
    if (_any(t, const ['bar & beverage', 'bar and beverage', 'beverage equipment'])) return 'bar';
    if (_any(t, const ['cooking equipment', 'pisirme', 'pişirme'])) return 'cooking';
    if (_any(t, const ['bakery_patisserie', 'bakery', 'patisserie'])) return 'bakery';
    if (_any(t, const ['cafe', 'café', 'coffee'])) return 'cafe';
    if (_any(t, const ['restaurant', 'club', 'catering_dark_kitchen', 'fast_food', 'pizzeria', 'other'])) {
      if (t.contains('pizzer')) return 'pizza';
      if (t.contains('cafe') || t.contains('café')) return 'cafe';
      if (t.contains('bar')) return 'bar';
      if (t.contains('baker') || t.contains('pastr')) return 'bakery';
      return 'restaurant';
    }

    return 'default';
  }

  /// Public alias for callers that pass free-text category labels.
  static String normalizeCategory(String category, [String? title]) => _normalizeTheme(category, title);

  static bool _any(String haystack, List<String> needles) {
    for (final n in needles) {
      if (haystack.contains(_fold(n))) return true;
    }
    return false;
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
