import 'package:twoja_gastromania/tg_core/tg_listing_images.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';

/// One new private member + one unpaid standard listing (no Bold / Spotlight / Glow).
class TGStandardMemberSeed {
  const TGStandardMemberSeed({
    required this.n,
    required this.category,
    required this.name,
    required this.slug,
    required this.city,
    required this.voivodeship,
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.description,
  });

  final int n;
  final TGCategory category;
  final String name;
  final String slug;
  final String city;
  final String voivodeship;
  final String title;
  final int price;
  final String imageUrl;
  final String description;

  String get id => 'pstd${n.toString().padLeft(2, '0')}';
  String get sellerId => 'seller_std_${n.toString().padLeft(2, '0')}';
  int get publicId => 8900 + n;
  String get listingNo => (40100000 + n).toString();
  String get phone => '+48 (511) 200-${n.toString().padLeft(3, '0')}';
}

const kStandardMemberSeeds = <TGStandardMemberSeed>[
  // Cooking
  TGStandardMemberSeed(n: 1, category: TGCategory.cookingEquipment, name: 'Kasia M.', slug: 'kasia-m', city: 'Lublin', voivodeship: 'Lubelskie', title: 'Kuchenka 4-palnikowa gazowa – linia 700', price: 2450, imageUrl: TGListingImages.combiOven, description: 'Używana kuchenka gazowa po przeglądzie. Odbiór osobisty, faktura na życzenie.'),
  TGStandardMemberSeed(n: 2, category: TGCategory.cookingEquipment, name: 'Tomasz R.', slug: 'tomasz-r', city: 'Białystok', voivodeship: 'Podlaskie', title: 'Frytkownica podwójna 8+8 L – elektryczna', price: 1680, imageUrl: TGListingImages.burgerGrill, description: 'Dwie komory, termostat i pokrywy. Sprawna, sprzedaję po zamknięciu food trucka.'),
  TGStandardMemberSeed(n: 3, category: TGCategory.cookingEquipment, name: 'Ewa L.', slug: 'ewa-l', city: 'Rzeszów', voivodeship: 'Podkarpackie', title: 'Grill lawowy 60 cm – gaz, żeliwny ruszt', price: 2100, imageUrl: TGListingImages.burgerGrill, description: 'Grill lawowy do burgersa. Palniki czyste, ruszt po wymianie.'),
  TGStandardMemberSeed(n: 4, category: TGCategory.cookingEquipment, name: 'Michał B.', slug: 'michal-b', city: 'Kielce', voivodeship: 'Świętokrzyskie', title: 'Taboret gazowy 9 kW – stanowisko wok', price: 890, imageUrl: TGListingImages.mutfakEquip, description: 'Mocny palnik do woka. Krótko używany w food hallu, odbiór od ręki.'),
  TGStandardMemberSeed(n: 5, category: TGCategory.cookingEquipment, name: 'Natalia S.', slug: 'natalia-s', city: 'Olsztyn', voivodeship: 'Warmińsko-Mazurskie', title: 'Patelnia uchylna 40 L – elektryczna, dno stal', price: 3200, imageUrl: TGListingImages.bainMarie, description: 'Patelnia uchylna po serwisie grzałek. Idealna do sosów i duszonych dań.'),
  // Refrigeration
  TGStandardMemberSeed(n: 6, category: TGCategory.refrigerationEquipment, name: 'Paweł G.', slug: 'pawel-g', city: 'Szczecin', voivodeship: 'Zachodniopomorskie', title: 'Witryna napojowa 380 L – drzwi przesuwne', price: 1750, imageUrl: TGListingImages.beverageFridge, description: 'Chłodzi równo, oświetlenie LED. Sprzedaję bo zmieniłem format baru.'),
  TGStandardMemberSeed(n: 7, category: TGCategory.refrigerationEquipment, name: 'Olga K.', slug: 'olga-k', city: 'Opole', voivodeship: 'Opolskie', title: 'Zamrażarka skrzyniowa 400 L – kosze w zestawie', price: 1420, imageUrl: TGListingImages.freezerVertical, description: 'Cicha, uszczelki nowe. Odbiór z magazynu przy dworcu.'),
  TGStandardMemberSeed(n: 8, category: TGCategory.refrigerationEquipment, name: 'Jakub N.', slug: 'jakub-n', city: 'Toruń', voivodeship: 'Kujawsko-Pomorskie', title: 'Stół mroźniczy 2-drzwiowy – blat roboczy', price: 4100, imageUrl: TGListingImages.pizzaColdTop, description: 'Blat roboczy i dwie komory. Agregat serwisowany w sierpniu.'),
  TGStandardMemberSeed(n: 9, category: TGCategory.refrigerationEquipment, name: 'Magda P.', slug: 'magda-p', city: 'Bydgoszcz', voivodeship: 'Kujawsko-Pomorskie', title: 'Szafa mroźnicza 600 L – praca do -18 C', price: 2680, imageUrl: TGListingImages.fridge700, description: 'Szafa pionowa, półki regulowane. Bez ogłoszeń sponsorowanych, cena stała.'),
  TGStandardMemberSeed(n: 10, category: TGCategory.refrigerationEquipment, name: 'Robert C.', slug: 'robert-c', city: 'Radom', voivodeship: 'Mazowieckie', title: 'Kostkarka 28 kg na dobę – chłodzona powietrzem', price: 1980, imageUrl: TGListingImages.iceMachine, description: 'Kostkarka podblatowa, filtr w komplecie. Sprawna, mało używana.'),
  // Warewashing
  TGStandardMemberSeed(n: 11, category: TGCategory.warewashing, name: 'Iza D.', slug: 'iza-d', city: 'Gorzów Wielkopolski', voivodeship: 'Lubuskie', title: 'Zmywarka kapturowa 50x50 – pompa spustowa', price: 5400, imageUrl: TGListingImages.warewashing, description: 'Kapturowa po wymianie uszczelek. Kosze w zestawie, odbiór z hali.'),
  TGStandardMemberSeed(n: 12, category: TGCategory.warewashing, name: 'Filip W.', slug: 'filip-w', city: 'Zielona Góra', voivodeship: 'Lubuskie', title: 'Wyparzacz szklanek 40x40 – do baru', price: 1290, imageUrl: TGListingImages.foodPrep, description: 'Szybki cykl do szklanek. Sprzedaję po zmianie konceptu kawiarni.'),
  TGStandardMemberSeed(n: 13, category: TGCategory.warewashing, name: 'Aneta H.', slug: 'aneta-h', city: 'Płock', voivodeship: 'Mazowieckie', title: 'Zmywarka podblatowa 500x500 – dozownik', price: 3100, imageUrl: TGListingImages.warewashing, description: 'Podblatowa z dozownikiem chemii. Cicha, gotowa do podłączenia.'),
  TGStandardMemberSeed(n: 14, category: TGCategory.warewashing, name: 'Konrad J.', slug: 'konrad-j', city: 'Elbląg', voivodeship: 'Warmińsko-Mazurskie', title: 'Stołowy wyparzacz 35x35 – mała gastronomia', price: 980, imageUrl: TGListingImages.foodPrep, description: 'Kompaktowy wyparzacz do food trucka. Niewielki przebieg.'),
  TGStandardMemberSeed(n: 15, category: TGCategory.warewashing, name: 'Zofia T.', slug: 'zofia-t', city: 'Kalisz', voivodeship: 'Wielkopolskie', title: 'Zmywarka kapturowa 50x50 – drugi obieg', price: 4700, imageUrl: TGListingImages.warewashing, description: 'Druga zmywarka z zaplecza. Pompa spustowa i wąż w komplecie.'),
  // Food preparation
  TGStandardMemberSeed(n: 16, category: TGCategory.foodPreparation, name: 'Marek U.', slug: 'marek-u', city: 'Koszalin', voivodeship: 'Zachodniopomorskie', title: 'Krajalnica wędlin 300 mm – nóż chromowany', price: 1350, imageUrl: TGListingImages.meatSlicer, description: 'Krajalnica po ostrzeniu noża. Osłona i popychacz w zestawie.'),
  TGStandardMemberSeed(n: 17, category: TGCategory.foodPreparation, name: 'Kinga F.', slug: 'kinga-f', city: 'Słupsk', voivodeship: 'Pomorskie', title: 'Mikser planetarny 20 L – trzy prędkości', price: 2890, imageUrl: TGListingImages.planetMixer, description: 'Misą i trzepaczka w komplecie. Używany w cukierni sezonowej.'),
  TGStandardMemberSeed(n: 18, category: TGCategory.foodPreparation, name: 'Bartek Z.', slug: 'bartek-z', city: 'Tarnów', voivodeship: 'Małopolskie', title: 'Wilk 12 mm – korpus ze stali nierdzewnej', price: 1620, imageUrl: TGListingImages.mixer, description: 'Wilk do mięsa, sitka w zestawie. Krótki sezon festynowy.'),
  TGStandardMemberSeed(n: 19, category: TGCategory.foodPreparation, name: 'Lena O.', slug: 'lena-o', city: 'Częstochowa', voivodeship: 'Śląskie', title: 'Szatkownica warzyw 550 W – komplet tarcz', price: 1180, imageUrl: TGListingImages.foodPrep, description: 'Szatkownica z tarczami do plastrów i słupków. Sprawna.'),
  TGStandardMemberSeed(n: 20, category: TGCategory.foodPreparation, name: 'Damian V.', slug: 'damian-v', city: 'Wałbrzych', voivodeship: 'Dolnośląskie', title: 'Pakowarka próżniowa 40 cm – listwa zgrzewu', price: 2540, imageUrl: TGListingImages.vacuum, description: 'Listwa 40 cm, pompa sucha. Sprzedaję po zmianie menu.'),
  // Stainless
  TGStandardMemberSeed(n: 21, category: TGCategory.stainlessSteelFurniture, name: 'Hania Q.', slug: 'hania-q', city: 'Legnica', voivodeship: 'Dolnośląskie', title: 'Regał ścienny inox 1200x400 – dwie półki', price: 640, imageUrl: TGListingImages.shelves, description: 'Regał ścienny AISI 304. Nowy, jeszcze w folii na półkach.'),
  TGStandardMemberSeed(n: 22, category: TGCategory.stainlessSteelFurniture, name: 'Artur Y.', slug: 'artur-y', city: 'Jelenia Góra', voivodeship: 'Dolnośląskie', title: 'Szafka przelotowa 1800 mm – drzwi suwane', price: 2280, imageUrl: TGListingImages.stainless, description: 'Szafka przelotowa do linii. Drzwi chodzą lekko, dno spawane.'),
  TGStandardMemberSeed(n: 23, category: TGCategory.stainlessSteelFurniture, name: 'Maja E.', slug: 'maja-e', city: 'Nowy Sącz', voivodeship: 'Małopolskie', title: 'Zlew dwukomorowy 1400 mm – noga regulowana', price: 1540, imageUrl: TGListingImages.paslanmazEquip, description: 'Wanna 2-komorowa z ociekaczem. Syfony w komplecie.'),
  TGStandardMemberSeed(n: 24, category: TGCategory.stainlessSteelFurniture, name: 'Szymon X.', slug: 'szymon-x', city: 'Piotrków Trybunalski', voivodeship: 'Łódzkie', title: 'Wózek transportowy 3 półki – koła z hamulcem', price: 720, imageUrl: TGListingImages.shelves, description: 'Wózek inox, obciążenie 150 kg. Koła nowe.'),
  TGStandardMemberSeed(n: 25, category: TGCategory.stainlessSteelFurniture, name: 'Weronika A.', slug: 'weronika-a', city: 'Siedlce', voivodeship: 'Mazowieckie', title: 'Okap przyścienny 2000x900 – filtr kasetowy', price: 3350, imageUrl: TGListingImages.aspirator, description: 'Okap z filtrami. Demontaż po mojej stronie, odbiór z lokalu.'),
  // Bar
  TGStandardMemberSeed(n: 26, category: TGCategory.barAndBeverageEquipment, name: 'Igor S.', slug: 'igor-s', city: 'Suwałki', voivodeship: 'Podlaskie', title: 'Blender barowy 2 L – wysokie obroty', price: 480, imageUrl: TGListingImages.milkshake, description: 'Blender do shake i koktajli. Nóż i dzban w komplecie.'),
  TGStandardMemberSeed(n: 27, category: TGCategory.barAndBeverageEquipment, name: 'Pola C.', slug: 'pola-c', city: 'Łomża', voivodeship: 'Podlaskie', title: 'Ekspres 2-grupowy – osobny młynek w zestawie', price: 6200, imageUrl: TGListingImages.coffeeEspresso, description: 'Ekspres dwugrupowy po przeglądzie. Młynek oddzielny, odbiór z kawiarni.'),
  TGStandardMemberSeed(n: 28, category: TGCategory.barAndBeverageEquipment, name: 'Tadeusz L.', slug: 'tadeusz-l', city: 'Chełm', voivodeship: 'Lubelskie', title: 'Kostkarka barowa 20 kg – model podblatowy', price: 1870, imageUrl: TGListingImages.iceMachine, description: 'Kostkarka do baru. Filtr wody wymieniony w tym miesiącu.'),
  TGStandardMemberSeed(n: 29, category: TGCategory.barAndBeverageEquipment, name: 'Nina Z.', slug: 'nina-z', city: 'Przemyśl', voivodeship: 'Podkarpackie', title: 'Sokowirówka cytrusowa – dźwignia ręczna', price: 390, imageUrl: TGListingImages.barEquip, description: 'Wyciskarka do cytrusów. Mało używana, czysta misa.'),
  TGStandardMemberSeed(n: 30, category: TGCategory.barAndBeverageEquipment, name: 'Kacper E.', slug: 'kacper-e', city: 'Zamość', voivodeship: 'Lubelskie', title: 'Chłodziarka do wina 50 butelek – dwie strefy', price: 2740, imageUrl: TGListingImages.wineBar, description: 'Dwie strefy temperatury. Szkło całe, półki drewniane.'),
];

List<TGProduct> buildStandardMemberListings(DateTime now) {
  return [
    for (final s in kStandardMemberSeeds)
      TGProduct(
        id: s.id,
        title: s.title,
        price: s.price,
        priceUnit: TGPriceUnit.oneTime,
        priceBasis: TGPriceBasis.brutto,
        negotiable: false,
        oldPrice: null,
        condition: TGCondition.used,
        listingType: TGListingType.buy,
        category: s.category,
        powerType: s.category == TGCategory.stainlessSteelFurniture ? TGPowerType.other : TGPowerType.electric,
        warrantyMonths: 0,
        delivery: false,
        pickup: true,
        seller: TGSeller(
          id: s.sellerId,
          name: s.name,
          type: TGSellerType.private,
          verified: false,
          rating: 4.0 + (s.n % 9) * 0.1,
        ),
        city: s.city,
        voivodeship: s.voivodeship,
        phone: s.phone,
        imageUrl: s.imageUrl,
        photoCount: 4,
        isPromoted: false,
        createdAt: now.subtract(Duration(hours: 6 + s.n)),
        description: s.description,
      ),
  ];
}

List<TGStoreProfile> buildStandardMemberProfiles() {
  return [
    for (final s in kStandardMemberSeeds)
      TGStoreProfile(
        publicId: s.publicId,
        slug: s.slug,
        sellerKey: s.sellerId,
        type: TGSellerType.private,
        name: s.name,
        verified: false,
        status: TGStoreStatus.active,
        phone: s.phone,
        city: s.city,
        voivodeship: s.voivodeship,
        memberSince: DateTime(2026, 9, 1).add(Duration(days: s.n)),
        rating: 4.0 + (s.n % 9) * 0.1,
        reviewsCount: 0,
        description: 'Nowe konto prywatne. Jedna standardowa oferta bez pakietu promocyjnego.',
        categories: [s.category],
      ),
  ];
}
