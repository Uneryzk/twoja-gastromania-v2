import 'package:flutter/material.dart';
import 'package:twoja_gastromania/features/magazine/presentation/pages/tg_magazine_article_view.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_util.dart';
import 'birinci_reklam_sayfasi_model.dart';
export 'birinci_reklam_sayfasi_model.dart';

/// Home-banner “Read more” destination: B2B magazine article with cost charts.
class BirinciReklamSayfasiWidget extends StatefulWidget {
  const BirinciReklamSayfasiWidget({super.key});

  static String routeName = 'BirinciReklamSayfasi';
  static String routePath = '/birinciReklamSayfasi';

  @override
  State<BirinciReklamSayfasiWidget> createState() => _BirinciReklamSayfasiWidgetState();
}

class _BirinciReklamSayfasiWidgetState extends State<BirinciReklamSayfasiWidget> {
  late BirinciReklamSayfasiModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BirinciReklamSayfasiModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const TgMagazineArticleView();
}
