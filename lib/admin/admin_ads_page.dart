import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/tg_core/duration_formatter.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_ad_slot.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
import 'package:twoja_gastromania/tg_models/tg_pricing_config.dart';
import 'package:twoja_gastromania/tg_services/ad_slot_service.dart';

class AdminAdsPage extends StatefulWidget {
  const AdminAdsPage({super.key});

  @override
  State<AdminAdsPage> createState() => _AdminAdsPageState();
}

class _AdminAdsPageState extends State<AdminAdsPage> {
  String? _decisionFlash; // id → last decision for chip cross-fade

  @override
  void initState() {
    super.initState();
    AdSlotService.instance.ensureSeeded();
  }

  Future<String?> _reason(String title) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          decoration: InputDecoration(labelText: ctx.t('ui_reason')),
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('ui_cancel'))),
          TGButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), label: ctx.t('ui_confirm'), height: 40),
        ],
      ),
    );
  }

  Future<void> _requestChanges(TGAdSlot slot) async {
    final auth = context.read<FakeAuthState>();
    final reason = await _reason(context.t('ui_admin_ad_request_changes'));
    if (reason == null || reason.isEmpty) return;
    final err = AdSlotService.instance.requestChanges(slot.id, actorId: auth.userId, actorRole: auth.role.name, reason: reason);
    if (!mounted) return;
    setState(() {});
    showTGToast(context, context.t(err ?? 'ui_admin_ad_changes_sent'));
  }

  Future<void> _decide(TGAdSlot slot, {required bool approve}) async {
    final auth = context.read<FakeAuthState>();
    final ads = AdSlotService.instance;
    if (!approve) {
      final reason = await _reason(context.t('ui_admin_reject_refund'));
      if (reason == null || reason.isEmpty) return;
      final preview = TGQueuedEmail(
        id: 'ad_reject_${slot.id}',
        to: '${slot.ownerId}@example.com',
        subject: 'Banner ad not published',
        body: 'Your banner “${slot.title}” was not approved.\n\n'
            '${slot.pricePln > 0 ? 'A full refund of ${slot.pricePln} PLN was issued.' : 'Your Enterprise entitlement was restored.'}\n\n'
            'Reason: $reason',
        templateId: 'ad_rejected',
        createdAt: TGClock.now(),
        listingNo: slot.id,
      );
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('ui_admin_reject_email_preview')),
          content: SingleChildScrollView(child: EmailPreviewBlock(email: preview)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('ui_cancel'))),
            TGButton(onPressed: () => Navigator.pop(ctx, true), label: ctx.t('ui_reject'), height: 40),
          ],
        ),
      );
      if (ok != true) return;
      ads.reject(slot.id, actorId: auth.userId, actorRole: auth.role.name, reason: reason);
      setState(() => _decisionFlash = '${slot.id}:reject');
      if (!mounted) return;
      showTGToast(
        context,
        context.t('ui_admin_rejected_undo'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: context.t('ui_undo'),
          textColor: TGColors.cta,
          onPressed: () {
            ads.undo(slot.id);
            if (mounted) setState(() {});
          },
        ),
      );
    } else {
      ads.approve(slot.id, actorId: auth.userId, actorRole: auth.role.name);
      setState(() => _decisionFlash = '${slot.id}:approve');
      if (!mounted) return;
      showTGToast(
        context,
        context.t('ui_admin_approved_undo'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: context.t('ui_undo'),
          textColor: TGColors.cta,
          onPressed: () {
            ads.undo(slot.id);
            if (mounted) setState(() {});
          },
        ),
      );
    }
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _decisionFlash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final ads = AdSlotService.instance;
    final pending = ads.pendingReview;
    final live = ads.liveSlides;
    final overbooked = ads.overbookedDays();
    final fmt = DateFormat('d MMM yyyy');
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return ListView(
      padding: EdgeInsets.all(phone ? 12 : 20),
      children: [
        Text(context.t('ui_admin_banner_ads_title'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(context.t('ui_admin_banner_ads_sub'), style: theme.bodySmall),
        const SizedBox(height: 18),
        Text(context.t('ui_admin_ad_review'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (pending.isEmpty)
          Text(context.t('ui_admin_no_pending_ads'), style: theme.bodySmall)
        else
          for (final s in pending)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(width: 120, height: 48, child: TGSmartImage(url: s.imageUrl, fit: BoxFit.cover)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                              Text('${s.kind.name} · ${s.targetUrl} · ${s.pricePln} PLN', style: theme.bodySmall),
                              Text(
                                '${fmt.format(s.startsAt)} → ${fmt.format(s.endsAt)} · ${DurationFormatter.daysOf(context, s.durationDays)} · '
                                '${context.t('ui_admin_ad_corrections', {'n': '${ads.pricing.maxCorrections - s.correctionsUsed}'})}',
                                style: theme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: Duration(milliseconds: reduce ? 0 : 200),
                          child: _decisionFlash?.startsWith(s.id) == true
                              ? Chip(
                                  key: ValueKey(_decisionFlash),
                                  label: Text(
                                    _decisionFlash!.endsWith('approve')
                                        ? context.t('ui_admin_approved')
                                        : context.t('ui_admin_rejected'),
                                  ),
                                )
                              : const SizedBox.shrink(key: ValueKey('empty')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        TGButton(
                          onPressed: () => _decide(s, approve: true),
                          label: context.t('ui_approve'),
                          height: 40,
                          borderRadius: BorderRadius.circular(TGRadius.pill),
                        ),
                        if (ads.canRequestChanges(s))
                          TGButton(
                            onPressed: () => _requestChanges(s),
                            label: context.t('ui_admin_ad_request_changes'),
                            variant: TGButtonVariant.outline,
                            height: 40,
                            borderRadius: BorderRadius.circular(TGRadius.pill),
                          ),
                        TGButton(
                          onPressed: () => _decide(s, approve: false),
                          label: context.t('ui_admin_reject_refund'),
                          variant: TGButtonVariant.outline,
                          height: 40,
                          borderRadius: BorderRadius.circular(TGRadius.pill),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            context.t('ui_admin_ad_seat_calendar', {'n': '${ads.maxPerDay}'}),
            style: theme.titleSmall.override(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 8),
        _SeatGrid(rows: ads.seatGrid(days: phone ? 14 : 28)),
        const SizedBox(height: 20),
        Text(context.t('ui_admin_live_slides'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (live.isEmpty)
          Text(context.t('ui_admin_no_live_slides'), style: theme.bodySmall)
        else
          for (final s in live)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(width: 72, height: 40, child: TGSmartImage(url: s.imageUrl, fit: BoxFit.cover)),
              title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                '${fmt.format(s.startsAt)} → ${fmt.format(s.endsAt)} · ${s.impressions} impr. · ${s.clicks} clicks',
              ),
              trailing: TextButton(
                onPressed: () async {
                  final reason = await _reason(context.t('ui_admin_early_termination'));
                  if (reason == null || reason.isEmpty) return;
                  ads.terminateEarly(s.id, actorId: auth.userId, actorRole: auth.role.name, reason: reason);
                  setState(() {});
                  if (!context.mounted) return;
                  showTGToast(
                    context,
                    context.t('ui_admin_ended_undo'),
                    duration: const Duration(seconds: 10),
                    action: SnackBarAction(
                      label: context.t('ui_undo'),
                      textColor: TGColors.cta,
                      onPressed: () {
                        ads.undo(s.id);
                        if (mounted) setState(() {});
                      },
                    ),
                  );
                },
                child: Text(context.t('ui_admin_end_early')),
              ),
            ),
        const SizedBox(height: 20),
        Text(context.t('ui_admin_slot_conflicts'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (overbooked.isEmpty)
          Text(context.t('ui_admin_no_slot_conflicts'), style: theme.bodySmall)
        else
          for (final d in overbooked)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                context.t('ui_admin_ad_overbooked', {'date': fmt.format(d.day), 'n': '${d.taken}', 'cap': '${d.capacity}'}),
                style: theme.bodySmall.override(fontWeight: FontWeight.w700),
              ),
            ),
      ],
    );
  }
}

/// Admin "N seats × day" occupancy grid.
class _SeatGrid extends StatelessWidget {
  const _SeatGrid({required this.rows});
  final List<({DateTime day, List<TGAdSlot?> seats})> rows;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final dayFmt = DateFormat('EEE d MMM', locale);
    final seatCount = rows.isEmpty ? 0 : rows.first.seats.length;
    Color tone(TGAdSlot s) => switch (s.status) {
          TGAdSlotStatus.live => TGColors.cta.withValues(alpha: 0.28),
          TGAdSlotStatus.approved => TGColors.cta.withValues(alpha: 0.14),
          _ => theme.alternate,
        };
    return Material(
      color: TGColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: TGColors.border)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final r in rows)
            Semantics(
              label: context.t('ui_admin_ad_seat_row_sem', {
                'date': dayFmt.format(r.day),
                'n': '${r.seats.where((s) => s != null).length}',
                'cap': '$seatCount',
              }),
              excludeSemantics: true,
              child: Container(
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TGColors.border, width: 0.5))),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 96, child: Text(dayFmt.format(r.day), style: theme.bodySmall.override(fontWeight: FontWeight.w800))),
                    for (final s in r.seats)
                      Expanded(
                        child: Container(
                          height: 24,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: s == null ? Colors.transparent : tone(s),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: TGColors.border),
                          ),
                          child: Text(
                            s?.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodySmall.override(fontSize: 11),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminAdsHost extends StatelessWidget {
  const AdminAdsHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'ads', child: AdminAdsPage());
}
