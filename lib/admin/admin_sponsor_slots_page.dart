import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:twoja_gastromania/admin/admin_chrome.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
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
        content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Reason'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TGButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), label: 'Confirm', height: 40),
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
        Text('Sponsor slots', style: theme.headlineSmall.override(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Content approval queue · segment grid', style: theme.bodySmall),
        const SizedBox(height: 16),
        Text('Content queue', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
        if (pending.isEmpty)
          Text('No pending content.', style: theme.bodySmall)
        else
          for (final s in pending)
            ListTile(
              title: Text(s.title ?? s.id, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${s.specialty.name} · ${s.region} · ${TGSellerProfileService.instance.bySellerKey(s.sellerId ?? "")?.name ?? s.sellerId}'),
              trailing: Wrap(
                children: [
                  TextButton(
                    onPressed: () async {
                      final note = await _note('Approve content');
                      if (note == null || note.isEmpty) return;
                      svc.decideContent(slotId: s.id, approve: true, actorId: auth.userId, note: note);
                      setState(() {});
                    },
                    child: const Text('Approve'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final note = await _note('Reject (full refund)');
                      if (note == null || note.isEmpty) return;
                      svc.decideContent(slotId: s.id, approve: false, actorId: auth.userId, note: note);
                      setState(() {});
                    },
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 20),
        Text('Segments', style: theme.titleSmall.override(fontWeight: FontWeight.w900)),
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
                      Text(seg.specialty.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(seg.region, style: theme.bodySmall),
                      const Spacer(),
                      Text(
                        active != null
                            ? 'Active until ${TGFounderService.fmtDate(active.endsAt!)}'
                            : (slot?.status.name ?? 'available'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      if (active != null)
                        TextButton(
                          onPressed: () async {
                            final note = await _note('Cancel with refund');
                            if (note == null || note.isEmpty) return;
                            svc.cancel(slotId: active.id, actorId: auth.userId, reason: note, refund: true);
                            setState(() {});
                          },
                          child: const Text('Cancel/refund', style: TextStyle(fontSize: 11)),
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
