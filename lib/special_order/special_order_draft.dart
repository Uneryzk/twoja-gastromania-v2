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
      parts.add('${widthMm ?? '—'} × ${depthMm ?? '—'} × ${heightMm ?? '—'} mm');
    }
    if (dimensionsNote.trim().isNotEmpty) parts.add(dimensionsNote.trim());
    return parts.join(' · ');
  }

  List<String> errorsForStep(int s) {
    switch (s) {
      case 0:
        return [
          if (projectTypes.isEmpty) 'Select at least one project type',
          if (title.trim().length < 15 || title.trim().length > 80) 'Title must be 15–80 characters',
          if (description.trim().length < 50 || description.trim().length > 3000) 'Description must be 50–3000 characters',
        ];
      case 1:
        return [
          if (quantity < 1) 'Quantity must be at least 1',
          if (!budgetUnsure && (budgetMin == null || budgetMax == null || (budgetMin ?? 0) > (budgetMax ?? 0)))
            'Enter a valid budget range or choose "I\'m not sure"',
          if (city.trim().isEmpty) 'City is required',
        ];
      case 2:
        return [
          if (files.length > 10) 'Maximum 10 files',
        ];
      case 3:
        return [
          if ((routingMode == TGSpecialRoutingMode.selected || routingMode == TGSpecialRoutingMode.both) && selectedSellerIds.isEmpty)
            'Select at least one manufacturer',
          if (selectedSellerIds.length > 5) 'You can select up to 5 manufacturers',
          if (buyerName.trim().length < 2) 'Name is required',
          if (nip.isNotEmpty && !isValidNip(nip)) 'Invalid NIP checksum',
          if (phone.replaceAll(RegExp(r'\D'), '').length < 11) 'Phone is required',
          if (!email.contains('@')) 'Valid email is required',
          if (!consent) 'Consent is required',
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
