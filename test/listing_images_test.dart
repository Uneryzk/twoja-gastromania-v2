import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

void main() {
  group('TGListingImages', () {
    test('cover is curated Unsplash URL (never Picsum)', () {
      final url = TGListingImages.cover(
        id: 'p001',
        category: TGCategory.cookingEquipment,
        title: 'Piec konwekcyjny',
      );
      expect(url, startsWith('https://images.unsplash.com/photo-'));
      expect(url, isNot(contains('picsum')));
      expect(url, contains('auto=format'));
    });

    test('different ids produce different URLs within theme', () {
      final a = TGListingImages.cover(id: 'p001', category: TGCategory.cookingEquipment, title: 'A');
      final b = TGListingImages.cover(id: 'p002', category: TGCategory.cookingEquipment, title: 'B');
      expect(a, isNot(equals(b)));
    });

    test('same inputs are stable', () {
      final a = TGListingImages.cover(id: 'p001', category: TGCategory.warewashing, title: 'Zmywarka');
      final b = TGListingImages.cover(id: 'p001', category: TGCategory.warewashing, title: 'Zmywarka');
      expect(a, equals(b));
    });

    test('gallery entries stay on Unsplash and cover-first', () {
      final gallery = TGListingImages.gallery(
        id: 'p003',
        category: TGCategory.refrigerationEquipment,
        title: 'Szafa chłodnicza',
        count: 5,
      );
      expect(gallery, hasLength(5));
      expect(gallery.every((u) => u.startsWith('https://images.unsplash.com/photo-')), isTrue);
      expect(gallery.first, TGListingImages.cover(id: 'p003', category: TGCategory.refrigerationEquipment, title: 'Szafa chłodnicza'));
    });

    test('category covers differ by category and are Unsplash', () {
      final cooking = TGListingImages.categoryCover(TGCategory.cookingEquipment);
      final bar = TGListingImages.categoryCover(TGCategory.barAndBeverageEquipment);
      final fridge = TGListingImages.categoryCover(TGCategory.refrigerationEquipment);
      expect(cooking, isNot(equals(bar)));
      expect(cooking, isNot(equals(fridge)));
      expect(cooking, startsWith('https://images.unsplash.com/photo-'));
      expect(bar, startsWith('https://images.unsplash.com/photo-'));
    });

    test('title keywords select oven / cafe / warewash / fridge themes', () {
      expect(TGListingImages.themeKey(title: 'Piec konwekcyjno-parowy Bartscher'), 'oven');
      expect(TGListingImages.themeKey(title: 'Ekspres kolbowy 2-grupowy'), 'cafe');
      expect(TGListingImages.themeKey(title: 'Zmywarka podblatowa Öztiryakiler'), 'warewash');
      expect(TGListingImages.themeKey(title: 'Szafa chłodnicza 700L'), 'fridge');
      expect(TGListingImages.themeKey(title: 'Stół ze stali nierdzewnej'), 'inox');
      expect(TGListingImages.themeKey(title: 'Pizza oven wood-fired'), 'pizza');
    });

    test('normalizeCategory covers TR/PL/EN labels', () {
      expect(TGListingImages.normalizeCategory('Pişirme Ekipmanları'), 'cooking');
      expect(TGListingImages.normalizeCategory('Soğutma'), 'fridge');
      expect(TGListingImages.normalizeCategory('Bulaşık Yıkama'), 'warewash');
      expect(TGListingImages.normalizeCategory('Yiyecek Hazırlama'), 'prep');
      expect(TGListingImages.normalizeCategory('Paslanmaz Çelik Mobilya'), 'inox');
      expect(TGListingImages.normalizeCategory('Bar ve İçecek'), 'bar');
      expect(TGListingImages.normalizeCategory('Cooking Equipment'), 'cooking');
      expect(TGListingImages.normalizeCategory('Warewashing'), 'warewash');
    });

    test('hero slides are gastronomy Unsplash URLs', () {
      for (var i = 0; i < 4; i++) {
        final u = TGListingImages.heroSlide(i);
        expect(u, startsWith('https://images.unsplash.com/photo-'));
        expect(u, isNot(contains('picsum')));
      }
    });
  });
}
