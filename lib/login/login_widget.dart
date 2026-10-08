import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_util.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/flutter_flow/nav/nav.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_company.dart';
import 'package:twoja_gastromania/tg_core/tg_contact.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_services/account_identity_service.dart';

import 'login_model.dart';
export 'login_model.dart';

Future<void> reportIdentityIssue(BuildContext context, TGIdentityConflict conflict) async {
  TGAnalytics.track('signup_issue_report', {'kind': conflict.kind.name});
  final kind = context.t('ui_identity_kind_${conflict.kind.name}');
  final uri = Uri(
    scheme: 'mailto',
    path: TGCompany.email,
    queryParameters: {
      'subject': context.t('ui_identity_issue_subject'),
      'body': context.t('ui_identity_issue_body', {'kind': kind, 'value': conflict.value}),
    },
  );
  await openExternalUrl(context, uri);
}

class LoginPageWidget extends StatefulWidget {
  const LoginPageWidget({super.key});

  static const String routeName = 'LoginPage';
  static const String routePath = '/login';

  @override
  State<LoginPageWidget> createState() => _LoginPageWidgetState();
}

class _LoginPageWidgetState extends State<LoginPageWidget> {
  late LoginPageModel _model;
  TGIdentityConflict? _conflict;

  @override
  void initState() {
    super.initState();
    debugPrint('LoginPageWidget initState -> route=${LoginPageWidget.routePath}');
    _model = createModel(context, () => LoginPageModel());
    _model.emailController ??= TextEditingController();
    _model.emailFocusNode ??= FocusNode();
    _model.passwordController ??= TextEditingController();
    _model.passwordFocusNode ??= FocusNode();
    _model.phoneController ??= TextEditingController();
    _model.phoneFocusNode ??= FocusNode();
    AccountIdentityService.instance.ensureSeeded();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  void _showConflict(TGIdentityConflict conflict) {
    TGAnalytics.track('signup_blocked', {'kind': conflict.kind.name});
    safeSetState(() => _conflict = conflict);
  }

  void _social(TGIdentityKind kind) {
    if (_model.isRegister) {
      final hit = AccountIdentityService.instance.checkSocial(kind);
      if (hit != null) {
        _showConflict(hit);
        return;
      }
    }
    context.read<FakeAuthState>().logIn();
    showTGToast(context, context.t('ui_signed_in_demo'));
    TGNav.home(context);
  }

  Future<void> _reportIssue() async {
    final conflict = _conflict;
    if (conflict == null) return;
    await reportIdentityIssue(context, conflict);
  }

  void _primary() {
    final email = _model.emailController?.text.trim() ?? '';
    final pw = _model.passwordController?.text ?? '';
    final phone = _model.phoneController?.text.trim() ?? '';
    if (email.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('ui_enter_email_password')), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (_model.isRegister) {
      if (phone.replaceAll(RegExp(r'\D'), '').length < 9) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('ui_enter_phone_signup')), behavior: SnackBarBehavior.floating),
        );
        return;
      }
      final hit = AccountIdentityService.instance.checkRegister(email: email, phone: phone);
      if (hit != null) {
        _showConflict(hit);
        return;
      }
      AccountIdentityService.instance.claim(email: email, phone: phone);
    }
    context.read<FakeAuthState>().logIn();
    showTGToast(context, context.t('ui_signed_in_demo'));
    TGNav.home(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final maxCardWidth = isDesktop ? 520.0 : 440.0;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _LoginBackground(),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: _TopBackButton(onPressed: () => context.safePop()),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxCardWidth),
                    child: LoginCard(
                      logoAssetPath: 'assets/images/Hand_Shake_LOGO.png',
                      onGooglePressed: () => _social(TGIdentityKind.google),
                      onFacebookPressed: () => _social(TGIdentityKind.facebook),
                      emailController: _model.emailController!,
                      emailFocusNode: _model.emailFocusNode!,
                      passwordController: _model.passwordController!,
                      passwordFocusNode: _model.passwordFocusNode!,
                      phoneController: _model.phoneController,
                      phoneFocusNode: _model.phoneFocusNode,
                      passwordVisible: _model.passwordVisibility,
                      isRegister: _model.isRegister,
                      conflict: _conflict,
                      onReportIssue: _reportIssue,
                      onTogglePasswordVisibility: () => safeSetState(
                        () => _model.passwordVisibility = !_model.passwordVisibility,
                      ),
                      onToggleMode: () => safeSetState(() {
                        _model.isRegister = !_model.isRegister;
                        _conflict = null;
                      }),
                      onForgotPassword: () {
                        debugPrint('Forgot password tapped');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.t('ui_password_reset_later')),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      onPrimaryAction: _primary,
                    ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.04, end: 0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/Food_Prepering_table.jpg',
          fit: BoxFit.cover,
          alignment: const Alignment(0.1, 0),
          errorBuilder: (context, error, stack) {
            debugPrint('Login background image failed: $error');
            return Container(color: theme.primaryBackground);
          },
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: const SizedBox.expand(),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.primaryBackground.withValues(alpha: 0.10),
                theme.primaryBackground.withValues(alpha: 0.78),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Opacity(
                opacity: 0.18,
                child: Icon(
                  Icons.restaurant_menu,
                  size: MediaQuery.sizeOf(context).width >= 900 ? 340 : 220,
                  color: theme.primaryText,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBackButton extends StatelessWidget {
  const _TopBackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: theme.secondaryBackground.withValues(alpha: 0.68),
      borderRadius: BorderRadius.circular(14.0),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14.0),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(Icons.arrow_back_rounded, color: theme.primaryText, size: 22),
        ),
      ),
    );
  }
}

class LoginCard extends StatelessWidget {
  const LoginCard({
    super.key,
    required this.logoAssetPath,
    required this.onGooglePressed,
    required this.onFacebookPressed,
    required this.emailController,
    required this.emailFocusNode,
    required this.passwordController,
    required this.passwordFocusNode,
    required this.passwordVisible,
    required this.isRegister,
    required this.onTogglePasswordVisibility,
    required this.onToggleMode,
    required this.onForgotPassword,
    required this.onPrimaryAction,
    this.phoneController,
    this.phoneFocusNode,
    this.conflict,
    this.onReportIssue,
  });

  final String logoAssetPath;
  final VoidCallback onGooglePressed;
  final VoidCallback onFacebookPressed;
  final TextEditingController emailController;
  final FocusNode emailFocusNode;
  final TextEditingController passwordController;
  final FocusNode passwordFocusNode;
  final TextEditingController? phoneController;
  final FocusNode? phoneFocusNode;
  final bool passwordVisible;
  final bool isRegister;
  final TGIdentityConflict? conflict;
  final VoidCallback? onReportIssue;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onToggleMode;
  final VoidCallback onForgotPassword;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final title = isRegister ? 'SIGN UP' : 'LOG IN';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.secondaryBackground.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: theme.alternate.withValues(alpha: 0.55), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24.0 : 18.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BrandHeader(logoAssetPath: logoAssetPath),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.titleLarge.override(
                font: GoogleFonts.interTight(
                  fontWeight: FontWeight.w700,
                  fontStyle: theme.titleLarge.fontStyle,
                ),
                color: theme.primaryText,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Step into the world of gastronomy',
              textAlign: TextAlign.center,
              style: theme.bodyMedium.override(
                font: GoogleFonts.inter(
                  fontWeight: theme.bodyMedium.fontWeight,
                  fontStyle: theme.bodyMedium.fontStyle,
                ),
                color: theme.secondaryText,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SocialAuthButton.google(
                    key: const Key('login-google'),
                    text: 'Continue with Google',
                    onPressed: onGooglePressed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SocialAuthButton.facebook(
                    key: const Key('login-facebook'),
                    text: 'Continue with Facebook',
                    onPressed: onFacebookPressed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const OrDivider(label: 'OR'),
            const SizedBox(height: 14),
            AuthTextField(
              fieldKey: const Key('login-email'),
              label: 'E-mail',
              controller: emailController,
              focusNode: emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.alternate_email_rounded,
            ),
            const SizedBox(height: 12),
            AuthTextField(
              fieldKey: const Key('login-password'),
              label: 'Password',
              controller: passwordController,
              focusNode: passwordFocusNode,
              obscureText: !passwordVisible,
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: passwordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              onSuffixPressed: onTogglePasswordVisibility,
            ),
            if (isRegister && phoneController != null && phoneFocusNode != null) ...[
              const SizedBox(height: 12),
              AuthTextField(
                fieldKey: const Key('login-phone'),
                label: context.t('ui_phone'),
                controller: phoneController!,
                focusNode: phoneFocusNode!,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
              ),
            ],
            if (conflict != null) ...[
              const SizedBox(height: 12),
              DuplicateAccountNotice(conflict: conflict!, onReportIssue: onReportIssue),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onForgotPassword,
                style: TextButton.styleFrom(foregroundColor: theme.secondaryText),
                child: Text(
                  'Forgot password?',
                  style: theme.labelMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontStyle: theme.labelMedium.fontStyle,
                    ),
                    color: theme.secondaryText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            PrimaryGradientButton(
              key: const Key('login-primary'),
              text: isRegister ? 'SIGN UP' : 'LOG IN',
              onPressed: onPrimaryAction,
              height: 46,
            ),
            const SizedBox(height: 12),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    isRegister ? 'Already have an account? ' : "Don't have an account yet? ",
                    style: theme.bodySmall.override(
                      font: GoogleFonts.inter(
                        fontWeight: theme.bodySmall.fontWeight,
                        fontStyle: theme.bodySmall.fontStyle,
                      ),
                      color: theme.secondaryText,
                    ),
                  ),
                  TextButton(
                    key: const Key('login-toggle-mode'),
                    onPressed: onToggleMode,
                    style: TextButton.styleFrom(foregroundColor: theme.secondary),
                    child: Text(
                      isRegister ? 'Log in' : 'Sign up now',
                      style: theme.labelLarge.override(
                        font: GoogleFonts.interTight(
                          fontWeight: FontWeight.w700,
                          fontStyle: theme.labelLarge.fontStyle,
                        ),
                        color: theme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.logoAssetPath});
  final String logoAssetPath;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final logoSize = screenWidth >= 900 ? 44.0 : 38.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipOval(
          child: Image.asset(
            logoAssetPath,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) {
              debugPrint('Login logo failed: $error');
              return Container(
                width: logoSize,
                height: logoSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.primaryBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.restaurant, color: theme.secondaryText),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Twoja Gastromania',
          style: theme.titleMedium.override(
            font: GoogleFonts.interTight(
              fontWeight: FontWeight.w700,
              fontStyle: theme.titleMedium.fontStyle,
            ),
            color: theme.primaryText,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class DuplicateAccountNotice extends StatelessWidget {
  const DuplicateAccountNotice({super.key, required this.conflict, this.onReportIssue});
  final TGIdentityConflict conflict;
  final VoidCallback? onReportIssue;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      key: const Key('login-duplicate-notice'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: TGColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TGColors.error.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: TGColors.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t(conflict.titleKey),
                  style: theme.bodyMedium.override(fontWeight: FontWeight.w800, color: theme.primaryText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.t('ui_identity_taken_help'),
            style: theme.bodySmall.override(color: theme.secondaryText, lineHeight: 1.35),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('login-report-issue'),
              onPressed: onReportIssue,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                visualDensity: VisualDensity.compact,
                foregroundColor: theme.secondary,
              ),
              child: Text(
                context.t('ui_report_issue'),
                maxLines: 2,
                style: theme.labelLarge.override(fontWeight: FontWeight.w800, color: theme.secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: theme.alternate.withValues(alpha: 0.8), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Text(
            label,
            style: theme.labelSmall.override(
              font: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontStyle: theme.labelSmall.fontStyle,
              ),
              color: theme.secondaryText,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(child: Divider(color: theme.alternate.withValues(alpha: 0.8), thickness: 1)),
      ],
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    this.keyboardType,
    this.obscureText = false,
    required this.prefixIcon,
    this.suffixIcon,
    this.onSuffixPressed,
    this.fieldKey,
  });

  final Key? fieldKey;
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return TextFormField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: theme.bodySmall.override(
          font: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontStyle: theme.bodySmall.fontStyle,
          ),
          color: theme.secondaryText,
        ),
        filled: true,
        fillColor: theme.primaryBackground.withValues(alpha: 0.70),
        prefixIcon: Icon(prefixIcon, color: theme.secondaryText, size: 20),
        suffixIcon: suffixIcon == null
            ? null
            : IconButton(
                icon: Icon(suffixIcon, color: theme.secondaryText, size: 20),
                onPressed: onSuffixPressed,
              ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.alternate.withValues(alpha: 0.8), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.secondary, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      style: theme.bodyMedium.override(
        font: GoogleFonts.inter(
          fontWeight: theme.bodyMedium.fontWeight,
          fontStyle: theme.bodyMedium.fontStyle,
        ),
        color: theme.primaryText,
      ),
    );
  }
}

class SocialAuthButton extends StatelessWidget {
  const SocialAuthButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onPressed,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
  });

  factory SocialAuthButton.google({Key? key, required String text, required VoidCallback onPressed}) {
    return SocialAuthButton(
      key: key,
      icon: Icons.g_mobiledata_rounded,
      text: text,
      onPressed: onPressed,
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFE5E7EB),
      foregroundColor: const Color(0xFF111827),
    );
  }

  factory SocialAuthButton.facebook({Key? key, required String text, required VoidCallback onPressed}) {
    return SocialAuthButton(
      key: key,
      icon: Icons.facebook_rounded,
      text: text,
      onPressed: onPressed,
      backgroundColor: const Color(0xFF1877F2),
      borderColor: const Color(0xFF1877F2),
      foregroundColor: Colors.white,
    );
  }

  final IconData icon;
  final String text;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: foregroundColor, size: 22),
        label: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.labelMedium.override(
            font: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontStyle: theme.labelMedium.fontStyle,
            ),
            color: foregroundColor,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}

class PrimaryGradientButton extends StatefulWidget {
  const PrimaryGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.height = 46,
  });

  final String text;
  final VoidCallback onPressed;
  final double height;

  @override
  State<PrimaryGradientButton> createState() => _PrimaryGradientButtonState();
}

class _PrimaryGradientButtonState extends State<PrimaryGradientButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        theme.secondary.withValues(alpha: 0.95),
        theme.tertiary.withValues(alpha: 0.95),
      ],
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: 160.ms,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.16 : 0.10),
                blurRadius: _hovered ? 22 : 16,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Center(
            child: Text(
              widget.text,
              style: theme.titleSmall.override(
                font: GoogleFonts.interTight(
                  fontWeight: FontWeight.w800,
                  fontStyle: theme.titleSmall.fontStyle,
                ),
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
