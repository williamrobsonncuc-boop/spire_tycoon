import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spire_tycoon/game/events.dart';
import 'package:spire_tycoon/game/floor_catalog.dart';
import 'package:spire_tycoon/game/formulas.dart';
import 'package:spire_tycoon/game/game_model.dart';

/// A player who taps, buys the next useful thing, and does not hoard.
///
/// Used to check that the first minutes always have something to buy, that
/// Floor 20 arrives in an afternoon of active play, and that a long run
/// stays finite.
class _AutoPlayer {
  _AutoPlayer(this.game);

  final GameModel game;
  final List<int> purchaseAt = [];
  int? floor20At;
  int? secondFloor20At;
  int? firstPrestigeAt;
  int? firstRunFloor10At;
  int? secondRunFloor10At;
  int prestigesAtStartOfFloor10 = 0;
  int stuckSeconds = 0;
  int lastProgressAt = 0;
  int lastFloor = 0;
  double lastGps = 0;
  int _seenPrestiges = 0;

  void act(int second, {required int taps}) {
    if (game.tutorialStep == 0) {
      game.acceptAppointment();
    }
    for (var i = 0; i < taps; i++) {
      game.tapLobby();
    }
    if (game.tutorialStep == 3) {
      game.openWelcomeBriefcase();
    }
    game.collectLoginBonus();
    if (game.canFileWeekendReport) {
      game.fileWeekendReport();
    }
    if (game.canFightMarket && game.goldPerSecond > 1) {
      game.fightMarket();
    }
    _clearCrises();
    _maybeSkipBuild();
    _buyResearch();
    if (game.canBuyPolicy) {
      game.buyPolicy();
      _bought(second, 'policy');
    }
    if (game.recruitmentOpen && game.goldTickets > 0) {
      game.openBriefcase();
    }
    if (game.autoUpgradeUnlocked && !game.autoUpgrade) {
      game.toggleAutoUpgrade();
    }

    final built = _tryBuild(second);
    if (!built) {
      _buyUpgrades(second);
    }
    _noteProgress(second);
    _maybePrestige(second);
  }

  void _clearCrises() {
    final event = game.officeEvent;
    if (event != null && event != OfficeEvent.boom) {
      game.resolveOfficeEvent();
    }
    for (final entry in game.floors.entries.toList()) {
      if (entry.value.clogged) {
        game.clearClog(entry.key);
      }
      if (entry.value.sleeping) {
        game.wakeFloor(entry.key);
      }
    }
  }

  void _maybeSkipBuild() {
    if (game.testDiamonds < 1) {
      return;
    }
    for (final entry in game.floors.entries) {
      final left = game.buildSecondsLeft(entry.key);
      if (left != null && left > 90) {
        game.skipBuildWithDiamond(entry.key);
        return;
      }
    }
  }

  void _buyResearch() {
    if (!game.researchOpen) {
      return;
    }
    for (final branch in [0, 2]) {
      if (game.canBuyResearch(branch)) {
        game.buyResearch(branch);
        return;
      }
    }
    // Equity is the prestige reward. Spend it only when there is plenty left.
    if (game.equity < 25) {
      return;
    }
    for (final branch in [1, 3]) {
      if (!game.canBuyResearch(branch)) {
        continue;
      }
      if (game.equity - game.researchCost(branch).ceil() < 20) {
        continue;
      }
      game.buyResearch(branch);
      return;
    }
  }

  bool _tryBuild(int second) {
    if (game.bossFloor != null) {
      return false;
    }
    final next = _nextFloor();
    if (next == null) {
      return false;
    }
    if (isBossFloor(next)) {
      return _tryBoss(next, second);
    }
    final cost = _buildCost(next);
    final income = _incomePerSecond();
    final secondsToSave = income <= 0 ? 9999 : (cost - game.gold) / income;
    // Hold gold for a floor that is close. Otherwise keep upgrading.
    if (secondsToSave > 40 && game.gold + 0.001 < cost) {
      return false;
    }
    if (game.gold + 0.001 < cost) {
      return false;
    }
    final before = game.gold;
    game.startBuild(next);
    if (game.gold < before) {
      _bought(second, 'build $next');
      return true;
    }
    return false;
  }

  bool _tryBoss(int index, int second) {
    final cost = _buildCost(index);
    if (game.gold + 0.001 < cost) {
      return false;
    }
    final before = game.goldPerSecond;
    final target = before * 1.5 + 1;
    // Upgrade until one more purchase can clear the audit, then start it.
    if (before + _bestUpgradeBump() + 0.01 < target) {
      return false;
    }
    game.startBuild(index);
    _buyUpgrades(second);
    return game.bossFloor == index;
  }

  double _bestUpgradeBump() {
    var best = 0.0;
    for (final entry in game.floors.entries) {
      if (!entry.value.running) {
        continue;
      }
      final cost = floorUpgradeCost(entry.key, entry.value.level);
      if (game.gold + 0.001 < cost) {
        continue;
      }
      final now = game.goldRateFor(entry.key);
      final bumped = now <= 0
          ? 0
          : now * ((entry.value.level + 2) / (entry.value.level + 1));
      if (bumped - now > best) {
        best = bumped - now;
      }
    }
    return best;
  }

  void _buyUpgrades(int second) {
    final next = _nextFloor();
    final savingForFloor =
        next != null &&
        !isBossFloor(next) &&
        _incomePerSecond() > 0 &&
        (_buildCost(next) - game.gold) / _incomePerSecond() <= 40;

    final idleLongEnough = purchaseAt.isEmpty || second - purchaseAt.last >= 25;
    for (var n = 0; n < 4; n++) {
      int? best;
      var bestPayback = double.infinity;
      for (final entry in game.floors.entries) {
        if (!entry.value.running ||
            entry.value.clogged ||
            entry.value.sleeping) {
          continue;
        }
        final cost = floorUpgradeCost(entry.key, entry.value.level);
        if (game.gold + 0.001 < cost) {
          continue;
        }
        if (savingForFloor && game.gold - cost < _buildCost(next)) {
          continue;
        }
        final rate = game.goldRateFor(entry.key);
        final gain = rate <= 0 ? 0.2 : rate / (entry.value.level + 1);
        final payback = gain <= 0 ? 9999.0 : cost / gain;
        if (payback < bestPayback) {
          bestPayback = payback;
          best = entry.key;
        }
      }
      final limit = idleLongEnough ? 180.0 : 40.0;
      if (best == null || bestPayback > limit) {
        return;
      }
      final before = game.gold;
      game.upgradeFloor(best);
      if (game.gold < before) {
        _bought(second, 'upgrade $best');
      }
    }
  }

  void _maybePrestige(int second) {
    if (!game.prestigeOpen) {
      return;
    }
    final next = _nextFloor();
    final wait = next == null || _incomePerSecond() <= 0
        ? 9999
        : max(0, _buildCost(next) - game.gold) / _incomePerSecond();
    final buildWait = next == null ? 0 : floorBuildSeconds(next);
    final first = game.restructures == 0 && (wait > 3 * 60 || buildWait >= 120);
    final later = game.restructures > 0 && (wait > 8 * 60 || buildWait >= 150);
    if (first || later) {
      final before = game.restructures;
      game.restructure();
      if (game.restructures > before) {
        firstPrestigeAt ??= second;
        _bought(second, 'prestige');
      }
    }
  }

  void _bought(int second, String label) {
    purchaseAt.add(second);
  }

  void _noteProgress(int second) {
    final floor = game.highestRunningFloor;
    final reset = game.restructures != _seenPrestiges || floor + 3 < lastFloor;
    if (reset) {
      _seenPrestiges = game.restructures;
      lastFloor = 0;
      lastGps = 0;
      lastProgressAt = second;
      stuckSeconds = 0;
    }
    if (floor >= 9 && firstRunFloor10At == null && game.restructures == 0) {
      firstRunFloor10At = second;
    }
    if (floor >= 9 && secondRunFloor10At == null && game.restructures > 0) {
      secondRunFloor10At = second;
      prestigesAtStartOfFloor10 = game.restructures;
    }
    if (floor >= 19 && floor20At == null) {
      floor20At = second;
    } else if (floor >= 19 &&
        secondFloor20At == null &&
        game.restructures > 0 &&
        floor20At != null &&
        second > floor20At!) {
      secondFloor20At = second;
    }
    final gps = game.goldPerSecond;
    if (floor > lastFloor || gps > lastGps * 1.05 + 0.01) {
      lastProgressAt = second;
      lastFloor = floor;
      lastGps = gps;
      stuckSeconds = 0;
    } else {
      stuckSeconds = second - lastProgressAt;
    }
  }

  int? _nextFloor() {
    for (var index = 1; index < 80; index++) {
      if (game.isRunning(index) || game.isBuilding(index)) {
        continue;
      }
      if (!game.isRunning(index - 1)) {
        return null;
      }
      return index;
    }
    return null;
  }

  double _buildCost(int index) {
    return floorBuildCost(index) * (1 - game.researchBuildDiscount);
  }

  double _incomePerSecond() {
    final tap = game.goldPerTap * game.researchTapBonus * 1.2;
    return game.liveGoldPerSecond + tap;
  }
}

class _Report {
  _Report(this.label, this.player, this.seconds);

  final String label;
  final _AutoPlayer player;
  final int seconds;

  int gapBefore(int limit) {
    final early = player.purchaseAt.where((t) => t <= limit).toList();
    if (early.length < 2) {
      return 9999;
    }
    var worst = early.first;
    for (var i = 1; i < early.length; i++) {
      final gap = early[i] - early[i - 1];
      if (gap > worst) {
        worst = gap;
      }
    }
    return worst;
  }

  String format() {
    final game = player.game;
    return '$label ${seconds}s floor ${game.highestRunningFloor + 1} '
        'gps ${formatNumber(game.goldPerSecond)} gold ${formatNumber(game.gold)} '
        'equity ${game.equity} prestiges ${game.restructures} '
        'floor20 ${player.floor20At} again ${player.secondFloor20At} '
        'firstPrestige ${player.firstPrestigeAt} '
        'floor10 ${player.firstRunFloor10At} again ${player.secondRunFloor10At} '
        'earlyGap ${gapBefore(5 * 60)}/${gapBefore(10 * 60)}s stuck ${player.stuckSeconds}s '
        'finite ${game.gold.isFinite && game.goldPerSecond.isFinite}';
  }
}

_Report _play(int seconds, {int seed = 3}) {
  var clock = DateTime.utc(2026, 6, 1, 9);
  final game = GameModel(
    enableIdleTicks: false,
    now: () => clock,
    random: Random(seed),
    netWorthEvery: 0,
  );
  addTearDown(game.dispose);
  game.floors[0] = FloorProgress(running: true);
  final player = _AutoPlayer(game);
  for (var second = 1; second <= seconds; second++) {
    clock = clock.add(const Duration(seconds: 1));
    game.advanceOneSecond();
    final taps = second < 10 * 60
        ? 3
        : second < 2 * 60 * 60
        ? 2
        : 1;
    player.act(second, taps: taps);
    if (!game.gold.isFinite || !game.goldPerSecond.isFinite) {
      break;
    }
  }
  return _Report(_label(seconds), player, seconds);
}

String _label(int seconds) {
  if (seconds <= 2 * 3600) {
    return '2h';
  }
  if (seconds <= 24 * 3600) {
    return '1d';
  }
  return '1w';
}

void main() {
  test('two hours of active play reaches a worthwhile prestige', () {
    final report = _play(2 * 60 * 60);
    // ignore: avoid_print
    expect(report.player.game.gold.isFinite, isTrue);
    expect(report.player.game.goldPerSecond.isFinite, isTrue);
    expect(report.gapBefore(5 * 60), lessThan(35));
    expect(report.gapBefore(10 * 60), lessThan(75));
    expect(report.player.floor20At, isNotNull);
    expect(report.player.floor20At!, greaterThan(45 * 60));
    expect(report.player.floor20At!, lessThan(2 * 60 * 60));
    expect(report.player.firstPrestigeAt, isNotNull);
    expect(report.player.firstPrestigeAt!, lessThan(2 * 60 * 60));
    expect(report.player.stuckSeconds, lessThan(20 * 60));
    expect(report.player.secondFloor20At, isNotNull);
    final firstClimb = report.player.floor20At!;
    final secondClimb =
        report.player.secondFloor20At! - report.player.firstPrestigeAt!;
    expect(secondClimb, lessThan(firstClimb * 0.7));
  });

  test('a day and a week of play stay finite and keep moving', () {
    final day = _play(24 * 60 * 60, seed: 5);
    // ignore: avoid_print
    expect(day.player.game.gold.isFinite, isTrue);
    expect(day.player.game.goldPerSecond.isFinite, isTrue);
    expect(day.player.game.goldPerSecond, greaterThan(1));
    expect(day.player.stuckSeconds, lessThan(30 * 60));
    expect(day.player.game.restructures, greaterThan(0));

    final week = _play(7 * 24 * 60 * 60, seed: 9);
    // ignore: avoid_print
    expect(week.player.game.gold.isFinite, isTrue);
    expect(week.player.game.goldPerSecond.isFinite, isTrue);
    expect(week.player.game.lifetimeGold, lessThan(1e300));
    expect(week.player.stuckSeconds, lessThan(60 * 60));
    expect(week.player.game.highestRunningFloor, greaterThan(10));
  });
}
