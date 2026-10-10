import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart' show LoginPageWidget;
import 'package:twoja_gastromania/add_product/wizard_mobile.dart';
import 'package:twoja_gastromania/special_order/special_order_draft.dart';
import 'package:twoja_gastromania/special_order/special_order_wizard_steps.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_sms_gate.dart';
import 'package:twoja_gastromania/tg_components/tg_top_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

class SpecialOrderNewPage extends StatefulWidget {
  const SpecialOrderNewPage({super.key, this.query = const {}});

  static const routeName = 'SpecialOrderNew';
  static const routePath = '/special-order/new';

  final Map<String, String> query;

  @override
  State<SpecialOrderNewPage> createState() => _SpecialOrderNewPageState();
}

class _SpecialOrderNewPageState extends State<SpecialOrderNewPage> {
  late final SpecialOrderDraft draft;
  late final FakeAuthState _auth;
  Timer? _autosave;
  bool _sending = false;
  final _smsKey = GlobalKey<TGSmsGateState>();

  List<String> get _steps => [
        context.t('ui_so_step_project'),
        context.t('ui_so_step_specs'),
        context.t('ui_so_step_files'),
        context.t('ui_so_step_who'),
        context.t('ui_so_step_review'),
      ];

  @override
  void initState() {
    super.initState();
    _auth = context.read<FakeAuthState>();
    TGSpecialOrderService.instance.ensureSeeded();
    final sellerIds = <String>[];
    final sellerRaw = widget.query['seller'] ?? '';
    final sellersRaw = widget.query['sellers'] ?? '';
    for (final raw in [if (sellerRaw.isNotEmpty) sellerRaw, ...sellersRaw.split(',')]) {
      final p = TGSellerProfileService.instance.resolve(raw.trim());
      if (p != null && p.isSpecialOrderManufacturer) sellerIds.add(p.sellerKey);
    }
    final types = <TGStoreSpecialty>{
      for (final part in (widget.query['type'] ?? '').split(','))
        if (specialtyFromKey(part) != null) specialtyFromKey(part)!,
    };
    draft = SpecialOrderDraft(
      preselectedSellerIds: sellerIds,
      preselectedTypes: types,
    );
    draft.buyerName = _auth.displayName;
    draft.email = _auth.isLoggedIn ? (_auth.role == TGUserRole.buyer ? 'marek@example.com' : _auth.mockEmail) : '';
    draft.phone = '+48 (532) 784-074';
    draft.addListener(_onDraft);
    _autosave = Timer.periodic(const Duration(seconds: 5), (_) {
      if (draft.dirty) {
        draft.saveDraft();
        if (mounted) setState(() {});
      }
    });
    TGAnalytics.track('so_request_start', widget.query);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeGate());
  }

  @override
  void dispose() {
    _autosave?.cancel();
    draft.removeListener(_onDraft);
    draft.dispose();
    super.dispose();
  }

  void _onDraft() {
    if (mounted) setState(() {});
  }

  Future<void> _maybeGate() async {
    final auth = context.read<FakeAuthState>();
    if (!auth.isLoggedIn) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(context.t('ui_so_login_required')),
          content: Text(context.t('ui_so_login_body')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('ui_cancel'))),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.goNamed(LoginPageWidget.routeName);
              },
              child: Text(context.t('ui_sign_up_now')),
            ),
            TGButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.goNamed(LoginPageWidget.routeName);
              },
              label: context.t('ui_login'),
              height: 40,
            ),
          ],
        ),
      );
      return;
    }
    if (!auth.phoneVerified) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.t('ui_verify_phone')),
          content: SizedBox(
            width: 360,
            child: TGSmsGate(key: _smsKey, intro: context.t('ui_so_sms_intro')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('ui_cancel'))),
            TGButton(
              onPressed: () {
                final gate = _smsKey.currentState;
                if (gate == null) return;
                if (!gate.codeSent) {
                  gate.send();
                  setState(() {});
                  return;
                }
                if (gate.verify()) {
                  auth.markPhoneVerified();
                  draft.phone = '+48 ${gate.digits.substring(0, 3)} ${gate.digits.substring(3, 6)}-${gate.digits.substring(6)}';
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
              label: context.t('ui_verify'),
              height: 40,
            ),
          ],
        ),
      );
    }
  }

  void _dirty() {
    draft.markDirty();
  }

  void _goStep(int s) {
    setState(() => draft.goStep(s));
  }

  Future<void> _next() async {
    final errs = draft.errorsForStep(draft.step);
    if (errs.isNotEmpty) {
      showTGToast(context, errs.first);
      return;
    }
    TGAnalytics.track('so_step_complete', {'step': draft.step});
    if (draft.step < 4) {
      draft.saveDraft();
      _goStep(draft.step + 1);
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    final auth = context.read<FakeAuthState>();
    if (!auth.isLoggedIn || !auth.phoneVerified) {
      await _maybeGate();
      return;
    }
    if (!TGSpecialOrderService.instance.canSubmitToday(auth.userId)) {
      showTGToast(context, context.t('ui_so_daily_limit'));
      return;
    }
    final errs = draft.errorsForStep(4);
    if (errs.isNotEmpty) {
      showTGToast(context, errs.first);
      return;
    }
    setState(() => _sending = true);
    await Future<void>.delayed(TGMotion.of(context, const Duration(milliseconds: 400)));
    final saved = TGSpecialOrderService.instance.submitRequest(draft.toRequest(buyerId: auth.userId));
    if (!mounted) return;
    setState(() => _sending = false);
    context.go('/special-order/success?no=${saved.requestNo}');
  }

  void _openSummarySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TGColors.surface,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            shrinkWrap: true,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: TGColors.border, borderRadius: BorderRadius.circular(99)))),
              SoRequestSummary(draft: draft),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final pad = phone ? 16.0 : 80.0;

    if (phone) {
      return TGPageScaffold(
        body: Column(
          children: [
            const TGTopNav(activeNavId: 'special_order'),
            const WizardOfflineBanner(),
            WizardMobileHeader(
              step: draft.step,
              labels: _steps,
              saved: draft.lastSavedAt != null && !draft.dirty,
              onSave: () {
                draft.saveDraft();
                showTGToast(context, context.t('ui_draft_saved'));
              },
            ),
            WizardProgressBar(step: draft.step, total: 5),
            if (!auth.isLoggedIn)
              Expanded(child: Center(child: TGButton(onPressed: _maybeGate, label: context.t('ui_login'), height: 48)))
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [_stepBody(auth)],
                ),
              ),
            if (auth.isLoggedIn) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(context.t('ui_so_summary_chip')),
                    onPressed: _openSummarySheet,
                  ),
                ),
              ),
              WizardStickyBar(
                back: TGButton(
                  onPressed: draft.step == 0 ? () => context.go('/special-order') : () => _goStep(draft.step - 1),
                  label: context.t('ui_back'),
                  variant: TGButtonVariant.ghost,
                  height: 48,
                ),
                next: TGButton(
                  onPressed: _sending ? null : _next,
                  label: draft.step == 4 ? (_sending ? '…' : context.t('ui_so_send_request')) : context.t('ui_next'),
                  height: 48,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return TGPageScaffold(
      body: Column(
        children: [
          const TGTopNav(activeNavId: 'special_order'),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TGBreadcrumb(
                          items: [
                            TGBreadcrumbItem(label: context.t('ui_home'), onTap: () => TGNav.home(context)),
                            TGBreadcrumbItem(label: context.t('ui_special_order'), onTap: () => context.go('/special-order')),
                            TGBreadcrumbItem(label: context.t('ui_request_quotes')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SoStepper(step: draft.step, labels: _steps, onTap: (i) {
                        if (i <= draft.step) _goStep(i);
                      }),
                      const SizedBox(height: 16),
                      if (!auth.isLoggedIn)
                        Expanded(
                          child: Center(
                            child: TGButton(onPressed: _maybeGate, label: context.t('ui_login'), height: 48),
                          ),
                        )
                      else
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 845),
                                    child: AnimatedSwitcher(
                                      duration: TGMotion.of(context, TGMotion.slide),
                                      transitionBuilder: (child, anim) => SlideTransition(
                                        position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(anim),
                                        child: FadeTransition(opacity: anim, child: child),
                                      ),
                                      child: KeyedSubtree(
                                        key: ValueKey(draft.step),
                                        child: ListView(
                                          padding: const EdgeInsets.only(bottom: 24),
                                          children: [
                                            _stepBody(auth),
                                            const SizedBox(height: 24),
                                            const TGFooter(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: 411,
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      SoRequestSummary(draft: draft),
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton(
                                          onPressed: () {
                                            draft.saveDraft();
                                            showTGToast(context, context.t('ui_draft_saved'));
                                          },
                                          child: Text(context.t('ui_save_draft')),
                                        ),
                                      ),
                                      if (draft.lastSavedAt != null)
                                        Text(context.t('ui_draft_autosaved'), style: theme.bodySmall.override(color: theme.secondaryText)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (auth.isLoggedIn)
            ColoredBox(
              color: TGColors.surface,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 10, pad, 10 + MediaQuery.paddingOf(context).bottom),
                    child: Row(
                      children: [
                        TGButton(
                          onPressed: draft.step == 0 ? () => context.go('/special-order') : () => _goStep(draft.step - 1),
                          label: context.t('ui_back'),
                          variant: TGButtonVariant.ghost,
                          height: 48,
                        ),
                        const Spacer(),
                        TGButton(
                          onPressed: _sending ? null : _next,
                          label: _sending
                              ? context.t('ui_sending')
                              : (draft.step == 4 ? context.t('ui_so_send_request') : context.t('ui_next')),
                          height: 48,
                          borderRadius: BorderRadius.circular(TGRadius.pill),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepBody(FakeAuthState auth) {
    return switch (draft.step) {
      0 => SoStepProject(draft: draft, onChanged: _dirty),
      1 => SoStepSpecs(draft: draft, onChanged: _dirty),
      2 => SoStepFiles(draft: draft, onChanged: _dirty),
      3 => SoStepAudience(draft: draft, onChanged: _dirty, phoneVerified: auth.phoneVerified),
      _ => SoStepReview(draft: draft, onEdit: _goStep),
    };
  }
}

class _SoStepper extends StatelessWidget {
  const _SoStepper({required this.step, required this.labels, required this.onTap});
  final int step;
  final List<String> labels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: AnimatedContainer(
                duration: TGMotion.of(context, TGMotion.stepper),
                height: 2,
                color: i <= step ? TGColors.cta : theme.tertiary,
              ),
            ),
          InkWell(
            onTap: () => onTap(i),
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: TGMotion.of(context, TGMotion.stepper),
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= step ? TGColors.cta : theme.alternate,
                    border: Border.all(color: i <= step ? TGColors.cta : theme.tertiary, width: 2),
                  ),
                  child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w900, color: i <= step ? TGColors.onCta : theme.secondaryText, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Text(labels[i], style: theme.bodySmall.override(fontWeight: FontWeight.w800, color: i == step ? theme.primaryText : theme.secondaryText)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
