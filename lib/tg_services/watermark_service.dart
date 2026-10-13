import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:twoja_gastromania/tg_core/tg_analytics.dart';
import 'package:twoja_gastromania/tg_models/tg_watermark.dart';
import 'package:twoja_gastromania/tg_services/listing_image_service.dart';
import 'package:twoja_gastromania/tg_services/moderation_service.dart';

/// Regulamin photo-licence clause still needs legal sign-off (go-live blocker).
const bool kPhotoLicenseClauseIsDraft = true;

/// Watermark config + the "Reprocess images" admin job.
class TGWatermarkService extends ChangeNotifier {
  TGWatermarkService._();
  static final TGWatermarkService instance = TGWatermarkService._();

  static const int batchSize = 8;
  static const Duration tick = Duration(milliseconds: 40);

  WatermarkConfig _config = const WatermarkConfig();
  WatermarkConfig get config => _config;

  Timer? _timer;
  List<String> _queue = const [];
  int _done = 0;
  int _total = 0;
  DateTime? _lastRunAt;

  bool get running => _timer != null;
  int get done => _done;
  int get total => _total;
  double get progress => _total == 0 ? (running ? 0 : 1) : _done / _total;
  DateTime? get lastRunAt => _lastRunAt;

  void reset() {
    _timer?.cancel();
    _timer = null;
    _config = const WatermarkConfig();
    _queue = const [];
    _done = 0;
    _total = 0;
    _lastRunAt = null;
  }

  /// Saves admin edits. A visual change bumps [WatermarkConfig.version] so
  /// existing derivatives show as stale until reprocessed.
  void setConfig(WatermarkConfig next, {required String actorId}) {
    final bumped = next.visuallyDiffers(_config) && next.version <= _config.version ? next.copyWith(version: _config.version + 1) : next;
    final prev = _config;
    _config = bumped;
    ModerationService.instance.recordAdminAudit(
      actorId: actorId,
      actorRole: 'admin',
      summary: 'Watermark config v${prev.version} → v${bumped.version}',
      details: {for (final e in bumped.toJson().entries) e.key: '${e.value}'},
    );
    TGAnalytics.track('watermark_config_change', {'version': bumped.version, 'enabled': bumped.enabled});
    notifyListeners();
  }

  /// Records not yet on the current version / enabled state.
  int staleCount() {
    final imgs = TGListingImageService.instance.syncAll();
    return imgs.where(_isStale).length;
  }

  bool _isStale(ListingImage i) => i.watermarkVersion != _config.version || i.watermarked != _config.enabled;

  /// Starts regenerating derivatives for every listing photo.
  void startReprocess({required String actorId}) {
    if (running) return;
    final imgs = TGListingImageService.instance.syncAll();
    _queue = [for (final i in imgs) i.id];
    _done = 0;
    _total = _queue.length;
    ModerationService.instance.recordAdminAudit(
      actorId: actorId,
      actorRole: 'admin',
      summary: 'Reprocess images started · $_total images · watermark v${_config.version}',
    );
    TGAnalytics.track('watermark_reprocess_start', {'total': _total, 'version': _config.version});
    _timer = Timer.periodic(tick, (_) => step());
    notifyListeners();
  }

  /// Processes one batch (public for tests).
  void step() {
    final svc = TGListingImageService.instance;
    final byId = {for (final i in svc.all) i.id: i};
    final end = (_done + batchSize).clamp(0, _total);
    for (var k = _done; k < end; k++) {
      final img = byId[_queue[k]];
      if (img == null) continue;
      svc.replace(img.copyWith(watermarked: _config.enabled, watermarkVersion: _config.version));
    }
    _done = end;
    if (_done >= _total) {
      _timer?.cancel();
      _timer = null;
      _lastRunAt = DateTime.now();
      TGAnalytics.track('watermark_reprocess_done', {'total': _total, 'version': _config.version});
      svc.notify();
    }
    notifyListeners();
  }
}
