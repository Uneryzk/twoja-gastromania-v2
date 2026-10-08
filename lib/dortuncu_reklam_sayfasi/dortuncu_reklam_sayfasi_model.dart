import 'package:twoja_gastromania/flutter_flow/flutter_flow_drop_down.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_util.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_widgets.dart';
import 'package:twoja_gastromania/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import 'dortuncu_reklam_sayfasi_widget.dart' show DortuncuReklamSayfasiWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class DortuncuReklamSayfasiModel
    extends FlutterFlowModel<DortuncuReklamSayfasiWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;
  // State field(s) for DropDown widget.
  String? dropDownValue;
  FormFieldController<String>? dropDownValueController;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
