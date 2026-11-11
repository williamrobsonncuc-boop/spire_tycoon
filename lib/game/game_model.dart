import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'formulas.dart';

/// One JSON blob in shared_preferences. On Chrome that is localStorage.
const String saveKey = 'spire_tycoon_save_v1';

/// Holds gold, the desk upgrade, and the save file.
///
/// The screen listens to this object. When something changes we call
/// [notifyListeners], and Flutter rebuilds the parts that are watching.
class GameModel extends ChangeNotifier with WidgetsBindingObserver {
  GameModel({DateTime Function()? now, this.enableIdleTicks = true})
    : _now = now ?? DateTime.now;

  /// Clock, so tests can pretend it is a fixed time.
  final DateTime Function() _now;

  /// Widget tests turn this off so a long `pump` does not also add idle gold.
  final bool enableIdleTicks;

  double gold = 0;
  int deskLevel = 0;

  /// Welcome-back gold the player has not collected yet.
  double pendingOfflineGold = 0;
  int pendingOfflineSeconds = 0;

  bool ready = false;

  SharedPreferences? _preferences;
  DateTime? _lastActive;
  Timer? _idleTimer;
  bool _loadStarted = false;
  bool _observing = false;
  bool _disposed = false;

  int get goldPerTap => 1 + deskLevel;

  double get goldPerSecond => idleGoldPerSecond(goldPerTap);

  bool get canAffordDesk => gold + 0.001 >= deskUpgradeCost(deskLevel);

  /// Reads the save file, then figures out offline gold.
  Future<void> load() async {
    if (_loadStarted || _disposed) {
      return;
    }
    _loadStarted = true;

    _preferences = await SharedPreferences.getInstance();
    if (_disposed) {
      return;
    }

    final now = _now();
    _readSave(now);

    // Pay for the time since the last save, then move the clock forward
    // so a refresh does not pay the same gap twice. Uncollected gold stays
    // in [pendingOfflineGold] and is written into the save immediately.
    final away = now.difference(_lastActive ?? now);
    final earned = offlineEarnings(goldPerSecond: goldPerSecond, away: away);
    if (earned > 0) {
      pendingOfflineGold = roundTenths(pendingOfflineGold + earned);
      final counted = away > offlineCap ? offlineCap : away;
      pendingOfflineSeconds += counted.inSeconds;
    }
    _lastActive = now;

    ready = true;
    await _writeSave();
    if (_disposed) {
      return;
    }
    _startIdleTimer();
    _listenForBackground();
    notifyListeners();
  }

  void tapGoblin() {
    gold = roundTenths(gold + goldPerTap);
    _touch();
  }

  void buyDesk() {
    final cost = deskUpgradeCost(deskLevel);
    if (gold + 0.001 < cost) {
      return;
    }
    gold = roundTenths(gold - cost);
    deskLevel += 1;
    _touch();
  }

  /// Moves welcome-back gold into the wallet.
  ///
  /// [doubled] is the reward for sitting through the practice sponsor memo.
  void collectOffline({bool doubled = false}) {
    if (pendingOfflineGold <= 0) {
      return;
    }
    final payout = doubled
        ? roundTenths(pendingOfflineGold * 2)
        : pendingOfflineGold;
    gold = roundTenths(gold + payout);
    pendingOfflineGold = 0;
    pendingOfflineSeconds = 0;
    _touch();
  }

  void _readSave(DateTime now) {
    final raw = _preferences?.getString(saveKey);
    if (raw == null) {
      _lastActive = now;
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      gold = (map['gold'] as num?)?.toDouble() ?? 0;
      deskLevel = (map['deskLevel'] as num?)?.toInt() ?? 0;
      pendingOfflineGold = (map['pendingOfflineGold'] as num?)?.toDouble() ?? 0;
      pendingOfflineSeconds =
          (map['pendingOfflineSeconds'] as num?)?.toInt() ?? 0;
      final lastMs = (map['lastActiveMs'] as num?)?.toInt();
      _lastActive = lastMs == null
          ? now
          : DateTime.fromMillisecondsSinceEpoch(lastMs);
    } catch (_) {
      // A broken save should not trap the player. Start a fresh lobby.
      gold = 0;
      deskLevel = 0;
      pendingOfflineGold = 0;
      pendingOfflineSeconds = 0;
      _lastActive = now;
    }
  }

  void _touch() {
    _lastActive = _now();
    notifyListeners();
    unawaited(_writeSave());
  }

  void _tickIdle() {
    if (!ready || _disposed) {
      return;
    }
    gold = roundTenths(gold + goldPerSecond);
    _lastActive = _now();
    notifyListeners();
    unawaited(_writeSave());
  }

  void _startIdleTimer() {
    if (!enableIdleTicks) {
      return;
    }
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickIdle());
  }

  void _listenForBackground() {
    if (_observing) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final now = _now();
      final away = now.difference(_lastActive ?? now);
      final earned = offlineEarnings(goldPerSecond: goldPerSecond, away: away);
      _lastActive = now;
      if (earned > 0) {
        pendingOfflineGold = roundTenths(pendingOfflineGold + earned);
        final counted = away > offlineCap ? offlineCap : away;
        pendingOfflineSeconds += counted.inSeconds;
        notifyListeners();
      }
      unawaited(_writeSave());
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _lastActive = _now();
      unawaited(_writeSave());
    }
  }

  Future<void> _writeSave() async {
    final prefs = _preferences;
    if (prefs == null || _disposed) {
      return;
    }
    final payload = jsonEncode({
      'version': 1,
      'gold': gold,
      'deskLevel': deskLevel,
      'pendingOfflineGold': pendingOfflineGold,
      'pendingOfflineSeconds': pendingOfflineSeconds,
      'lastActiveMs': (_lastActive ?? _now()).millisecondsSinceEpoch,
    });
    await prefs.setString(saveKey, payload);
  }

  @override
  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    super.dispose();
  }
}
