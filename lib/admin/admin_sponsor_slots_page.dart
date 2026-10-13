import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/state/fake_auth_state.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_review.dart';
import 'package:twoja_gastromania/tg_services/founder_service.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/sponsor_slot_service.dart';

class AdminSponsorSlotsPage extends StatefulWidget {
  const AdminSponsorSlotsPage({super.key});
  @override
  State<AdminSponsorSlotsPage> createState() => _AdminSponsorSlotsPageState();
}

class _AdminSponsorSlotsPageState extends State<AdminSponsorSlotsPage> {
  @override
  void initState() {
    super.initState();
    TGSponsorSlotService.instance.ensureSeeded();
  }

  Future<String?> _note(String title) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          decoration: InputDecoration(labelText: ctx.t('ui_reason')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('ui_cancel'))),
          TGButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), label: ctx.t('ui_confirm'), height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final auth = context.watch<FakeAuthState>();
    final phone = MediaQuery.sizeOf(context).width < TGBreakpoints.phone;
    final svc = TGSponsorSlotService.instance;
    final pending = svc.slots.where((s) => s.status == TGSponsorSlotStatus.contentPending).toList();

    return ListView(
      padding: EdgeInsets.all(phone ? 12 : 20),
      children: [
        Text(context.t('ui_admin_sponsor_title'), style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(context.t('ui_admin_content_queue_sub'), style: theme.bodySmall),
        const SizedBox(height: 16),
        Text(context.t('ui_admin_content_queue'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        if (pending.isEmpty)
          Text(context.t('ui_admin_no_pending_content'), style: theme.bodySmall)
        else
          for (final s in pending)
            ListTile(
              title: Text(s.title ?? s.id, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                '${context.t('ui_so_spec_${s.specialty.name}')} · ${s.region} · '
                '${TGSellerProfileService.instance.bySellerKey(s.sellerId ?? "")?.name ?? s.sellerId}\n'
                '${s.startsAt == null ? '' : TGFounderService.fmtDate(s.startsAt!)}'
                '${s.endsAt == null ? '' : ' – ${TGFounderService.fmtDate(s.endsAt!.subtract(const Duration(days: 1)))}'}'
                '${s.paidAmount == null ? '' : ' · ${s.paidAmount} PLN'}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                children: [
                  TextButton(
                    onPressed: () async {
                      final note = await _note(context.t('ui_admin_approve_content'));
                      if (note == null || note.isEmpty) return;
                      svc.decideContent(slotId: s.id, approve: true, actorId: auth.userId, note: note);
                      setState(() {});
                    },
                    child: Text(context.t('ui_approve')),
                  ),
                  TextButton(
                    onPressed: () async {
                      final note = await _note(context.t('ui_admin_reject_refund'));
                      if (note == null || note.isEmpty) return;
                      svc.decideContent(slotId: s.id, approve: false, actorId: auth.userId, note: note);
                      setState(() {});
                    },
                    child: Text(context.t('ui_reject')),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 20),
        Text(context.t('ui_admin_segments'), style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: phone ? 2 : 4,
          childAspectRatio: 1.4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final seg in svc.segments)
              Builder(builder: (_) {
                final active = svc.activeFor(seg.specialty, seg.region);
                final slot = svc.slotAt(seg.specialty, seg.region);
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(border: Border.all(color: theme.tertiary), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t('ui_so_spec_${seg.specialty.name}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(seg.region, style: theme.bodySmall),
                      const Spacer(),
                      Text(
                        active != null
                            ? context.t('ui_admin_active_until', {'d': TGFounderService.fmtDate(active.endsAt!)})
                            : slot?.status == TGSponsorSlotStatus.reserved && slot?.startsAt != null
                                ? context.t('ui_admin_slot_scheduled', {'d': TGFounderService.fmtDate(slot!.startsAt!)})
                                : (slot?.status.name ?? context.t('ui_admin_available')),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      if (active != null)
                        TextButton(
                          onPressed: () async {
                            final note = await _note(context.t('ui_admin_cancel_with_refund'));
                            if (note == null || note.isEmpty) return;
                            svc.cancel(slotId: active.id, actorId: auth.userId, reason: note, refund: true);
                            setState(() {});
                          },
                          child: Text(context.t('ui_admin_cancel_refund'), style: const TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }
}

class AdminSponsorSlotsHost extends StatelessWidget {
  const AdminSponsorSlotsHost({super.key});
  @override
  Widget build(BuildContext context) => const AdminShell(section: 'sponsor_slots', child: AdminSponsorSlotsPage());
}
