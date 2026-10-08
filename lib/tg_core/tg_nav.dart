import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/tg_components/tg_account_sheets.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/messaging_service.dart';

/// Every cross-page navigation of the app goes through here, so a "Buy"
/// button on the home page, in the footer or on an ad page all behave the same.
///
/// `/products` is deliberately opened with `go` (not `push`): the products page
/// keeps its filters in the URL and updates it with `go`, so using the same call
/// keeps a single, stable page instance.
abstract final class TGNav {
  static const String homePath = '/';
  static const String productsPath = '/products';

  static void home(BuildContext context) => context.go(homePath);

  /// Opens the products page with [query] applied (defaults to "everything").
  static void products(BuildContext context, [TGProductsQueryState query = const TGProductsQueryState()]) =>
      context.go(query.toLocation(path: productsPath));

  static void buy(BuildContext context) =>
      products(context, const TGProductsQueryState(listingType: TGListingType.buy));

  static void rent(BuildContext context) =>
      products(context, const TGProductsQueryState(listingType: TGListingType.rent));

  static void category(BuildContext context, TGCategory category) =>
      products(context, TGProductsQueryState(categories: {category}));

  static void verifiedSellers(BuildContext context) =>
      products(context, const TGProductsQueryState(verifiedOnly: true));

  static void listing(BuildContext context, TGProduct product) => context.go(product.detailPath);

  static void search(BuildContext context, String text) {
    final t = text.trim();
    products(context, TGProductsQueryState(search: t.isEmpty ? null : t));
  }

  static void login(BuildContext context) => context.goNamed(LoginPageWidget.routeName);

  /// "+ Add Product" opens the listing wizard.
  static void addProduct(BuildContext context) => context.go('/add-product');

  static void pricing(BuildContext context) => showTGPricingSheet(context);

  /// Direct B2B lead-gen for manufacturers, with a reference photo gallery.
  static void specialOrder(BuildContext context) => showTGSpecialOrderSheet(context);

  static void storeQuote(BuildContext context, int sellerId) => context.push('/special-order?seller=$sellerId');

  static void dashboardListings(BuildContext context, {String? filter, String? renew}) {
    final parts = <String>[
      if (filter != null && filter.isNotEmpty) 'filter=$filter',
      if (renew != null && renew.isNotEmpty) 'renew=$renew',
    ];
    context.go('/dashboard/listings${parts.isEmpty ? '' : '?${parts.join('&')}'}');
  }

  static void messages(BuildContext context, {String? threadId}) {
    final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
    if (wide) {
      MessagingService.instance.openDock(threadId: threadId, inbox: true);
      return;
    }
    context.go('/dashboard/messages${threadId == null || threadId.isEmpty ? '' : '?thread=$threadId'}');
  }

  static void restaurantsForSale(BuildContext context) => _comingSoon(context, 'Restaurants for Sale');

  static void _comingSoon(BuildContext context, String feature) => showTGToast(
        context,
        '$feature is coming soon',
        icon: Icons.schedule_rounded,
      );
}
