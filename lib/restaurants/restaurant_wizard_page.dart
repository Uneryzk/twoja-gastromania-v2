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

  static const _steps = ['Business', 'Premises', 'Lease & price', 'Equipment & photos', 'Publish'];

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
    if (!silent && mounted) showTGToast(context, 'Draft saved');
  }

  Future<bool> _confirmLeave() async {
    if (!draft.dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave wizard?'),
        content: const Text('Save your draft before leaving?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(
            onPressed: () {
              _saveDraft();
              Navigator.pop(ctx, true);
            },
            child: const Text('Save & leave'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
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
      showTGToast(context, 'Verified phone is required.', icon: Icons.phone_locked);
      return;
    }
    final life = RestaurantLifecycleService.instance..ensureSeeded();
    if (!life.underDailyCap(auth.userId)) {
      showTGToast(context, 'Daily restaurant listing cap reached.');
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
      showTGToast(context, 'You already have a listing for these premises. Edit it instead.');
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
    return Semantics(
      label: 'Step ${draft.step + 1} of ${_steps.length}: ${_steps[draft.step]}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text(_steps[draft.step], style: theme.titleSmall.override(fontWeight: FontWeight.w900))),
              ActionChip(label: const Text('Preview'), onPressed: () => setState(() => _previewOpen = !_previewOpen)),
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
              TextButton(onPressed: draft.step == 0 ? null : () => _goStep(draft.step - 1), child: const Text('Back')),
              TextButton(onPressed: () => _saveDraft(), child: const Text('Save draft')),
              const Spacer(),
              TGButton(
                onPressed: _publishing ? null : _next,
                label: _publishing
                    ? 'Publishing…'
                    : draft.step < 4
                        ? 'Next'
                        : (draft.canUseFree && draft.promoteDays == 0
                            ? 'Publish for free'
                            : 'Continue to payment · ${draft.totalPln} PLN'),
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
          seller: TGSeller(id: draft.ownerId, name: draft.contactName.isEmpty ? 'You' : draft.contactName, type: TGSellerType.private, verified: false, rating: 4.5),
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
          Text('Live preview', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${(draft.completion * 100).round()}% complete', style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
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
              child: const Text('Fill required fields to preview'),
            ),
          const SizedBox(height: 12),
          Text('Tips', style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
          const Text('· Full address is shown publicly.', style: TextStyle(fontSize: 12)),
          const Text('· Phone is always visible on cards.', style: TextStyle(fontSize: 12)),
          const Text('· Photograph front, dining, kitchen & equipment.', style: TextStyle(fontSize: 12)),
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
      child: Text(e, style: const TextStyle(color: TGColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _stepBusiness(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Business', style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text('Your role', style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        RadioListTile<RestaurantPosterRole>(
          value: RestaurantPosterRole.owner,
          groupValue: draft.role,
          onChanged: (v) {
            draft.role = v!;
            draft.touch();
          },
          title: const Text('Owner'),
        ),
        RadioListTile<RestaurantPosterRole>(
          value: RestaurantPosterRole.agent,
          groupValue: draft.role,
          onChanged: (v) {
            draft.role = v!;
            draft.touch();
          },
          title: const Text('Agent (pośrednik)'),
        ),
        CheckboxListTile(
          value: draft.authorized,
          onChanged: (v) {
            draft.authorized = v ?? false;
            draft.touch();
          },
          title: const Text("I'm authorized to advertise this business and premises."),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        _err('auth'),
        if (draft.role == RestaurantPosterRole.agent)
          TextButton(
            onPressed: () {
              draft.authDocName = 'authorization.pdf';
              draft.touch();
              showTGToast(context, 'Authorization document attached (mock)');
            },
            child: Text(draft.authDocName == null ? 'Attach authorization (optional)' : 'Attached: ${draft.authDocName}'),
          ),
        const SizedBox(height: 12),
        Text('Business type', style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in RestaurantBusinessType.values)
              ChoiceChip(
                selected: draft.businessType == t,
                label: Text(RestaurantListing.businessTypeLabel(t)),
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
        TextField(
          decoration: const InputDecoration(labelText: 'Title (15–80)', border: OutlineInputBorder()),
          controller: TextEditingController(text: draft.title)
            ..selection = TextSelection.collapsed(offset: draft.title.length),
          onChanged: (v) {
            draft.title = v;
            draft.touch();
          },
          maxLength: 80,
        ),
        _err('title'),
        TextField(
          decoration: const InputDecoration(labelText: 'Description (50–4000)', border: OutlineInputBorder()),
          maxLines: 6,
          maxLength: 4000,
          controller: TextEditingController(text: draft.description)
            ..selection = TextSelection.collapsed(offset: draft.description.length),
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
              label: Text('$s found. Add to equipment list?'),
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
        Text('Premises & location', style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('The full address is shown publicly on your listing.', style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 12),
        _text('City', draft.city, (v) => draft.city = v, err: 'city'),
        _text('District (optional)', draft.district, (v) => draft.district = v),
        _text('Street', draft.street, (v) => draft.street = v, err: 'street'),
        _text('Building No.', draft.buildingNo, (v) => draft.buildingNo = v, err: 'building'),
        Row(
          children: [
            Expanded(child: _text('Unit / lokal No.', draft.unitNo, (v) => draft.unitNo = v, err: 'unit', enabled: !draft.noUnit)),
            Checkbox(
              value: draft.noUnit,
              onChanged: (v) {
                draft.noUnit = v ?? false;
                draft.touch();
              },
            ),
            const Text('No unit number'),
          ],
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Total area m²', border: OutlineInputBorder()),
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
          child: Text(draft.city.isEmpty ? 'Map pin preview' : 'Map · ${draft.city}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _stepLease(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Lease & price', style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: 'Monthly rent (PLN)', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            draft.rentMonthly = int.tryParse(v.replaceAll(RegExp(r'\D'), ''));
            draft.touch();
          },
        ),
        _err('rent'),
        const SizedBox(height: 8),
        Text('Rent VAT basis', style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
        Wrap(
          spacing: 8,
          children: [
            for (final b in RestaurantVatBasis.values)
              ChoiceChip(
                label: Text(switch (b) {
                  RestaurantVatBasis.netto => 'Netto',
                  RestaurantVatBasis.brutto => 'Brutto',
                  RestaurantVatBasis.vatUnspecified => 'VAT not specified',
                }),
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
                  ? '≈ ${(draft.rentMonthly! * 1.23).round()} PLN brutto'
                  : '≈ ${(draft.rentMonthly! / 1.23).round()} PLN netto',
              style: theme.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        Text('Lease type', style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Fixed'),
              selected: draft.leaseType == RestaurantLeaseType.fixed,
              onSelected: (_) {
                draft.leaseType = RestaurantLeaseType.fixed;
                draft.touch();
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Indefinite'),
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
            child: Text(draft.leaseEndsAt == null ? 'Pick lease end date' : 'Ends ${DateFormat('d MMM yyyy').format(draft.leaseEndsAt!)}'),
          ),
        _err('leaseEnds'),
        const SizedBox(height: 8),
        Text('Landlord consent for transfer', style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
        Wrap(
          spacing: 8,
          children: [
            for (final c in RestaurantLandlordConsent.values)
              ChoiceChip(
                label: Text(c.name),
                selected: draft.landlordConsent == c,
                onSelected: (_) {
                  draft.landlordConsent = c;
                  draft.touch();
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Transfer fee', style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Amount'),
              selected: draft.feeKind == RestaurantTransferFeeKind.amount,
              onSelected: (_) {
                draft.feeKind = RestaurantTransferFeeKind.amount;
                draft.touch();
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('No transfer fee'),
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
            decoration: const InputDecoration(labelText: 'Transfer fee (PLN)', border: OutlineInputBorder()),
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
                  label: Text(b.name),
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
          title: const Text('Negotiable'),
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
        Text('Equipment & photos', style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Equipment inventory (optional — skippable)', style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        Text('Equipment included', style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
        Wrap(
          spacing: 8,
          children: [
            for (final e in RestaurantEquipmentIncluded.values)
              ChoiceChip(
                label: Text(switch (e) {
                  RestaurantEquipmentIncluded.all => 'All',
                  RestaurantEquipmentIncluded.partial => 'Partial',
                  RestaurantEquipmentIncluded.none => 'None',
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
                      Text('${item.category.name} · ×${item.qty}', style: theme.bodySmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: phone ? double.infinity : 120,
                            child: TextField(
                              decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder(), isDense: true),
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(text: '${item.qty}')
                                ..selection = TextSelection.collapsed(offset: '${item.qty}'.length),
                              onChanged: (v) => draft.updateInventoryItem(item.id, qty: int.tryParse(v) ?? 1),
                            ),
                          ),
                          SizedBox(
                            width: phone ? double.infinity : 160,
                            child: TextField(
                              decoration: const InputDecoration(labelText: 'Brand', border: OutlineInputBorder(), isDense: true),
                              controller: TextEditingController(text: item.brand ?? ''),
                              onChanged: (v) => draft.updateInventoryItem(item.id, brand: v),
                            ),
                          ),
                          SizedBox(
                            width: phone ? double.infinity : 160,
                            child: TextField(
                              decoration: const InputDecoration(labelText: 'Model (opt.)', border: OutlineInputBorder(), isDense: true),
                              controller: TextEditingController(text: item.model ?? ''),
                              onChanged: (v) => draft.updateInventoryItem(item.id, model: v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Condition', style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final c in RestaurantInventoryCondition.values)
                            ChoiceChip(
                              label: Text(c.name),
                              selected: item.condition == c,
                              onSelected: (_) => draft.updateInventoryItem(item.id, condition: c),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Availability', style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final a in RestaurantInventoryAvailability.values)
                            ChoiceChip(
                              label: Text(switch (a) {
                                RestaurantInventoryAvailability.included => 'Included',
                                RestaurantInventoryAvailability.maySellSeparately => 'Included but may be sold separately',
                                RestaurantInventoryAvailability.excluded => 'Not included',
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
                              showTGToast(context, phone ? 'Photo attached (camera mock)' : 'Photo attached (gallery mock)');
                            },
                            icon: Icon(phone ? Icons.photo_camera_outlined : Icons.photo_library_outlined, size: 16),
                            label: Text(phone ? 'Take photo' : 'Choose from gallery'),
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
                            child: const Text('Sell this item separately'),
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
        Text('Photos (min 3, max 20 · 5 recommended)', style: theme.bodyMedium.override(fontWeight: FontWeight.w800)),
        Text('Photograph the front, dining area, kitchen and your main equipment.', style: theme.bodySmall),
        Text('EXIF stripped · HEIC supported (mock).', style: theme.bodySmall.override(color: theme.secondaryText)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TGButton(
              onPressed: () {
                if (draft.photos.length >= 20) {
                  showTGToast(context, 'Maximum 20 photos');
                  return;
                }
                draft.addMockPhotos(phone ? 1 : 3);
              },
              label: phone ? 'Take photo' : 'Add photos',
              height: 40,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            ),
            if (phone)
              OutlinedButton(
                onPressed: () => draft.addMockPhotos(1),
                child: const Text('Choose from gallery'),
              ),
            OutlinedButton(
              onPressed: () {
                draft.floorPlanUrl = 'floorplan_mock.pdf';
                draft.touch();
                showTGToast(context, 'Floor plan attached (PDF/JPG mock)');
              },
              child: Text(draft.floorPlanUrl == null ? 'Upload floor plan' : 'Floor plan ✓'),
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
                child: const Text('Undo delete'),
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
                            child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
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
                          onPressed: () => showTGToast(context, 'Rotated (mock · EXIF stripped)'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        Text('${draft.photos.length} photos', style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
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
        Text('Contact & publish', style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('This number is shown publicly on your listing and cards.', style: theme.bodySmall.override(color: theme.secondaryText)),
        TextField(
          decoration: const InputDecoration(labelText: 'Phone (+48)', border: OutlineInputBorder(), hintText: '+48 XXX XXX XXX'),
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
                decoration: const InputDecoration(labelText: 'SMS code (123456)', border: OutlineInputBorder()),
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
                  showTGToast(context, 'Phone verified');
                } else {
                  showTGToast(context, 'Invalid code', icon: Icons.error_outline);
                }
              },
              label: 'Verify',
              height: 44,
              borderRadius: BorderRadius.circular(TGRadius.pill),
            ),
          ],
        ),
        _err('phone'),
        _text('Name', draft.contactName, (v) => draft.contactName = v, err: 'name'),
        _text('Email', draft.email, (v) => draft.email = v, err: 'email', keyboard: TextInputType.emailAddress),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: theme.alternate), borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                free ? 'Restaurant listing · ${cfg.freeDays} days · Free' : 'Restaurant listing · ${cfg.paidDays} days · ${cfg.paidPricePln},00 PLN',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              if (free)
                Text(
                  'If you get no contacts and no favorites in ${cfg.freeDays} days, we add ${cfg.freeExtensionDays} more free days. Afterwards ${cfg.paidPricePln} PLN / ${cfg.paidDays} days.',
                  style: theme.bodySmall,
                )
              else
                Text(draft.freeStartBlockReasonSafe(), style: theme.bodySmall),
              const SizedBox(height: 12),
              Text('Promote (WYRÓŻNIONE)', style: theme.bodySmall.override(fontWeight: FontWeight.w800)),
              Text(
                'Shown at the top of Restaurants for Sale, in the homepage “Restaurants for Sale” strip, in search results, and labelled WYRÓŻNIONE.',
                style: theme.bodySmall,
              ),
              RadioListTile<int>(
                value: 0,
                groupValue: draft.promoteDays,
                onChanged: (v) {
                  draft.promoteDays = v!;
                  draft.touch();
                },
                title: const Text('None'),
              ),
              RadioListTile<int>(
                value: 14,
                groupValue: draft.promoteDays,
                onChanged: (v) {
                  draft.promoteDays = v!;
                  draft.touch();
                  TGAnalytics.track('resto_promote_selected', {'days': 14});
                },
                title: Text('+${cfg.promote.pln14} PLN · 14 days'),
              ),
              RadioListTile<int>(
                value: 30,
                groupValue: draft.promoteDays,
                onChanged: (v) {
                  draft.promoteDays = v!;
                  draft.touch();
                  TGAnalytics.track('resto_promote_selected', {'days': 30});
                },
                title: Text('+${cfg.promote.pln30} PLN · 30 days'),
              ),
              Text('Total (brutto, VAT 23% included): ${draft.totalPln},00 PLN', style: const TextStyle(fontWeight: FontWeight.w900)),
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
          TextField(
            enabled: enabled,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
            keyboardType: keyboard,
            controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
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
