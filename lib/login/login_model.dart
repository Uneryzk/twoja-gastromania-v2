import 'package:flutter/material.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_model.dart';

import 'login_widget.dart' show LoginPageWidget;

class LoginPageModel extends FlutterFlowModel<LoginPageWidget> {
  FocusNode? emailFocusNode;
  TextEditingController? emailController;
  String? Function(BuildContext, String?)? emailControllerValidator;

  FocusNode? passwordFocusNode;
  TextEditingController? passwordController;
  String? Function(BuildContext, String?)? passwordControllerValidator;

  FocusNode? phoneFocusNode;
  TextEditingController? phoneController;

  bool passwordVisibility = false;
  bool isRegister = false;

  @override
  void initState(BuildContext context) {
    passwordVisibility = false;
    isRegister = false;
  }

  @override
  void dispose() {
    emailFocusNode?.dispose();
    emailController?.dispose();
    passwordFocusNode?.dispose();
    passwordController?.dispose();
    phoneFocusNode?.dispose();
    phoneController?.dispose();
  }
}
