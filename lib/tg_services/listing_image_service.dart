import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_seed_phash.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_models/tg_watermark.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

/// Listing photo records: public variants + private originals.
///
/// Prototype: there is no image server, so every variant points at the same
/// bundled file and the watermark is a client overlay. Overlay gives no real
/// protection — the raw file URL stays open. Production must burn the mark
/// into server-side derivatives and keep originals private.
class TGListingImageService extends ChangeNotifier {
  TGListingImageService._();
  static final TGListingImageService instance = TGListingImageService._();

  final Map<String, List<ListingImage>> _byListing = {};

  /// originalRef → source the original bytes are read from (staff/server only).
  final Map<String, String> _originalSource = {};

  static String productKey(TGProduct p) => 'product:${p.listingNo ?? p.id}';
  static String restaurantKey(RestaurantListing r) => 'restaurant:${r.listingNo}';
  static String listingNoKey(String listingNo) => 'product:$listingNo';

  void reset() {
    _byListing.clear();
    _originalSource.clear();
  }

  List<ListingImage> imagesFor(String listingKey) => List.unmodifiable(_byListing[listingKey] ?? const []);

  Iterable<ListingImage> get all => _byListing.values.expand((e) => e);

  /// Registers (or keeps) one record per URL. Never notifies — safe during build.
  List<ListingImage> sync({
    required String listingKey,
    required List<String> urls,
    required String uploadedById,
    required String uploadedByName,
    required DateTime uploadedAt,
  }) {
    final existing = _byListing[listingKey] ?? const <ListingImage>[];
    final out = <ListingImage>[];
    for (var i = 0; i < urls.length; i++) {
      final url = urls[i].trim();
      if (url.isEmpty) continue;
      final prev = existing.where((e) => e.variant(TGImageVariant.card) == url).firstOrNull;
      if (prev != null) {
        out.add(prev);
        continue;
      }
      final ref = 'originals/$listingKey/${out.length}-${url.hashCode.toUnsigned(32).toRadixString(16)}';
      _originalSource[ref] = url;
      out.add(ListingImage.upload(
        id: '$listingKey#${out.length}',
        listingKey: listingKey,
        index: out.length,
        originalRef: ref,
        variants: {for (final v in TGImageVariant.values) v: url},
        uploadedById: uploadedById,
        uploadedByName: uploadedByName,
        uploadedAt: uploadedAt,
        phash: kSeedOriginalPhash[url],
      ));
    }
    _byListing[listingKey] = out;
    return out;
  }

  List<ListingImage> syncProduct(TGProduct p) => sync(
        listingKey: productKey(p),
        urls: p.gallery,
        uploadedById: p.seller.id,
        uploadedByName: p.seller.name,
        uploadedAt: p.publishedAt ?? p.createdAt,
      );

  List<ListingImage> syncRestaurant(RestaurantListing r) => sync(
        listingKey: restaurantKey(r),
        urls: r.images,
        uploadedById: r.seller.id,
        uploadedByName: r.seller.name,
        uploadedAt: r.publishedAt ?? TGClock.now(),
      );

  /// Every cached product and restaurant listing (reprocess job input).
  List<ListingImage> syncAll() {
    for (final p in TGProductService.instance.cachedAll) {
      syncProduct(p);
    }
    for (final r in RestaurantService.instance.all) {
      syncRestaurant(r);
    }
    return all.toList();
  }

  void replace(ListingImage next) {
    final list = _byListing[next.listingKey];
    if (list == null) return;
    final i = list.indexWhere((e) => e.id == next.id);
    if (i >= 0) list[i] = next;
  }

  void notify() => notifyListeners();

  /// Staff-only lookup of the private original reference.
  String? originalRefFor(String imageId, TGUserRole role) {
    if (!role.isStaff) return null;
    return all.where((e) => e.id == imageId).firstOrNull?.originalRefFor(role);
  }

  /// Hashes originals that have no pHash yet (new uploads). Reads the ORIGINAL bytes.
  Future<int> computePendingHashes({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    var done = 0;
    for (final img in all.where((e) => e.phash == null).toList()) {
      final src = _originalSource[img.originalRefFor(TGUserRole.admin)];
      if (src == null || !src.startsWith('assets/')) continue;
      try {
        final bytes = (await b.load(src)).buffer.asUint8List();
        replace(img.copyWith(phash: await TGPhash.fromEncoded(bytes)));
        done++;
      } catch (_) {}
    }
    if (done > 0) notifyListeners();
    return done;
  }

  /// Closest pair of ORIGINALS between two listings. Staff only; null otherwise
  /// or when either side has no hashed original.
  TGOriginalMatch? compareOriginals(String listingKeyA, String listingKeyB, TGUserRole role) {
    if (!role.isStaff) return null;
    TGOriginalMatch? best;
    for (final a in imagesFor(listingKeyA)) {
      for (final b in imagesFor(listingKeyB)) {
        if (a.phash == null || b.phash == null) continue;
        final d = TGPhash.distance(a.phash!, b.phash!);
        if (best != null && d >= best.distance) continue;
        final aFirst = !a.uploadedAt.isAfter(b.uploadedAt);
        best = TGOriginalMatch(distance: d, earlier: aFirst ? a : b, later: aFirst ? b : a);
      }
    }
    return best;
  }
}
