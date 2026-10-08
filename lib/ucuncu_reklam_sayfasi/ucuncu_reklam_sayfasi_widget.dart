import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_top_nav.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ucuncu_reklam_sayfasi_model.dart';
export 'ucuncu_reklam_sayfasi_model.dart';

class UcuncuReklamSayfasiWidget extends StatefulWidget {
  const UcuncuReklamSayfasiWidget({super.key});

  static String routeName = 'UcuncuReklamSayfasi';
  static String routePath = '/ucuncuReklamSayfasi';

  @override
  State<UcuncuReklamSayfasiWidget> createState() =>
      _UcuncuReklamSayfasiWidgetState();
}

class _UcuncuReklamSayfasiWidgetState extends State<UcuncuReklamSayfasiWidget> {
  late UcuncuReklamSayfasiModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => UcuncuReklamSayfasiModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {
          _model.textController?.text = FFLocalizations.of(context).getText(
            'jarfuz0t' /* Equipment name  */,
          );
        }));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: TGPageScaffold(
        body: SafeArea(
          top: true,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
              Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  const TGTopNav(),
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      
                      
                      
                      Align(
                        alignment: AlignmentDirectional(0.0, 0.0),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 110.0, 0.0, 0.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.asset(
                              'assets/images/icons8-working-100.png',
                              width: 200.0,
                              height: 200.0,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional(0.0, 0.0),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 10.0, 0.0, 0.0),
                          child: Text(
                            FFLocalizations.of(context).getText(
                              'oib93k7r' /* "This advertising page will be... */,
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w800,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  fontSize: 15.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
