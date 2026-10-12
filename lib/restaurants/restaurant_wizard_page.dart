import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/login/login_widget.dart';
import 'package:twoja_gastromania/payment/payment_models.dart';
import 'package:twoja_gastromania/restaurants/restaurant_card.dart';
import 'package:twoja_gastromania/restaurants/restaurant_detail_sections.dart' show restoInvCatLabel;
import 'package:twoja_gastromania/restaurants/restaurant_l10n.dart';
import 'package:twoja_gastromania/restaurants/restaurant_wizard_draft.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_header.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
// tgAnim / tgReduceMotion live in tg_analytics.dart
import 'package:twoja_gastromania/tg_models/tg_product.dart' show TGSeller, TGSellerType;
import 'package:twoja_gastromania/tg_models/tg_restaurant_listing.dart';
import 'package:twoja_gastromania/tg_services/restaurant_lifecycle_service.dart';
import 'package:twoja_gastromania/tg_services/restaurant_service.dart';

class RestaurantWizardPage extends StatefulWidget {
  const RestaurantWizardPage({super.key, this.resumeId});

  static const routeName = 'restaurantNew';
  static const routePath = '/restaurants/new';

  final String? resumeId;

  @override
  State<RestaurantWizardPage> createState() => _RestaurantWizardPageState();
}

class _RestaurantWizardPageState extends State<RestaurantWizardPage> {
  late RestaurantWizardDraft draft;
  Timer? _autosave;
  bool _publishing = false;
  bool _previewOpen = false;
  String? _undoPhoto;
  int _undoIndex = 0;
  final _sms = TextEditingController();

  List<String> _steps(BuildContext context) => [
        context.t('ui_wiz_step_business'),
        context.t('ui_wiz_step_premises'),
        context.t('ui_wiz_step_lease'),
        context.t('ui_wiz_step_equipment'),
        context.t('ui_wiz_step_publish'),
      ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<FakeAuthState>();
    final resume = widget.resumeId == null ? null : RestaurantService.instance.byId(widget.resumeId!);
    draft = resume != null && resume.status == RestaurantListingStatus.draft
        ? RestaurantWizardDraft.fromListing(resume)
        : RestaurantWizardDraft(ownerId: auth.userId);
    draft.addListener(() => setState(() {}));
    _autosave = Timer.periodic(const Duration(seconds: 5), (_) => _saveDraft(silent: true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TGAnalytics.track('resto_wizard_step', {'step': 0});
      _gate();
    });
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _sms.dispose();
    draft.dispose();
    super.dispose();
  }

  Future<void> _gate() async {
    final auth = context.read<FakeAuthState>();
    if (!auth.isLoggedIn) {
      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.t('ui_login_required'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 12),
              TGButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ctx.goNamed(LoginPageWidget.routeName);
                },
                label: ctx.t('ui_login'),
                height: 44,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _saveDraft({bool silent = false}) {
    final auth = context.read<FakeAuthState>();
    if (!auth.isLoggedIn) return;
    final listing = draft.toListing(
      seller: TGSeller(id: auth.userId, name: draft.contactName.isEmpty ? auth.displayName : draft.contactName, type: TGSellerType.private, verified: false, rating: 4.5),
      status: RestaurantListingStatus.draft,
    );
    draft.draftId = listing.id;
    RestaurantService.instance.upsertDraft(listing);
    draft.markSaved();
    if (!silent && mounted) showTGToast(context, context.t('ui_draft_saved'));
  }

  Future<bool> _confirmLeave() async {
    if (!draft.dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('ui_wiz_leave_title')),
        content: Text(ctx.t('ui_wiz_leave_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_wiz_stay'))),
          TextButton(
            onPressed: () {
              _saveDraft();
              Navigator.pop(ctx, true);
            },
            child: Text(ctx.t('ui_wiz_save_leave')),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.t('ui_wiz_discard'))),
        ],
      ),
    );
    return ok ?? false;
  }

  void _goStep(int s) {
    setState(() => draft.step = s.clamp(0, 4));
    TGAnalytics.track('resto_wizard_step', {'step': draft.step});
  }

  Future<void> _next() async {
    if (!draft.validateStep(draft.step)) return;
    if (draft.step < 4) {
      _goStep(draft.step + 1);
      return;
    }
    await _publish();
  }

  Future<void> _publish() async {
    for (var i = 0; i <= 4; i++) {
      if (!draft.validateStep(i)) {
        _goStep(i);
        return;
      }
    }
    final auth = context.read<FakeAuthState>();
    if (!auth.isLoggedIn || !auth.phoneVerified && !draft.phoneVerified) {
      showTGToast(context, context.t('ui_wiz_phone_required'), icon: Icons.phone_locked);
      return;
    }
    final life = RestaurantLifecycleService.instance..ensureSeeded();
    if (!life.underDailyCap(auth.userId)) {
      showTGToast(context, context.t('ui_wiz_daily_cap'));
      return;
    }

    final seller = TGSeller(
      id: auth.userId,
      name: draft.contactName,
      type: TGSellerType.private,
      verified: false,
      rating: 4.5,
    );
    var listing = draft.toListing(seller: seller, status: RestaurantListingStatus.paymentPending);
    // Fix draft listingNo placeholder
    listing = listing.copyWith(listingNo: '');

    final gate = life.checkPremisesGate(ownerId: auth.userId, premisesKey: listing.premisesKey, excludeId: listing.id);
    if (gate.isBlocked) {
      TGAnalytics.track('resto_premises_conflict', {'result': 'same_account'});
      showTGToast(context, context.t('ui_wiz_premises_conflict'));
      return;
    }

    setState(() => _publishing = true);

    if (gate.requiresPendingAuth) {
      RestaurantService.instance.replace(listing);
      life.activate(listing: listing, useFreeIntro: false, pendingAuthorization: true);
      if (!mounted) return;
      context.go('/restaurants/success?id=${listing.id}&pending=1');
      return;
    }

    final useFree = draft.canUseFree;
    if (draft.goesToCheckout) {
      final pending = listing.copyWith(status: RestaurantListingStatus.paymentPending);
      RestaurantService.instance.replace(pending);
      auth.beginCheckout(
        TGCheckoutCart.restaurantListing(
          listingId: pending.id,
          listingFee: draft.listingFeePln,
          promoteFee: draft.promoteFeePln,
          promoteDays: draft.promoteDays,
          useFreeIntro: useFree,
        ),
      );
      if (!mounted) return;
      context.go('/restaurants/checkout');
      return;
    }

    RestaurantService.instance.replace(listing);
    final live = life.activate(listing: listing, useFreeIntro: useFree, promoteDays: draft.promoteDays);
    if (!mounted) return;
    context.go('/restaurants/success?id=${live.id}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final w = MediaQuery.sizeOf(context).width;
    final desktop = w >= TGBreakpoints.desktop;
    final phone = w < TGBreakpoints.phone;
    final pad = phone ? 16.0 : 24.0;

    return PopScope(
      canPop: !draft.dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) context.go('/restaurants');
      },
      child: TGPageScaffold(
        header: const TGHeader(),
        body: Column(
          children: [
            _stepper(theme),
            Expanded(
              child: phone
                  ? _mobileBody(theme, auth)
                  : Padding(
                      padding: EdgeInsets.fromLTRB(pad, 16, pad, 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1440),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 8,
                                child: SingleChildScrollView(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 845),
                                    child: _stepContent(theme, auth),
                                  ),
                                ),
                              ),
                              if (desktop) ...[
                                const SizedBox(width: 24),
                                SizedBox(width: 411, child: _preview(theme)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            _footerBar(theme, phone: phone),
          ],
        ),
      ),
    );
  }

  Widget _stepper(FlutterFlowTheme theme) {
    final steps = _steps(context);
    return Semantics(
      label: context.t('ui_wiz_step_of', {'n': '${draft.step + 1}', 'm': '${steps.length}', 'name': steps[draft.step]}),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: AnimatedContainer(
                    duration: tgAnim(context, const Duration(milliseconds: 250)),
                    height: 2,
                    color: i <= draft.step ? TGColors.cta : theme.alternate,
                  ),
                ),
              CircleAvatar(
                radius: 12,
                backgroundColor: i <= draft.step ? TGColors.cta : theme.alternate,
                child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mobileBody(FlutterFlowTheme theme, FakeAuthState auth) {
    final steps = _steps(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text(steps[draft.step], style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
              ActionChip(label: Text(context.t('ui_preview')), onPressed: () => setState(() => _previewOpen = !_previewOpen)),
            ],
          ),
        ),
        if (_previewOpen) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _preview(theme)),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _stepContent(theme, auth))),
      ],
    );
  }

  Widget _footerBar(FlutterFlowTheme theme, {required bool phone}) {
    return Material(
      elevation: 8,
      color: theme.secondaryBackground,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              TextButton(onPressed: draft.step == 0 ? null : () => _goStep(draft.step - 1), child: Text(context.t('ui_back'))),
              TextButton(onPressed: () => _saveDraft(), child: Text(context.t('ui_save_draft'))),
              const Spacer(),
              TGButton(
                onPressed: _publishing ? null : _next,
                label: _publishing
                    ? context.t('ui_wiz_publishing')
                    : draft.step < 4
                        ? context.t('ui_next')
                        : (draft.canUseFree && draft.promoteDays == 0
                            ? context.t('ui_wiz_publish_free')
                            : context.t('ui_wiz_continue_payment', {'amount': '${draft.totalPln}'})),
                height: 48,
                borderRadius: BorderRadius.circular(TGRadius.pill),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(FlutterFlowTheme theme) {
    RestaurantListing? preview;
    try {
      if (draft.title.length >= 5 && draft.city.isNotEmpty) {
        preview = draft.toListing(
          seller: TGSeller(id: draft.ownerId, name: draft.contactName.isEmpty ? context.t('ui_wiz_you') : draft.contactName, type: TGSellerType.private, verified: false, rating: 4.5),
          status: RestaurantListingStatus.draft,
        );
      }
    } catch (_) {}
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('ui_live_preview'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(context.t('ui_wiz_pct_complete', {'n': '${(draft.completion * 100).round()}'}), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: draft.completion, minHeight: 6, color: TGColors.cta, backgroundColor: theme.alternate),
          ),
          const SizedBox(height: 12),
          if (preview != null)
            AnimatedContainer(
              duration: tgAnim(context, const Duration(milliseconds: 300)),
              decoration: draft.promoteDays > 0
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(colors: [TGColors.accent, TGColors.cta]),
                      border: Border.all(width: 2, color: Colors.transparent),
                    )
                  : null,
              padding: draft.promoteDays > 0 ? const EdgeInsets.all(2) : EdgeInsets.zero,
              child: RestaurantCard(listing: preview, variant: RestaurantCardVariant.grid),
            )
          else
            Container(
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: theme.primaryBackground, borderRadius: BorderRadius.circular(12)),
              child: Text(context.t('ui_wiz_fill_preview')),
            ),
          const SizedBox(height: 12),
          Text(context.t('ui_wiz_tips'), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
          Text('· ${context.t('ui_wiz_tip_1')}', style: const TextStyle(fontSize: 12)),
          Text('· ${context.t('ui_wiz_tip_2')}', style: const TextStyle(fontSize: 12)),
          Text('· ${context.t('ui_wiz_tip_3')}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _stepContent(FlutterFlowTheme theme, FakeAuthState auth) {
    return AnimatedSwitcher(
      duration: tgAnim(context, const Duration(milliseconds: 200)),
      child: KeyedSubtree(
        key: ValueKey(draft.step),
        child: switch (draft.step) {
          0 => _stepBusiness(theme),
          1 => _stepPremises(theme),
          2 => _stepLease(theme),
          3 => _stepEquipment(theme),
          _ => _stepPublish(theme, auth),
        },
      ),
    );
  }

  Widget _err(String key) {
    final e = draft.errors[key];
    if (e == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(context.t(e), style: const TextStyle(color: TGColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _stepBusiness(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_wiz_step_business'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text(context.t('ui_wiz_your_role'), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        RadioListTile<RestaurantPosterRole>(
          value: RestaurantPosterRole.owner,
          groupValue: draft.role,
          onChanged: (v) {
            draft.role = v!;
            draft.touch();
          },
          title: Text(context.t('resto_poster_owner')),
        ),
        RadioListTile<RestaurantPosterRole>(
          value: RestaurantPosterRole.agent,
          groupValue: draft.role,
          onChanged: (v) {
            draft.role = v!;
            draft.touch();
          },
          title: Text(context.t('ui_wiz_agent')),
        ),
        CheckboxListTile(
          value: draft.authorized,
          onChanged: (v) {
            draft.authorized = v ?? false;
            draft.touch();
          },
          title: Text(context.t('ui_wiz_authorized')),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        _err('auth'),
        if (draft.role == RestaurantPosterRole.agent)
          TextButton(
            onPressed: () {
              draft.authDocName = 'authorization.pdf';
              draft.touch();
              showTGToast(context, context.t('ui_wiz_auth_mock'));
            },
            child: Text(
              draft.authDocName == null
                  ? context.t('ui_wiz_attach_auth')
                  : context.t('ui_wiz_attached', {'name': draft.authDocName!}),
            ),
          ),
        const SizedBox(height: 12),
        Text(context.t('ui_wiz_business_type'), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in RestaurantBusinessType.values)
              ChoiceChip(
                selected: draft.businessType == t,
                label: Text(restoLocalizedBusinessType(context, t)),
                selectedColor: TGColors.accent.withValues(alpha: 0.25),
                onSelected: (_) {
                  draft.businessType = t;
                  draft.touch();
                },
              ),
          ],
        ),
        _err('type'),
        const SizedBox(height: 12),
        _RestoStableTextField(
          label: context.t('ui_wiz_title_label'),
          value: draft.title,
          onChanged: (v) {
            draft.title = v;
            draft.touch();
          },
        ),
        _err('title'),
        _RestoStableTextField(
          label: context.t('ui_wiz_desc_label'),
          value: draft.description,
          maxLines: 6,
          onChanged: (v) {
            draft.description = v;
            draft.scanDescriptionSuggestions();
            draft.touch();
          },
        ),
        _err('description'),
        if (draft.suggestedEquipment.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final s in draft.suggestedEquipment)
            ActionChip(
              label: Text(context.t('ui_wiz_equip_suggest', {'name': s})),
              onPressed: () => draft.addSuggested(s),
            ),
        ],
      ],
    );
  }

  Widget _stepPremises(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_wiz_premises_location'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(context.t('ui_wiz_address_public'), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 12),
        _text(context.t('ui_city'), draft.city, (v) => draft.city = v, err: 'city'),
        _text(context.t('ui_wiz_district_opt'), draft.district, (v) => draft.district = v),
        _text(context.t('ui_wiz_street'), draft.street, (v) => draft.street = v, err: 'street'),
        _text(context.t('ui_wiz_building_no'), draft.buildingNo, (v) => draft.buildingNo = v, err: 'building'),
        Row(
          children: [
            Expanded(child: _text(context.t('ui_wiz_unit_no'), draft.unitNo, (v) => draft.unitNo = v, err: 'unit', enabled: !draft.noUnit)),
            Checkbox(
              value: draft.noUnit,
              onChanged: (v) {
                draft.noUnit = v ?? false;
                draft.touch();
              },
            ),
            Text(context.t('ui_wiz_no_unit')),
          ],
        ),
        TextField(
          decoration: InputDecoration(labelText: context.t('ui_wiz_total_area_m2'), border: const OutlineInputBorder()),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            draft.totalAreaM2 = double.tryParse(v.replaceAll(',', '.'));
            draft.touch();
          },
        ),
        _err('area'),
        const SizedBox(height: 12),
        Container(
          height: 140,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFE8EEF2), borderRadius: BorderRadius.circular(12)),
          child: Text(
            draft.city.isEmpty ? context.t('ui_wiz_map_preview') : context.t('ui_map_city', {'city': draft.city}),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  String _vatBasisLabel(RestaurantVatBasis b) => switch (b) {
        RestaurantVatBasis.netto => 'Netto',
        RestaurantVatBasis.brutto => 'Brutto',
        RestaurantVatBasis.vatUnspecified => context.t('ui_wiz_vat_unspecified'),
      };

  String _consentLabel(RestaurantLandlordConsent c) => switch (c) {
        RestaurantLandlordConsent.yes => context.t('ui_wiz_consent_yes'),
        RestaurantLandlordConsent.no => context.t('ui_wiz_consent_no'),
        RestaurantLandlordConsent.toBeArranged => context.t('ui_wiz_consent_tba'),
      };

  String _invConditionLabel(RestaurantInventoryCondition c) => switch (c) {
        RestaurantInventoryCondition.newItem => context.t('ui_wiz_cond_new'),
        RestaurantInventoryCondition.used => context.t('ui_wiz_cond_used'),
        RestaurantInventoryCondition.unknown => context.t('ui_wiz_cond_unknown'),
      };

  Widget _stepLease(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_wiz_step_lease'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(labelText: context.t('ui_wiz_monthly_rent_pln'), border: const OutlineInputBorder()),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            draft.rentMonthly = int.tryParse(v.replaceAll(RegExp(r'\D'), ''));
            draft.touch();
          },
        ),
        _err('rent'),
        const SizedBox(height: 8),
        Text(context.t('ui_wiz_rent_vat_basis'), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
        Wrap(
          spacing: 8,
          children: [
            for (final b in RestaurantVatBasis.values)
              ChoiceChip(
                label: Text(_vatBasisLabel(b)),
                selected: draft.rentBasis == b,
                onSelected: (_) {
                  draft.rentBasis = b;
                  draft.touch();
                },
              ),
          ],
        ),
        if (draft.rentMonthly != null && draft.rentBasis != RestaurantVatBasis.vatUnspecified)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              draft.rentBasis == RestaurantVatBasis.netto
                  ? context.t('ui_wiz_approx_brutto', {'amount': '${(draft.rentMonthly! * 1.23).round()}'})
                  : context.t('ui_wiz_approx_netto', {'amount': '${(draft.rentMonthly! / 1.23).round()}'}),
              style: theme.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        Text(context.t('ui_lease_type'), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
        Row(
          children: [
            ChoiceChip(
              label: Text(context.t('ui_fixed_term')),
              selected: draft.leaseType == RestaurantLeaseType.fixed,
              onSelected: (_) {
                draft.leaseType = RestaurantLeaseType.fixed;
                draft.touch();
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(context.t('ui_indefinite')),
              selected: draft.leaseType == RestaurantLeaseType.indefinite,
              onSelected: (_) {
                draft.leaseType = RestaurantLeaseType.indefinite;
                draft.touch();
              },
            ),
          ],
        ),
        if (draft.leaseType == RestaurantLeaseType.fixed)
          TextButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                initialDate: draft.leaseEndsAt ?? DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) {
                draft.leaseEndsAt = d;
                draft.touch();
              }
            },
            child: Text(
              draft.leaseEndsAt == null
                  ? context.t('ui_wiz_pick_lease_end')
                  : context.t('ui_wiz_ends_on', {'d': DateFormat('d MMM yyyy').format(draft.leaseEndsAt!)}),
            ),
          ),
        _err('leaseEnds'),
        const SizedBox(height: 8),
        Text(context.t('ui_landlord_consent'), style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
        Wrap(
          spacing: 8,
          children: [
            for (final c in RestaurantLandlordConsent.values)
              ChoiceChip(
                label: Text(_consentLabel(c)),
                selected: draft.landlordConsent == c,
                onSelected: (_) {
                  draft.landlordConsent = c;
                  draft.touch();
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(context.t('ui_transfer_fee'), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        Row(
          children: [
            ChoiceChip(
              label: Text(context.t('ui_wiz_fee_amount')),
              selected: draft.feeKind == RestaurantTransferFeeKind.amount,
              onSelected: (_) {
                draft.feeKind = RestaurantTransferFeeKind.amount;
                draft.touch();
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(context.t('ui_no_transfer_fee')),
              selected: draft.feeKind == RestaurantTransferFeeKind.none,
              onSelected: (_) {
                draft.feeKind = RestaurantTransferFeeKind.none;
                draft.touch();
              },
            ),
          ],
        ),
        _err('fee'),
        if (draft.feeKind == RestaurantTransferFeeKind.amount) ...[
          TextField(
            decoration: InputDecoration(labelText: context.t('ui_wiz_transfer_fee_pln'), border: const OutlineInputBorder()),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              draft.feeAmount = int.tryParse(v.replaceAll(RegExp(r'\D'), ''));
              draft.touch();
            },
          ),
          _err('feeAmount'),
          Wrap(
            spacing: 8,
            children: [
              for (final b in RestaurantVatBasis.values)
                ChoiceChip(
                  label: Text(_vatBasisLabel(b)),
                  selected: draft.feeBasis == b,
                  onSelected: (_) {
                    draft.feeBasis = b;
                    draft.touch();
                  },
                ),
            ],
          ),
        ],
        CheckboxListTile(
          value: draft.negotiable,
          onChanged: (v) {
            draft.negotiable = v ?? false;
            draft.touch();
          },
          title: Text(context.t('ui_negotiable')),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  Widget _stepEquipment(FlutterFlowTheme theme) {
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_wiz_step_equipment'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(context.t('ui_wiz_equip_optional'), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        Text(context.t('ui_wiz_equip_included'), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
        Wrap(
          spacing: 8,
          children: [
            for (final e in RestaurantEquipmentIncluded.values)
              ChoiceChip(
                label: Text(switch (e) {
                  RestaurantEquipmentIncluded.all => context.t('ui_wiz_equip_all'),
                  RestaurantEquipmentIncluded.partial => context.t('ui_wiz_equip_partial'),
                  RestaurantEquipmentIncluded.none => context.t('ui_none'),
                }),
                selected: draft.equipmentIncluded == e,
                onSelected: (_) {
                  draft.equipmentIncluded = e;
                  draft.touch();
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final e in kQuickInventory.entries) ...[
          Text(e.key.name, style: theme.bodySmall.override(fontWeight: FontWeight.w800, color: TGColors.cta)),
          Wrap(
            spacing: 6,
            children: [
              for (final name in e.value)
                ActionChip(
                  label: Text('+ $name'),
                  onPressed: () {
                    draft.addQuickItem(e.key, name);
                    if (!tgReduceMotion(context)) {
                      // scale-in is handled by AnimatedSwitcher below
                    }
                  },
                ),
            ],
          ),
        ],
        if (draft.inventory.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final item in draft.inventory)
            AnimatedScale(
              key: ValueKey(item.id),
              scale: 1,
              duration: tgAnim(context, const Duration(milliseconds: 120)),
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              draft.inventory = draft.inventory.where((i) => i.id != item.id).toList();
                              draft.touch();
                            },
                          ),
                        ],
                      ),
                      Text('${restoInvCatLabel(context, item.category)} · ×${item.qty}', style: theme.bodySmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: phone ? double.infinity : 120,
                            child: _RestoStableTextField(
                              key: ValueKey('inv-qty-${item.id}'),
                              label: context.t('ui_wiz_qty'),
                              value: '${item.qty}',
                              dense: true,
                              keyboardType: TextInputType.number,
                              onChanged: (v) => draft.updateInventoryItem(item.id, qty: int.tryParse(v) ?? 1),
                            ),
                          ),
                          SizedBox(
                            width: phone ? double.infinity : 160,
                            child: _RestoStableTextField(
                              key: ValueKey('inv-brand-${item.id}'),
                              label: context.t('ui_brand'),
                              value: item.brand ?? '',
                              dense: true,
                              onChanged: (v) => draft.updateInventoryItem(item.id, brand: v),
                            ),
                          ),
                          SizedBox(
                            width: phone ? double.infinity : 160,
                            child: _RestoStableTextField(
                              key: ValueKey('inv-model-${item.id}'),
                              label: context.t('ui_wiz_model_opt'),
                              value: item.model ?? '',
                              dense: true,
                              onChanged: (v) => draft.updateInventoryItem(item.id, model: v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(context.t('ui_condition'), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final c in RestaurantInventoryCondition.values)
                            ChoiceChip(
                              label: Text(_invConditionLabel(c)),
                              selected: item.condition == c,
                              onSelected: (_) => draft.updateInventoryItem(item.id, condition: c),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(context.t('ui_wiz_availability'), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final a in RestaurantInventoryAvailability.values)
                            ChoiceChip(
                              label: Text(switch (a) {
                                RestaurantInventoryAvailability.included => context.t('ui_wiz_inv_included'),
                                RestaurantInventoryAvailability.maySellSeparately => context.t('ui_wiz_inv_may_sell'),
                                RestaurantInventoryAvailability.excluded => context.t('ui_wiz_inv_excluded'),
                              }),
                              selected: item.availability == a,
                              onSelected: (_) => draft.updateInventoryItem(item.id, availability: a),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              draft.updateInventoryItem(item.id, photos: ['mock_item_${item.id}.jpg']);
                              showTGToast(context, context.t(phone ? 'ui_photo_attached_camera' : 'ui_photo_attached_gallery'));
                            },
                            icon: Icon(phone ? Icons.photo_camera_outlined : Icons.photo_library_outlined, size: 16),
                            label: Text(phone ? context.t('ui_wiz_take_photo') : context.t('ui_wiz_choose_gallery')),
                          ),
                          TextButton(
                            onPressed: () {
                              TGAnalytics.track('separate_listing_create', {'itemId': item.id, 'from': 'wizard'});
                              final q = Uri(
                                path: '/add-product',
                                queryParameters: {
                                  'kind': 'equipment',
                                  'resto': draft.draftId ?? '',
                                  'inv': item.id,
                                  'title': item.name,
                                  'qty': '1',
                                  'city': draft.city,
                                  'phone': draft.phone,
                                  if (item.photos.isNotEmpty) 'photo': item.photos.first,
                                },
                              );
                              context.go(q.toString());
                            },
                            child: Text(context.t('ui_wiz_sell_separately')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        Text(context.t('ui_wiz_photos_limits'), style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        Text(context.t('ui_wiz_photos_hint'), style: theme.bodySmall),
        Text(context.t('ui_wiz_exif_mock'), style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TGButton(
              onPressed: () {
                if (draft.photos.length >= 20) {
                  showTGToast(context, context.t('ui_wiz_max_photos'));
                  return;
                }
                draft.addMockPhotos(phone ? 1 : 3);
              },
              label: phone ? context.t('ui_wiz_take_photo') : context.t('ui_wiz_add_photos'),
              height: 40,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            ),
            if (phone)
              OutlinedButton(
                onPressed: () => draft.addMockPhotos(1),
                child: Text(context.t('ui_wiz_choose_gallery')),
              ),
            OutlinedButton(
              onPressed: () {
                draft.floorPlanUrl = 'floorplan_mock.pdf';
                draft.touch();
                showTGToast(context, context.t('ui_floor_plan_attached'));
              },
              child: Text(draft.floorPlanUrl == null ? context.t('ui_wiz_upload_floor') : context.t('ui_wiz_floor_ok')),
            ),
            if (_undoPhoto != null)
              TextButton(
                onPressed: () {
                  final list = [...draft.photos];
                  final i = _undoIndex.clamp(0, list.length);
                  list.insert(i, _undoPhoto!);
                  draft.photos = list;
                  _undoPhoto = null;
                  draft.touch();
                },
                child: Text(context.t('ui_wiz_undo_delete')),
              ),
          ],
        ),
        if (draft.photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: true,
              itemCount: draft.photos.length,
              onReorder: (a, b) {
                final list = [...draft.photos];
                final item = list.removeAt(a);
                list.insert(b > a ? b - 1 : b, item);
                draft.photos = list;
                draft.touch();
              },
              itemBuilder: (ctx, i) {
                final url = draft.photos[i];
                return Padding(
                  key: ValueKey('$url-$i'),
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(url, width: 120, height: 96, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 120, height: 96, color: theme.alternate)),
                      ),
                      if (i == 0)
                        Positioned(
                          left: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: TGColors.cta, borderRadius: BorderRadius.circular(99)),
                            child: Text(context.t('ui_wiz_cover'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
                          onPressed: () {
                            _undoPhoto = url;
                            _undoIndex = i;
                            draft.photos = [...draft.photos]..removeAt(i);
                            draft.touch();
                          },
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton(
                          icon: const Icon(Icons.rotate_right, size: 18, color: Colors.white),
                          onPressed: () => showTGToast(context, context.t('ui_photo_rotated_mock')),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        Text(context.t('ui_wiz_photos_n', {'n': '${draft.photos.length}'}), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
        _err('photos'),
      ],
    );
  }

  Widget _stepPublish(FlutterFlowTheme theme, FakeAuthState auth) {
    final cfg = draft.cfg;
    final free = draft.canUseFree;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t('ui_wiz_contact_publish'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(context.t('ui_phone_public'), style: theme.bodySmall.override(color: theme.secondaryText)),
        TextField(
          decoration: InputDecoration(labelText: context.t('ui_wiz_phone_48'), border: const OutlineInputBorder(), hintText: '+48 XXX XXX XXX'),
          keyboardType: TextInputType.phone,
          inputFormatters: [_PlPhoneMaskFormatter()],
          controller: TextEditingController(text: draft.phone)
            ..selection = TextSelection.collapsed(offset: draft.phone.length),
          onChanged: (v) {
            draft.phone = v;
            draft.touch();
          },
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _sms,
                decoration: InputDecoration(labelText: context.t('ui_wiz_sms_code'), border: const OutlineInputBorder()),
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
              ),
            ),
            const SizedBox(width: 8),
            TGButton(
              onPressed: () {
                if (_sms.text.trim() == '123456') {
                  draft.phoneVerified = true;
                  auth.phoneVerified = true;
                  draft.touch();
                  showTGToast(context, context.t('ui_wiz_phone_ok'));
                } else {
                  showTGToast(context, context.t('ui_wiz_invalid_code'), icon: Icons.error_outline);
                }
              },
              label: context.t('ui_wiz_verify'),
              height: 44,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            ),
          ],
        ),
        _err('phone'),
        _text(context.t('ui_wiz_name'), draft.contactName, (v) => draft.contactName = v, err: 'name'),
        _text(context.t('ui_wiz_email'), draft.email, (v) => draft.email = v, err: 'email', keyboard: TextInputType.emailAddress),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: theme.alternate), borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                free
                    ? context.t('ui_wiz_listing_free', {'days': '${cfg.freeDays}'})
                    : context.t('ui_wiz_listing_paid', {'days': '${cfg.paidDays}', 'price': '${cfg.paidPricePln}'}),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              if (free)
                Text(
                  context.t('ui_wiz_free_extension', {
                    'free': '${cfg.freeDays}',
                    'extra': '${cfg.freeExtensionDays}',
                    'price': '${cfg.paidPricePln}',
                    'paid': '${cfg.paidDays}',
                  }),
                  style: theme.bodySmall,
                )
              else
                Text(draft.freeStartBlockReasonSafe(), style: theme.bodySmall),
              const SizedBox(height: 12),
              Text(
                context.t('ui_wiz_promote', {'badge': context.t('ui_promoted_badge')}),
                style: theme.bodySmall.override(fontWeight: FontWeight.w800),
              ),
              Text(
                context.t('ui_wiz_promote_help', {'badge': context.t('ui_promoted_badge')}),
                style: theme.bodySmall,
              ),
              RadioListTile<int>(
                value: 0,
                groupValue: draft.promoteDays,
                onChanged: (v) {
                  draft.promoteDays = v!;
                  draft.touch();
                },
                title: Text(context.t('ui_none')),
              ),
              RadioListTile<int>(
                value: 14,
                groupValue: draft.promoteDays,
                onChanged: (v) {
                  draft.promoteDays = v!;
                  draft.touch();
                  TGAnalytics.track('resto_promote_selected', {'days': 14});
                },
                title: Text(context.t('ui_wiz_promote_days', {'price': '${cfg.promote.pln14}', 'days': '14'})),
              ),
              RadioListTile<int>(
                value: 30,
                groupValue: draft.promoteDays,
                onChanged: (v) {
                  draft.promoteDays = v!;
                  draft.touch();
                  TGAnalytics.track('resto_promote_selected', {'days': 30});
                },
                title: Text(context.t('ui_wiz_promote_days', {'price': '${cfg.promote.pln30}', 'days': '30'})),
              ),
              Text(context.t('ui_wiz_total_brutto', {'amount': '${draft.totalPln}'}), style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _text(String label, String value, ValueChanged<String> onChanged, {String? err, bool enabled = true, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RestoStableTextField(
            label: label,
            value: value,
            enabled: enabled,
            keyboardType: keyboard,
            onChanged: (v) {
              onChanged(v);
              draft.touch();
            },
          ),
          if (err != null) _err(err),
        ],
      ),
    );
  }
}

/// Keeps a single [TextEditingController] so rebuilds after `notifyListeners`
/// do not reset the caret (which reverses typed characters).
class _RestoStableTextField extends StatefulWidget {
  const _RestoStableTextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.dense = false,
    this.enabled = true,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool dense;
  final bool enabled;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;

  @override
  State<_RestoStableTextField> createState() => _RestoStableTextFieldState();
}

class _RestoStableTextFieldState extends State<_RestoStableTextField> {
  late final TextEditingController _c;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _RestoStableTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _c.text != widget.value) {
      _c.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      focusNode: _focus,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        isDense: widget.dense,
      ),
      onChanged: widget.onChanged,
    );
  }
}

extension on RestaurantWizardDraft {
  String freeStartBlockReasonSafe() {
    return RestaurantLifecycleService.instance.freeStartBlockReason(
      ownerId: ownerId,
      premisesKey: premisesKey,
      phone: phone,
    );
  }
}

/// +48 XXX XXX XXX mask (mock SMS verification).
class _PlPhoneMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('48')) digits = digits.substring(2);
    if (digits.length > 9) digits = digits.substring(0, 9);
    final buf = StringBuffer('+48');
    for (var i = 0; i < digits.length; i++) {
      if (i == 0 || i == 3 || i == 6) buf.write(' ');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
