import 'tg_jsonld_stub.dart' if (dart.library.html) 'tg_jsonld_web.dart';

void setStoreAggregateRating({required String name, required double rating, required int count}) =>
    applyStoreAggregateRating(name: name, rating: rating, count: count);

void clearStoreAggregateRatingSeo() => clearStoreAggregateRating();
