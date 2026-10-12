import 'package:flutter_test/flutter_test.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

void main() {
  group('TGListingImages — local assets only', () {
    test('category covers are assets/images paths', () {
      for (final url in TGListingImages.categoryCoverUrls.values) {
        expect(url, startsWith('assets/images/'));
        expect(url, isNot(contains('unsplash')));
        expect(url, isNot(contains('picsum')));
        expect(url, isNot(contains('http')));
      }
      expect(TGListingImages.categoryCover(TGCategory.cookingEquipment), TGListingImages.mutfakEquip);
      expect(TGListingImages.categoryCover(TGCategory.refrigerationEquipment), TGListingImages.fridge700);
      expect(TGListingImages.categoryCover(TGCategory.warewashing), TGListingImages.warewashing);
      expect(TGListingImages.categoryCover(TGCategory.foodPreparation), TGListingImages.foodPrep);
      expect(TGListingImages.categoryCover(TGCategory.stainlessSteelFurniture), TGListingImages.shelves);
      expect(TGListingImages.categoryCover(TGCategory.barAndBeverageEquipment), TGListingImages.coffeeEspresso);
    });

    test('dynamic listing matching is disabled', () {
      expect(TGListingImages.kDisableDynamicListingImages, isTrue);
      expect(TGListingImages.cover(id: 'x', category: TGCategory.cookingEquipment, title: 'Oven'), isEmpty);
      expect(TGListingImages.gallery(id: 'x', category: TGCategory.cookingEquipment, title: 'Oven', count: 5), isEmpty);
      expect(TGListingImages.galleryForTheme(id: 'x', theme: 'pizzeria', title: 'Pizza', count: 4), isEmpty);
      expect(TGListingImages.forEquipmentKey('resto_eq_dishwasher'), isEmpty);
    });

    test('galleryWithPrimary keeps only stored primary when matching off', () {
      const primary = 'assets/images/bartscher_2002170.webp';
      final g = TGListingImages.galleryWithPrimary(
        primary: primary,
        id: 'p001',
        category: TGCategory.cookingEquipment,
        title: 'Piec',
        count: 4,
      );
      expect(g, [primary]);
    });

    test('hero slides stay local assets', () {
      for (var i = 0; i < 4; i++) {
        expect(TGListingImages.heroSlide(i), startsWith('assets/images/'));
      }
    });

    test('no remote URL constants remain', () {
      expect(TGListingImages.cooking, isNot(contains('http')));
      expect(TGListingImages.allFixed.every((u) => u.startsWith('assets/images/')), isTrue);
      expect(TGListingImages.listingPool.every((u) => u.startsWith('assets/images/')), isTrue);
    });
  });
}
