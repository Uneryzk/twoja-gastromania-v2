import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_model.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/index.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_search_field.dart';
import 'package:twoja_gastromania/tg_components/tg_top_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';
import 'home_page_model.dart';
import 'home_sections.dart';

export 'home_page_model.dart';

/// `/` – the landing page.
///
/// Every entry point to the catalogue goes through [TGNav] and ends up on
/// `/products`: the "Buy" / "Rent" pills, each category card, "View all", the
/// header search and the best-seller cards.
class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static const String routeName = 'HomePage';
  static const String routePath = '/';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  late HomePageModel _model;
  List<TGProduct> _all = const [];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());
    _loadCatalogue();
  }

  Future<void> _loadCatalogue() async {
    try {
      final all = await TGProductService.instance.getAll();
      if (mounted) setState(() => _all = all);
    } catch (e) {
      debugPrint('Home catalogue load failed: $e');
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final pad = phone ? 16.0 : 24.0;

    final promoted = _all.where((p) => p.isActive && p.isPromoted).take(3).toList();
    final counts = {for (final c in TGCategory.values) c: _all.where((p) => p.isPubliclyVisible && p.category == c).length};

    Widget section(Widget child, {double top = 56}) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(padding: EdgeInsets.fromLTRB(pad, top, pad, 0), child: child),
          ),
        );

    return TGPageScaffold(
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          controller: _model.scrollController,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, t, child) => Opacity(opacity: t, child: child),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TGTopNav(),
                if (phone)
                  // The global header hides its search box on phones.
                  section(
                    TGSearchField(hint: context.t('ui_search_equipment'), onSubmitted: (q) => TGNav.search(context, q)),
                    top: 2,
                  ),
                section(
                  HomeHeroCarousel(
                    slideRouteNames: [
                      BirinciReklamSayfasiWidget.routeName,
                      IkinciReklamSayfasiWidget.routeName,
                      UcuncuReklamSayfasiWidget.routeName,
                      DortuncuReklamSayfasiWidget.routeName,
                    ],
                  ),
                  top: 12,
                ),
                section(HomeCategorySection(listingCounts: counts)),
                if (promoted.isNotEmpty) section(HomePromotedSection(products: promoted)),
                section(const HomeBestSellers()),
                section(const HomeStatsSection()),
                const SizedBox(height: 72),
                const TGFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
