class TGListingImages {
  static const Map<String, List<String>> _categoryImagePools = {
    'cooking': [
      '1556910103-1c02745aae0f',
      '1556911220-e15b29be8c8f',
      '1556911260-ac2f5a512c3b',
    ],
    'cooling': [
      '1584622650111-993a426fbf0a',
      '1571175443880-49e2f2b0907f',
    ],
    'preparation': [
      '1556909212-d5b604d0c90d',
      '1556909114-f6e7ad7d3136',
    ],
    'cafe': [
      '1501339847302-ac426a4a7cbb',
      '1514432324607-a09d9b4aefdd',
    ],
    'default': [
      '1556909212-d5b604d0c90d',
      '1556910103-1c02745aae0f',
    ],
  };

  static String getImageUrl({
    required String category,
    required String id,
    String? title,
    int index = 0,
  }) {
    final catKey = _normalizeCategory(category, title);
    final pool = _categoryImagePools[catKey] ?? _categoryImagePools['default']!;
    final hashCode = (id.hashCode + index).abs();
    final imageId = pool[hashCode % pool.length];
    return 'https://images.unsplash.com/photo-$imageId?auto=format&fit=crop&w=1200&q=80';
  }

  static String _normalizeCategory(String category, String? title) {
    final combined = '${category.toLowerCase()} ${title?.toLowerCase() ?? ''}';
    if (combined.contains('fırın') || combined.contains('ocak') || combined.contains('pişir') || combined.contains('cook')) {
      return 'cooking';
    } else if (combined.contains('dolap') || combined.contains('soğut') || combined.contains('buz') || combined.contains('cool')) {
      return 'cooling';
    } else if (combined.contains('kahve') || combined.contains('bar') || combined.contains('espresso') || combined.contains('cafe')) {
      return 'cafe';
    } else if (combined.contains('tezgah') || combined.contains('paslanmaz') || combined.contains('hazırlık') || combined.contains('maliyet') || combined.contains('mutfak')) {
      return 'preparation';
    }
    return 'default';
  }
}
