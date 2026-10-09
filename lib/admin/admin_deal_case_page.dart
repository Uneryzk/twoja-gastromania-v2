import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/admin/admin_deal_modals.dart';
import 'package:twoja_gastromania/admin/admin_deal_queue_page.dart';
import 'package:twoja_gastromania/admin/admin_modals.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_deal_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_purchase_review.dart';
import 'package:twoja_gastromania/tg_services/deal_moderation_service.dart';

class AdminDealCasePage extends StatefulWidget {
  const AdminDealCasePage({super.key, required this.dealNo});
  final String dealNo;

  @override
  State<AdminDealCasePage> createState() => _AdminDealCasePageState();
}

class _AdminDealCasePageState extends State<AdminDealCasePage> {
  @override
  void initState() {
    super.initState();
    DealModerationService.instance.ensureSeeded();
    DealModerationService.instance.openTracked(widget.dealNo);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<DealModerationService>();
    final kase = DealModerationService.instance.byDealNo(widget.dealNo);
    if (kase == null) {
      return Center(child: Text(context.t('ui_admin_forbidden')));
    }
    final w = MediaQuery.sizeOf(context).width;
    final phone = w < TGBreakpoints.phone;
    final twoCol = w >= 1280;
    final left = _LeftColumn(kase: kase);
    final right = _RightColumn(kase: kase, showActions: !phone);

    final body = twoCol
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              SizedBox(width: 411, child: right),
            ],
          )
        : Column(children: [left, const SizedBox(height: 16), right]);

    return Column(
      children: [
        Expanded(
          child: twoCol
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 14, 8, 16), child: left)),
                    SizedBox(width: 411, child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(8, 14, 16, 16), child: right)),
                  ],
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: body)),
                    const SliverToBoxAdapter(child: AdminPrinciplesFooter()),
                  ],
                ),
        ),
        if (phone) AdminDealActionBar(kase: kase, dense: true),
      ],
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.kase});
  final TGAdminDealCase kase;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(kase: kase),
        const SizedBox(height: 12),
        _Timeline(kase: kase),
        const SizedBox(height: 12),
        _Signals(kase: kase),
        const SizedBox(height: 12),
        _EvidenceViewer(kase: kase),
        const SizedBox(height: 12),
        _Scorecard(kase: kase),
        const SizedBox(height: 12),
        _Sides(kase: kase),
        const SizedBox(height: 12),
        _Threads(kase: kase),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.kase});
  final TGAdminDealCase kase;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(kase.dealNo, style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
              Text(adminDealQueueLabel(context, kase.queue), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              AnimatedSwitcher(
                duration: tgAnim(context, const Duration(milliseconds: 200)),
                child: Text(kase.statusLabel, key: ValueKey(kase.statusLabel), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: dealSlaChips(context, kase)),
        ],
      ),
    );
  }
}

class _Timeline extends StatefulWidget {
  const _Timeline({required this.kase});
  final TGAdminDealCase kase;
  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (tgReduceMotion(context)) {
        setState(() => _shown = widget.kase.timeline.length);
        return;
      }
      _reveal();
    });
  }

  Future<void> _reveal() async {
    for (var i = 0; i < widget.kase.timeline.length; i++) {
      await Future<void>.delayed(tgAnim(context, const Duration(milliseconds: 40)));
      if (!mounted) return;
      setState(() => _shown = i + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM · HH:mm');
    final events = widget.kase.timeline;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('ui_timeline'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 8),
          for (var i = 0; i < events.length; i++)
            AnimatedOpacity(
              duration: tgAnim(context, const Duration(milliseconds: 200)),
              opacity: i < _shown ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 88, child: Text(fmt.format(events[i].at), style: const TextStyle(fontSize: 11, color: TGColors.textSecondary))),
                    Expanded(child: Text('${events[i].actor} · ${events[i].label}', style: const TextStyle(fontSize: 12, height: 1.35))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Signals extends StatelessWidget {
  const _Signals({required this.kase});
  final TGAdminDealCase kase;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('ui_platform_signals'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 8),
          for (final s in kase.signals)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(s.present ? '✓' : '—', style: TextStyle(fontWeight: FontWeight.w900, color: s.present ? TGColors.cta : TGColors.textSecondary)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.text, style: const TextStyle(fontSize: 12, height: 1.35))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EvidenceViewer extends StatelessWidget {
  const _EvidenceViewer({required this.kase});
  final TGAdminDealCase kase;

  @override
  Widget build(BuildContext context) {
    final videos = kase.evidence.where((e) => e.type == TGEvidenceType.liveVideo);
    final traces = kase.evidence.where((e) => e.type == TGEvidenceType.paymentTrace);
    final docs = kase.evidence.where((e) => e.type == TGEvidenceType.document);
    final photos = kase.evidence.where((e) => e.type == TGEvidenceType.photo);
    final svc = DealModerationService.instance;
    final fmt = DateFormat('d MMM');
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kase.lastViewed != null) Text(kase.lastViewed!, style: const TextStyle(fontSize: 11, color: TGColors.textSecondary)),
          if (kase.evidenceDeleteAt != null) Text(context.t('ui_deleted_on', {'d': fmt.format(kase.evidenceDeleteAt!)}), style: const TextStyle(fontSize: 11, color: TGColors.error)),
          if (videos.isNotEmpty) ...[
            Text(context.t('ui_expected_code', {'code': kase.captureCode ?? videos.first.captureCode ?? '4827'}), style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            InkWell(
              key: const Key('admin-deal-video'),
              onTap: () => svc.logView(kase, actorName: 'Anna M.', kind: 'video'),
              child: Container(
                height: 180,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: TGColors.surfaceHover, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.play_circle_outline, size: 48, color: TGColors.cta),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: Text(context.t('ui_code_matches')), selected: kase.codeMatch == TGCodeMatch.matches, onSelected: (_) => svc.setCodeMatch(kase, TGCodeMatch.matches)),
                ChoiceChip(label: Text(context.t('ui_code_doesnt_match')), selected: kase.codeMatch == TGCodeMatch.doesNotMatch, onSelected: (_) => svc.setCodeMatch(kase, TGCodeMatch.doesNotMatch)),
                ChoiceChip(label: Text(context.t('ui_code_cant_tell')), selected: kase.codeMatch == TGCodeMatch.cantTell, onSelected: (_) => svc.setCodeMatch(kase, TGCodeMatch.cantTell)),
              ],
            ),
            const SizedBox(height: 8),
            TGLinkButton(
              label: context.t('ui_compare_nameplate'),
              onTap: () {
                svc.logView(kase, actorName: 'Anna M.', kind: 'compare');
                showPhotoCompare(
                  context,
                  TGPhotoMatch(listingNoA: kase.listingNo, listingNoB: kase.dealNo, similarityPercent: 86, imageA: kase.imageUrl, imageB: kase.imageUrl),
                  null,
                  null,
                );
              },
            ),
          ],
          for (final t in traces)
            ListTile(
              dense: true,
              leading: const Icon(Icons.receipt_long_outlined, size: 18),
              title: const Text('Payment trace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onTap: () {
                svc.logView(kase, actorName: 'Anna M.', kind: 'payment');
                showAdminDialog<void>(
                  context: context,
                  builder: (ctx) => AdminDialogScaffold(title: ctx.t('ui_score_payment'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('ui_close')))], child: Container(height: 240, color: TGColors.surfaceHover, alignment: Alignment.center, child: Text(t.fileUrl))),
                );
              },
            ),
          for (final _ in docs)
            ListTile(
              dense: true,
              leading: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              title: const Text('Document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onTap: () {
                svc.logView(kase, actorName: 'Anna M.', kind: 'document');
                showAdminDialog<void>(
                  context: context,
                  builder: (ctx) => AdminDialogScaffold(
                    title: ctx.t('ui_score_documents'),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('ui_close')))],
                    child: Image.asset(kase.imageUrl, height: 240, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 240, child: ColoredBox(color: TGColors.surfaceHover))),
                  ),
                );
              },
            ),
          if (photos.isNotEmpty) ...[
            Text(context.t('ui_supporting_only'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: TGColors.textSecondary)),
            const SizedBox(height: 6),
            SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in photos)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => svc.logView(kase, actorName: 'Anna M.', kind: 'photo'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(p.fileUrl, width: 120, height: 88, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 120, height: 88, child: ColoredBox(color: TGColors.surfaceHover))),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (kase.evidence.isEmpty) Text(context.t('ui_no_evidence'), style: const TextStyle(color: TGColors.textSecondary)),
        ],
      ),
    );
  }
}

class TGLinkButton extends StatelessWidget {
  const TGLinkButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('admin-deal-compare'),
      onTap: onTap,
      child: Text(label, style: const TextStyle(color: TGColors.cta, fontWeight: FontWeight.w800, decoration: TextDecoration.underline, fontSize: 12)),
    );
  }
}

class _Scorecard extends StatelessWidget {
  const _Scorecard({required this.kase});
  final TGAdminDealCase kase;

  @override
  Widget build(BuildContext context) {
    String label(TGScoreRow r) => switch (r) {
          TGScoreRow.platformSignals => context.t('ui_score_platform'),
          TGScoreRow.liveVideo => context.t('ui_score_live_video'),
          TGScoreRow.paymentTrace => context.t('ui_score_payment'),
          TGScoreRow.documents => context.t('ui_score_documents'),
          TGScoreRow.sellerCrossCheck => context.t('ui_score_crosscheck'),
          TGScoreRow.photos => context.t('ui_score_photos'),
        };
    String mark(TGScoreMark m) => switch (m) {
          TGScoreMark.strong => context.t('ui_score_strong'),
          TGScoreMark.weak => context.t('ui_score_weak'),
          TGScoreMark.missing => context.t('ui_score_missing'),
          TGScoreMark.contradicts => context.t('ui_score_contradicts'),
        };
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('ui_evidence_scorecard'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 8),
          for (final line in kase.scorecard)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label(line.row), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final m in TGScoreMark.values)
                        ChoiceChip(
                          label: Text(mark(m), style: const TextStyle(fontSize: 11)),
                          selected: line.mark == m,
                          onSelected: (_) => DealModerationService.instance.setScore(kase, line.row, m),
                        ),
                    ],
                  ),
                  TextField(
                    decoration: InputDecoration(isDense: true, hintText: context.t('ui_internal_rationale')),
                    onChanged: (v) => DealModerationService.instance.setScore(kase, line.row, line.mark, note: v),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Sides extends StatelessWidget {
  const _Sides({required this.kase});
  final TGAdminDealCase kase;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('ui_seller_response'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 6),
                Text(kase.sellerReason ?? '—', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                Text(kase.sellerNote ?? '', style: const TextStyle(fontSize: 12, height: 1.35)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('ui_buyer_explanation'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                const SizedBox(height: 6),
                Text(kase.buyerNote ?? kase.reviewPreview, style: const TextStyle(fontSize: 12, height: 1.35)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Threads extends StatefulWidget {
  const _Threads({required this.kase});
  final TGAdminDealCase kase;
  @override
  State<_Threads> createState() => _ThreadsState();
}

class _ThreadsState extends State<_Threads> {
  var _lang = 'en';
  var _seller = false;
  final _text = TextEditingController();
  var _privateOpen = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kase = widget.kase;
    final auth = context.watch<FakeAuthState>();
    final thread = _seller ? kase.sellerThread : kase.buyerThread;
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: Text(context.t('ui_buyer_thread')), selected: !_seller, onSelected: (_) => setState(() => _seller = false)),
              ChoiceChip(label: Text(context.t('ui_seller_thread')), selected: _seller, onSelected: (_) => setState(() => _seller = true)),
            ],
          ),
          const SizedBox(height: 8),
          for (final m in thread)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${m.from}: ${m.body}', style: const TextStyle(fontSize: 12)),
            ),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(label: Text(_lang == 'pl' ? 'Szablon PL' : 'EN template'), onPressed: () => _text.text = _lang == 'pl' ? 'Dzień dobry, piszemy w sprawie ${kase.dealNo}.' : 'Hello, we are writing about ${kase.dealNo}.'),
              ChoiceChip(label: const Text('EN'), selected: _lang == 'en', onSelected: (_) => setState(() => _lang = 'en')),
              ChoiceChip(label: const Text('PL'), selected: _lang == 'pl', onSelected: (_) => setState(() => _lang = 'pl')),
            ],
          ),
          TextField(controller: _text, maxLines: 3, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: context.t('ui_message'))),
          const SizedBox(height: 8),
          EmailPreviewBlock(
            email: DealModerationService.instance.preview(
              templateId: _seller ? 'deal_contact_seller' : 'deal_contact_buyer',
              lang: _lang,
              to: '${_seller ? kase.seller.name : kase.buyer.name} <party@mail.com>',
              subject: 'Message about ${kase.dealNo}',
              body: _text.text.isEmpty ? (_lang == 'pl' ? 'Dzień dobry, piszemy w sprawie ${kase.dealNo}.' : 'Hello, we are writing about ${kase.dealNo}.') : _text.text,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () {
                  DealModerationService.instance.postThread(kase, seller: _seller, body: _text.text, actorId: auth.userId, actorRole: auth.role.name);
                  _text.clear();
                },
                child: Text(context.t('ui_send')),
              ),
              TextButton(onPressed: () => showDealPrivate(context, kase).then((_) => setState(() => _privateOpen = true)), child: Text(context.t('ui_open_private'))),
            ],
          ),
          if (_privateOpen) ...[
            const SizedBox(height: 8),
            Text(context.t('ui_private_readonly'), style: const TextStyle(fontSize: 12, color: TGColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn({required this.kase, this.showActions = true});
  final TGAdminDealCase kase;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Party(card: kase.seller, seller: true),
        const SizedBox(height: 12),
        _Party(card: kase.buyer, seller: false),
        const SizedBox(height: 12),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('ui_listing_snapshot'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(kase.imageUrl, height: 120, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 120, child: ColoredBox(color: TGColors.surfaceHover))),
              ),
              const SizedBox(height: 8),
              Text(kase.listingTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              Text('No. ${kase.listingNo}', style: const TextStyle(fontSize: 12, color: TGColors.textSecondary)),
              if (kase.snapshotStatus != null) Text(kase.snapshotStatus!, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('ui_risk_flags'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 8),
              for (final f in kase.flags)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tgDealRiskIsHold(f) ? TGColors.slaAmber.withValues(alpha: 0.16) : TGColors.surfaceHover,
                          borderRadius: BorderRadius.circular(TGRadius.pill),
                          border: Border.all(color: tgDealRiskIsHold(f) ? TGColors.slaAmber : TGColors.border),
                        ),
                        child: Text(tgDealRiskIsHold(f) ? context.t('ui_hold_flag') : context.t('ui_context_flag'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 4),
                      Text(context.t('ui_flag_${f.name}'), style: const TextStyle(fontSize: 12, height: 1.35)),
                    ],
                  ),
                ),
              if (kase.flags.isEmpty) const Text('—', style: TextStyle(color: TGColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('ui_linked_review'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: tgAnim(context, const Duration(milliseconds: 200)),
                child: Container(
                  key: ValueKey(kase.reviewState),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: TGColors.surfaceHover,
                    borderRadius: BorderRadius.circular(TGRadius.pill),
                    border: Border.all(color: TGColors.border),
                  ),
                  child: Text(_reviewStateLabel(context, kase.reviewState), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ),
              Text(kase.reviewPreview, style: const TextStyle(fontSize: 12, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('ui_past_deals'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 6),
              for (final p in kase.pastDeals) Text(p, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        if (showActions) ...[
          const SizedBox(height: 12),
          AdminDealActionBar(kase: kase),
        ],
      ],
    );
  }
}

String _reviewStateLabel(BuildContext context, TGPurchaseReviewState state) => switch (state) {
      TGPurchaseReviewState.awaitingSeller => context.t('ui_deal_chip_waiting_seller'),
      TGPurchaseReviewState.confirmed => context.t('ui_deal_chip_confirmed'),
      TGPurchaseReviewState.confirmedModerator => context.t('ui_deal_chip_moderator'),
      TGPurchaseReviewState.notDisputed => context.t('ui_deal_chip_not_disputed'),
      TGPurchaseReviewState.notVerified => context.t('ui_deal_chip_not_verified'),
      TGPurchaseReviewState.suspendedObjection => context.t('ui_deal_chip_moderation'),
      TGPurchaseReviewState.pendingCheck => context.t('ui_queue_flagged'),
      TGPurchaseReviewState.removed => context.t('ui_status_removed'),
    };

class _Party extends StatelessWidget {
  const _Party({required this.card, required this.seller});
  final TGDealPartyCard card;
  final bool seller;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(seller ? context.t('ui_seller') : context.t('ui_buyer'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 4),
          Text(card.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(context.t('ui_account_age', {'n': '${card.accountAgeDays}'}), style: const TextStyle(fontSize: 12)),
          Text(card.phoneVerified ? context.t('ui_phone_verified') : context.t('ui_phone_unverified'), style: const TextStyle(fontSize: 12)),
          Text(context.t('ui_total_deals', {'n': '${card.totalDeals}'}), style: const TextStyle(fontSize: 12)),
          Text(context.t('ui_confirm_decline', {'c': '${card.confirmed}', 'd': '${card.declined}'}), style: const TextStyle(fontSize: 12)),
          if (seller && card.unjustObjections90d != null)
            Text(context.t('ui_unjust_disputes', {'n': '${card.unjustObjections90d}'}), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
