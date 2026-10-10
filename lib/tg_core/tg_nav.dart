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

  /// Special Order hub + manufacturer guide.
  static void specialOrder(BuildContext context) => context.go('/special-order');

  static void storeQuote(BuildContext context, int sellerId) => context.go('/special-order/new?seller=$sellerId');

  static void dashboardListings(BuildContext context, {String? filter, String? renew, String? sold}) {
    final parts = <String>[
      if (filter != null && filter.isNotEmpty) 'filter=$filter',
      if (renew != null && renew.isNotEmpty) 'renew=$renew',
      if (sold != null && sold.isNotEmpty) 'sold=$sold',
    ];
    context.go('/dashboard/listings${parts.isEmpty ? '' : '?${parts.join('&')}'}');
  }

  static void dashboardDeals(BuildContext context, {String? tab}) {
    context.go('/dashboard/deals${tab == null || tab.isEmpty || tab == 'all' ? '' : '?tab=$tab'}');
  }

  static void accountDeals(BuildContext context, {String? tab, String? dealId, bool confirm = false}) {
    if (dealId != null && dealId.isNotEmpty) {
      context.go('/account/deals/$dealId${confirm ? '?confirm=1' : ''}');
      return;
    }
    context.go('/account/deals${tab == null || tab.isEmpty ? '' : '?tab=$tab'}');
  }

  static void accountReviews(BuildContext context, {String? tab, String? reviewId, bool evidence = false, bool compose = false, String? listingNo}) {
    if (reviewId != null && reviewId.isNotEmpty) {
      context.go('/account/reviews/$reviewId${evidence ? '?evidence=1' : ''}');
      return;
    }
    final q = <String>[
      if (tab != null && tab.isNotEmpty) 'tab=$tab',
      if (compose) 'compose=1',
      if (listingNo != null && listingNo.isNotEmpty) 'listingNo=$listingNo',
    ];
    context.go('/account/reviews${q.isEmpty ? '' : '?${q.join('&')}'}');
  }

  static void accountNotifications(BuildContext context) => context.go('/account/notifications');

  static void messages(BuildContext context, {String? threadId}) {
    final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
    if (wide) {
      MessagingService.instance.openDock(threadId: threadId, inbox: true);
      return;
    }
    context.go('/dashboard/messages${threadId == null || threadId.isEmpty ? '' : '?thread=$threadId'}');
  }

  static void plans(BuildContext context) => context.go('/plans');

  static void accountRequests(BuildContext context, {String? requestNo, String? tab}) {
    if (requestNo != null && requestNo.isNotEmpty) {
      context.go('/account/requests/$requestNo${tab == null || tab.isEmpty ? '' : '?tab=$tab'}');
      return;
    }
    context.go('/account/requests${tab == null || tab.isEmpty ? '' : '?tab=$tab'}');
  }

  static void sellerLeads(BuildContext context, {String? requestNo, String? tab, bool directed = false}) {
    final q = <String>[
      if (requestNo != null && requestNo.isNotEmpty) 'id=$requestNo',
      if (tab != null && tab.isNotEmpty) 'tab=$tab',
      if (directed) 'directed=1',
    ];
    context.go('/dashboard/leads${q.isEmpty ? '' : '?${q.join('&')}'}');
  }

  static void restaurantsForSale(BuildContext context) => _comingSoon(context, 'Restaurants for Sale');

  static void _comingSoon(BuildContext context, String feature) => showTGToast(
        context,
        '$feature is coming soon',
        icon: Icons.schedule_rounded,
      );
}
