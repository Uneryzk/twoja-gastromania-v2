import 'package:twoja_gastromania/flutter_flow/flutter_flow_model.dart';
import 'package:flutter/material.dart';
import 'home_page_widget.dart' show HomePageWidget;

class HomePageModel extends FlutterFlowModel<HomePageWidget> {
  /// Scroll position of the home page (used for the back-to-top affordance).
  final ScrollController scrollController = ScrollController();

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    scrollController.dispose();
  }
}
