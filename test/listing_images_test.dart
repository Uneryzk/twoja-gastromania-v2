import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

void main() {
  group('TGListingImages', () {
    test('cover is Picsum seed URL with category + id', () {
      final url = TGListingImages.cover(
        id: 'p001',
        category: TGCategory.cookingEquipment,
        title: 'Piec konwekcyjny',
      );
      expect(url, startsWith('https://picsum.photos/seed/'));
      expect(url, contains('cooking'));
      expect(url, contains('p001'));
      expect(url, endsWith('/800/600'));
    });

    test('different ids produce different URLs', () {
      final a = TGListingImages.cover(id: 'p001', category: TGCategory.cookingEquipment, title: 'A');
      final b = TGListingImages.cover(id: 'p002', category: TGCategory.cookingEquipment, title: 'B');
      expect(a, isNot(equals(b)));
    });

    test('same inputs are stable', () {
      final a = TGListingImages.cover(id: 'p001', category: TGCategory.warewashing, title: 'Zmywarka');
      final b = TGListingImages.cover(id: 'p001', category: TGCategory.warewashing, title: 'Zmywarka');
      expect(a, equals(b));
    });

    test('gallery entries are unique and cover-first', () {
      final gallery = TGListingImages.gallery(
        id: 'p003',
        category: TGCategory.refrigerationEquipment,
        title: 'Szafa chłodnicza',
        count: 5,
      );
      expect(gallery, hasLength(5));
      expect(gallery.toSet(), hasLength(5));
      expect(gallery.first, TGListingImages.cover(id: 'p003', category: TGCategory.refrigerationEquipment, title: 'Szafa chłodnicza'));
    });

    test('category covers differ by category', () {
      final cooking = TGListingImages.categoryCover(TGCategory.cookingEquipment);
      final bar = TGListingImages.categoryCover(TGCategory.barAndBeverageEquipment);
      expect(cooking, isNot(equals(bar)));
      expect(cooking, contains('cooking'));
      expect(bar, contains('bar'));
    });
  });
}
