import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'floor_catalog.dart';
import 'formulas.dart';

/// One JSON blob in shared_preferences. On Chrome that is localStorage.
const String saveKey = 'spire_tycoon_save_v1';

/// A floor the player has actually touched.
///
/// Locked floors are not stored. Their name, cost, and income come from
/// [floorRecipe], so the save stays small no matter how tall the spire is.
class FloorProgress {
  FloorProgress({
    this.level = 0,
    this.running = false,
    this.constructionEndsMs,
    this.clogged = false,
  });

  int level;
  bool running;
  int? constructionEndsMs;
  bool clogged;

  bool get isBuilding => !running && constructionEndsMs != null;

  /// Compact tuple: [index is added by the caller, level, flags, until].
  /// flags: 1 = running, 2 = clogged.
  List<int> toTuple(int index) {
    var flags = 0;
    if (running) {
      flags |= 1;
    }
    if (clogged) {
      flags |= 2;
    }
    return [index, level, flags, constructionEndsMs ?? 0];
  }

  static FloorProgress fromTuple(List<dynamic> tuple) {
    final level = (tuple[1] as num).toInt();
    final flags = (tuple[2] as num).toInt();
    final until = (tuple[3] as num).toInt();
    return FloorProgress(
      level: level,
      running: (flags & 1) != 0,
      clogged: (flags & 2) != 0,
      constructionEndsMs: until == 0 ? null : until,
    );
  }
}

/// Gold, compliance, and the handful of floors the player has opened.
class GameModel extends ChangeNotifier with WidgetsBindingObserver {
  GameModel({
    DateTime Function()? now,
    this.enableIdleTicks = true,
    this.clogChance = 0.03,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random();

  final DateTime Function() _now;
  final bool enableIdleTicks;

  /// Chance, once a second, that the bottling plant clogs. Tests set this to 1.
  final double clogChance;
  final Random _random;

  double gold = 0;
  double compliance = 0;
  int policyLevel = 0;

  /// Welcome-back rewards the player has not collected yet.
  double pendingOfflineGold = 0;
  double pendingCompliance = 0;
  int pendingOfflineSeconds = 0;

  /// Only floors that are built, building, or upgraded. Floor 1 is always here.
  final Map<int, FloorProgress> floors = {};

  bool ready = false;

  SharedPreferences? _preferences;
  DateTime? _lastActive;
  Timer? _idleTimer;
  double _slowCharge = 0;
  bool _loadStarted = false;
  bool _observing = false;
  bool _disposed = false;

  DateTime get currentTime => _now();

  int get lobbyLevel => floors[0]?.level ?? 0;

  int get goldPerTap => 1 + lobbyLevel;

  /// +10% gold income per policy, forever (until a later prestige reset).
  double get goldMultiplier => 1 + policyLevel * 0.10;

  double get policyCost => roundMoney((8 * pow(1.55, policyLevel)).toDouble());

  /// Average gold per second, including the necromancy floor's lumps.
  double get goldPerSecond {
    var total = 0.0;
    for (final index in floors.keys) {
      total += goldRateFor(index);
    }
    return total;
  }

  double get compliancePerSecond {
    var total = 0.0;
    for (final index in floors.keys) {
      total += complianceRateFor(index);
    }
    return total;
  }

  FloorProgress progressOf(int index) {
    return floors[index] ?? FloorProgress();
  }

  bool isRunning(int index) => progressOf(index).running;

  bool isBuilding(int index) => progressOf(index).isBuilding;

  double goldRateFor(int index) {
    final progress = floors[index];
    if (progress == null || !progress.running || progress.clogged) {
      return 0;
    }
    if (floorKind(index) == FloorKind.compliance) {
      return 0;
    }
    return floorBaseGold(index) * (1 + progress.level) * goldMultiplier;
  }

  double complianceRateFor(int index) {
    final progress = floors[index];
    if (progress == null || !progress.running) {
      return 0;
    }
    if (floorKind(index) != FloorKind.compliance) {
      return 0;
    }
    return floorBaseCompliance(index) * (1 + progress.level);
  }

  bool canBuild(int index) {
    if (index <= 0 || isRunning(index) || isBuilding(index)) {
      return false;
    }
    if (!isRunning(index - 1)) {
      return false;
    }
    return gold + 0.001 >= floorBuildCost(index);
  }

  bool canUpgrade(int index) {
    final progress = floors[index];
    if (progress == null || !progress.running) {
      return false;
    }
    return gold + 0.001 >= floorUpgradeCost(index, progress.level);
  }

  bool get canBuyPolicy => compliance + 0.001 >= policyCost;

  int? buildSecondsLeft(int index) {
    final ends = floors[index]?.constructionEndsMs;
    if (ends == null || isRunning(index)) {
      return null;
    }
    final leftMs = ends - _now().millisecondsSinceEpoch;
    if (leftMs <= 0) {
      return 0;
    }
    return (leftMs / 1000).ceil();
  }

  Future<void> load() async {
    if (_loadStarted || _disposed) {
      return;
    }
    _loadStarted = true;
    floors[0] = FloorProgress(running: true);

    _preferences = await SharedPreferences.getInstance();
    if (_disposed) {
      return;
    }

    final now = _now();
    _readSave(now);

    final away = now.difference(_lastActive ?? now);
    final earnedGold = offlineEarnings(
      goldPerSecond: goldPerSecond,
      away: away,
    );
    final earnedCompliance = offlineEarnings(
      goldPerSecond: compliancePerSecond,
      away: away,
    );
    if (earnedGold > 0 || earnedCompliance > 0) {
      pendingOfflineGold = roundMoney(pendingOfflineGold + earnedGold);
      pendingCompliance = roundMoney(pendingCompliance + earnedCompliance);
      final counted = away > offlineCap ? offlineCap : away;
      pendingOfflineSeconds += counted.inSeconds;
    }
    // Floors that finished while the game was closed open now.
    // They were not included in the payout above.
    _finishConstruction(now);
    _lastActive = now;

    ready = true;
    await persist();
    if (_disposed) {
      return;
    }
    _startIdleTimer();
    _listenForBackground();
    notifyListeners();
  }

  void tapLobby() {
    gold = roundMoney(gold + goldPerTap);
    _touch();
  }

  void startBuild(int index) {
    if (index <= 0 || isRunning(index) || isBuilding(index)) {
      return;
    }
    if (!isRunning(index - 1)) {
      return;
    }
    final cost = floorBuildCost(index);
    if (gold + 0.001 < cost) {
      return;
    }
    gold = roundMoney(gold - cost);
    floors[index] = FloorProgress(
      constructionEndsMs:
          _now().millisecondsSinceEpoch + floorBuildSeconds(index) * 1000,
    );
    _touch();
  }

  void upgradeFloor(int index) {
    final progress = floors[index];
    if (progress == null || !progress.running) {
      return;
    }
    final cost = floorUpgradeCost(index, progress.level);
    if (gold + 0.001 < cost) {
      return;
    }
    gold = roundMoney(gold - cost);
    progress.level += 1;
    _touch();
  }

  void clearClog(int index) {
    final progress = floors[index];
    if (progress == null || !progress.clogged) {
      return;
    }
    progress.clogged = false;
    _touch();
  }

  void buyPolicy() {
    if (compliance + 0.001 < policyCost) {
      return;
    }
    compliance = roundMoney(compliance - policyCost);
    policyLevel += 1;
    _touch();
  }

  /// One second of the live game: income, finished construction, maybe a clog.
  void advanceOneSecond() {
    if (_disposed) {
      return;
    }
    final now = _now();
    _finishConstruction(now);
    _produce(const Duration(seconds: 1));
    _rollClogs();
    _lastActive = now;
    notifyListeners();
    unawaited(persist());
  }

  void collectOffline({bool doubled = false}) {
    if (pendingOfflineGold <= 0 && pendingCompliance <= 0) {
      return;
    }
    final factor = doubled ? 2.0 : 1.0;
    gold = roundMoney(gold + pendingOfflineGold * factor);
    compliance = roundMoney(compliance + pendingCompliance * factor);
    pendingOfflineGold = 0;
    pendingCompliance = 0;
    pendingOfflineSeconds = 0;
    _touch();
  }

  Future<void> persist() => _writeSave();

  void _produce(Duration elapsed) {
    final seconds = elapsed.inMilliseconds / 1000;
    if (seconds <= 0) {
      return;
    }
    var goldGain = 0.0;
    var complianceGain = 0.0;
    for (final index in floors.keys.toList()) {
      final kind = floorKind(index);
      if (kind == FloorKind.slowBurst) {
        final rate = goldRateFor(index);
        if (rate <= 0) {
          continue;
        }
        _slowCharge += seconds;
        while (_slowCharge >= slowBurstSeconds) {
          goldGain += rate * slowBurstSeconds;
          _slowCharge -= slowBurstSeconds;
        }
      } else if (kind == FloorKind.compliance) {
        complianceGain += complianceRateFor(index) * seconds;
      } else {
        goldGain += goldRateFor(index) * seconds;
      }
    }
    if (goldGain != 0) {
      gold = roundMoney(gold + goldGain);
    }
    if (complianceGain != 0) {
      compliance = roundMoney(compliance + complianceGain);
    }
  }

  void _finishConstruction(DateTime now) {
    final nowMs = now.millisecondsSinceEpoch;
    for (final progress in floors.values) {
      final ends = progress.constructionEndsMs;
      if (ends != null && !progress.running && ends <= nowMs) {
        progress.running = true;
        progress.constructionEndsMs = null;
      }
    }
  }

  void _rollClogs() {
    for (final entry in floors.entries) {
      if (floorKind(entry.key) != FloorKind.clog) {
        continue;
      }
      final progress = entry.value;
      if (!progress.running || progress.clogged) {
        continue;
      }
      if (_random.nextDouble() < clogChance) {
        progress.clogged = true;
      }
    }
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
      compliance = (map['compliance'] as num?)?.toDouble() ?? 0;
      policyLevel = (map['policy'] as num?)?.toInt() ?? 0;
      _slowCharge = (map['slow'] as num?)?.toDouble() ?? 0;
      pendingOfflineGold = (map['pendingOfflineGold'] as num?)?.toDouble() ?? 0;
      pendingCompliance = (map['pendingCompliance'] as num?)?.toDouble() ?? 0;
      pendingOfflineSeconds =
          (map['pendingOfflineSeconds'] as num?)?.toInt() ?? 0;
      final lastMs = (map['lastActiveMs'] as num?)?.toInt();
      _lastActive = lastMs == null
          ? now
          : DateTime.fromMillisecondsSinceEpoch(lastMs);

      final version = (map['version'] as num?)?.toInt() ?? 1;
      floors.clear();
      if (version >= 2 && map['floors'] is List) {
        for (final entry in map['floors'] as List) {
          final tuple = entry as List;
          final index = (tuple[0] as num).toInt();
          floors[index] = FloorProgress.fromTuple(tuple);
        }
      }
      // Version 1 only knew about the lobby desk.
      final deskLevel = (map['deskLevel'] as num?)?.toInt();
      floors.putIfAbsent(0, () => FloorProgress(running: true));
      final lobby = floors[0]!;
      lobby.running = true;
      if (version < 2 && deskLevel != null) {
        lobby.level = deskLevel;
      }
    } catch (_) {
      gold = 0;
      compliance = 0;
      policyLevel = 0;
      floors
        ..clear()
        ..[0] = FloorProgress(running: true);
      _lastActive = now;
    }
  }

  Map<String, Object?> _saveMap() {
    final stored = <List<int>>[];
    final indexes = floors.keys.toList()..sort();
    for (final index in indexes) {
      final progress = floors[index]!;
      final touched =
          index == 0 ||
          progress.running ||
          progress.isBuilding ||
          progress.level > 0 ||
          progress.clogged;
      if (touched) {
        stored.add(progress.toTuple(index));
      }
    }
    return {
      'version': 2,
      'gold': gold,
      'compliance': compliance,
      'policy': policyLevel,
      'slow': _slowCharge,
      'pendingOfflineGold': pendingOfflineGold,
      'pendingCompliance': pendingCompliance,
      'pendingOfflineSeconds': pendingOfflineSeconds,
      'lastActiveMs': (_lastActive ?? _now()).millisecondsSinceEpoch,
      // Keep deskLevel so an older build can still open the lobby.
      'deskLevel': lobbyLevel,
      'floors': stored,
    };
  }

  void _touch() {
    _lastActive = _now();
    notifyListeners();
    unawaited(persist());
  }

  void _startIdleTimer() {
    if (!enableIdleTicks) {
      return;
    }
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => advanceOneSecond(),
    );
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
      final earnedGold = offlineEarnings(
        goldPerSecond: goldPerSecond,
        away: away,
      );
      final earnedCompliance = offlineEarnings(
        goldPerSecond: compliancePerSecond,
        away: away,
      );
      _finishConstruction(now);
      _lastActive = now;
      if (earnedGold > 0 || earnedCompliance > 0) {
        pendingOfflineGold = roundMoney(pendingOfflineGold + earnedGold);
        pendingCompliance = roundMoney(pendingCompliance + earnedCompliance);
        final counted = away > offlineCap ? offlineCap : away;
        pendingOfflineSeconds += counted.inSeconds;
        notifyListeners();
      }
      unawaited(persist());
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _lastActive = _now();
      unawaited(persist());
    }
  }

  Future<void> _writeSave() async {
    final prefs = _preferences;
    if (prefs == null || _disposed) {
      return;
    }
    await prefs.setString(saveKey, jsonEncode(_saveMap()));
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
