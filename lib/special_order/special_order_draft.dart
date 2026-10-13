import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';

class SpecialOrderDraft extends ChangeNotifier {
  SpecialOrderDraft({
    List<String>? preselectedSellerIds,
    Set<TGStoreSpecialty>? preselectedTypes,
    this.routingDefault,
  }) {
    if (preselectedSellerIds != null) selectedSellerIds.addAll(preselectedSellerIds.take(5));
    if (preselectedTypes != null) projectTypes.addAll(preselectedTypes);
    routingMode = routingDefault ??
        (selectedSellerIds.isNotEmpty ? TGSpecialRoutingMode.selected : TGSpecialRoutingMode.team);
  }

  final TGSpecialRoutingMode? routingDefault;

  int step = 0;
  DateTime? lastSavedAt;
  bool dirty = false;

  final Set<TGStoreSpecialty> projectTypes = {};
  String title = '';
  String description = '';

  int? widthMm;
  int? depthMm;
  int? heightMm;
  /// UI unit for dimension fields; values are always stored in millimetres.
  bool dimensionsInCm = false;
  String dimensionsNote = '';
  int quantity = 1;
  String material = 'AISI 304';
  String finish = 'Brushed';
  int? budgetMin;
  int? budgetMax;
  bool budgetUnsure = false;
  TGSpecialDeadline deadline = TGSpecialDeadline.flex;
  bool installationNeeded = false;
  bool deliveryNeeded = false;
  String city = '';
  String voivodeship = 'Śląskie';

  final List<TGSpecialFile> files = [];

  TGSpecialRoutingMode routingMode = TGSpecialRoutingMode.team;
  final List<String> selectedSellerIds = [];
  String buyerName = '';
  String companyName = '';
  String nip = '';
  String phone = '+48 (532) 784-074';
  String email = '';
  TGSpecialContactPref contactPref = TGSpecialContactPref.share;
  bool consent = false;

  void markDirty() {
    dirty = true;
    notifyListeners();
  }

  void saveDraft() {
    lastSavedAt = TGClock.now();
    dirty = false;
    notifyListeners();
  }

  void goStep(int s) {
    step = s.clamp(0, 4);
    notifyListeners();
  }

  String get dimensionsText {
    final parts = <String>[];
    if (widthMm != null || depthMm != null || heightMm != null) {
      if (dimensionsInCm) {
        String cm(int? mm) => mm == null ? '—' : ((mm % 10 == 0) ? '${mm ~/ 10}' : (mm / 10).toStringAsFixed(1));
        parts.add('${cm(widthMm)} × ${cm(depthMm)} × ${cm(heightMm)} cm');
      } else {
        parts.add('${widthMm ?? '—'} × ${depthMm ?? '—'} × ${heightMm ?? '—'} mm');
      }
    }
    if (dimensionsNote.trim().isNotEmpty) parts.add(dimensionsNote.trim());
    return parts.join(' · ');
  }

  /// Returns l10n keys (translate with `context.t` at display).
  List<String> errorsForStep(int s) {
    switch (s) {
      case 0:
        return [
          if (projectTypes.isEmpty) 'err_so_project_type',
          if (title.trim().length < 15 || title.trim().length > 80) 'err_wizard_title_len',
          if (description.trim().length < 50 || description.trim().length > 3000) 'err_so_description_len',
        ];
      case 1:
        return [
          if (quantity < 1) 'err_so_quantity',
          if (!budgetUnsure && (budgetMin == null || budgetMax == null || (budgetMin ?? 0) > (budgetMax ?? 0)))
            'err_so_budget',
          if (city.trim().isEmpty) 'err_resto_city_required',
        ];
      case 2:
        return [
          if (files.length > 10) 'err_so_max_files',
        ];
      case 3:
        return [
          if ((routingMode == TGSpecialRoutingMode.selected || routingMode == TGSpecialRoutingMode.both) && selectedSellerIds.isEmpty)
            'err_so_select_maker',
          if (selectedSellerIds.length > 5) 'err_so_max_makers',
          if (buyerName.trim().length < 2) 'err_resto_name',
          if (nip.isNotEmpty && !isValidNip(nip)) 'err_so_nip',
          if (phone.replaceAll(RegExp(r'\D'), '').length < 11) 'err_resto_phone_verify',
          if (!email.contains('@')) 'err_resto_email',
          if (!consent) 'err_so_consent',
        ];
      case 4:
        return [
          ...errorsForStep(0),
          ...errorsForStep(1),
          ...errorsForStep(3),
        ];
      default:
        return const [];
    }
  }

  /// Restores a stored (cancelled or timed-out) request into the wizard.
  void loadFrom(TGSpecialRequest r) {
    projectTypes
      ..clear()
      ..addAll(r.projectTypes);
    title = r.title;
    description = r.description;
    widthMm = r.widthMm;
    depthMm = r.depthMm;
    heightMm = r.heightMm;
    quantity = r.quantity;
    material = r.material;
    finish = r.finish;
    budgetMin = r.budgetMin;
    budgetMax = r.budgetMax;
    budgetUnsure = r.budgetMin == null && r.budgetMax == null;
    deadline = r.deadline;
    installationNeeded = r.installationNeeded;
    deliveryNeeded = r.deliveryNeeded;
    city = r.city;
    voivodeship = r.voivodeship;
    files
      ..clear()
      ..addAll(r.files);
    routingMode = r.routingMode;
    selectedSellerIds
      ..clear()
      ..addAll(r.selectedSellerIds);
    buyerName = r.buyerName;
    companyName = r.companyName;
    nip = r.nip ?? '';
    phone = r.phone;
    email = r.email;
    contactPref = r.contactPref;
    consent = true;
    step = 4;
    notifyListeners();
  }

  TGSpecialRequest toRequest({required String buyerId}) {
    final now = TGClock.now();
    return TGSpecialRequest(
      id: 'draft',
      requestNo: 'DRAFT',
      buyerId: buyerId,
      buyerName: buyerName.trim(),
      companyName: companyName.trim(),
      phone: phone.trim(),
      email: email.trim(),
      nip: nip.trim().isEmpty ? null : nip.replaceAll(RegExp(r'\D'), ''),
      projectTypes: projectTypes.toList(),
      title: title.trim(),
      description: description.trim(),
      quantity: quantity,
      widthMm: widthMm,
      depthMm: depthMm,
      heightMm: heightMm,
      dimensionsText: dimensionsText,
      material: material,
      finish: finish,
      budgetMin: budgetUnsure ? null : budgetMin,
      budgetMax: budgetUnsure ? null : budgetMax,
      deadline: deadline,
      city: city.trim(),
      voivodeship: voivodeship,
      installationNeeded: installationNeeded,
      deliveryNeeded: deliveryNeeded,
      files: List.of(files),
      routingMode: routingMode,
      selectedSellerIds: List.of(selectedSellerIds),
      contactPref: contactPref,
      consentAt: now,
      status: TGSpecialRequestStatus.draft,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 30)),
      teamQueued: routingMode != TGSpecialRoutingMode.selected,
    );
  }
}
