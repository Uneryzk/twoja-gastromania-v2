import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';

import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_util.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'serialization_util.dart';

import 'package:twoja_gastromania/admin/admin_target_pages.dart';
import 'package:twoja_gastromania/index.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  bool showSplashImage = true;

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

/// Legacy URL of the home page (it used to live at `/homePage`).
const String kLegacyHomePath = '/homePage';

GoRouter createRouter(AppStateNotifier appStateNotifier, {String initialLocation = '/'}) => GoRouter(
      // The app opens on the home page; "Buy", "Rent" and every category card
      // there lead to `/products` (see TGNav).
      initialLocation: initialLocation,
      debugLogDiagnostics: true,
      refreshListenable: appStateNotifier,
      navigatorKey: appNavigatorKey,
      errorBuilder: (context, state) {
        // NOTE: go_router asserts if more than one of onException / errorPageBuilder /
        // errorBuilder are provided. Keep errorBuilder and log from here.
        debugPrint('GoRouter error at location=${state.uri} error=${state.error}');
        final theme = FlutterFlowTheme.of(context);
        return Scaffold(
          backgroundColor: theme.primaryBackground,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.explore_off_outlined, color: theme.primary, size: 48),
                      const SizedBox(height: 14),
                      Text(context.t('ui_page_not_found'), style: theme.titleLarge, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                        context.t('ui_page_not_found_path', {'uri': '${state.uri}'}),
                        style: theme.bodyMedium.override(color: theme.secondaryText),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TGButton(
                        onPressed: () => context.go('/'),
                        label: context.t('ui_back_to_home'),
                        icon: Icons.home_outlined,
                        height: 46,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      routes: [
        FFRoute(
          name: HomePageWidget.routeName,
          path: HomePageWidget.routePath, // '/'
          builder: (context, params) => const HomePageWidget(),
        ),
        FFRoute(
          name: BirinciReklamSayfasiWidget.routeName,
          path: BirinciReklamSayfasiWidget.routePath,
          builder: (context, params) => BirinciReklamSayfasiWidget(),
        ),
        FFRoute(
          name: TgEditorialMagazineView.routeName,
          path: TgEditorialMagazineView.routePath,
          builder: (context, params) => const TgEditorialMagazineView(),
        ),
        FFRoute(
          name: IkinciReklamSayfasiWidget.routeName,
          path: IkinciReklamSayfasiWidget.routePath,
          builder: (context, params) => IkinciReklamSayfasiWidget(),
        ),
        FFRoute(
          name: UcuncuReklamSayfasiWidget.routeName,
          path: UcuncuReklamSayfasiWidget.routePath,
          builder: (context, params) => UcuncuReklamSayfasiWidget(),
        ),
        FFRoute(
          name: DortuncuReklamSayfasiWidget.routeName,
          path: DortuncuReklamSayfasiWidget.routePath,
          builder: (context, params) => DortuncuReklamSayfasiWidget(),
        ),
        FFRoute(
          name: LoginPageWidget.routeName,
          path: LoginPageWidget.routePath,
          builder: (context, params) => LoginPageWidget(
            startRegister: params.state.uri.queryParameters['mode'] == 'register',
            referralCode: params.state.uri.queryParameters['ref'],
          ),
        ),
        FFRoute(
          name: 'RegisterPage',
          path: LoginPageWidget.registerPath,
          builder: (context, params) => LoginPageWidget(
            startRegister: true,
            referralCode: params.state.uri.queryParameters['ref'],
          ),
        ),
        FFRoute(
          name: ProductDetailPageWidget.routeName,
          path: ProductDetailPageWidget.routePath,
          builder: (context, params) => ProductDetailPageWidget(productId: params.state.pathParameters['id'] ?? ''),
        ),
        FFRoute(
          name: SellerProfilePageWidget.routeName,
          path: SellerProfilePageWidget.routePath,
          builder: (context, params) => SellerProfilePageWidget(sellerId: params.state.pathParameters['id'] ?? ''),
        ),
        FFRoute(
          name: SpecialOrderHubPage.routeName,
          path: SpecialOrderHubPage.routePath,
          builder: (context, params) => SpecialOrderHubPage(initialQuery: params.state.uri.queryParameters),
        ),
        FFRoute(
          name: SpecialOrderNewPage.routeName,
          path: SpecialOrderNewPage.routePath,
          builder: (context, params) => SpecialOrderNewPage(query: params.state.uri.queryParameters),
        ),
        FFRoute(
          name: SpecialOrderConfirmPage.routeName,
          path: SpecialOrderConfirmPage.routePath,
          builder: (context, params) => SpecialOrderConfirmPage(draftId: params.state.uri.queryParameters['draft'] ?? ''),
        ),
        FFRoute(
          name: SpecialOrderSuccessPage.routeName,
          path: SpecialOrderSuccessPage.routePath,
          builder: (context, params) => SpecialOrderSuccessPage(requestNo: params.state.uri.queryParameters['no']),
        ),
        FFRoute(
          name: BuyerRequestsPage.routeName,
          path: BuyerRequestsPage.routePath,
          builder: (context, params) => BuyerRequestsPage(tab: params.state.uri.queryParameters['tab']),
        ),
        FFRoute(
          name: SpecialRequestConsentPage.routeName,
          path: SpecialRequestConsentPage.routePath,
          builder: (context, params) => SpecialRequestConsentPage(requestNo: params.state.pathParameters['requestNo'] ?? ''),
        ),
        FFRoute(
          name: 'BuyerRequestDetail',
          path: '/account/requests/:requestNo',
          builder: (context, params) => BuyerRequestsPage(
            requestNo: params.state.pathParameters['requestNo'],
            tab: params.state.uri.queryParameters['tab'],
          ),
        ),
        FFRoute(
          name: SellerLeadsPage.routeName,
          path: SellerLeadsPage.routePath,
          builder: (context, params) => SellerLeadsPage(
            tab: params.state.uri.queryParameters['tab'],
            requestNo: params.state.uri.queryParameters['id'],
            directedOnly: params.state.uri.queryParameters['directed'] == '1',
          ),
        ),
        FFRoute(
          // Filters live in the query string: /products?type=rent&cat=cooking&...
          name: ProductsPageWidget.routeName,
          path: ProductsPageWidget.routePath,
          builder: (context, params) => const ProductsPageWidget(),
        ),
        FFRoute(
          name: RestaurantsPageWidget.routeName,
          path: RestaurantsPageWidget.routePath,
          builder: (context, params) => const RestaurantsPageWidget(),
        ),
        FFRoute(
          name: RestaurantWizardPage.routeName,
          path: RestaurantWizardPage.routePath,
          builder: (context, params) => RestaurantWizardPage(
            resumeId: params.state.uri.queryParameters['resume'],
          ),
        ),
        // Static /restaurants/* paths MUST be registered before :segment,
        // otherwise "success" / "checkout" match the detail route and show 404.
        FFRoute(
          name: RestaurantSuccessPage.routeName,
          path: RestaurantSuccessPage.routePath,
          builder: (context, params) => RestaurantSuccessPage(
            listingId: params.state.uri.queryParameters['id'],
            pending: params.state.uri.queryParameters['pending'] == '1',
          ),
        ),
        FFRoute(
          name: 'RestaurantCheckout',
          path: '/restaurants/checkout',
          builder: (context, params) => const CheckoutPage(),
        ),
        FFRoute(
          name: RestaurantDetailsEditorPage.routeName,
          path: RestaurantDetailsEditorPage.routePath,
          builder: (context, params) => RestaurantDetailsEditorPage(
            listingNo: params.state.pathParameters['listingNo'] ?? '',
            section: params.state.uri.queryParameters['section'],
          ),
        ),
        FFRoute(
          name: RestaurantDetailPage.routeName,
          path: RestaurantDetailPage.routePath,
          builder: (context, params) => RestaurantDetailPage(
            segment: params.state.pathParameters['segment'] ?? '',
          ),
        ),
        FFRoute(
          name: ListingsDashboardPage.routeName,
          path: ListingsDashboardPage.routePath,
          builder: (context, params) => ListingsDashboardPage(
            filter: params.state.uri.queryParameters['filter'] ?? params.state.uri.queryParameters['tab'],
            renewId: params.state.uri.queryParameters['renew'],
            renewedId: params.state.uri.queryParameters['renewed'],
            soldId: params.state.uri.queryParameters['sold'],
            type: params.state.uri.queryParameters['type'],
            query: params.state.uri.queryParameters['q'],
          ),
        ),
        FFRoute(
          name: BulkAddPage.routeName,
          path: BulkAddPage.routePath,
          builder: (context, params) => const BulkAddPage(),
        ),
        FFRoute(
          name: SellerDealsPage.routeName,
          path: SellerDealsPage.routePath,
          builder: (context, params) => SellerDealsPage(tab: params.state.uri.queryParameters['tab']),
        ),
        FFRoute(
          name: BuyerDealsPage.routeName,
          path: BuyerDealsPage.routePath,
          builder: (context, params) => BuyerDealsPage(
            tab: params.state.uri.queryParameters['tab'],
            confirm: params.state.uri.queryParameters['confirm'] == '1',
          ),
        ),
        FFRoute(
          name: 'BuyerDealDetail',
          path: '/account/deals/:id',
          builder: (context, params) => BuyerDealsPage(
            dealId: params.state.pathParameters['id'],
            confirm: params.state.uri.queryParameters['confirm'] == '1',
            tab: params.state.uri.queryParameters['tab'],
          ),
        ),
        FFRoute(
          name: BuyerReviewsPage.routeName,
          path: BuyerReviewsPage.routePath,
          builder: (context, params) => BuyerReviewsPage(
            tab: params.state.uri.queryParameters['tab'],
            compose: params.state.uri.queryParameters['compose'] == '1',
            listingNo: params.state.uri.queryParameters['listingNo'],
          ),
        ),
        FFRoute(
          name: 'BuyerReviewDetail',
          path: '/account/reviews/:id',
          builder: (context, params) => BuyerReviewsPage(
            reviewId: params.state.pathParameters['id'],
            evidence: params.state.uri.queryParameters['evidence'] == '1',
            tab: params.state.uri.queryParameters['tab'],
          ),
        ),
        FFRoute(
          name: NotificationsPage.routeName,
          path: NotificationsPage.routePath,
          builder: (context, params) => NotificationsPage(tab: params.state.uri.queryParameters['tab']),
        ),
        FFRoute(
          name: SellerVerificationPage.routeName,
          path: SellerVerificationPage.routePath,
          builder: (context, params) => SellerVerificationPage(sellerId: params.state.uri.queryParameters['seller']),
        ),
        FFRoute(
          name: AdminVerifiedPage.routeName,
          path: AdminVerifiedPage.routePath,
          builder: (context, params) => const AdminVerifiedHost(),
        ),
        FFRoute(
          name: AdminWatermarkPage.routeName,
          path: AdminWatermarkPage.routePath,
          builder: (context, params) => const AdminWatermarkHost(),
        ),
        FFRoute(
          name: MessagesPage.routeName,
          path: MessagesPage.routePath,
          builder: (context, params) => MessagesPage(threadId: params.state.uri.queryParameters['thread']),
        ),
        FFRoute(
          name: AddProductPage.routeName,
          path: AddProductPage.routePath,
          builder: (context, params) => const AddProductPage(),
        ),
        FFRoute(
          name: PublishSuccessPage.routeName,
          path: PublishSuccessPage.routePath,
          builder: (context, params) => PublishSuccessPage(listingId: params.state.uri.queryParameters['id']),
        ),
        FFRoute(
          name: CheckoutPage.routeName,
          path: CheckoutPage.routePath,
          builder: (context, params) => const CheckoutPage(),
        ),
        FFRoute(
          name: PlansPage.routeName,
          path: PlansPage.routePath,
          builder: (context, params) => const PlansPage(),
        ),
        FFRoute(
          name: 'AdminQueue',
          path: '/admin',
          builder: (context, params) => AdminQueueHost(filter: params.state.uri.queryParameters['filter']),
        ),
        FFRoute(
          name: 'AdminListings',
          path: '/admin/listings',
          builder: (context, params) => const AdminListingsHost(),
        ),
        FFRoute(
          name: 'AdminSellers',
          path: '/admin/sellers',
          builder: (context, params) => const AdminSellersHost(),
        ),
        FFRoute(
          name: 'AdminAudit',
          path: '/admin/audit',
          builder: (context, params) => const AdminAuditHost(),
        ),
        FFRoute(name: 'AdminToday', path: '/admin/today', builder: (context, params) => const AdminTodayHost()),
        FFRoute(
          name: 'AdminUsers',
          path: '/admin/users',
          builder: (context, params) => AdminUsersHost(query: params.state.uri.queryParameters['q']),
        ),
        FFRoute(
          name: 'AdminUser360',
          path: '/admin/users/:userId',
          builder: (context, params) => AdminUser360Host(userId: params.state.pathParameters['userId'] ?? ''),
        ),
        FFRoute(name: 'AdminPayments', path: '/admin/payments', builder: (context, params) => const AdminPaymentsHost()),
        FFRoute(name: 'AdminConversations', path: '/admin/conversations', builder: (context, params) => const AdminConversationsHost()),
        FFRoute(name: 'AdminNip', path: '/admin/nip', builder: (context, params) => const AdminNipHost()),
        FFRoute(name: 'AdminGoLive', path: '/admin/go-live', builder: (context, params) => const AdminGoLiveHost()),
        FFRoute(
          name: 'AdminTemplates',
          path: '/admin/templates',
          builder: (context, params) => const AdminTemplatesHost(),
        ),
        FFRoute(
          name: 'AdminCase',
          path: '/admin/l/:listingNo',
          builder: (context, params) => AdminCaseHost(listingNo: params.state.pathParameters['listingNo'] ?? ''),
        ),
        FFRoute(
          name: 'AdminSellerCase',
          path: '/admin/s/:sellerId',
          builder: (context, params) => AdminSellerCaseHost(sellerId: params.state.pathParameters['sellerId'] ?? ''),
        ),
        FFRoute(
          name: 'AdminReviewCase',
          path: '/admin/r/:reviewId',
          builder: (context, params) => AdminReviewCaseHost(reviewId: params.state.pathParameters['reviewId'] ?? ''),
        ),
        FFRoute(
          name: 'AdminDeals',
          path: '/admin/deals',
          builder: (context, params) => AdminDealsHost(queue: params.state.uri.queryParameters['queue']),
        ),
        FFRoute(
          name: 'AdminDealCase',
          path: '/admin/d/:dealNo',
          builder: (context, params) => AdminDealCaseHost(dealNo: params.state.pathParameters['dealNo'] ?? ''),
        ),
        FFRoute(
          name: 'AdminSpecialOrders',
          path: '/admin/special-orders',
          builder: (context, params) => AdminSoHost(queue: params.state.uri.queryParameters['queue']),
        ),
        FFRoute(
          name: 'AdminSpecialOrderCase',
          path: '/admin/special-orders/:requestNo',
          builder: (context, params) => AdminSoCaseHost(requestNo: params.state.pathParameters['requestNo'] ?? ''),
        ),
        FFRoute(
          name: 'AdminRevenueConfig',
          path: '/admin/revenue-config',
          builder: (context, params) => const AdminRevenueConfigHost(),
        ),
        FFRoute(
          name: 'AdminGrowth',
          path: '/admin/growth',
          builder: (context, params) => AdminGrowthHost(tab: params.state.uri.queryParameters['tab']),
        ),
        FFRoute(
          name: 'AdminPriority',
          path: '/admin/priority',
          builder: (context, params) => const AdminPriorityHost(),
        ),
        FFRoute(
          name: 'AdminFounders',
          path: '/admin/founders',
          builder: (context, params) => const AdminFoundersHost(),
        ),
        FFRoute(
          name: 'AdminSponsorSlots',
          path: '/admin/sponsor-slots',
          builder: (context, params) => const AdminSponsorSlotsHost(),
        ),
        FFRoute(
          name: 'AdminAds',
          path: '/admin/ads',
          builder: (context, params) => const AdminAdsHost(),
        ),
        FFRoute(
          name: AdvertisingPage.routeName,
          path: AdvertisingPage.routePath,
          builder: (context, params) => AdvertisingPage(
            prefillTarget: params.state.uri.queryParameters['target'],
            tab: params.state.uri.queryParameters['tab'],
          ),
        ),
        FFRoute(
          name: FoundersPage.routeName,
          path: FoundersPage.routePath,
          builder: (context, params) => const FoundersPage(),
        ),
        FFRoute(
          name: ManufacturerDashboardPage.routeName,
          path: ManufacturerDashboardPage.routePath,
          builder: (context, params) => ManufacturerDashboardPage(tab: params.state.uri.queryParameters['tab']),
        ),
        FFRoute(
          name: DashboardOverviewPage.routeName,
          path: DashboardOverviewPage.routePath,
          builder: (context, params) => const DashboardOverviewPage(),
        ),
        FFRoute(
          name: DashboardActionsPage.routeName,
          path: DashboardActionsPage.routePath,
          builder: (context, params) => const DashboardActionsPage(),
        ),
        FFRoute(
          name: InsightsPage.routeName,
          path: InsightsPage.routePath,
          builder: (context, params) => InsightsPage(
            period: int.tryParse(params.state.uri.queryParameters['period'] ?? ''),
            listingId: params.state.uri.queryParameters['listing'],
          ),
        ),
        FFRoute(
          name: FavoritesPage.routeName,
          path: FavoritesPage.routePath,
          builder: (context, params) => FavoritesPage(tab: params.state.uri.queryParameters['tab']),
        ),
        FFRoute(
          name: BillingPage.routeName,
          path: BillingPage.routePath,
          builder: (context, params) => BillingPage(tab: params.state.uri.queryParameters['tab']),
        ),
        FFRoute(
          name: SettingsPage.routeName,
          path: SettingsPage.routePath,
          builder: (context, params) => SettingsPage(tab: params.state.uri.queryParameters['tab']),
        ),
        FFRoute(
          name: RepresentativePage.routeName,
          path: RepresentativePage.routePath,
          builder: (context, params) => RepresentativePage(tab: params.state.uri.queryParameters['tab']),
        ),
        FFRoute(
          name: RepShareReportPage.routeName,
          path: RepShareReportPage.routePath,
          builder: (context, params) => RepShareReportPage(token: params.state.pathParameters['token'] ?? ''),
        ),
        for (final item in DashPlaceholders.all)
          FFRoute(
            name: 'Dashboard-${item.id}',
            path: item.route,
            builder: (context, params) => DashboardPlaceholderPage(item: item),
          ),
      ].map((r) => r.toRoute(appStateNotifier)).toList()
        ..add(GoRoute(path: '/checkout', redirect: (_, __) => CheckoutPage.routePath))
        ..add(GoRoute(path: kLegacyHomePath, redirect: (_, __) => HomePageWidget.routePath)),
    );

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void safePop() {
    // If there is only one route on the stack, navigate to the initial
    // page instead of popping.
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap =>
      extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  // Parameters are empty if the params map is empty or if the only parameter
  // present is the special extra parameter reserved for the transition info.
  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 &&
          state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map(
          (param) async {
            final doc = await asyncParams[param.key]!(param.value)
                .onError((_, __) => null);
            if (doc != null) {
              futureParamValues[param.key] = doc;
              return true;
            }
            return false;
          },
        ),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(
    String paramName,
    ParamType type, {
    bool isList = false,
  }) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) {
      return null;
    }
    final param = state.allParams[paramName];
    // Got parameter from `extras`, so just directly return it.
    if (param is! String) {
      return param;
    }
    // Return serialized value.
    return deserializeParam<T>(
      param,
      type,
      isList,
    );
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = FFParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);
          final child = page;

          final transitionInfo = state.transitionInfo;
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  name: state.name,
                  child: child,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ),
                )
              : MaterialPage(
                  key: state.pageKey, name: state.name, child: child);
        },
        routes: routes,
      );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage &&
        location != '/' &&
        location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
