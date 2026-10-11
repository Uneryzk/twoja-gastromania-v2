import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// Single source of truth for marketplace / hub imagery.
///
/// **Only these 6 fixed industrial-kitchen Unsplash URLs are allowed.**
/// No Picsum, no keyword search, no other photo IDs — ever.
class TGListingImages {
  TGListingImages._();

  // ---------------------------------------------------------------------------
  // THE ONLY allowed images (global constants)
  // ---------------------------------------------------------------------------

  static const String cooking =
      'https://images.unsplash.com/photo-1556910103-1c02745aae0f?auto=format&fit=crop&w=1200&q=80';
  static const String refrigeration =
      'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&w=1200&q=80';
  static const String warewashing =
      'https://images.unsplash.com/photo-1585837575652-267c041d77d4?auto=format&fit=crop&w=1200&q=80';
  static const String foodPrep =
      'https://images.unsplash.com/photo-1556909212-d5b604d0c90d?auto=format&fit=crop&w=1200&q=80';
  static const String stainless =
      'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&w=1200&q=80';
  static const String barCafe =
      'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=1200&q=80';

  /// All allowed URLs (order = cooking → … → bar).
  static const List<String> allFixed = [
    cooking,
    refrigeration,
    warewashing,
    foodPrep,
    stainless,
    barCafe,
  ];

  /// Category tile + listing cover map — one fixed URL per [TGCategory].
  static const Map<TGCategory, String> categoryCoverUrls = {
    TGCategory.cookingEquipment: cooking,
    TGCategory.refrigerationEquipment: refrigeration,
    TGCategory.warewashing: warewashing,
    TGCategory.foodPreparation: foodPrep,
    TGCategory.stainlessSteelFurniture: stainless,
    TGCategory.barAndBeverageEquipment: barCafe,
  };

  // ---------------------------------------------------------------------------
  // Public API — always returns one of [allFixed]
  // ---------------------------------------------------------------------------

  static String cover({
    required String id,
    required TGCategory category,
    String? title,
    int width = 1200,
    int height = 800,
  }) =>
      _urlFor(category: category, title: title);

  static String coverForTheme({
    required String id,
    required String theme,
    String? title,
    int width = 1200,
    int height = 800,
    int index = 0,
  }) =>
      _urlForTheme(theme, title);

  static List<String> gallery({
    required String id,
    required TGCategory category,
    String? title,
    int count = 4,
    int width = 1200,
    int height = 800,
  }) {
    final url = _urlFor(category: category, title: title);
    final n = count.clamp(1, 12);
    // Same on-theme industrial photo for every gallery slot (no off-theme fillers).
    return List<String>.filled(n, url, growable: false);
  }

  static List<String> galleryForTheme({
    required String id,
    required String theme,
    String? title,
    int count = 4,
    int width = 1200,
    int height = 800,
  }) {
    final url = _urlForTheme(theme, title);
    final n = count.clamp(1, 12);
    return List<String>.filled(n, url, growable: false);
  }

  static String forIndex({
    required String id,
    required TGCategory category,
    String? title,
    int index = 0,
    int width = 1200,
    int height = 800,
  }) =>
      _urlFor(category: category, title: title);

  static String categoryCover(TGCategory category, {int width = 1200, int height = 800}) =>
      categoryCoverUrls[category] ?? cooking;

  /// Hero / banner — cycles only through the 6 fixed URLs.
  static String heroSlide(int index, {int width = 1200, int height = 800}) =>
      allFixed[index.abs() % allFixed.length];

  static String themeKey({TGCategory? category, String? label, String? title}) {
    if (label != null && label.trim().isNotEmpty) return _normalizeTheme(label, title);
    if (category != null) return _themeForCategory(category, title);
    return _normalizeTheme('', title);
  }

  static String normalizeCategory(String category, [String? title]) => _normalizeTheme(category, title);

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static String _urlFor({required TGCategory category, String? title}) {
    final theme = _themeForCategory(category, title);
    return _urlForThemeKey(theme);
  }

  static String _urlForTheme(String theme, String? title) =>
      _urlForThemeKey(_normalizeTheme(theme, title));

  static String _urlForThemeKey(String theme) => switch (theme) {
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

  /// Maps free-text (TR / PL / EN) onto one of the 6 theme keys.
  static String _normalizeTheme(String category, String? title) {
    final t = _fold('${category.toLowerCase()} ${title?.toLowerCase() ?? ''}');

    if (_any(t, const ['pizza', 'pizzer', 'piec pizza', 'wood-fired'])) return 'cooking';
    // Warewash before bar — brands like "Hobart" contain the letters "bar".
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
      'cooking', 'range', 'pisirme', 'pişirme',
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
    ])) {
      return 'cooking';
    }
    if (_any(t, const ['cooking equipment'])) return 'cooking';
    if (_any(t, const ['bar & beverage', 'bar and beverage', 'beverage equipment'])) return 'bar';
    return 'default';
  }

  static bool _any(String haystack, List<String> needles) {
    for (final n in needles) {
      if (haystack.contains(_fold(n))) return true;
    }
    return false;
  }

  /// Whole-word match (avoids "bar" inside "Hobart").
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
