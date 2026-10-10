import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:twoja_gastromania/add_product/add_product_fields.dart';
import 'package:twoja_gastromania/flutter_flow/flutter_flow_theme.dart';
import 'package:twoja_gastromania/flutter_flow/internationalization.dart';
import 'package:twoja_gastromania/special_order/special_order_draft.dart';
import 'package:twoja_gastromania/tg_components/tg_buttons.dart';
import 'package:twoja_gastromania/tg_core/tg_tokens.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';
import 'package:twoja_gastromania/tg_services/seller_profile_service.dart';
import 'package:twoja_gastromania/tg_services/special_order_service.dart';

const kSoMaterials = ['AISI 304', 'AISI 430', 'Aluminium', 'Other', 'Not sure'];
const kSoFinishes = ['Brushed', 'Polished', 'Other'];
const kSoCities = ['Gliwice', 'Katowice', 'Chorzów', 'Kraków', 'Warszawa', 'Wrocław', 'Łódź', 'Rybnik'];

class SoStepProject extends StatelessWidget {
  const SoStepProject({super.key, required this.draft, required this.onChanged});
  final SpecialOrderDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return WizardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('ui_so_step_project'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          WizardLabel(context.t('ui_project_type')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in TGStoreSpecialty.values.where((e) => e != TGStoreSpecialty.other))
                FilterChip(
                  selected: draft.projectTypes.contains(s),
                  label: Text(context.t('ui_so_spec_${s.name}')),
                  selectedColor: TGColors.accent,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: draft.projectTypes.contains(s) ? Colors.white : theme.primaryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  onSelected: (v) {
                    if (v) {
                      draft.projectTypes.add(s);
                    } else {
                      draft.projectTypes.remove(s);
                    }
                    onChanged();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          WizardLabel(context.t('ui_title')),
          WizardField(
            controller: TextEditingController(text: draft.title)..selection = TextSelection.collapsed(offset: draft.title.length),
            hint: context.t('ui_so_title_hint'),
            onChanged: (v) {
              draft.title = v;
              onChanged();
            },
          ),
          Text('${draft.title.trim().length}/80', style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 12),
          WizardLabel(context.t('ui_description')),
          WizardField(
            controller: TextEditingController(text: draft.description)..selection = TextSelection.collapsed(offset: draft.description.length),
            maxLines: 6,
            hint: context.t('ui_so_desc_hint'),
            onChanged: (v) {
              draft.description = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: Text(context.t('ui_so_chip_dimensions')),
                onPressed: () {
                  if (!draft.description.contains('Dimensions:')) {
                    draft.description = '${draft.description.trim()}\n\nDimensions: '.trim();
                    onChanged();
                  }
                },
              ),
              ActionChip(
                label: Text(context.t('ui_so_chip_certs')),
                onPressed: () {
                  if (!draft.description.contains('Certificates:')) {
                    draft.description = '${draft.description.trim()}\n\nCertificates: '.trim();
                    onChanged();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SoStepSpecs extends StatelessWidget {
  const SoStepSpecs({super.key, required this.draft, required this.onChanged});
  final SpecialOrderDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return WizardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('ui_so_step_specs'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          WizardLabel(context.t('ui_dimensions')),
          Row(
            children: [
              Expanded(child: _num(context, 'W', draft.widthMm, (v) { draft.widthMm = v; onChanged(); })),
              const SizedBox(width: 8),
              Expanded(child: _num(context, 'D', draft.depthMm, (v) { draft.depthMm = v; onChanged(); })),
              const SizedBox(width: 8),
              Expanded(child: _num(context, 'H', draft.heightMm, (v) { draft.heightMm = v; onChanged(); })),
            ],
          ),
          const SizedBox(height: 8),
          WizardField(
            controller: TextEditingController(text: draft.dimensionsNote)..selection = TextSelection.collapsed(offset: draft.dimensionsNote.length),
            hint: context.t('ui_so_dim_note'),
            onChanged: (v) { draft.dimensionsNote = v; onChanged(); },
          ),
          const SizedBox(height: 12),
          WizardLabel(context.t('ui_quantity')),
          WizardField(
            controller: TextEditingController(text: '${draft.quantity}')..selection = TextSelection.collapsed(offset: '${draft.quantity}'.length),
            keyboardType: TextInputType.number,
            onChanged: (v) { draft.quantity = int.tryParse(v) ?? 1; onChanged(); },
          ),
          const SizedBox(height: 12),
          WizardLabel(context.t('ui_material')),
          Wrap(
            spacing: 8,
            children: [
              for (final m in kSoMaterials)
                ChoiceChip(label: Text(m), selected: draft.material == m, onSelected: (_) { draft.material = m; onChanged(); }),
            ],
          ),
          const SizedBox(height: 12),
          WizardLabel(context.t('ui_so_finish')),
          Wrap(
            spacing: 8,
            children: [
              for (final f in kSoFinishes)
                ChoiceChip(label: Text(f), selected: draft.finish == f, onSelected: (_) { draft.finish = f; onChanged(); }),
            ],
          ),
          const SizedBox(height: 12),
          WizardLabel(context.t('ui_so_budget_netto')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('ui_so_budget_unsure'), style: const TextStyle(fontWeight: FontWeight.w700)),
            value: draft.budgetUnsure,
            activeColor: TGColors.cta,
            onChanged: (v) { draft.budgetUnsure = v; onChanged(); },
          ),
          if (!draft.budgetUnsure)
            Row(
              children: [
                Expanded(child: _num(context, 'Min', draft.budgetMin, (v) { draft.budgetMin = v; onChanged(); })),
                const SizedBox(width: 8),
                Expanded(child: _num(context, 'Max', draft.budgetMax, (v) { draft.budgetMax = v; onChanged(); })),
              ],
            ),
          const SizedBox(height: 12),
          WizardLabel(context.t('ui_so_deadline')),
          ...[
            (TGSpecialDeadline.asap, context.t('ui_so_deadline_asap')),
            (TGSpecialDeadline.oneMonth, context.t('ui_so_deadline_1m')),
            (TGSpecialDeadline.threeMonths, context.t('ui_so_deadline_3m')),
            (TGSpecialDeadline.flex, context.t('ui_so_deadline_flex')),
          ].map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: WizardRadioCard(
                  compact: true,
                  selected: draft.deadline == e.$1,
                  title: e.$2,
                  onTap: () { draft.deadline = e.$1; onChanged(); },
                ),
              )),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: draft.installationNeeded,
            onChanged: (v) { draft.installationNeeded = v ?? false; onChanged(); },
            title: Text(context.t('ui_so_install_needed')),
            activeColor: TGColors.cta,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: draft.deliveryNeeded,
            onChanged: (v) { draft.deliveryNeeded = v ?? false; onChanged(); },
            title: Text(context.t('ui_so_delivery_needed')),
            activeColor: TGColors.cta,
          ),
          WizardLabel(context.t('ui_city')),
          Autocomplete<String>(
            initialValue: TextEditingValue(text: draft.city),
            optionsBuilder: (v) {
              final q = v.text.toLowerCase();
              return kSoCities.where((c) => c.toLowerCase().contains(q));
            },
            onSelected: (v) { draft.city = v; onChanged(); },
            fieldViewBuilder: (ctx, c, f, onSubmit) {
              return TextField(
                controller: c,
                focusNode: f,
                decoration: InputDecoration(hintText: context.t('ui_city')),
                onChanged: (v) { draft.city = v; onChanged(); },
              );
            },
          ),
          const SizedBox(height: 4),
          Text(draft.voivodeship, style: theme.bodySmall.override(color: theme.secondaryText)),
        ],
      ),
    );
  }

  Widget _num(BuildContext context, String label, int? value, ValueChanged<int?> onSet) {
    return TextField(
      controller: TextEditingController(text: value?.toString() ?? ''),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: (v) => onSet(v.isEmpty ? null : int.tryParse(v)),
    );
  }
}

class SoStepFiles extends StatelessWidget {
  const SoStepFiles({super.key, required this.draft, required this.onChanged});
  final SpecialOrderDraft draft;
  final VoidCallback onChanged;

  static const _pool = <(String, String, int)>[
    ('layout.pdf', 'assets/images/blog-26.jpg', 420000),
    ('drawing.dxf', 'assets/images/Food_Prepering_table.jpg', 380000),
    ('photo.jpg', 'assets/images/stainless_steel_table_Food_Preparation_table_gastronomi.jpg', 900000),
    ('detail.png', 'assets/images/1525682723endustriyel-mutfak-ekupmanlar.jpg', 700000),
  ];

  static void _addFile(SpecialOrderDraft draft, VoidCallback onChanged, {required bool preferImage}) {
    if (draft.files.length >= 10) return;
    final pool = preferImage ? _pool.where((e) => e.$1.endsWith('.jpg') || e.$1.endsWith('.png')).toList() : _pool;
    final i = draft.files.length % pool.length;
    final p = pool[i];
    if (p.$3 > 25 * 1024 * 1024) return;
    final lower = p.$1.toLowerCase();
    draft.files.add(TGSpecialFile(
      id: 'f_${DateTime.now().microsecondsSinceEpoch}',
      name: p.$1,
      assetPath: p.$2,
      bytes: p.$3,
      exifStripped: lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png'),
    ));
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return WizardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('ui_so_step_files'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(context.t('ui_so_files_hint'), style: theme.bodySmall.override(color: theme.secondaryText, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          if (MediaQuery.sizeOf(context).width < TGBreakpoints.phone) ...[
            Row(
              children: [
                Expanded(
                  child: TGButton(
                    onPressed: () => _addFile(draft, onChanged, preferImage: true),
                    label: context.t('ui_so_take_photo'),
                    variant: TGButtonVariant.outline,
                    height: 48,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TGButton(
                    onPressed: () => _addFile(draft, onChanged, preferImage: false),
                    label: context.t('ui_so_choose_file'),
                    variant: TGButtonVariant.outline,
                    height: 48,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (draft.files.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: draft.files.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                itemBuilder: (_, i) {
                  final f = draft.files[i];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset(f.assetPath, fit: BoxFit.cover)),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            draft.files.removeAt(i);
                            onChanged();
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
          ] else
            InkWell(
              onTap: () => _addFile(draft, onChanged, preferImage: false),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 140,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TGColors.cta.withValues(alpha: 0.5), width: 1.5),
                  color: theme.alternate,
                ),
                child: Text(context.t('ui_so_drop_files'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          const SizedBox(height: 8),
          Text(context.t('ui_so_files_limits'), style: theme.bodySmall.override(color: theme.secondaryText)),
          const SizedBox(height: 12),
          if (MediaQuery.sizeOf(context).width >= TGBreakpoints.phone)
            for (final f in draft.files)
              ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${(f.bytes / 1024).round()} KB · EXIF cleared'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  draft.files.remove(f);
                  onChanged();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class SoStepAudience extends StatefulWidget {
  const SoStepAudience({super.key, required this.draft, required this.onChanged, required this.phoneVerified});
  final SpecialOrderDraft draft;
  final VoidCallback onChanged;
  final bool phoneVerified;

  @override
  State<SoStepAudience> createState() => _SoStepAudienceState();
}

class _SoStepAudienceState extends State<SoStepAudience> {
  String _makerQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final draft = widget.draft;
    final onChanged = widget.onChanged;
    final makers = TGSpecialOrderService.instance.manufacturers();
    final q = _makerQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? makers
        : makers.where((m) => m.name.toLowerCase().contains(q) || m.city.toLowerCase().contains(q)).toList();
    final selected = [
      for (final id in draft.selectedSellerIds)
        if (TGSellerProfileService.instance.bySellerKey(id) != null) TGSellerProfileService.instance.bySellerKey(id)!,
    ];
    return WizardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('ui_so_step_who'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Semantics(
            container: true,
            label: context.t('ui_so_step_who'),
            child: Column(
              children: [
                WizardRadioCard(
                  selected: draft.routingMode == TGSpecialRoutingMode.selected,
                  title: context.t('ui_so_route_selected', {'n': '${draft.selectedSellerIds.length}'}),
                  onTap: () { draft.routingMode = TGSpecialRoutingMode.selected; onChanged(); },
                ),
                const SizedBox(height: 8),
                WizardRadioCard(
                  selected: draft.routingMode == TGSpecialRoutingMode.team,
                  title: context.t('ui_so_route_team'),
                  onTap: () { draft.routingMode = TGSpecialRoutingMode.team; onChanged(); },
                ),
                const SizedBox(height: 8),
                WizardRadioCard(
                  selected: draft.routingMode == TGSpecialRoutingMode.both,
                  title: context.t('ui_so_route_both'),
                  onTap: () { draft.routingMode = TGSpecialRoutingMode.both; onChanged(); },
                ),
              ],
            ),
          ),
          if (draft.routingMode != TGSpecialRoutingMode.team) ...[
            const SizedBox(height: 16),
            WizardLabel(context.t('ui_so_pick_makers')),
            if (selected.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in selected)
                    InputChip(
                      label: Text(m.name),
                      onDeleted: () {
                        draft.selectedSellerIds.remove(m.sellerKey);
                        onChanged();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              decoration: InputDecoration(hintText: context.t('ui_search_ellipsis'), isDense: true, prefixIcon: const Icon(Icons.search, size: 18)),
              onChanged: (v) => setState(() => _makerQuery = v),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in filtered.take(12))
                  FilterChip(
                    selected: draft.selectedSellerIds.contains(m.sellerKey),
                    label: Text(m.name),
                    onSelected: (v) {
                      if (v) {
                        if (draft.selectedSellerIds.length >= 5) return;
                        draft.selectedSellerIds.add(m.sellerKey);
                      } else {
                        draft.selectedSellerIds.remove(m.sellerKey);
                      }
                      onChanged();
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          WizardLabel(context.t('ui_contact')),
          WizardField(controller: TextEditingController(text: draft.buyerName)..selection = TextSelection.collapsed(offset: draft.buyerName.length), hint: context.t('ui_name'), onChanged: (v) { draft.buyerName = v; onChanged(); }),
          const SizedBox(height: 8),
          WizardField(controller: TextEditingController(text: draft.companyName)..selection = TextSelection.collapsed(offset: draft.companyName.length), hint: context.t('ui_company_optional'), onChanged: (v) { draft.companyName = v; onChanged(); }),
          const SizedBox(height: 8),
          WizardField(controller: TextEditingController(text: draft.nip)..selection = TextSelection.collapsed(offset: draft.nip.length), hint: context.t('ui_nip_optional'), keyboardType: TextInputType.number, onChanged: (v) { draft.nip = v; onChanged(); }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(draft.phone, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              if (widget.phoneVerified)
                Text(context.t('ui_verified'), style: TextStyle(color: theme.success, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          WizardField(controller: TextEditingController(text: draft.email)..selection = TextSelection.collapsed(offset: draft.email.length), hint: context.t('ui_email'), onChanged: (v) { draft.email = v; onChanged(); }),
          const SizedBox(height: 12),
          Semantics(
            container: true,
            label: context.t('ui_contact'),
            child: Column(
              children: [
                WizardRadioCard(
                  selected: draft.contactPref == TGSpecialContactPref.share,
                  title: context.t('ui_so_contact_share'),
                  onTap: () { draft.contactPref = TGSpecialContactPref.share; onChanged(); },
                ),
                const SizedBox(height: 8),
                WizardRadioCard(
                  selected: draft.contactPref == TGSpecialContactPref.platformOnly,
                  title: context.t('ui_so_contact_platform'),
                  onTap: () { draft.contactPref = TGSpecialContactPref.platformOnly; onChanged(); },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: draft.consent,
            activeColor: TGColors.cta,
            onChanged: (v) { draft.consent = v ?? false; onChanged(); },
            title: Text(context.t('ui_so_consent'), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class SoStepReview extends StatelessWidget {
  const SoStepReview({super.key, required this.draft, required this.onEdit});
  final SpecialOrderDraft draft;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final errs = draft.errorsForStep(4);
    final makers = [
      for (final id in draft.selectedSellerIds)
        if (TGSellerProfileService.instance.bySellerKey(id) != null) TGSellerProfileService.instance.bySellerKey(id)!.name,
    ];
    return WizardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('ui_so_step_review'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (errs.isNotEmpty) ...[
            for (final e in errs) WizardError(e),
            const SizedBox(height: 8),
          ],
          _block(context, context.t('ui_so_step_project'), '${draft.title}\n${draft.projectTypes.map((s) => context.t('ui_so_spec_${s.name}')).join(', ')}', 0, onEdit),
          _block(context, context.t('ui_so_step_specs'), '${draft.dimensionsText}\n${draft.material} · ${draft.finish}\n${draft.city}', 1, onEdit),
          _block(context, context.t('ui_so_step_files'), draft.files.isEmpty ? context.t('ui_so_no_files') : '${draft.files.length} files', 2, onEdit),
          _block(context, context.t('ui_so_step_who'), '${draft.routingMode.name} · ${makers.join(', ')}\n${draft.phone} · ${draft.email}', 3, onEdit),
          const SizedBox(height: 12),
          Text(context.t('ui_so_free_buyers'), style: theme.bodyMedium.override(fontWeight: FontWeight.w800, color: TGColors.cta)),
        ],
      ),
    );
  }

  Widget _block(BuildContext context, String title, String body, int step, ValueChanged<int> onEdit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: Border.all(color: TGColors.border), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
                TextButton(onPressed: () => onEdit(step), child: Text(context.t('ui_edit'))),
              ],
            ),
            Text(body, style: const TextStyle(height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class SoRequestSummary extends StatelessWidget {
  const SoRequestSummary({super.key, required this.draft});
  final SpecialOrderDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return AnimatedSwitcher(
      duration: TGMotion.of(context, TGMotion.fade),
      child: WizardCard(
        key: ValueKey('${draft.step}-${draft.title}-${draft.selectedSellerIds.length}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('ui_so_request_summary'), style: theme.titleMedium.override(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(draft.title.isEmpty ? context.t('ui_so_summary_empty') : draft.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              [
                if (draft.projectTypes.isNotEmpty) draft.projectTypes.map((s) => context.t('ui_so_spec_${s.name}')).join(', '),
                if (draft.city.isNotEmpty) draft.city,
                if (!draft.budgetUnsure && draft.budgetMin != null) '${draft.budgetMin}–${draft.budgetMax} PLN netto',
                if (draft.selectedSellerIds.isNotEmpty)
                  draft.selectedSellerIds
                      .map((id) => TGSellerProfileService.instance.bySellerKey(id)?.name ?? id)
                      .join(', '),
              ].where((e) => e.isNotEmpty).join('\n'),
              style: theme.bodySmall.override(lineHeight: 1.4),
            ),
            const SizedBox(height: 16),
            Text(context.t('ui_so_what_next'), style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(context.t('ui_so_what_next_body'), style: theme.bodySmall.override(lineHeight: 1.4)),
            const SizedBox(height: 16),
            Text(context.t('ui_so_team_phone'), style: theme.bodySmall.override(color: theme.secondaryText)),
            const Text('+48 (532) 784-074', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
