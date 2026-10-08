import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';

enum TGStoreTab { products, about, reviews }

@immutable
class TGStoreQuery {
  const TGStoreQuery({
    this.tab = TGStoreTab.products,
    this.search,
    this.category,
    this.conditions = const {},
    this.sort = TGProductsSort.recommended,
    this.page = 1,
    this.view = TGProductCardLayout.grid,
  });

  final TGStoreTab tab;
  final String? search;
  final TGCategory? category;
  final Set<TGCondition> conditions;
  final TGProductsSort sort;
  final int page;
  final TGProductCardLayout view;

  TGStoreQuery copyWith({
    TGStoreTab? tab,
    String? search,
    bool searchToNull = false,
    TGCategory? category,
    bool categoryToNull = false,
    Set<TGCondition>? conditions,
    TGProductsSort? sort,
    int? page,
    TGProductCardLayout? view,
  }) =>
      TGStoreQuery(
        tab: tab ?? this.tab,
        search: searchToNull ? null : (search ?? this.search),
        category: categoryToNull ? null : (category ?? this.category),
        conditions: conditions ?? this.conditions,
        sort: sort ?? this.sort,
        page: page ?? this.page,
        view: view ?? this.view,
      );

  Map<String, String> toQuery() {
    final qp = <String, String>{};
    if (tab != TGStoreTab.products) qp['tab'] = tab.name;
    if (search != null && search!.trim().isNotEmpty) qp['q'] = search!.trim();
    if (category != null) qp['cat'] = encodeCategory(category!);
    if (conditions.isNotEmpty) {
      qp['condition'] = conditions.map((c) => c == TGCondition.newItem ? 'new' : 'used').join(',');
    }
    if (sort != TGProductsSort.recommended) qp['sort'] = encodeSort(sort);
    if (page > 1) qp['page'] = '$page';
    if (view == TGProductCardLayout.list) qp['view'] = 'list';
    return qp;
  }

  String toLocation(String path) {
    final qp = toQuery();
    return Uri(path: path, queryParameters: qp.isEmpty ? null : qp).toString();
  }

  static TGStoreQuery fromQuery(Map<String, String> qp) {
    final tabRaw = (qp['tab'] ?? 'products').toLowerCase();
    final tab = switch (tabRaw) {
      'about' => TGStoreTab.about,
      'reviews' => TGStoreTab.reviews,
      _ => TGStoreTab.products,
    };
    final catQp = TGProductsQueryState.fromQuery({'cat': qp['cat'] ?? ''});
    return TGStoreQuery(
      tab: tab,
      search: (qp['q'] ?? '').trim().isEmpty ? null : qp['q']!.trim(),
      category: catQp.categories.firstOrNull,
      conditions: TGProductsQueryState.fromQuery({'condition': qp['condition'] ?? ''}).conditions,
      sort: decodeSort(qp['sort']),
      page: int.tryParse(qp['page'] ?? '') ?? 1,
      view: (qp['view'] ?? '') == 'list' ? TGProductCardLayout.list : TGProductCardLayout.grid,
    );
  }
}

const kStoreGridGutter = 24.0;

int storeGridColumnsFor(double width) {
  if (width >= 1180) return 4;
  if (width >= 880) return 3;
  if (width >= 560) return 2;
  return 1;
}
