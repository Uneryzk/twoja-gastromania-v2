import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/add_product/add_product_draft.dart';
import 'package:twoja_gastromania/add_product/add_product_fields.dart';
import 'package:twoja_gastromania/add_product/wizard_mobile.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_listing_no.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart';
import 'package:twoja_gastromania/products/products_query.dart';
import 'package:twoja_gastromania/products/tg_geo.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_breadcrumb.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_footer.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_components/tg_product_card.dart';
import 'package:twoja_gastromania/tg_core/tg_nav.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_services/account_identity_service.dart';
import 'package:twoja_gastromania/tg_services/product_service.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  static const routeName = 'AddProduct';
  static const routePath = '/add-product';

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  late final AddProductDraft draft;
  late final FakeAuthState _auth;
  Timer? _autosave;
  bool _loginPrompted = false;
  bool _saving = false;
  bool _stepLoading = false;
  bool _publishing = false;
  AddProductPhoto? _undoPhoto;
  int _undoIndex = 0;
  final _errorSummary = FocusNode();

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _deposit = TextEditingController();
  final _minPeriod = TextEditingController();
  final _year = TextEditingController();
  final _hours = TextEditingController();
  final _service = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _powerKw = TextEditingController();
  final _width = TextEditingController();
  final _depth = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _customWarr = TextEditingController();
  final _temp = TextEditingController();
  final _volume = TextEditingController();
  final _program = TextEditingController();
  final _company = TextEditingController();
  final _nip = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _sms = TextEditingController();
  final _city = TextEditingController();
  final _hoursCall = TextEditingController();
  final _email = TextEditingController();
  final _foci = <String, FocusNode>{};

  List<String> get _steps => [
        context.t('ui_step_basic'),
        context.t('ui_step_specs'),
        context.t('ui_step_photos'),
        context.t('ui_contact'),
        context.t('ui_step_review'),
      ];

  FocusNode _focus(String key) => _foci.putIfAbsent(key, FocusNode.new);

  @override
  void initState() {
    super.initState();
    _auth = context.read<FakeAuthState>();
    draft = AddProductDraft(auth: _auth);
    draft.addListener(_onDraft);
    _auth.addListener(_onAuth);
    _autosave = Timer.periodic(const Duration(seconds: 5), (_) => _saveDraft(silent: true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TGAnalytics.emit('wizard_step_view', {'step': 0});
      _maybeGate();
    });
  }

  @override
  void dispose() {
    _autosave?.cancel();
    draft.removeListener(_onDraft);
    _auth.removeListener(_onAuth);
    _errorSummary.dispose();
    for (final c in [
      _title, _description, _price, _deposit, _minPeriod, _year, _hours, _service, _brand, _model, _powerKw,
      _width, _depth, _height, _weight, _customWarr, _temp, _volume, _program, _company, _nip, _address,
      _contact, _phone, _sms, _city, _hoursCall, _email,
    ]) {
      c.dispose();
    }
    for (final f in _foci.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDraft() {
    if (mounted) setState(() {});
  }

  void _onAuth() {
    if (!_auth.isLoggedIn && mounted) {
      _loginPrompted = false;
      _maybeGate();
    }
  }

  void _goStep(int i) {
    TGAnalytics.emit('wizard_step_complete', {'step': draft.step});
    draft.setStep(i);
    TGAnalytics.emit('wizard_step_view', {'step': i});
    if (!tgInWidgetTest()) {
      setState(() => _stepLoading = true);
      Future<void>.delayed(TGMotion.skeleton, () {
        if (mounted) setState(() => _stepLoading = false);
      });
    }
  }

  void _dirty(VoidCallback fn) {
    fn();
    draft.markDirty();
  }

  Future<void> _maybeGate() async {
    final auth = context.read<FakeAuthState>();
    if (auth.isLoggedIn || _loginPrompted || !mounted) return;
    _loginPrompted = true;
    await _openLogin();
  }

  Future<void> _openLogin() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _LoginModal(
        onDone: () {
          Navigator.pop(ctx);
          setState(() {});
        },
      ),
    );
  }

  Future<bool> _confirmLeave() async {
    if (!draft.dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = FlutterFlowTheme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.secondaryBackground,
          title: Text(ctx.t('ui_discard_title')),
          content: Text(ctx.t('ui_discard_body')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_stay'))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('ui_leave')),
            ),
          ],
        );
      },
    );
    return ok ?? false;
  }

  void _saveDraft({bool silent = false}) {
    setState(() => _saving = true);
    final product = draft.toProduct();
    _auth.upsertOwned(product);
    draft.markSaved();
    TGAnalytics.emit('draft_saved', {'silent': silent});
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (!draft.validateStep(draft.step)) {
      final key = draft.firstErrorField;
      if (key != null) _focus(key).requestFocus();
      _errorSummary.requestFocus();
      return;
    }
    _saveDraft(silent: true);
    if (draft.step < 4) {
      _goStep(draft.step + 1);
    } else {
      await _publish();
    }
  }

  Future<void> _publish() async {
    if (!draft.validateStep(4)) {
      final key = draft.firstErrorField;
      if (key != null) {
        final stepFor = switch (key) {
          'category' || 'title' || 'description' || 'price' || 'deposit' || 'minPeriod' => 0,
          'brand' || 'year' => 1,
          'photos' => 2,
          _ => 3,
        };
        _goStep(stepFor);
        _focus(key).requestFocus();
      }
      _errorSummary.requestFocus();
      return;
    }
    setState(() => _publishing = true);
    TGAnalytics.emit('publish_click', {'total': draft.totalPln, 'promote': draft.promoteDays});
    if (draft.promoteDays > 0) TGAnalytics.emit('promote_addon_selected', {'days': draft.promoteDays});
    final auth = context.read<FakeAuthState>();
    if (auth.listingPlan == TGListingPlan.storeFull) {
      context.go('/plans');
      return;
    }
    if (draft.goesToCheckout) {
      final pending = draft.toProduct(status: TGListingStatus.paymentPending).copyWith(
            listingNo: TGListingNo.allocate(),
          );
      auth.upsertOwned(pending);
      await TGProductService.instance.upsert(pending);
      auth.beginCheckout(
        TGCheckoutCart.listing(
          listingId: pending.id,
          listingNo: pending.listingNo,
          listingFee: draft.listingFeePln,
          promoteFee: draft.promoteFeePln,
          promoteDays: draft.promoteDays,
        ),
      );
      if (!mounted) return;
      context.go('/add-product/checkout');
      return;
    }
    if (auth.listingPlan == TGListingPlan.free) {
      TGAnalytics.emit('free_slot_used');
    }
    final published = auth.publishOwned(draft.toProduct(), promoteDays: draft.promoteDays);
    await TGProductService.instance.upsert(published);
    if (!mounted) return;
    context.go('/add-product/success?id=${published.id}');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FakeAuthState>();
    final w = MediaQuery.sizeOf(context).width;
    final desktop = w >= 1024;
    final phone = w < TGBreakpoints.phone;
    final pad = phone ? 16.0 : 24.0;

    return PopScope(
      canPop: !draft.dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) context.go('/');
      },
      child: TGPageScaffold(
        body: phone ? _phoneBody(auth) : _wideBody(auth, desktop: desktop, pad: pad),
      ),
    );
  }

  Widget _phoneBody(FakeAuthState auth) {
    return Column(
      children: [
        const WizardOfflineBanner(),
        WizardMobileHeader(
          step: draft.step,
          labels: _steps,
          saving: _saving,
          saved: draft.lastSavedAt != null,
          onSave: () => _saveDraft(),
        ),
        WizardProgressBar(step: draft.step, total: _steps.length),
        if (!auth.isLoggedIn)
          Expanded(child: _Gate(onLogin: _openLogin))
        else ...[
          Expanded(
            child: AnimatedSwitcher(
              duration: TGMotion.of(context, TGMotion.slide),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey(draft.step),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    if (_stepLoading) const WizardStepSkeleton() else _formBody(),
                  ],
                ),
              ),
            ),
          ),
          WizardPreviewChip(onOpen: _openPreviewSheet),
          WizardStickyBar(
            totalLabel: draft.step == 4 ? context.t('ui_total_pln', {'n': '${draft.totalPln}'}) : null,
            back: _backButton(),
            next: _nextButton(),
          ),
        ],
      ],
    );
  }

  Widget _wideBody(FakeAuthState auth, {required bool desktop, required double pad}) {
    return Column(
      children: [
        const WizardOfflineBanner(),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TGBreadcrumb(
                        items: [
                          TGBreadcrumbItem(label: context.t('ui_home'), onTap: () async {
                            if (await _confirmLeave() && mounted) TGNav.home(context);
                          }),
                          TGBreadcrumbItem(label: context.t('ui_add_product')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Stepper(
                      step: draft.step,
                      labels: _steps,
                      onTap: (i) {
                        if (i <= draft.step) {
                          _saveDraft(silent: true);
                          _goStep(i);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!auth.isLoggedIn)
                      Expanded(child: _Gate(onLogin: _openLogin))
                    else
                      Expanded(
                        child: desktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 8, child: _formColumn()),
                                  const SizedBox(width: 24),
                                  SizedBox(width: 411, child: _PreviewPanel(draft: draft)),
                                ],
                              )
                            : ListView(
                                children: [
                                  _formBody(),
                                  const SizedBox(height: 16),
                                  _PreviewPanel(draft: draft),
                                  const SizedBox(height: 24),
                                  const TGFooter(),
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
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 10, pad, 10 + MediaQuery.paddingOf(context).bottom),
                  child: _navRow(),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openPreviewSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: TGColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(TGRadius.modal))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: WizardPreviewSheetChrome(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _PreviewPanel(draft: draft),
            ),
          ),
        ),
      ),
    );
  }

  Widget _backButton() {
    return TGButton(
      key: const Key('wizard-back'),
      onPressed: draft.step == 0
          ? () async {
              if (await _confirmLeave() && mounted) TGNav.home(context);
            }
          : () {
              _saveDraft(silent: true);
              _goStep(draft.step - 1);
            },
      label: context.t('ui_back'),
      variant: TGButtonVariant.ghost,
      height: 48,
    );
  }

  Widget _nextButton() {
    return TGButton(
      key: const Key('wizard-next'),
      onPressed: _publishing ? null : _next,
      label: _publishing ? context.t('ui_publishing') : (draft.step == 4 ? _ctaLabel() : context.t('ui_next')),
      height: 48,
      borderRadius: BorderRadius.circular(TGRadius.pill),
    );
  }

  Widget _formColumn() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                _formBody(),
                const SizedBox(height: 24),
                const TGFooter(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _formBody() {
    final errors = draft.fieldErrors;
    return WizardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (errors.isNotEmpty)
            Focus(
              focusNode: _errorSummary,
              child: WizardError(context.t('err_wizard_fields_n', {'n': '${errors.length}'})),
            ),
          switch (draft.step) {
            0 => _stepBasic(),
            1 => _stepSpecs(),
            2 => _stepPhotos(),
            3 => _stepContact(),
            _ => _stepReview(),
          },
        ],
      ),
    );
  }

  Widget _navRow() {
    final saved = draft.lastSavedAt;
    final narrow = MediaQuery.sizeOf(context).width < 700;
    final back = TGButton(
      key: const Key('wizard-back'),
      onPressed: draft.step == 0
          ? () async {
              if (await _confirmLeave() && mounted) TGNav.home(context);
            }
          : () {
              _saveDraft(silent: true);
              _goStep(draft.step - 1);
            },
      label: context.t('ui_back'),
      variant: TGButtonVariant.ghost,
      height: 48,
    );
    final save = TGButton(
      key: const Key('wizard-save-draft'),
      onPressed: () => _saveDraft(),
      label: context.t('ui_save_draft'),
      variant: TGButtonVariant.ghost,
      height: 48,
    );
    final next = TGButton(
      key: const Key('wizard-next'),
      onPressed: _next,
      label: draft.step == 4 ? _ctaLabel() : context.t('ui_next'),
      height: 48,
      borderRadius: BorderRadius.circular(TGRadius.pill),
    );
    final savedLabel = saved == null
        ? const SizedBox.shrink()
        : Text(context.t('ui_saved_just_now'), style: TextStyle(color: FlutterFlowTheme.of(context).secondaryText, fontSize: 13));
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (saved != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: savedLabel),
          Row(children: [back, const SizedBox(width: 8), save, const Spacer(), next]),
        ],
      );
    }
    return Row(
      children: [
        back,
        const SizedBox(width: 8),
        save,
        if (saved != null) ...[const SizedBox(width: 8), savedLabel],
        const Spacer(),
        next,
      ],
    );
  }

  String _ctaLabel() {
    final auth = context.read<FakeAuthState>();
    return switch (auth.listingPlan) {
      TGListingPlan.free => context.t('ui_publish_free'),
      TGListingPlan.store => context.t('ui_publish'),
      TGListingPlan.storeFull => context.t('ui_upgrade_plan'),
      TGListingPlan.paid => context.t('ui_continue_payment', {'fee': '${TGPricing.listingFeePln}'}),
    };
  }

  String? _err(String key) {
    final k = draft.fieldErrors[key];
    return k == null ? null : context.t(k);
  }

  String _subLabel(String s) {
    final key = AddProductDraft.subcategoryKeys[s];
    return key == null ? s : context.t(key);
  }

  Widget _labeled(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WizardLabel(label),
        field,
      ],
    );
  }

  Widget _specRow(List<Widget> cells, {double gap = 12}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: cells[i]),
        ],
      ],
    );
  }

  Widget _stepBasic() {
    final err = draft.fieldErrors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WizardLabel(context.t('ui_listing_type')),
        WizardSegmented(
          large: true,
          value: draft.listingType,
          options: [(TGListingType.buy, context.t('ui_sell')), (TGListingType.rent, context.t('ui_rent'))],
          onChanged: (v) => _dirty(() => draft.listingType = v),
        ),
        if (draft.listingType == TGListingType.rent) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WizardLabel(context.t('ui_deposit')),
                    WizardField(controller: _deposit, suffix: 'PLN', keyboardType: TextInputType.number, error: _err('deposit'), onChanged: (v) => _dirty(() => draft.depositText = v)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WizardLabel(context.t('ui_min_period')),
                    WizardField(controller: _minPeriod, suffix: context.t('ui_per_month'), keyboardType: TextInputType.number, error: _err('minPeriod'), onChanged: (v) => _dirty(() => draft.minPeriodText = v)),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        WizardLabel(context.t('ui_category')),
        _CategoryMenu(
          selected: draft.category,
          list: MediaQuery.sizeOf(context).width < TGBreakpoints.phone,
          onSelect: (c) => _dirty(() {
            draft.category = c;
            final subs = AddProductDraft.subcategories[c] ?? const [];
            draft.subcategory = subs.isEmpty ? '' : subs.first;
          }),
        ),
        if (err['category'] != null) WizardError(context.t(err['category']!)),
        if (draft.category != null) ...[
          const SizedBox(height: 12),
          WizardLabel(context.t('ui_subcategory')),
          WizardDropdown(
            value: draft.subcategory.isEmpty ? null : draft.subcategory,
            items: [
              for (final s in AddProductDraft.subcategories[draft.category] ?? const <String>[]) (s, _subLabel(s)),
            ],
            onChanged: (v) => _dirty(() => draft.subcategory = v),
          ),
        ],
        const SizedBox(height: 16),
        WizardLabel(context.t('ui_title')),
        WizardField(
          key: const Key('wizard-title'),
          controller: _title,
          focusNode: _focus('title'),
          maxLength: 80,
          hint: context.t('ui_title_hint'),
          error: _err('title'),
          onChanged: (v) => _dirty(() => draft.title = v),
          onEditingComplete: () => draft.validateStep(0),
        ),
        WizardHelp('${draft.title.trim().length}/80 · ${context.t('ui_title_hint')}'),
        const SizedBox(height: 14),
        WizardLabel(context.t('ui_description')),
        WizardField(
          key: const Key('wizard-description'),
          controller: _description,
          focusNode: _focus('description'),
          maxLines: 6,
          maxLength: 4000,
          error: _err('description'),
          onChanged: (v) => _dirty(() => draft.description = v),
          onEditingComplete: () => draft.validateStep(0),
        ),
        WizardHelp('${draft.description.trim().length}/4000'),
        Wrap(
          spacing: 8,
          children: [
            for (final chip in [context.t('ui_chip_serviced'), context.t('ui_chip_extras'), context.t('ui_chip_ready')])
              ActionChip(
                label: Text(chip),
                onPressed: () {
                  final next = draft.description.trim().isEmpty ? chip : '${draft.description.trim()} $chip';
                  _description.text = next;
                  _dirty(() => draft.description = next);
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        WizardLabel(context.t('ui_price')),
        Builder(builder: (context) {
          final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
          final field = WizardField(
            key: const Key('wizard-price'),
            controller: _price,
            focusNode: _focus('price'),
            suffix: 'PLN',
            enabled: !draft.askPrice,
            keyboardType: TextInputType.number,
            error: _err('price'),
            onChanged: (v) => _dirty(() => draft.priceText = v),
            onEditingComplete: () => draft.validateStep(0),
          );
          final basis = WizardSegmented(
            value: draft.priceBasis,
            options: [(TGPriceBasis.netto, context.t('ui_netto')), (TGPriceBasis.brutto, context.t('ui_brutto'))],
            onChanged: (v) => _dirty(() => draft.priceBasis = v),
          );
          if (phone) {
            return Column(children: [field, const SizedBox(height: 8), basis]);
          }
          return Row(children: [
            Expanded(child: field),
            const SizedBox(width: 12),
            SizedBox(width: 200, child: basis),
          ]);
        }),
        if (!draft.askPrice && draft.pricePln != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              draft.priceBasis == TGPriceBasis.netto
                  ? context.t('ui_eq_brutto', {'n': NumberFormat.decimalPattern('pl_PL').format(draft.counterpartPln)})
                  : context.t('ui_eq_netto', {'n': NumberFormat.decimalPattern('pl_PL').format(draft.counterpartPln)}),
              style: TextStyle(color: FlutterFlowTheme.of(context).secondaryText, fontWeight: FontWeight.w600),
            ),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: draft.negotiable,
          onChanged: (v) => _dirty(() => draft.negotiable = v ?? false),
          title: Text(context.t('ui_negotiable')),
          activeColor: TGColors.cta,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: draft.askPrice,
          onChanged: (v) => _dirty(() => draft.askPrice = v),
          title: Text(context.t('ui_no_price')),
          activeColor: TGColors.cta,
        ),
      ],
    );
  }

  Widget _stepSpecs() {
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final gap = phone ? 8.0 : 12.0;
    final t = context.t;
    final brandField = Autocomplete<String>(
      optionsBuilder: (v) {
        final q = v.text.toLowerCase();
        return AddProductDraft.brands.where((b) => b.toLowerCase().contains(q));
      },
      onSelected: (v) {
        _brand.text = v;
        _dirty(() => draft.brand = v);
      },
      fieldViewBuilder: (context, controller, focus, onSubmit) {
        return WizardField(
          key: const Key('wizard-brand'),
          controller: controller,
          focusNode: focus,
          dense: phone,
          hint: t('ui_brand_hint'),
          error: _err('brand'),
          onChanged: (v) => _dirty(() => draft.brand = v),
          onEditingComplete: () {
            onSubmit();
            draft.validateStep(1);
          },
        );
      },
    );
    final modelField = WizardField(controller: _model, dense: phone, onChanged: (v) => _dirty(() => draft.model = v));
    final powerField = WizardField(
      controller: _powerKw,
      dense: phone,
      suffix: 'kW',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) => _dirty(() => draft.powerKwText = v),
    );
    final voltageField = WizardDropdown(
      value: draft.voltage,
      dense: phone,
      items: [('230', '230 V'), ('400', '400 V'), ('other', t('ui_other'))],
      onChanged: (v) => _dirty(() => draft.voltage = v),
    );
    final phasesField = WizardDropdown(
      value: draft.phasesText,
      dense: phone,
      items: const [('1', '1'), ('3', '3')],
      onChanged: (v) => _dirty(() => draft.phasesText = v),
    );
    final dimFields = Row(children: [
      Expanded(child: WizardField(controller: _width, dense: phone, suffix: 'mm', keyboardType: TextInputType.number, onChanged: (v) => _dirty(() => draft.widthText = v))),
      SizedBox(width: gap),
      Expanded(child: WizardField(controller: _depth, dense: phone, suffix: 'mm', keyboardType: TextInputType.number, onChanged: (v) => _dirty(() => draft.depthText = v))),
      SizedBox(width: gap),
      Expanded(child: WizardField(controller: _height, dense: phone, suffix: 'mm', keyboardType: TextInputType.number, onChanged: (v) => _dirty(() => draft.heightText = v))),
    ]);
    final weightField = WizardField(
      controller: _weight,
      dense: phone,
      suffix: 'kg',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) => _dirty(() => draft.weightText = v),
    );
    final materialField = WizardDropdown(
      value: draft.material,
      dense: phone,
      items: [('AISI 304', 'AISI 304'), ('AISI 430', 'AISI 430'), ('Other', t('ui_other'))],
      onChanged: (v) => _dirty(() => draft.material = v),
    );
    final warrantyChips = Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final m in const [0, 3, 6, 12, 24, -1])
          ChoiceChip(
            label: Text(m < 0 ? t('ui_custom') : (m == 0 ? t('ui_warranty_none') : t('ui_n_months', {'n': '$m'}))),
            selected: draft.warrantyMonths == m,
            onSelected: (_) => _dirty(() => draft.warrantyMonths = m),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WizardLabel(t('ui_condition')),
        if (phone)
          WizardSegmented(
            value: draft.condition,
            options: [
              (TGCondition.newItem, t('ui_condition_new')),
              (TGCondition.used, t('ui_condition_used')),
            ],
            onChanged: (v) => _dirty(() => draft.condition = v),
          )
        else
          Row(
            children: [
              Expanded(
                child: WizardRadioCard(
                  compact: true,
                  selected: draft.condition == TGCondition.newItem,
                  title: t('ui_condition_new'),
                  subtitle: t('ui_condition_new_hint'),
                  onTap: () => _dirty(() => draft.condition = TGCondition.newItem),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: WizardRadioCard(
                  compact: true,
                  selected: draft.condition == TGCondition.used,
                  title: t('ui_condition_used'),
                  subtitle: t('ui_condition_used_hint'),
                  onTap: () => _dirty(() => draft.condition = TGCondition.used),
                ),
              ),
            ],
          ),
        if (draft.condition == TGCondition.used) ...[
          const SizedBox(height: 10),
          _specRow([
            _labeled(
              t('ui_year_manufacture'),
              WizardField(key: const Key('wizard-year'), controller: _year, focusNode: _focus('year'), dense: phone, keyboardType: TextInputType.number, error: _err('year'), onChanged: (v) => _dirty(() => draft.yearText = v), onEditingComplete: () => draft.validateStep(1)),
            ),
            _labeled(
              t('ui_hours_used'),
              WizardField(controller: _hours, dense: phone, keyboardType: TextInputType.number, onChanged: (v) => _dirty(() => draft.hoursText = v)),
            ),
          ], gap: gap),
          const SizedBox(height: 10),
          WizardLabel(t('ui_service_history')),
          WizardField(controller: _service, maxLines: 2, onChanged: (v) => _dirty(() => draft.serviceHistory = v)),
          const SizedBox(height: 4),
          if (phone) ...[
            CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, visualDensity: VisualDensity.compact, value: draft.originalPackaging, onChanged: (v) => _dirty(() => draft.originalPackaging = v ?? false), title: Text(t('ui_original_packaging')), activeColor: TGColors.cta),
            CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, visualDensity: VisualDensity.compact, value: draft.onSiteInspection, onChanged: (v) => _dirty(() => draft.onSiteInspection = v ?? false), title: Text(t('ui_onsite_inspection')), activeColor: TGColors.cta),
          ] else
            Row(
              children: [
                Expanded(child: CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, visualDensity: VisualDensity.compact, value: draft.originalPackaging, onChanged: (v) => _dirty(() => draft.originalPackaging = v ?? false), title: Text(t('ui_original_packaging')), activeColor: TGColors.cta)),
                Expanded(child: CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, visualDensity: VisualDensity.compact, value: draft.onSiteInspection, onChanged: (v) => _dirty(() => draft.onSiteInspection = v ?? false), title: Text(t('ui_onsite_inspection')), activeColor: TGColors.cta)),
              ],
            ),
        ],
        const SizedBox(height: 10),
        _specRow([
          _labeled(t('ui_brand'), brandField),
          _labeled(t('ui_model'), modelField),
        ], gap: gap),
        const SizedBox(height: 10),
        WizardLabel(t('ui_power_type')),
        Wrap(
          spacing: 8,
          children: [
            for (final e in [
              (TGPowerType.electric, t('ui_electric'), Icons.bolt_outlined),
              (TGPowerType.gas, t('ui_gas'), Icons.local_fire_department_outlined),
              (TGPowerType.other, t('ui_other'), Icons.extension_outlined),
            ])
              ChoiceChip(
                label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(e.$3, size: 16), const SizedBox(width: 6), Text(e.$2)]),
                selected: draft.powerType == e.$1,
                onSelected: (_) => _dirty(() => draft.powerType = e.$1),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (phone) ...[
          _labeled(t('ui_power'), powerField),
          const SizedBox(height: 10),
          _specRow([
            _labeled(t('ui_voltage'), voltageField),
            _labeled(t('ui_phases'), phasesField),
          ], gap: gap),
        ] else
          _specRow([
            _labeled(t('ui_power'), powerField),
            _labeled(t('ui_voltage'), voltageField),
            _labeled(t('ui_phases'), phasesField),
          ], gap: gap),
        const SizedBox(height: 10),
        if (phone) ...[
          WizardLabel(t('ui_dimensions')),
          dimFields,
          const SizedBox(height: 10),
          _specRow([
            _labeled(t('ui_weight'), weightField),
            _labeled(t('ui_material'), materialField),
          ], gap: gap),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WizardLabel(t('ui_dimensions')),
                    dimFields,
                  ],
                ),
              ),
              SizedBox(width: gap),
              Expanded(child: _labeled(t('ui_weight'), weightField)),
            ],
          ),
        const SizedBox(height: 10),
        if (phone) ...[
          WizardLabel(t('ui_warranty')),
          warrantyChips,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _labeled(t('ui_material'), materialField)),
              SizedBox(width: gap),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WizardLabel(t('ui_warranty')),
                    warrantyChips,
                  ],
                ),
              ),
            ],
          ),
        if (draft.warrantyMonths < 0) ...[
          const SizedBox(height: 8),
          WizardField(controller: _customWarr, dense: phone, suffix: t('ui_n_months', {'n': ''}).trim(), keyboardType: TextInputType.number, onChanged: (v) => _dirty(() => draft.customWarrantyText = v)),
        ],
        CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, visualDensity: VisualDensity.compact, value: draft.fakturaVat, onChanged: (v) => _dirty(() => draft.fakturaVat = v ?? false), title: Text(t('ui_faktura_available')), activeColor: TGColors.cta),
        WizardLabel(t('ui_delivery')),
        WizardRadioCard(
          compact: true,
          selected: draft.fulfillment == AddProductFulfillment.pickupOnly,
          title: t('ui_pickup'),
          onTap: () => _dirty(() => draft.fulfillment = AddProductFulfillment.pickupOnly),
        ),
        const SizedBox(height: 8),
        WizardRadioCard(
          compact: false,
          selected: draft.fulfillment == AddProductFulfillment.shipping,
          title: t('ui_shipping'),
          subtitle: t('ui_shipping_not_included'),
          onTap: () => _dirty(() => draft.fulfillment = AddProductFulfillment.shipping),
        ),
        const SizedBox(height: 8),
        WizardRadioCard(
          compact: false,
          selected: draft.fulfillment == AddProductFulfillment.buyerChoice,
          title: t('ui_buyer_choice'),
          subtitle: t('ui_buyer_choice_help'),
          onTap: () => _dirty(() => draft.fulfillment = AddProductFulfillment.buyerChoice),
        ),
        WizardHelp(t('ui_shipping_arranged')),
        if (draft.category == TGCategory.refrigerationEquipment) ...[
          const SizedBox(height: 10),
          WizardLabel(t('ui_refrigeration')),
          _specRow([
            WizardField(controller: _temp, dense: phone, suffix: '°C', onChanged: (v) => _dirty(() => draft.tempText = v)),
            WizardField(controller: _volume, dense: phone, suffix: 'L', onChanged: (v) => _dirty(() => draft.volumeText = v)),
          ], gap: gap),
        ],
        if (draft.category == TGCategory.warewashing) ...[
          const SizedBox(height: 10),
          WizardLabel(t('ui_cat_warewashing')),
          _specRow([
            WizardField(controller: _program, dense: phone, suffix: 'min', onChanged: (v) => _dirty(() => draft.programText = v)),
            WizardDropdown(
              value: draft.basketSize.isEmpty ? null : draft.basketSize,
              dense: phone,
              hint: t('ui_basket_size'),
              items: const [('500 × 500', '500 × 500'), ('500 × 600', '500 × 600')],
              onChanged: (v) => _dirty(() => draft.basketSize = v),
            ),
          ], gap: gap),
        ],
      ],
    );
  }

  void _addPhoto() {
    if (draft.photos.length >= 12) {
      showTGToast(context, context.t('ui_max_photos'));
      return;
    }
    draft.addSamplePhoto();
  }

  Widget _stepPhotos() {
    final err = draft.fieldErrors;
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WizardLabel(context.t('ui_step_photos')),
        if (phone)
          Row(
            children: [
              Expanded(
                child: TGButton(
                  key: const Key('wizard-take-photo'),
                  onPressed: _addPhoto,
                  icon: Icons.photo_camera_outlined,
                  label: context.t('ui_take_photo'),
                  height: 52,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TGButton(
                  key: const Key('wizard-add-photo'),
                  onPressed: _addPhoto,
                  icon: Icons.photo_library_outlined,
                  label: context.t('ui_choose_gallery'),
                  variant: TGButtonVariant.outline,
                  height: 52,
                ),
              ),
            ],
          )
        else
          _DropZone(
            key: const Key('wizard-add-photo'),
            onAdd: _addPhoto,
            onTooLarge: () => draft.addPhotoError('err_wizard_file_too_large'),
          ),
        if (err['photos'] != null) WizardError(context.t(err['photos']!)),
        const SizedBox(height: 8),
        WizardHelp(context.t('ui_photos_help')),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: draft.photos.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: phone ? 3 : 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 4 / 3),
          itemBuilder: (context, i) {
            final p = draft.photos[i];
            return _PhotoThumb(
              photo: p,
              cover: i == 0 && p.error == null,
              onDelete: () {
                _undoPhoto = draft.removePhoto(p.id);
                _undoIndex = i;
                showTGToast(
                  context,
                  context.t('ui_photo_removed'),
                  icon: Icons.undo,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: context.t('ui_undo'),
                    onPressed: () {
                      if (_undoPhoto != null) {
                        draft.insertPhoto(_undoIndex, _undoPhoto!);
                        _undoPhoto = null;
                      }
                    },
                  ),
                );
              },
              onRetry: p.error == null ? null : _addPhoto,
              onLeft: i == 0 ? null : () => draft.movePhoto(i, i - 1),
              onRight: i == draft.photos.length - 1 ? null : () => draft.movePhoto(i, i + 1),
            );
          },
        ),
        if (_undoPhoto != null)
          TextButton(
            onPressed: () {
              draft.insertPhoto(_undoIndex, _undoPhoto!);
              _undoPhoto = null;
            },
            child: Text(context.t('ui_undo')),
          ),
        const SizedBox(height: 10),
        WizardHelp(context.t('ui_photos_nameplate')),
      ],
    );
  }

  Widget _stepContact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WizardLabel(context.t('ui_seller_type')),
        WizardSegmented(
          value: draft.sellerType,
          options: [(TGSellerType.private, context.t('ui_private')), (TGSellerType.store, context.t('ui_company'))],
          onChanged: (v) => _dirty(() => draft.sellerType = v),
        ),
        if (draft.sellerType == TGSellerType.store) ...[
          const SizedBox(height: 12),
          WizardLabel(context.t('ui_company_name')),
          WizardField(controller: _company, focusNode: _focus('company'), error: _err('company'), onChanged: (v) => _dirty(() => draft.companyName = v)),
          const SizedBox(height: 12),
          if (MediaQuery.sizeOf(context).width < TGBreakpoints.phone) ...[
            WizardLabel(context.t('ui_nip')),
            WizardField(controller: _nip, focusNode: _focus('nip'), error: _err('nip'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)], onChanged: (v) => _dirty(() => draft.nip = v), onEditingComplete: () => draft.validateStep(3)),
            const SizedBox(height: 12),
            WizardLabel(context.t('ui_address')),
            WizardField(controller: _address, onChanged: (v) => _dirty(() => draft.companyAddress = v)),
          ] else
            _specRow([
              _labeled(
                context.t('ui_nip'),
                WizardField(controller: _nip, focusNode: _focus('nip'), error: _err('nip'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)], onChanged: (v) => _dirty(() => draft.nip = v), onEditingComplete: () => draft.validateStep(3)),
              ),
              _labeled(context.t('ui_address'), WizardField(controller: _address, onChanged: (v) => _dirty(() => draft.companyAddress = v))),
            ]),
        ],
        const SizedBox(height: 12),
        WizardLabel(context.t('ui_contact_name')),
          WizardField(key: const Key('wizard-contact'), controller: _contact, focusNode: _focus('contact'), error: _err('contact'), onChanged: (v) => _dirty(() => draft.contactName = v)),
        const SizedBox(height: 12),
        WizardLabel(context.t('ui_phone')),
        WizardField(
          key: const Key('wizard-phone'),
          controller: _phone,
          focusNode: _focus('phone'),
          hint: '+48 ___ ___ ___',
          error: _err('phone'),
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
          onChanged: (v) => _dirty(() {
            draft.phoneDigits = v;
            draft.phoneVerified = false;
          }),
        ),
        WizardHelp(context.t('ui_phone_public')),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: WizardField(
                key: const Key('wizard-sms'),
                controller: _sms,
                focusNode: _focus('sms'),
                hint: context.t('ui_sms_code'),
                error: _err('sms'),
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                onChanged: (v) => draft.smsCode = v,
              ),
            ),
            const SizedBox(width: 10),
            TGButton(
              key: const Key('wizard-verify'),
              onPressed: () {
                if (draft.smsCode == '123456' && draft.phoneDigits.length == 9) {
                  _dirty(() => draft.phoneVerified = true);
                  showTGToast(context, context.t('ui_phone_verified'));
                } else {
                  draft.setFieldError('sms', 'err_wizard_sms_mock');
                }
              },
              label: draft.phoneVerified ? context.t('ui_verified') : context.t('ui_verify'),
              height: 48,
            ),
          ],
        ),
        const SizedBox(height: 12),
        WizardLabel(context.t('ui_city')),
        Autocomplete<TGCity>(
          optionsBuilder: (v) {
            final q = TGGeo.normalize(v.text);
            if (q.isEmpty) return TGGeo.cities;
            return TGGeo.cities.where((c) => TGGeo.normalize(c.name).contains(q));
          },
          displayStringForOption: (c) => c.name,
          onSelected: (c) {
            _city.text = c.name;
            _dirty(() {
              draft.city = c.name;
              draft.voivodeship = c.voivodeship;
            });
          },
          fieldViewBuilder: (context, controller, focus, onSubmit) {
            return WizardField(
              key: const Key('wizard-city'),
              controller: controller,
              focusNode: focus,
              hint: context.t('ui_city_type'),
              error: _err('city'),
              onChanged: (v) => _dirty(() => draft.city = v),
              onEditingComplete: onSubmit,
            );
          },
        ),
        if (draft.voivodeship.isNotEmpty) WizardHelp(context.t('ui_voivodeship_n', {'n': draft.voivodeship})),
        const SizedBox(height: 10),
        _MapPin(city: draft.city),
        const SizedBox(height: 12),
        if (MediaQuery.sizeOf(context).width < TGBreakpoints.phone) ...[
          WizardLabel(context.t('ui_hours_to_call')),
          WizardField(controller: _hoursCall, hint: context.t('ui_hours_hint'), onChanged: (v) => _dirty(() => draft.hoursToCall = v)),
          const SizedBox(height: 12),
          WizardLabel(context.t('ui_notify_email')),
          WizardField(controller: _email, keyboardType: TextInputType.emailAddress, onChanged: (v) => _dirty(() => draft.notifyEmail = v)),
        ] else
          _specRow([
            _labeled(context.t('ui_hours_to_call'), WizardField(controller: _hoursCall, hint: context.t('ui_hours_hint'), onChanged: (v) => _dirty(() => draft.hoursToCall = v))),
            _labeled(context.t('ui_notify_email'), WizardField(controller: _email, keyboardType: TextInputType.emailAddress, onChanged: (v) => _dirty(() => draft.notifyEmail = v))),
          ]),
      ],
    );
  }

  Widget _stepReview() {
    final auth = context.watch<FakeAuthState>();
    final plan = auth.listingPlan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (MediaQuery.sizeOf(context).width < TGBreakpoints.phone)
          ExpansionTile(
            initiallyExpanded: true,
            title: Text(context.t('ui_summary')),
            children: [
              _ReviewBlock(title: context.t('ui_step_basic'), onEdit: () => _goStep(0), lines: [
                draft.listingType == TGListingType.rent ? context.t('ui_rent') : context.t('ui_sell'),
                draft.category == null ? context.t('ui_no_category') : categoryLabel(draft.category!, t: (k) => context.t(k)),
                draft.title.trim().isEmpty ? context.t('ui_no_title') : draft.title.trim(),
              ]),
            ],
          )
        else
        _ReviewBlock(title: context.t('ui_step_basic'), onEdit: () => _goStep(0), lines: [
          draft.listingType == TGListingType.rent ? context.t('ui_rent') : context.t('ui_sell'),
          draft.category == null ? context.t('ui_no_category') : categoryLabel(draft.category!, t: (k) => context.t(k)),
          draft.title.trim().isEmpty ? context.t('ui_no_title') : draft.title.trim(),
        ]),
        _ReviewBlock(title: context.t('ui_step_specs'), onEdit: () => _goStep(1), lines: [
          conditionLabel(draft.condition, t: (k) => context.t(k)),
          if (draft.brand.isNotEmpty) draft.brand,
        ]),
        _ReviewBlock(title: context.t('ui_step_photos'), onEdit: () => _goStep(2), lines: [context.t('ui_photo_count', {'n': '${draft.photos.where((p) => p.error == null).length}'})]),
        _ReviewBlock(title: context.t('ui_contact'), onEdit: () => _goStep(3), lines: [
          draft.contactName,
          draft.phoneDisplay,
          draft.city,
        ]),
        if (draft.fieldErrors.isNotEmpty) ...[
          const SizedBox(height: 8),
          WizardError(context.t('ui_fix_missing')),
        ],
        const SizedBox(height: 16),
        WizardSegmented(
          value: draft.reviewTab,
          options: [(0, context.t('ui_card_preview')), (1, context.t('ui_detail_preview'))],
          onChanged: (v) => _dirty(() => draft.reviewTab = v),
        ),
        const SizedBox(height: 12),
        if (draft.reviewTab == 0)
          SizedBox(
            height: TGProductCard.gridExtent(320, MediaQuery.textScalerOf(context)),
            width: 320,
            child: TGProductCard(product: draft.toProduct(), layout: TGProductCardLayout.grid),
          )
        else
          Text(
            draft.toProduct().extra.entries.map((e) => '${_extraLabel(context, e.key)}: ${_extraValue(context, e.value)}').join('\n'),
            style: FlutterFlowTheme.of(context).bodySmall,
          ),
        const SizedBox(height: 18),
        _PlanBox(auth: auth),
        const SizedBox(height: 14),
        WizardLabel(context.t('ui_promote')),
        WizardRadioCard(selected: draft.promote == AddProductPromote.none, title: context.t('ui_warranty_none'), onTap: () => _dirty(() => draft.promote = AddProductPromote.none)),
        const SizedBox(height: 8),
        WizardRadioCard(selected: draft.promote == AddProductPromote.days14, title: context.t('ui_promote_14'), subtitle: context.t('ui_promote_help', {'badge': context.t('ui_promoted_badge')}), onTap: () => _dirty(() => draft.promote = AddProductPromote.days14)),
        const SizedBox(height: 8),
        WizardRadioCard(selected: draft.promote == AddProductPromote.days30, title: context.t('ui_promote_30'), subtitle: context.t('ui_promote_help', {'badge': context.t('ui_promoted_badge')}), onTap: () => _dirty(() => draft.promote = AddProductPromote.days30)),
        const SizedBox(height: 14),
        Text(context.t('ui_total_brutto_vat', {'n': '${draft.totalPln}'}), style: FlutterFlowTheme.of(context).titleSmall.override(fontWeight: FontWeight.w900)),
        if (plan == TGListingPlan.paid) ...[
          const SizedBox(height: 12),
          WizardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('ui_store_nudge'), style: FlutterFlowTheme.of(context).titleSmall.override(fontWeight: FontWeight.w800)),
                WizardHelp(context.t('ui_store_nudge_help')),
                const SizedBox(height: 8),
                TGButton(onPressed: () => context.go('/plans'), label: context.t('ui_see_basic_store'), variant: TGButtonVariant.outline, height: 44),
              ],
            ),
          ),
        ],
      ],
    );
  }

}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step, required this.labels, required this.onTap});
  final int step;
  final List<String> labels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    Widget connector(int i) => AnimatedContainer(
          duration: TGMotion.of(context, TGMotion.stepper),
          height: 2,
          width: wide ? null : 16,
          color: i <= step ? theme.primary : TGColors.border,
        );
    final row = Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) wide ? Expanded(child: connector(i)) : connector(i),
          Semantics(
            button: true,
            selected: i == step,
            label: context.t('ui_step_n', {'n': '${i + 1}', 'label': labels[i]}),
            child: GestureDetector(
            onTap: i <= step ? () => onTap(i) : null,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: TGMotion.of(context, TGMotion.stepper),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < step ? theme.primary : Colors.transparent,
                    border: Border.all(color: i <= step ? theme.primary : TGColors.border, width: 2),
                  ),
                  child: AnimatedSwitcher(
                    duration: TGMotion.of(context, TGMotion.fade),
                    child: i < step
                        ? Icon(Icons.check, key: const ValueKey('check'), size: 16, color: TGColors.onCta)
                        : Text('${i + 1}', key: ValueKey('n$i'), style: theme.labelSmall.override(fontWeight: FontWeight.w800, color: i == step ? theme.primary : theme.secondaryText)),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: wide ? 88 : 72,
                  child: Text(labels[i], textAlign: TextAlign.center, maxLines: 2, style: theme.bodySmall.override(fontWeight: i == step ? FontWeight.w800 : FontWeight.w500)),
                ),
              ],
            ),
          ),
          ),
        ],
      ],
    );
    return WizardCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: wide ? row : SingleChildScrollView(scrollDirection: Axis.horizontal, child: row),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.draft});
  final AddProductDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final pct = (draft.completeness * 100).round();
    final product = draft.toProduct();
    final empty = draft.title.trim().isEmpty && draft.photos.isEmpty;
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        child: WizardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(draft.step == 4 ? context.t('ui_order_summary') : context.t('ui_live_preview'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: TGMotion.of(context, TGMotion.fade),
                child: empty
                    ? const TGProductCardSkeleton()
                    : LayoutBuilder(
                        key: ValueKey(product.title),
                        builder: (context, c) {
                          final w = c.maxWidth;
                          return SizedBox(
                            height: TGProductCard.gridExtent(w, MediaQuery.textScalerOf(context)),
                            width: w,
                            child: TGProductCard(product: product, layout: TGProductCardLayout.grid),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct.toDouble()),
                duration: TGMotion.of(context, TGMotion.price),
                builder: (context, v, _) => Text(context.t('ui_pct_complete', {'n': '${v.round()}'}), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: draft.completeness,
                  minHeight: 8,
                  backgroundColor: TGColors.border,
                  color: theme.primary,
                ),
              ),
              const SizedBox(height: 12),
              for (final h in draft.hints)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: theme.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(context.t(h), style: theme.bodySmall.override(color: theme.secondaryText))),
                    ],
                  ),
                ),
              if (draft.step == 4) ...[
                const Divider(height: 24),
                Text(context.t('ui_listing_pln', {'n': '${draft.listingFeePln}'}), style: theme.bodySmall),
                Text(context.t('ui_promote_pln', {'n': '${draft.promoteFeePln}'}), style: theme.bodySmall),
                Text(context.t('ui_total_pln', {'n': '${draft.totalPln}'}), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryMenu extends StatelessWidget {
  const _CategoryMenu({required this.selected, required this.onSelect, required this.list});
  final TGCategory? selected;
  final ValueChanged<TGCategory> onSelect;
  final bool list;

  static IconData _icon(TGCategory category) => switch (category) {
        TGCategory.cookingEquipment => Icons.local_fire_department_outlined,
        TGCategory.refrigerationEquipment => Icons.kitchen_outlined,
        TGCategory.warewashing => Icons.water_drop_outlined,
        TGCategory.foodPreparation => Icons.blender_outlined,
        TGCategory.stainlessSteelFurniture => Icons.table_restaurant_outlined,
        TGCategory.barAndBeverageEquipment => Icons.local_bar_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final c in TGCategory.values)
        _CategoryRow(
          key: Key('wizard-cat-${c.name}'),
          icon: _icon(c),
          label: categoryLabel(c, t: (k) => context.t(k)),
          selected: selected == c,
          expand: list,
          onTap: () => onSelect(c),
        ),
    ];
    if (!list) {
      return Wrap(spacing: 8, runSpacing: 8, children: items);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TGColors.surfaceHover,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: TGColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: TGColors.border),
            items[i],
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = true,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.bodyMedium.override(fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
    );
    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: selected ? theme.primary : theme.primaryText),
        const SizedBox(width: 10),
        if (expand) Expanded(child: labelWidget) else labelWidget,
        if (selected) ...[
          const SizedBox(width: 8),
          Icon(Icons.check, size: 18, color: theme.primary),
        ],
      ],
    );
    return Material(
      color: selected ? theme.primary.withValues(alpha: 0.12) : (expand ? Colors.transparent : TGColors.surfaceHover),
      shape: expand
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TGRadius.pill),
              side: BorderSide(color: selected ? theme.primary : TGColors.border, width: selected ? 2 : 1),
            ),
      child: InkWell(
        onTap: onTap,
        borderRadius: expand ? null : BorderRadius.circular(TGRadius.pill),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: expand ? 12 : 12, vertical: expand ? 11 : 8),
          child: row,
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.text, required this.pink});
  final String text;
  final bool pink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: pink ? TGColors.accent : TGColors.cta, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: pink ? Colors.white : TGColors.onCta, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class _DropZone extends StatefulWidget {
  const _DropZone({super.key, required this.onAdd, required this.onTooLarge});
  final VoidCallback onAdd;
  final VoidCallback onTooLarge;

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Semantics(
      button: true,
      label: context.t('ui_upload_photos'),
      child: FocusableActionDetector(
      onShowFocusHighlight: (_) {},
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onAdd();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onAdd,
        child: MouseRegion(
          onEnter: (_) => setState(() => _over = true),
          onExit: (_) => setState(() => _over = false),
          child: AnimatedContainer(
            duration: TGMotion.of(context, TGMotion.quick),
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _over ? theme.primary.withValues(alpha: 0.06) : TGColors.surface,
              borderRadius: BorderRadius.circular(TGRadius.card),
              border: Border.all(color: _over ? theme.primary : TGColors.border, width: 2, style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_upload_outlined, color: theme.primary, size: 32),
                const SizedBox(height: 8),
                Text(_over ? context.t('ui_drop_upload') : context.t('ui_drag_photos'), style: theme.bodyMedium.override(fontWeight: FontWeight.w700)),
                TextButton(onPressed: widget.onTooLarge, child: Text(context.t('ui_simulate_large'))),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo, required this.cover, required this.onDelete, this.onLeft, this.onRight, this.onRetry});
  final AddProductPhoto photo;
  final bool cover;
  final VoidCallback onDelete;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: photo.error != null ? TGColors.error : theme.tertiary),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo.error != null)
              ColoredBox(
                color: TGColors.surfaceHover,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.t(photo.error!), textAlign: TextAlign.center, style: const TextStyle(color: TGColors.error, fontSize: 11)),
                      if (onRetry != null)
                        TextButton(onPressed: onRetry, child: Text(context.t('ui_retry'))),
                    ],
                  ),
                ),
              )
            else
              Image.asset(photo.assetPath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: TGColors.border)),
            if (cover)
              Positioned(top: 6, left: 6, child: _MiniPill(text: context.t('ui_cover'), pink: true)),
            if (photo.error == null)
              const Positioned(top: 6, right: 6, child: Icon(Icons.check_circle, color: TGColors.cta, size: 18)),
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: Row(
                children: [
                  _TinyIcon(icon: Icons.chevron_left, onTap: onLeft),
                  _TinyIcon(icon: Icons.chevron_right, onTap: onRight),
                  const Spacer(),
                  _TinyIcon(icon: Icons.delete_outline, onTap: onDelete),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyIcon extends StatelessWidget {
  const _TinyIcon({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16, color: onTap == null ? Colors.white24 : Colors.white),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.city});
  final String city;

  @override
  Widget build(BuildContext context) {
    final hit = TGGeo.lookup(city);
    final theme = FlutterFlowTheme.of(context);
    return Container(
      height: 88,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TGColors.surfaceHover,
        borderRadius: BorderRadius.circular(TGRadius.card),
        border: Border.all(color: TGColors.border),
      ),
      child: hit == null
          ? Text(context.t('ui_map_pin'), style: theme.bodySmall.override(color: theme.secondaryText))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, color: theme.primary),
                const SizedBox(width: 8),
                Text('${hit.name} · ${hit.lat.toStringAsFixed(2)}, ${hit.lng.toStringAsFixed(2)}'),
              ],
            ),
    );
  }
}

class _ReviewBlock extends StatelessWidget {
  const _ReviewBlock({required this.title, required this.lines, required this.onEdit});
  final String title;
  final List<String> lines;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
                for (final l in lines.where((e) => e.trim().isNotEmpty))
                  Text(l, style: theme.bodySmall.override(color: theme.secondaryText)),
              ],
            ),
          ),
          TextButton(onPressed: onEdit, child: Text(context.t('ui_edit'))),
        ],
      ),
    );
  }
}

class _PlanBox extends StatelessWidget {
  const _PlanBox({required this.auth});
  final FakeAuthState auth;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final plan = auth.listingPlan;
    final title = switch (plan) {
      TGListingPlan.free when auth.publishedListings.isEmpty =>
        context.t('ui_free_listing_n', {'n': '1'}),
      TGListingPlan.free => context.t('ui_free_listing_n', {'n': '${auth.freeSlotsUsed + 1}'}),
      TGListingPlan.paid => context.t('ui_standard_listing_n', {'fee': '${TGPricing.listingFeePln}'}),
      TGListingPlan.store => context.t('ui_included_in_plan', {
          'plan': auth.storePlanLabel,
          'used': '${auth.storeActiveUsed}',
          'limit': '${auth.storeActiveLimit}',
        }),
      TGListingPlan.storeFull => context.t('ui_store_quota_full'),
    };
    final leftAfter = (auth.freeListingsLeft - 1).clamp(0, auth.freeListingsTotal);
    return WizardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
          if (plan == TGListingPlan.free)
            WizardHelp(
              leftAfter > 0
                  ? context.t('ui_free_listing_help', {'n': '$leftAfter'})
                  : context.t('ui_free_listing_help_last'),
            ),
        ],
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Center(
      child: WizardCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.t('ui_login_to_add'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(context.t('ui_draft_stays')),
            const SizedBox(height: 16),
            TGButton(onPressed: onLogin, label: context.t('ui_login'), height: 48, borderRadius: BorderRadius.circular(TGRadius.pill)),
          ],
        ),
      ),
    );
  }
}

class _LoginModal extends StatefulWidget {
  const _LoginModal({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_LoginModal> createState() => _LoginModalState();
}

class _LoginModalState extends State<_LoginModal> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _phoneFocus = FocusNode();
  bool _register = false;
  bool _visible = false;
  TGIdentityConflict? _conflict;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _social(TGIdentityKind kind) {
    if (_register) {
      final hit = AccountIdentityService.instance.checkSocial(kind);
      if (hit != null) {
        setState(() => _conflict = hit);
        return;
      }
    }
    context.read<FakeAuthState>().logIn();
    widget.onDone();
  }

  void _primary() {
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    if (email.isEmpty || _password.text.isEmpty) return;
    if (_register) {
      final hit = AccountIdentityService.instance.checkRegister(email: email, phone: phone);
      if (hit != null) {
        setState(() => _conflict = hit);
        return;
      }
      if (phone.replaceAll(RegExp(r'\D'), '').length < 9) return;
      AccountIdentityService.instance.claim(email: email, phone: phone);
    }
    context.read<FakeAuthState>().logIn();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: LoginCard(
          logoAssetPath: 'assets/images/Hand_Shake_LOGO.png',
          onGooglePressed: () => _social(TGIdentityKind.google),
          onFacebookPressed: () => _social(TGIdentityKind.facebook),
          emailController: _email,
          emailFocusNode: _emailFocus,
          passwordController: _password,
          passwordFocusNode: _passwordFocus,
          phoneController: _phone,
          phoneFocusNode: _phoneFocus,
          passwordVisible: _visible,
          isRegister: _register,
          conflict: _conflict,
          onReportIssue: () {
            final c = _conflict;
            if (c != null) reportIdentityIssue(context, c);
          },
          onTogglePasswordVisibility: () => setState(() => _visible = !_visible),
          onToggleMode: () => setState(() {
            _register = !_register;
            _conflict = null;
          }),
          onForgotPassword: () {},
          onPrimaryAction: _primary,
        ),
      ),
    );
  }
}

String _extraLabel(BuildContext context, String key) {
  const map = {
    'Subcategory': 'ui_subcategory',
    'Brand': 'ui_brand',
    'Model': 'ui_model',
    'Year': 'ui_year',
    'Hours': 'ui_hours',
    'Service history': 'ui_service_history',
    'Original packaging': 'ui_original_packaging',
    'On-site inspection': 'ui_onsite_inspection',
    'Power': 'ui_power',
    'Voltage': 'ui_voltage',
    'Phases': 'ui_phases',
    'Dimensions': 'ui_dimensions',
    'Weight': 'ui_weight',
    'Material': 'ui_material',
    'Faktura VAT': 'ui_faktura_vat',
    'Temperature': 'ui_temperature',
    'Volume': 'ui_volume',
    'Program time': 'ui_program_time',
    'Basket size': 'ui_basket_size',
    'Deposit': 'ui_deposit',
    'Min. period': 'ui_min_period',
  };
  final k = map[key];
  return k == null ? key : context.t(k);
}

String _extraValue(BuildContext context, String value) {
  if (value == 'Yes') return context.t('ui_yes');
  if (value == 'No') return context.t('ui_no');
  if (value == 'Other') return context.t('ui_other');
  return value;
}
