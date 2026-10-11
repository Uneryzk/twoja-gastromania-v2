import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

void main() {
  group('TGListingImages — 6 fixed gastro URLs only', () {
    test('allFixed has exactly the 6 mandated URLs', () {
      expect(TGListingImages.allFixed, [
        TGListingImages.cooking,
        TGListingImages.refrigeration,
        TGListingImages.warewashing,
        TGListingImages.foodPrep,
        TGListingImages.stainless,
        TGListingImages.barCafe,
      ]);
      expect(TGListingImages.allFixed, hasLength(6));
      for (final u in TGListingImages.allFixed) {
        expect(u, startsWith('https://images.unsplash.com/photo-'));
        expect(u, contains('w=1200'));
        expect(u, isNot(contains('picsum')));
      }
    });

    test('category covers match the 6 fixed URLs', () {
      expect(TGListingImages.categoryCover(TGCategory.cookingEquipment), TGListingImages.cooking);
      expect(TGListingImages.categoryCover(TGCategory.refrigerationEquipment), TGListingImages.refrigeration);
      expect(TGListingImages.categoryCover(TGCategory.warewashing), TGListingImages.warewashing);
      expect(TGListingImages.categoryCover(TGCategory.foodPreparation), TGListingImages.foodPrep);
      expect(TGListingImages.categoryCover(TGCategory.stainlessSteelFurniture), TGListingImages.stainless);
      expect(TGListingImages.categoryCover(TGCategory.barAndBeverageEquipment), TGListingImages.barCafe);
    });

    test('listing cover / gallery never leave the 6 URLs', () {
      for (final cat in TGCategory.values) {
        final cover = TGListingImages.cover(id: 'x', category: cat, title: 'test');
        expect(TGListingImages.allFixed, contains(cover));
        final gallery = TGListingImages.gallery(id: 'x', category: cat, title: 'test', count: 5);
        expect(gallery.every(TGListingImages.allFixed.contains), isTrue);
      }
    });

    test('title keywords still map onto the 6 URLs only', () {
      expect(
        TGListingImages.cover(id: '1', category: TGCategory.cookingEquipment, title: 'Piec konwekcyjny'),
        TGListingImages.cooking,
      );
      expect(
        TGListingImages.cover(id: '2', category: TGCategory.cookingEquipment, title: 'Zmywarka Hobart'),
        TGListingImages.warewashing,
      );
      expect(
        TGListingImages.cover(id: '3', category: TGCategory.cookingEquipment, title: 'Szafa chłodnicza'),
        TGListingImages.refrigeration,
      );
      expect(
        TGListingImages.cover(id: '4', category: TGCategory.cookingEquipment, title: 'Ekspres kolbowy'),
        TGListingImages.barCafe,
      );
      expect(
        TGListingImages.cover(id: '5', category: TGCategory.cookingEquipment, title: 'Stół nierdzewny'),
        TGListingImages.stainless,
      );
    });

    test('hero slides cycle only within the 6 URLs', () {
      for (var i = 0; i < 12; i++) {
        expect(TGListingImages.allFixed, contains(TGListingImages.heroSlide(i)));
      }
    });

    test('theme helpers never invent external photo IDs', () {
      final themes = ['restaurant', 'pizza', 'bakery', 'cafe', 'oven', 'default', 'unknown-xyz'];
      for (final t in themes) {
        final url = TGListingImages.coverForTheme(id: 'r', theme: t, title: t);
        expect(TGListingImages.allFixed, contains(url));
      }
    });
  });
}
