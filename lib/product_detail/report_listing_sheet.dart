import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_product.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_models/tg_review.dart';
import 'package:twoja_gastromania/tg_models/tg_store_profile.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';

const _kListingReasons = <TGReportReason>[
  TGReportReason.duplicate,
  TGReportReason.copied,
  TGReportReason.sold,
  TGReportReason.misleading,
  TGReportReason.fraud,
  TGReportReason.wrongCategory,
  TGReportReason.prohibited,
  TGReportReason.offensive,
  TGReportReason.other,
];

const _kSellerReasons = <TGReportReason>[
  TGReportReason.fakeStore,
  TGReportReason.fraud,
  TGReportReason.fakeReviews,
  TGReportReason.harassment,
  TGReportReason.prohibited,
  TGReportReason.other,
];

const _kReviewReasons = <TGReportReason>[
  TGReportReason.fakeReview,
  TGReportReason.sellerOrCompetitor,
  TGReportReason.offensive,
  TGReportReason.personalData,
  TGReportReason.other,
];

class TGReportSubject {
  const TGReportSubject.listing(this.product)
      : kind = TGReportTarget.listing,
        seller = null,
        review = null,
        purchaseReview = null;
  const TGReportSubject.seller(this.seller)
      : kind = TGReportTarget.seller,
        product = null,
        review = null,
        purchaseReview = null;
  const TGReportSubject.review(this.review, this.seller)
      : kind = TGReportTarget.review,
        product = null,
        purchaseReview = null;
  const TGReportSubject.purchaseReview(this.purchaseReview, this.seller)
      : kind = TGReportTarget.review,
        product = null,
        review = null;

  final TGReportTarget kind;
  final TGProduct? product;
  final TGStoreProfile? seller;
  final TGStoreReview? review;
  final TGPurchaseReview? purchaseReview;

  String get targetId => switch (kind) {
        TGReportTarget.listing => product?.listingNo ?? product?.id ?? '',
        TGReportTarget.seller => seller?.sellerKey ?? '',
        TGReportTarget.review => purchaseReview?.id ?? review?.id ?? '',
      };

  List<TGReportReason> get reasons => switch (kind) {
        TGReportTarget.listing => _kListingReasons,
        TGReportTarget.seller => _kSellerReasons,
        TGReportTarget.review => _kReviewReasons,
      };
}

const _kEvidencePool = <({String path, int bytes, bool video})>[
  (path: 'assets/images/image.png', bytes: 420000, video: false),
  (path: 'assets/images/images.jpeg', bytes: 380000, video: false),
  (path: 'assets/images/bartscher_2002170.webp', bytes: 900000, video: false),
  (path: 'mock/clip.mp4', bytes: 1400000, video: true),
];

const _kOversized = (path: 'mock/too-big.jpg', bytes: 6000000, video: false);

Future<void> showReportListingFlow(BuildContext context, TGProduct product) =>
    showReportFlow(context, TGReportSubject.listing(product));

Future<void> showReportFlow(BuildContext context, TGReportSubject subject) {
  if (subject.kind == TGReportTarget.listing && subject.product != null) {
    TGAnalytics.track('report_open', TGAnalytics.listingProps(subject.product!));
    TGAnalytics.track('report_listing', TGAnalytics.listingProps(subject.product!));
  } else if (subject.kind == TGReportTarget.seller) {
    TGAnalytics.track('seller_report_open', {'sellerId': subject.seller?.sellerKey, 'id': subject.seller?.publicId});
  } else {
    TGAnalytics.track('review_report', {'reviewId': subject.targetId, 'sellerId': subject.seller?.sellerKey});
  }
  final wide = MediaQuery.sizeOf(context).width >= TGBreakpoints.phone;
  if (wide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.t('ui_close'),
      barrierColor: Colors.black54,
      transitionDuration: tgAnim(context, const Duration(milliseconds: 200)),
      pageBuilder: (ctx, _, __) => ReportListingFlow(subject: subject, desktop: true),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    sheetAnimationStyle: AnimationStyle(duration: tgAnim(context, const Duration(milliseconds: 250))),
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.9,
      child: ReportListingFlow(subject: subject, desktop: false),
    ),
  );
}

class ReportListingFlow extends StatefulWidget {
  const ReportListingFlow({super.key, required this.subject, required this.desktop});

  final TGReportSubject subject;
  final bool desktop;

  @override
  State<ReportListingFlow> createState() => _ReportListingFlowState();
}

class _ReportListingFlowState extends State<ReportListingFlow> {
  int _step = 0;
  int _dir = 1;
  TGReportReason? _reason;
  final _details = TextEditingController();
  final _otherRef = TextEditingController();
  final _originalRef = TextEditingController();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _otp = TextEditingController();
  bool _owner = false;
  bool _confirm = false;
  bool _emailVerified = false;
  bool _submitting = false;
  TGMisleadingPart? _part;
  final Set<TGFraudSignal> _fraud = {};
  final List<String> _evidence = [];
  TGModerationReport? _submitted;
  TGModerationReport? _duplicate;
  bool _rateLimited = false;
  bool _copied = false;
  bool _tick = false;
  String? _liveError;
  bool _emailReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_emailReady) return;
    _emailReady = true;
    final auth = context.read<FakeAuthState>();
    if (auth.isLoggedIn) {
      _email.text = auth.mockEmail;
      _emailVerified = true;
    }
  }

  @override
  void dispose() {
    _details.dispose();
    _otherRef.dispose();
    _originalRef.dispose();
    _email.dispose();
    _name.dispose();
    _otp.dispose();
    super.dispose();
  }

  bool get _detailsOk {
    final t = _details.text.trim();
    if (!_isListing || _reason == TGReportReason.other) return t.length >= 20 && t.length <= 1000;
    if (t.isEmpty) return true;
    return t.length >= 20 && t.length <= 1000;
  }

  bool get _isListing => widget.subject.kind == TGReportTarget.listing;

  bool get _step2Ok {
    if (_reason == null || !_detailsOk || !_confirm) return false;
    if (_isListing && _reason == TGReportReason.copied) {
      if (_originalRef.text.trim().isEmpty || !_owner || _evidence.isEmpty) return false;
    }
    if (_isListing && _reason == TGReportReason.misleading && _part == null) return false;
    if (_isListing && _reason == TGReportReason.fraud && _fraud.isEmpty) return false;
    final auth = context.read<FakeAuthState>();
    if (!auth.isLoggedIn) {
      if (!_email.text.contains('@') || !_emailVerified) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _tick = false;
      _liveError = null;
    });
    if (!tgInWidgetTest()) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _tick = true);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    final auth = context.read<FakeAuthState>();
    final subject = widget.subject;
    final result = ModerationService.instance.submitReport(
      target: subject.kind,
      targetId: subject.targetId,
      reason: _reason!,
      email: _email.text.trim(),
      reporterId: auth.isLoggedIn ? auth.userId : 'guest',
      name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      text: _details.text.trim(),
      sellerId: subject.seller?.sellerKey ?? subject.product?.seller.id,
      reviewId: subject.kind == TGReportTarget.review ? subject.targetId : null,
      otherListingRef: _otherRef.text.trim().isEmpty ? null : _otherRef.text.trim(),
      originalListingRef: _originalRef.text.trim().isEmpty ? null : _originalRef.text.trim(),
      isOriginalOwner: _owner,
      misleadingPart: _part,
      fraudSignals: _fraud.toList(),
      evidenceUrls: List.of(_evidence),
      product: subject.product,
    );
    setState(() {
      _submitting = false;
      _tick = false;
      if (result.duplicateOf != null) {
        _duplicate = result.duplicateOf;
        _liveError = context.t('ui_already_reported', {
          'd': DateFormat('d MMMM', Localizations.localeOf(context).languageCode).format(result.duplicateOf!.createdAt),
          'n': result.duplicateOf!.reportNo,
        });
      } else if (result.rateLimited) {
        _rateLimited = true;
        _liveError = context.t('ui_report_rate_limit');
      } else {
        _submitted = result.report;
        _step = 2;
      }
    });
  }

  void _go(int next) {
    setState(() {
      _dir = next >= _step ? 1 : -1;
      _step = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final blocked = _duplicate != null || _rateLimited;
    final body = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.maybePop(context),
      },
      child: FocusScope(
        autofocus: true,
        child: FocusTraversalGroup(
        child: Material(
          color: TGColors.surface,
          borderRadius: widget.desktop ? BorderRadius.circular(TGRadius.modal) : const BorderRadius.vertical(top: Radius.circular(TGRadius.modal)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.desktop ? 560 : double.infinity,
              maxHeight: MediaQuery.sizeOf(context).height * (widget.desktop ? 0.86 : 1),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _submitted != null
                              ? context.t('ui_report_thanks')
                              : switch (widget.subject.kind) {
                                  TGReportTarget.listing => context.t('ui_report_listing'),
                                  TGReportTarget.seller => context.t('ui_report_seller'),
                                  TGReportTarget.review => context.t('ui_report_review'),
                                },
                          style: theme.titleMedium.override(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, size: 18)),
                    ],
                  ),
                  if (_submitted == null && !blocked) ...[
                    Text(
                      context.t('ui_step_n_of_m', {'n': _step == 0 ? '1' : '2', 'm': '2'}),
                      key: const Key('report-step-label'),
                      style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    _TargetSummary(subject: widget.subject),
                  ],
                  const SizedBox(height: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: tgAnim(context, const Duration(milliseconds: 200)),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) {
                        final offset = Tween<Offset>(begin: Offset(_dir * 0.08, 0), end: Offset.zero).animate(anim);
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(position: offset, child: child),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_submitted != null ? 'ok' : blocked ? 'block' : 'step-$_step'),
                        child: _submitted != null
                            ? _Success(report: _submitted!, copied: _copied, onCopy: _copyNo)
                            : blocked
                                ? _Blocked(message: _liveError ?? '', reportNo: _duplicate?.reportNo)
                                : (_step == 0
                                    ? _StepReasons(
                                        reasons: widget.subject.reasons,
                                        selected: _reason,
                                        target: widget.subject.kind,
                                        onSelect: (r) {
                                          TGAnalytics.track('report_reason_selected', {'reason': r.name, 'target': widget.subject.kind.name});
                                          setState(() => _reason = r);
                                        },
                                      )
                                    : _stepDetails(theme)),
                      ),
                    ),
                  ),
                  if (_liveError != null && !blocked)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_liveError!, style: const TextStyle(color: TGColors.error, fontSize: 12)),
                      ),
                    ),
                  if (_submitted == null && !blocked) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_step == 1) TextButton(onPressed: () => _go(0), child: Text(context.t('ui_back'))),
                        const Spacer(),
                        TGButton(
                          key: Key(_step == 0 ? 'report-next' : 'report-submit'),
                          onPressed: _submitting
                              ? null
                              : _step == 0
                                  ? (_reason == null ? null : () => _go(1))
                                  : (_step2Ok ? _submit : null),
                          label: _submitting
                              ? '…'
                              : (_step == 0 ? context.t('ui_continue') : context.t('ui_submit_report')),
                          height: 44,
                        ),
                      ],
                    ),
                  ] else if (_submitted != null)
                    TGButton(onPressed: () => Navigator.pop(context), label: context.t('ui_done'), height: 44),
                  if (_submitting || _tick)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Center(
                        child: _tick
                            ? TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.6, end: 1),
                                duration: tgAnim(context, const Duration(milliseconds: 150)),
                                curve: Curves.easeOutBack,
                                builder: (context, v, child) => Transform.scale(scale: v, child: child),
                                child: const Icon(Icons.check_circle, color: TGColors.cta, size: 28),
                              )
                            : const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: TGColors.cta)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
    if (widget.desktop) return Center(child: body);
    return body;
  }

  Future<void> _copyNo() async {
    await Clipboard.setData(ClipboardData(text: _submitted!.reportNo));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _copied = false);
  }

  void _addEvidence({bool oversized = false, bool video = false}) {
    if (_evidence.length >= 3) return;
    if (oversized) {
      if (_kOversized.bytes > 5 * 1024 * 1024) {
        setState(() => _liveError = context.t('ui_file_too_large'));
      }
      return;
    }
    final pool = _kEvidencePool.where((e) => video ? e.video : !e.video).toList();
    if (pool.isEmpty) return;
    final pick = pool[_evidence.length % pool.length];
    if (pick.bytes > 5 * 1024 * 1024) {
      setState(() => _liveError = context.t('ui_file_too_large'));
      return;
    }
    setState(() {
      _liveError = null;
      _evidence.add(pick.path);
    });
  }

  Widget _stepDetails(FlutterFlowTheme theme) {
    final auth = context.watch<FakeAuthState>();
    final count = _details.text.trim().length;
    return ListView(
      key: const Key('report-step-2'),
      children: [
        Text(context.t('ui_details'), style: theme.titleSmall.override(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          key: const Key('report-details'),
          controller: _details,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: context.t('ui_report_details_hint'),
            counterText: '$count / 1000',
            errorText: (!_isListing || _reason == TGReportReason.other) && count > 0 && count < 20 ? context.t('ui_report_details_hint') : null,
          ),
        ),
        AnimatedSize(
          duration: tgAnim(context, const Duration(milliseconds: 200)),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isListing && _reason == TGReportReason.duplicate) ...[
                const SizedBox(height: 10),
                TextField(controller: _otherRef, decoration: InputDecoration(labelText: context.t('ui_other_listing_ref'))),
              ],
              if (_isListing && _reason == TGReportReason.copied) ...[
                const SizedBox(height: 10),
                TextField(key: const Key('report-original'), controller: _originalRef, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: context.t('ui_original_listing_ref'))),
                CheckboxListTile(
                  key: const Key('report-original-owner'),
                  value: _owner,
                  onChanged: (v) => setState(() => _owner = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('ui_original_owner')),
                ),
              ],
              if (_isListing && _reason == TGReportReason.misleading) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<TGMisleadingPart>(
                  key: const Key('report-misleading-part'),
                  initialValue: _part,
                  hint: Text(context.t('ui_which_section_wrong')),
                  items: [
                    DropdownMenuItem(value: TGMisleadingPart.price, child: Text(context.t('ui_price'))),
                    DropdownMenuItem(value: TGMisleadingPart.condition, child: Text(context.t('ui_condition'))),
                    DropdownMenuItem(value: TGMisleadingPart.specs, child: Text(context.t('ui_specs'))),
                    DropdownMenuItem(value: TGMisleadingPart.photos, child: Text(context.t('ui_photos'))),
                  ],
                  onChanged: (v) => setState(() => _part = v),
                ),
              ],
              if (_isListing && _reason == TGReportReason.fraud) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in TGFraudSignal.values)
                      FilterChip(
                        key: Key('report-fraud-${s.name}'),
                        label: Text(context.t('ui_fraud_${s.name}')),
                        selected: _fraud.contains(s),
                        onSelected: (on) => setState(() => on ? _fraud.add(s) : _fraud.remove(s)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(context.t('ui_evidence_max'), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _evidence)
              Chip(label: Text(e.split('/').last), onDeleted: () => setState(() => _evidence.remove(e))),
            if (_evidence.length < 3) ...[
              ActionChip(
                key: const Key('report-add-evidence'),
                label: Text(context.t('ui_add_evidence')),
                onPressed: () => _addEvidence(),
              ),
              ActionChip(
                key: const Key('report-add-video'),
                label: Text(context.t('ui_add_video')),
                onPressed: () => _addEvidence(video: true),
              ),
              ActionChip(
                key: const Key('report-add-oversized'),
                label: const Text('5 MB+'),
                onPressed: () => _addEvidence(oversized: true),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (!auth.isLoggedIn) ...[
          TextField(key: const Key('report-email'), controller: _email, onChanged: (_) => setState(() => _emailVerified = false), decoration: InputDecoration(labelText: context.t('ui_email'))),
          const SizedBox(height: 8),
          TextField(controller: _name, decoration: InputDecoration(labelText: context.t('ui_name_optional'))),
          const SizedBox(height: 8),
          if (!_emailVerified) ...[
            Text(context.t('ui_verify_email'), style: theme.bodySmall.override(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TGButton(
                  key: const Key('report-magic-link'),
                  onPressed: !_email.text.contains('@')
                      ? null
                      : () => setState(() => _emailVerified = true),
                  label: context.t('ui_send_magic_link'),
                  height: 40,
                  variant: TGButtonVariant.outline,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('report-otp'),
              controller: _otp,
              decoration: InputDecoration(labelText: context.t('ui_otp_code')),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('report-otp-verify'),
                onPressed: () {
                  if (_otp.text.trim() == '123456') {
                    setState(() {
                      _emailVerified = true;
                      _liveError = null;
                    });
                  } else {
                    setState(() => _liveError = context.t('ui_otp_wrong'));
                  }
                },
                child: Text(context.t('ui_verify')),
              ),
            ),
          ] else
            Text(context.t('ui_email_verified'), style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w700)),
        ] else
          Text(context.t('ui_well_email', {'email': _email.text}), style: const TextStyle(color: TGColors.textSecondary, fontSize: 12)),
        CheckboxListTile(
          key: const Key('report-confirm'),
          value: _confirm,
          onChanged: (v) => setState(() => _confirm = v ?? false),
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('ui_report_confirm')),
        ),
        Text(context.t('ui_seller_wont_see'), style: const TextStyle(color: TGColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _TargetSummary extends StatelessWidget {
  const _TargetSummary({required this.subject});
  final TGReportSubject subject;

  @override
  Widget build(BuildContext context) {
    if (subject.kind == TGReportTarget.listing && subject.product != null) {
      final product = subject.product!;
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 42,
              child: product.imageUrl.isEmpty
                  ? const ColoredBox(color: TGColors.border)
                  : Image.asset(product.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: TGColors.border)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(product.price == null ? context.t('ui_price_on_request') : '${product.price} PLN', style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
          if (product.listingNo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: TGColors.border)),
              child: Text(context.t('ui_listing_no', {'n': product.listingNo!}), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
        ],
      );
    }
    if (subject.kind == TGReportTarget.seller && subject.seller != null) {
      return Text(subject.seller!.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13));
    }
    final review = subject.review;
    if (review == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(review.authorName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        Text(review.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TGColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

String _reasonTitle(BuildContext context, TGReportReason reason, TGReportTarget target) {
  if (reason == TGReportReason.other) return context.t('ui_other');
  if (target == TGReportTarget.seller && reason == TGReportReason.fraud) {
    return context.t('ui_rr_seller_fraud');
  }
  if (target == TGReportTarget.seller && reason == TGReportReason.prohibited) {
    return context.t('ui_rr_prohibited_activity');
  }
  return context.t('ui_rr_${reason.name}');
}

class _StepReasons extends StatelessWidget {
  const _StepReasons({required this.reasons, required this.selected, required this.onSelect, required this.target});
  final List<TGReportReason> reasons;
  final TGReportReason? selected;
  final ValueChanged<TGReportReason> onSelect;
  final TGReportTarget target;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: context.t('ui_whats_wrong'),
      child: ListView(
        key: const Key('report-step-1'),
        children: [
          Text(context.t('ui_whats_wrong'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final reason in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                button: true,
                selected: selected == reason,
                inMutuallyExclusiveGroup: true,
                child: InkWell(
                  key: Key('report-reason-${reason.name}'),
                  onTap: () => onSelect(reason),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: tgAnim(context, const Duration(milliseconds: 200)),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TGColors.surfaceHover,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected == reason ? TGColors.cta : TGColors.border, width: selected == reason ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _reasonTitle(context, reason, target),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              Text(
                                context.t('ui_rr_${reason.name}_hint'),
                                style: const TextStyle(color: TGColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (selected == reason)
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.6, end: 1),
                            duration: tgAnim(context, const Duration(milliseconds: 150)),
                            curve: Curves.easeOutBack,
                            builder: (context, v, child) => Transform.scale(scale: v, child: child),
                            child: const Icon(Icons.check_circle, color: TGColors.cta, size: 20),
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
}

class _Success extends StatelessWidget {
  const _Success({required this.report, required this.copied, required this.onCopy});
  final TGModerationReport report;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        key: const Key('report-success'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: TGColors.cta, size: 40),
          const SizedBox(height: 12),
          Text(context.t('ui_report_thanks'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          InkWell(
            key: const Key('report-no-copy'),
            onTap: onCopy,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(report.reportNo, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                const SizedBox(width: 8),
                Icon(copied ? Icons.check : Icons.copy, size: 16, color: TGColors.cta),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(context.t('ui_report_email_followup'), textAlign: TextAlign.center, style: const TextStyle(color: TGColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Blocked extends StatelessWidget {
  const _Blocked({required this.message, this.reportNo});
  final String message;
  final String? reportNo;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        key: const Key('report-blocked'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, color: TGColors.cta, size: 36),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
          if (reportNo != null) ...[
            const SizedBox(height: 8),
            Text(reportNo!, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.4)),
          ],
        ],
      ),
    );
  }
}
