import 'package:twoja_gastromania/tg_models/tg_product.dart';

/// Deterministic placeholder images for listings / product cards.
///
/// Uses [Lorem Picsum](https://picsum.photos) seed URLs so each listing keeps a
/// stable cover across reloads, while id / title / category / index produce
/// visibly different photos (no more repeating the same static asset pool).
///
/// Category keywords are baked into the seed so cooking vs warewashing vs bar
/// equipment diverge into different image families.
class TGListingImages {
  TGListingImages._();

  /// Primary cover for a listing.
  static String cover({
    required String id,
    required TGCategory category,
    String? title,
    int width = 800,
    int height = 600,
  }) =>
      forIndex(
        id: id,
        category: category,
        title: title,
        index: 0,
        width: width,
        height: height,
      );

  /// Gallery URLs (cover first). Count is clamped to 1–12.
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
        forIndex(
          id: id,
          category: category,
          title: title,
          index: i,
          width: width,
          height: height,
        ),
    ];
  }

  /// Single image at [index] (0 = cover).
  static String forIndex({
    required String id,
    required TGCategory category,
    String? title,
    int index = 0,
    int width = 800,
    int height = 600,
  }) {
    final seed = _seed(id: id, category: category, title: title, index: index);
    // Picsum seed endpoint: same seed → same photo; different seed → different photo.
    return 'https://picsum.photos/seed/$seed/$width/$height';
  }

  /// Category tile / browse image (stable per category, not per listing).
  static String categoryCover(TGCategory category, {int width = 640, int height = 480}) {
    final seed = 'tg-cat-${_categorySlug(category)}';
    return 'https://picsum.photos/seed/$seed/$width/$height';
  }

  static String _seed({
    required String id,
    required TGCategory category,
    String? title,
    required int index,
  }) {
    final cat = _categorySlug(category);
    final tags = _categoryTags(category).join('-');
    final titleSlug = _slug(title ?? '');
    final parts = <String>[
      'tg',
      cat,
      tags,
      _slug(id),
      if (titleSlug.isNotEmpty) titleSlug,
      '$index',
    ];
    // Picsum accepts arbitrary seed strings; keep URL-safe and bounded.
    final raw = parts.join('-');
    return raw.length <= 80 ? raw : raw.substring(0, 80);
  }

  static String _categorySlug(TGCategory c) => switch (c) {
        TGCategory.cookingEquipment => 'cooking',
        TGCategory.refrigerationEquipment => 'fridge',
        TGCategory.warewashing => 'warewash',
        TGCategory.foodPreparation => 'prep',
        TGCategory.stainlessSteelFurniture => 'inox',
        TGCategory.barAndBeverageEquipment => 'bar',
      };

  /// Soft theme hints embedded in the seed (Picsum has no tag search).
  static List<String> _categoryTags(TGCategory c) => switch (c) {
        TGCategory.cookingEquipment => const ['oven', 'kitchen', 'industrial'],
        TGCategory.refrigerationEquipment => const ['cold', 'fridge', 'storage'],
        TGCategory.warewashing => const ['dishwasher', 'sink', 'clean'],
        TGCategory.foodPreparation => const ['prep', 'counter', 'chef'],
        TGCategory.stainlessSteelFurniture => const ['steel', 'table', 'workshop'],
        TGCategory.barAndBeverageEquipment => const ['coffee', 'bar', 'beverage'],
      };

  static String _slug(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.isEmpty) return '';
    final buf = StringBuffer();
    var prevDash = false;
    for (final code in lower.runes) {
      final isAz = code >= 97 && code <= 122;
      final isDigit = code >= 48 && code <= 57;
      if (isAz || isDigit) {
        buf.writeCharCode(code);
        prevDash = false;
      } else if (!prevDash && buf.isNotEmpty) {
        buf.writeCharCode(45); // '-'
        prevDash = true;
      }
    }
    var s = buf.toString();
    if (s.endsWith('-')) s = s.substring(0, s.length - 1);
    if (s.length > 28) s = s.substring(0, 28);
    return s;
  }
}
