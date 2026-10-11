import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_components/tg_smart_image.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_core/tg_toast.dart';
import 'package:twoja_gastromania/tg_models/tg_ad_slot.dart';
import 'package:twoja_gastromania/tg_models/tg_moderation.dart';
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
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Reason'), autofocus: true, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TGButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), label: 'Confirm', height: 40),
        ],
      ),
    );
  }

  Future<void> _decide(TGAdSlot slot, {required bool approve}) async {
    final auth = context.read<FakeAuthState>();
    final ads = AdSlotService.instance;
    if (!approve) {
      final reason = await _reason('Reject (full refund)');
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
          title: const Text('Reject · email preview'),
          content: SingleChildScrollView(child: EmailPreviewBlock(email: preview)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TGButton(onPressed: () => Navigator.pop(ctx, true), label: 'Reject', height: 40),
          ],
        ),
      );
      if (ok != true) return;
      ads.reject(slot.id, actorId: auth.userId, actorRole: auth.role.name, reason: reason);
      setState(() => _decisionFlash = '${slot.id}:reject');
      if (!mounted) return;
      showTGToast(
        context,
        'Rejected · Undo 10s',
        duration: const Duration(seconds: 10),
        action: SnackBarAction(label: 'Undo', textColor: TGColors.cta, onPressed: () {
          ads.undo(slot.id);
          if (mounted) setState(() {});
        }),
      );
    } else {
      ads.approve(slot.id, actorId: auth.userId, actorRole: auth.role.name);
      setState(() => _decisionFlash = '${slot.id}:approve');
      if (!mounted) return;
      showTGToast(
        context,
        'Approved · Undo 10s',
        duration: const Duration(seconds: 10),
        action: SnackBarAction(label: 'Undo', textColor: TGColors.cta, onPressed: () {
          ads.undo(slot.id);
          if (mounted) setState(() {});
        }),
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
    final conflicts = ads.slotConflicts();
    final fmt = DateFormat('d MMM yyyy');
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return ListView(
      padding: EdgeInsets.all(phone ? 12 : 20),
      children: [
        Text('Banner ads', style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Ad review · live slides · early termination · slot conflicts', style: theme.bodySmall),
        const SizedBox(height: 18),
        Text('Ad review', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (pending.isEmpty)
          Text('No pending ads.', style: theme.bodySmall)
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
                            ],
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: Duration(milliseconds: reduce ? 0 : 200),
                          child: _decisionFlash?.startsWith(s.id) == true
                              ? Chip(
                                  key: ValueKey(_decisionFlash),
                                  label: Text(_decisionFlash!.endsWith('approve') ? 'Approved' : 'Rejected'),
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
                          label: 'Approve',
                          height: 40,
                          borderRadius: BorderRadius.circular(TGRadius.pill),
                        ),
                        TGButton(
                          onPressed: () => _decide(s, approve: false),
                          label: 'Reject',
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
        Text('Live slides', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (live.isEmpty)
          Text('No live slides.', style: theme.bodySmall)
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
                  final reason = await _reason('Early termination');
                  if (reason == null || reason.isEmpty) return;
                  ads.terminateEarly(s.id, actorId: auth.userId, actorRole: auth.role.name, reason: reason);
                  setState(() {});
                  if (!context.mounted) return;
                  showTGToast(
                    context,
                    'Ended · Undo 10s',
                    duration: const Duration(seconds: 10),
                    action: SnackBarAction(label: 'Undo', textColor: TGColors.cta, onPressed: () {
                      ads.undo(s.id);
                      if (mounted) setState(() {});
                    }),
                  );
                },
                child: const Text('End early'),
              ),
            ),
        const SizedBox(height: 20),
        Text('Slot conflicts', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (conflicts.isEmpty)
          Text('No overlapping approved/live windows beyond capacity view.', style: theme.bodySmall)
        else
          for (final c in conflicts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Overlap: “${c.a.title}” ↔ “${c.b.title}” (${fmt.format(c.a.startsAt)}–${fmt.format(c.a.endsAt)})',
                style: theme.bodySmall.override(fontWeight: FontWeight.w700),
              ),
            ),
      ],
    );
  }
}

class AdminAdsHost extends StatelessWidget {
  const AdminAdsHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'ads', child: AdminAdsPage());
}
