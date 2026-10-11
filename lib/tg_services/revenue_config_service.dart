import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_core/tg_clock.dart';
import 'package:twoja_gastromania/tg_models/tg_revenue.dart';
import 'package:twoja_gastromania/tg_models/tg_special_order.dart';

/// Single source of truth for Special Order revenue phases and feature flags.
class TGRevenueConfigService extends ChangeNotifier {
  TGRevenueConfigService._();
  static final TGRevenueConfigService instance = TGRevenueConfigService._();

  TGRevenueConfig _config = TGRevenueConfig.mockDefault();
  final List<TGRevenueAuditEntry> audit = [];
  final Map<String, TGSegmentGateOverride> segmentOverrides = {};

  TGRevenueConfig get config => _config;
  bool get productionMode => _config.productionMode;
  TGRevenueFlags get flags => _config.flags;
  TGWaveConfig get waves => _config.waves;

  void reset() {
    _config = TGRevenueConfig.mockDefault();
    audit.clear();
    segmentOverrides.clear();
    notifyListeners();
  }

  void setPhase(int phase, {required String actorId, String? reason}) {
    final p = phase.clamp(0, 2);
    applyConfig(
      TGRevenueConfig.forPhase(p, productionMode: _config.productionMode).copyWith(
        priority: _config.priority,
        waves: _config.waves,
        quietMonthThreshold: _config.quietMonthThreshold,
      ),
      actorId: actorId,
      action: 'revenue_phase_set',
      reason: reason,
      detail: 'phase=$p',
    );
  }

  void applyConfig(
    TGRevenueConfig next, {
    required String actorId,
    required String action,
    String? reason,
    String? detail,
  }) {
    _config = next;
    _log(actorId: actorId, action: action, reason: reason, detail: detail);
    TGAnalytics.track('revenue_config_change', {'action': action, 'phase': next.phase, 'production': next.productionMode});
    notifyListeners();
  }

  void setProductionMode(bool enabled, {required String actorId, required String reason}) {
    applyConfig(
      _config.copyWith(productionMode: enabled),
      actorId: actorId,
      action: 'production_mode',
      reason: reason,
      detail: 'productionMode=$enabled',
    );
  }

  void setFlag(String name, bool value, {required String actorId, String? reason}) {
    final f = _config.flags;
    final next = switch (name) {
      'priorityForSale' => f.copyWith(priorityForSale: value),
      'marketInsight' => f.copyWith(marketInsight: value),
      'bulkBilling' => f.copyWith(bulkBilling: value),
      'sponsorSlots' => f.copyWith(sponsorSlots: value),
      'auditProgram' => f.copyWith(auditProgram: value),
      'founderProgram' => f.copyWith(founderProgram: value),
      'bannerAds' => f.copyWith(bannerAds: value),
      _ => f,
    };
    applyConfig(_config.copyWith(flags: next), actorId: actorId, action: 'flag_$name', reason: reason, detail: '$name=$value');
  }

  void overrideSegmentGate({
    required TGStoreSpecialty specialty,
    required String region,
    required bool open,
    required String reason,
    required String actorId,
  }) {
    final o = TGSegmentGateOverride(
      specialty: specialty,
      region: region,
      open: open,
      reason: reason,
      at: TGClock.now(),
      actorId: actorId,
    );
    segmentOverrides[o.key] = o;
    _log(actorId: actorId, action: 'segment_gate_override', reason: reason, detail: '${o.key} open=$open');
    TGAnalytics.track('priority_seat_override', {'segment': o.key, 'open': open});
    notifyListeners();
  }

  bool isSegmentGateOpen({
    required TGStoreSpecialty specialty,
    required String region,
    required int matchingRequests30d,
  }) {
    final key = '${specialty.name}|$region';
    final o = segmentOverrides[key];
    if (o != null) return o.open;
    final gate = _config.priority.gate;
    final regionOk = gate.openRegions.any((r) => r.toLowerCase() == region.toLowerCase());
    return matchingRequests30d >= gate.minRequests30d && regionOk;
  }

  void _log({required String actorId, required String action, String? reason, String? detail}) {
    audit.insert(
      0,
      TGRevenueAuditEntry(
        id: 'RA-${TGClock.now().microsecondsSinceEpoch}',
        at: TGClock.now(),
        actorId: actorId,
        action: action,
        reason: reason,
        detail: detail,
      ),
    );
  }
}
