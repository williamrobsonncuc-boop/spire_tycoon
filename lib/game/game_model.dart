import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'achievements.dart';
import 'dialogue.dart';
import 'events.dart';
import 'floor_catalog.dart';
import 'formulas.dart';
import 'managers.dart';
import 'market.dart';
import 'prestige.dart';
import 'weekend.dart';

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
    this.sleeping = false,
  });

  int level;
  bool running;
  int? constructionEndsMs;
  bool clogged;

  /// A sleeping orc stops this floor until the player taps it.
  bool sleeping;

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
    if (sleeping) {
      flags |= 4;
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
      sleeping: (flags & 4) != 0,
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
    this.crisisChance = 0.02,
    this.eventGap = 180,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random(),
       _eventWait = eventGap;

  final DateTime Function() _now;
  final bool enableIdleTicks;

  /// Chance, once a second, that the bottling plant clogs. Tests set this to 1.
  final double clogChance;

  /// Chance, once a second, that a running floor's orc falls asleep.
  final double crisisChance;

  /// Seconds of the game being open between office events. 0 turns them off.
  final int eventGap;
  int _eventWait;
  final Random _random;

  /// The happening on the tower right now, if any.
  OfficeEvent? officeEvent;

  /// When a market boom ends. Other events wait for a tap.
  int eventEndsMs = 0;

  double gold = 0;
  double compliance = 0;
  int policyLevel = 0;

  /// Milestone currency. One ticket each time a floor finishes building.
  int goldTickets = 0;

  /// Practice premium currency. Not bought with real money.
  int testDiamonds = 0;

  /// Prestige currency. Each point is +10% gold. Restructuring grants it later.
  int equity = 0;

  /// When true, the office stays quiet. Saved with the rest of the game.
  bool muted = false;

  /// 0 = appointment, 1 = hire intern, 2 = build floor 2, 3 = free briefcase, 4 = done.
  int tutorialStep = 0;

  int loginStreak = 0;
  int streakFreezes = 1;
  String questDay = '';
  String questWeek = '';
  int tapsToday = 0;
  int buildsThisWeek = 0;
  int recruitsThisWeek = 0;
  bool dailyTapClaimed = false;
  bool weeklyBuildClaimed = false;
  bool weeklyRecruitClaimed = false;
  String lastLoginDay = '';
  double pendingLoginGold = 0;

  int weekendWeek = 0;
  int weekendScore = 0;
  String weekendFiledDay = '';
  String marketFoughtDay = '';
  MarketFight? lastMarketFight;

  /// Gold ever earned, including gold you have already spent.
  double lifetimeGold = 0;
  int marketWins = 0;
  final Set<String> claimedAchievements = {};
  final Set<String> discoveredCreatures = {};

  /// Set when an upgrade crosses 10, 25, 50... Cleared when the player taps it.
  String? celebration;

  /// Highest district the player has already been told about. 0 is the basement.
  int highestDistrict = 0;
  String? districtNotice;

  /// The boss attempt currently on the clock, if any.
  int? bossFloor;
  int? bossEndsMs;
  double bossTarget = 0;
  double _bossStake = 0;

  final Map<ManagerId, int> managers = {};
  ManagerId? lastHire;
  String? lastQuip;
  int _quipIndex = 0;

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

  /// Each Shareholder Equity point is another +10% gold.
  double get equityMultiplier => 1 + equity * 0.10;

  /// Highest floor index that is open. The lobby is 0.
  int get highestRunningFloor {
    var highest = 0;
    for (final entry in floors.entries) {
      if (entry.value.running && entry.key > highest) {
        highest = entry.key;
      }
    }
    return highest;
  }

  /// Equity you would earn by restructuring. The lobby alone is not enough.
  int get restructuringEquity =>
      highestRunningFloor < 1 ? 0 : highestRunningFloor;

  /// How many times this tower has been restructured. Unlocks stay.
  int restructures = 0;

  /// Cosmetic background. "standard" follows the district tint.
  String selectedSkin = 'standard';

  /// Buys the cheapest running-floor upgrade once a second.
  bool autoUpgrade = false;

  bool get autoUpgradeUnlocked => restructures >= 3;

  String get nextPrestigePreview {
    for (final reward in prestigeRewards) {
      if (restructures < reward.at) {
        return 'Next restructuring unlocks ${reward.title}. ${reward.detail}';
      }
    }
    return 'Every later restructuring still adds Shareholder Equity. The listed rewards are already yours.';
  }

  String get unlockedPrestigeSummary {
    final names = [
      for (final reward in prestigeRewards)
        if (restructures >= reward.at) reward.title,
    ];
    if (names.isEmpty) {
      return 'No restructuring rewards yet.';
    }
    return 'Unlocked: ${names.join(', ')}.';
  }

  /// Stars, capped at 5. A sixth copy becomes a Gold Ticket instead.
  int copies(ManagerId id) {
    final count = managers[id] ?? 0;
    if (count < 0) {
      return 0;
    }
    return count > 5 ? 5 : count;
  }

  double get collectionBonus =>
      1 + 0.05 * completedDistrictSets(discoveredCreatures);

  /// Research levels. 0 speed, 1 offline hours, 2 cheaper builds, 3 stronger taps.
  final List<int> researchLevels = [0, 0, 0, 0];

  static const int researchCap = 10;

  /// Research opens with floor 10 so the early tower is not a menu of systems.
  bool get researchOpen => highestRunningFloor >= 9;

  int researchLevel(int branch) {
    if (branch < 0 || branch >= researchLevels.length) {
      return 0;
    }
    final level = researchLevels[branch];
    if (level < 0) {
      return 0;
    }
    return level > researchCap ? researchCap : level;
  }

  bool researchUsesEquity(int branch) => branch == 1 || branch == 3;

  double researchCost(int branch) {
    final level = researchLevel(branch);
    return positiveCost(20 * safePow(1.6, level));
  }

  double get researchSpeed => 1 + 0.05 * researchLevel(0);

  Duration get offlineResearchCap => offlineCapFor(researchLevel(1));

  double get researchBuildDiscount {
    final cut = 0.03 * researchLevel(2);
    return cut > 0.3 ? 0.3 : cut;
  }

  double get researchTapBonus => 1 + 0.02 * researchLevel(3);

  /// Gary's +2% speed per copy.
  double get speedBonus => 1 + 0.02 * copies(ManagerId.gary);

  /// Vlad's +300% offline earnings per copy. One Vlad means 4× offline gold.
  double get offlineBonus => 1 + 3.0 * copies(ManagerId.vlad);

  /// Construction time after Karen and the Lich. Cuts never pass 75%.
  int constructionSeconds(int index) {
    final base = floorBuildSeconds(index);
    if (base <= 0) {
      return 0;
    }
    var cut = 0.15 * copies(ManagerId.karen) + 0.50 * copies(ManagerId.lich);
    if (cut > 0.75) {
      cut = 0.75;
    }
    final seconds = (base * (1 - cut)).round();
    return seconds < 1 ? 1 : seconds;
  }

  double get policyCost => positiveCost(8 * safePow(1.55, policyLevel));

  /// Average gold per second, including the necromancy floor's lumps.
  double get goldPerSecond {
    var total = 0.0;
    for (final index in floors.keys) {
      total += goldRateFor(index);
    }
    return total;
  }

  /// What the header shows. A boom doubles it. An outage shows zero.
  double get liveGoldPerSecond {
    if (officeEvent == OfficeEvent.outage) {
      return 0;
    }
    if (officeEvent == OfficeEvent.boom) {
      return goldPerSecond * 2;
    }
    return goldPerSecond;
  }

  /// Gold from tapping a courier or a party. Never tiny, never past 1T.
  double get eventPayout {
    final raw = goldPerSecond * 20;
    if (raw.isNaN || raw.isInfinite || raw < 5) {
      return 5;
    }
    if (raw > 1e12) {
      return 1e12;
    }
    return roundMoney(raw);
  }

  String get eventLine {
    switch (officeEvent) {
      case OfficeEvent.courier:
        return 'A golden goblin courier is waiting. Tap to take the pouch.';
      case OfficeEvent.boom:
        final leftMs = eventEndsMs - _now().millisecondsSinceEpoch;
        final left = (leftMs / 1000).ceil();
        final seconds = left < 0 ? 0 : left;
        return 'Market Boom. Gold income is doubled for another $seconds seconds.';
      case OfficeEvent.party:
        return 'The office is having a party. Tap to take a slice of cake.';
      case OfficeEvent.outage:
        return 'The lights are out. Tap to restore power. Income waits until you do.';
      case null:
        return '';
    }
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
    if (progress == null ||
        !progress.running ||
        progress.clogged ||
        progress.sleeping) {
      return 0;
    }
    if (floorKind(index, prestige: restructures) == FloorKind.compliance) {
      return 0;
    }
    var rate =
        floorBaseGold(index, prestige: restructures) *
        (1 + progress.level) *
        goldMultiplier *
        speedBonus *
        equityMultiplier *
        milestoneSpeed(progress.level) *
        collectionBonus *
        researchSpeed;
    // Gary's first copy doubles the forge. Brutus buffs every heavy floor.
    if (index == 1 && copies(ManagerId.gary) > 0) {
      rate *= 2;
    }
    if (isHeavyFloor(index) && copies(ManagerId.brutus) > 0) {
      rate *= 1 + 0.40 * copies(ManagerId.brutus);
    }
    return rate;
  }

  double complianceRateFor(int index) {
    final progress = floors[index];
    if (progress == null || !progress.running) {
      return 0;
    }
    if (floorKind(index, prestige: restructures) != FloorKind.compliance) {
      return 0;
    }
    return floorBaseCompliance(index) *
        (1 + progress.level) *
        milestoneSpeed(progress.level);
  }

  void _creditLifetime(double amount) {
    if (amount.isNaN || amount.isInfinite || amount <= 0) {
      return;
    }
    final next = lifetimeGold + amount;
    lifetimeGold = next.isNaN || next.isInfinite || next > 1e300 ? 1e300 : next;
  }

  void dismissCelebration() {
    if (celebration == null) {
      return;
    }
    celebration = null;
    notifyListeners();
  }

  void dismissDistrictNotice() {
    if (districtNotice == null) {
      return;
    }
    districtNotice = null;
    _touch();
  }

  int get districtTint {
    final skin = towerSkinById(selectedSkin);
    if (skin != null && skin.tint != 0 && restructures >= skin.unlockAt) {
      return skin.tint;
    }
    return districtAt(highestDistrict).tint;
  }

  void selectSkin(String id) {
    final skin = towerSkinById(id);
    if (skin == null || restructures < skin.unlockAt) {
      return;
    }
    selectedSkin = id;
    _touch();
  }

  void toggleAutoUpgrade() {
    if (!autoUpgradeUnlocked) {
      autoUpgrade = false;
      return;
    }
    autoUpgrade = !autoUpgrade;
    _touch();
  }

  void _noteDistrict(int floorIndex, {required bool announce}) {
    final district = districtIndexForFloor(floorIndex);
    if (district <= highestDistrict) {
      return;
    }
    highestDistrict = district;
    if (announce && district > 0) {
      districtNotice = 'New District Unlocked: ${districtAt(district).name}';
    }
  }

  bool canBuild(int index) {
    if (bossFloor != null ||
        index <= 0 ||
        isRunning(index) ||
        isBuilding(index)) {
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
    final earnedGold =
        offlineEarnings(
          goldPerSecond: goldPerSecond,
          away: away,
          cap: offlineResearchCap,
        ) *
        offlineBonus;
    final earnedCompliance =
        offlineEarnings(
          goldPerSecond: compliancePerSecond,
          away: away,
          cap: offlineResearchCap,
        ) *
        offlineBonus;
    if (earnedGold > 0 || earnedCompliance > 0) {
      pendingOfflineGold = roundMoney(pendingOfflineGold + earnedGold);
      pendingCompliance = roundMoney(pendingCompliance + earnedCompliance);
      final counted = away > offlineCap ? offlineCap : away;
      pendingOfflineSeconds += counted.inSeconds;
    }
    // Floors that finished while the game was closed open now.
    // They were not included in the payout above.
    _resolveBoss(now);
    _finishConstruction(now);
    _lastActive = now;
    _rollDailyLogin(now);
    _syncWeekend(now);
    _syncQuests(now);

    ready = true;
    await persist();
    if (_disposed) {
      return;
    }
    _startIdleTimer();
    _listenForBackground();
    notifyListeners();
  }

  bool get canFileWeekendReport {
    final now = _now();
    return isWeekend(now) &&
        weekendWeek == weekKey(now) &&
        weekendFiledDay != dayKey(now);
  }

  /// Updates the daily streak and the weekend week. Safe to call often.
  void prepareCalendar() {
    final now = _now();
    _syncWeekend(now);
    _rollDailyLogin(now);
    _syncQuests(now);
  }

  /// Quests start once Floor 3 is open, so the first floors stay simple.
  bool get questsOpen => highestRunningFloor >= 2;

  /// Adds one minute of tower income to this week's local score.
  void fileWeekendReport() {
    final now = _now();
    _syncWeekend(now);
    if (!isWeekend(now) || weekendFiledDay == dayKey(now)) {
      return;
    }
    weekendScore = addScore(weekendScore, weekendReportPoints(goldPerSecond));
    weekendFiledDay = dayKey(now);
    _touch();
  }

  bool get canFightMarket => marketFoughtDay != dayKey(_now());

  /// Runs today's boardroom campaign. A second tap the same day does nothing.
  void fightMarket() {
    if (!canFightMarket) {
      return;
    }
    final fight = runMarketFight(
      power: goldPerSecond,
      seed: weekKey(_now()) + loginStreak + goldPerTap,
    );
    marketFoughtDay = dayKey(_now());
    lastMarketFight = fight;
    if (fight.won && fight.reward > 0) {
      gold = roundMoney(gold + fight.reward);
      _creditLifetime(fight.reward);
      marketWins += 1;
    }
    _checkAchievements();
    _touch();
  }

  void collectLoginBonus() {
    if (pendingLoginGold <= 0) {
      return;
    }
    _creditLifetime(pendingLoginGold);
    gold = roundMoney(gold + pendingLoginGold);
    pendingLoginGold = 0;
    _checkAchievements();
    _touch();
  }

  void _rollDailyLogin(DateTime now) {
    final today = dayKey(now);
    if (lastLoginDay == today) {
      return;
    }
    if (lastLoginDay == yesterdayKey(now)) {
      loginStreak += 1;
    } else if (lastLoginDay.isNotEmpty && streakFreezes > 0) {
      // A freeze keeps the streak. The player still checks in today.
      streakFreezes -= 1;
    } else {
      loginStreak = 1;
    }
    if (loginStreak < 1) {
      loginStreak = 1;
    }
    lastLoginDay = today;
    pendingLoginGold = roundMoney(10.0 * loginStreak);
  }

  void _syncWeekend(DateTime now) {
    final week = weekKey(now);
    if (weekendWeek != week) {
      weekendWeek = week;
      weekendScore = 0;
      weekendFiledDay = '';
    }
  }

  void acceptAppointment() {
    if (tutorialStep != 0) {
      return;
    }
    tutorialStep = 1;
    _touch();
  }

  /// Practice shop. Adds labelled TEST diamonds. No payment is taken.
  void grantTestDiamonds(int amount) {
    if (amount <= 0) {
      return;
    }
    testDiamonds += amount;
    _touch();
  }

  void toggleMute() {
    muted = !muted;
    _touch();
  }

  void tapLobby() {
    _syncQuests(_now());
    tapsToday += 1;
    final gained = goldPerTap * researchTapBonus;
    gold = roundMoney(gold + gained);
    _creditLifetime(gained);
    lastQuip = corporateLines[_quipIndex % corporateLines.length];
    _quipIndex += 1;
    if (tutorialStep == 1) {
      tutorialStep = 2;
    }
    _touch();
  }

  void startBuild(int index) {
    if (index <= 0 || isRunning(index) || isBuilding(index)) {
      return;
    }
    if (!isRunning(index - 1)) {
      return;
    }
    final cost = roundMoney(
      floorBuildCost(index) * (1 - researchBuildDiscount),
    );
    if (gold + 0.001 < cost) {
      return;
    }
    if (isBossFloor(index)) {
      _startBoss(index, cost);
      return;
    }
    gold = roundMoney(gold - cost);
    floors[index] = FloorProgress(
      constructionEndsMs:
          _now().millisecondsSinceEpoch + constructionSeconds(index) * 1000,
    );
    if (index == 1 && tutorialStep == 2) {
      tutorialStep = 3;
    }
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
    final previous = progress.level;
    progress.level += 1;
    if (crossedMilestone(previous, progress.level)) {
      final floorNumber = index + 1;
      celebration =
          'Floor $floorNumber reached level ${progress.level}. Speed doubled.';
    }
    _checkAchievements();
    _touch();
  }

  /// The first-day briefcase. Always Brutus, and it does not cost a ticket.
  void openWelcomeBriefcase() {
    if (tutorialStep != 3) {
      return;
    }
    managers[ManagerId.brutus] = copies(ManagerId.brutus) + 1;
    recruitsThisWeek += 1;
    lastHire = ManagerId.brutus;
    tutorialStep = 4;
    _touch();
  }

  /// Spends one Gold Ticket and hires whoever the roll lands on.
  void openBriefcase({double? roll}) {
    if (goldTickets < 1) {
      return;
    }
    goldTickets -= 1;
    final hire = managerForRoll(roll ?? _random.nextDouble());
    if (copies(hire) >= 5) {
      goldTickets += 1;
    } else {
      managers[hire] = copies(hire) + 1;
    }
    recruitsThisWeek += 1;
    lastHire = hire;
    _checkAchievements();
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

  void wakeFloor(int index) {
    final progress = floors[index];
    if (progress == null || !progress.sleeping) {
      return;
    }
    progress.sleeping = false;
    _touch();
  }

  /// Spends one TEST diamond to open the floor right now.
  /// The usual "floor finished" diamond is not granted, so this actually costs one.
  void skipBuildWithDiamond(int index) {
    if (testDiamonds < 1 || !isBuilding(index)) {
      return;
    }
    testDiamonds -= 1;
    _openFloor(floors[index]!, index: index, grantDiamond: false);
    _touch();
  }

  /// Cuts the remaining construction time in half. Used after the practice ad.
  void halveBuild(int index) {
    final left = buildSecondsLeft(index);
    final progress = floors[index];
    if (left == null || progress == null) {
      return;
    }
    final halved = (left / 2).ceil();
    progress.constructionEndsMs = _now().millisecondsSinceEpoch + halved * 1000;
    _touch();
  }

  /// Wipes the run and keeps Shareholder Equity, which multiplies gold forever.
  ///
  /// TEST diamonds stay, because they are a practice currency, not progress.
  /// The endless tower comes back from the same recipes, starting at the lobby.
  void restructure() {
    final gain = restructuringEquity;
    if (gain <= 0) {
      return;
    }
    equity += gain;
    restructures += 1;
    if (restructures > 100) {
      restructures = 100;
    }
    gold = 0;
    compliance = 0;
    policyLevel = 0;
    goldTickets = 0;
    managers.clear();
    lastHire = null;
    pendingOfflineGold = 0;
    pendingCompliance = 0;
    pendingOfflineSeconds = 0;
    _slowCharge = 0;
    bossFloor = null;
    bossEndsMs = null;
    bossTarget = 0;
    _bossStake = 0;
    officeEvent = null;
    eventEndsMs = 0;
    _eventWait = eventGap;
    floors
      ..clear()
      ..[0] = FloorProgress(running: true);
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
    prepareCalendar();
    _resolveBoss(now);
    _finishConstruction(now);
    _expireEvent(now);
    _produce(const Duration(seconds: 1));
    _rollClogs();
    _rollSleepingOrcs();
    _rollOfficeEvent();
    _autoUpgrade();
    _checkAchievements();
    _lastActive = now;
    notifyListeners();
    unawaited(persist());
  }

  void collectOffline({bool doubled = false}) {
    if (pendingOfflineGold <= 0 && pendingCompliance <= 0) {
      return;
    }
    final factor = doubled ? 2.0 : 1.0;
    final payout = pendingOfflineGold * factor;
    _creditLifetime(payout);
    gold = roundMoney(gold + payout);
    compliance = roundMoney(compliance + pendingCompliance * factor);
    pendingOfflineGold = 0;
    pendingCompliance = 0;
    pendingOfflineSeconds = 0;
    _touch();
  }

  Future<void> persist() => _writeSave();

  void _produce(Duration elapsed) {
    if (officeEvent == OfficeEvent.outage) {
      return;
    }
    final seconds = elapsed.inMilliseconds / 1000;
    if (seconds <= 0) {
      return;
    }
    var goldGain = 0.0;
    var complianceGain = 0.0;
    for (final index in floors.keys.toList()) {
      final kind = floorKind(index, prestige: restructures);
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
    if (officeEvent == OfficeEvent.boom && goldGain > 0) {
      goldGain *= 2;
    }
    if (goldGain > 0) {
      gold = roundMoney(gold + goldGain);
      _creditLifetime(goldGain);
    }
    if (complianceGain != 0) {
      compliance = roundMoney(compliance + complianceGain);
    }
  }

  void _startBoss(int index, double cost) {
    if (bossFloor != null) {
      return;
    }
    gold = roundMoney(gold - cost);
    _bossStake = cost;
    bossFloor = index;
    bossEndsMs = _now().millisecondsSinceEpoch + 45 * 1000;
    final current = goldPerSecond;
    final base = current.isFinite && current > 0 ? current : 0;
    bossTarget = positiveCost(base * 1.5 + 1);
    floors[index] = FloorProgress();
    _touch();
  }

  int? get bossSecondsLeft {
    final ends = bossEndsMs;
    if (bossFloor == null || ends == null) {
      return null;
    }
    final leftMs = ends - _now().millisecondsSinceEpoch;
    if (leftMs <= 0) {
      return 0;
    }
    return (leftMs / 1000).ceil();
  }

  void _resolveBoss(DateTime now) {
    final index = bossFloor;
    final ends = bossEndsMs;
    if (index == null || ends == null) {
      return;
    }
    final success = goldPerSecond + 0.0001 >= bossTarget;
    if (!success && now.millisecondsSinceEpoch < ends) {
      return;
    }
    if (success) {
      final reward = bossTarget * 30;
      final paid = reward.isFinite && reward > 0
          ? (reward > 1e12 ? 1e12 : reward)
          : 0.0;
      gold = roundMoney(gold + paid);
      _creditLifetime(paid);
      floors[index] = FloorProgress(running: true);
      if (copies(ManagerId.karen) >= 5) {
        goldTickets += 1;
      } else {
        managers[ManagerId.karen] = copies(ManagerId.karen) + 1;
      }
      discoveredCreatures.add(creatureOnFloor(index));
      lastHire = ManagerId.karen;
      celebration =
          '${bossChallengeName(index)} cleared. Karen joined the staff.';
      _noteDistrict(index, announce: true);
      goldTickets += 1;
    } else {
      gold = roundMoney(gold + _bossStake);
      floors.remove(index);
    }
    bossFloor = null;
    bossEndsMs = null;
    bossTarget = 0;
    _bossStake = 0;
  }

  void _finishConstruction(DateTime now) {
    final nowMs = now.millisecondsSinceEpoch;
    for (final entry in floors.entries) {
      final progress = entry.value;
      final ends = progress.constructionEndsMs;
      if (ends != null && !progress.running && ends <= nowMs) {
        _openFloor(progress, index: entry.key, grantDiamond: true);
      }
    }
  }

  void _openFloor(
    FloorProgress progress, {
    required int index,
    required bool grantDiamond,
  }) {
    progress.running = true;
    progress.constructionEndsMs = null;
    goldTickets += 1;
    buildsThisWeek += 1;
    if (grantDiamond) {
      testDiamonds += 1;
    }
    _noteDistrict(index, announce: true);
    discoveredCreatures.add(creatureOnFloor(index));
  }

  void _syncQuests(DateTime now) {
    final today = dayKey(now);
    if (questDay != today) {
      questDay = today;
      tapsToday = 0;
      dailyTapClaimed = false;
    }
    final week = weekKey(now).toString();
    if (questWeek != week) {
      questWeek = week;
      buildsThisWeek = 0;
      recruitsThisWeek = 0;
      weeklyBuildClaimed = false;
      weeklyRecruitClaimed = false;
    }
  }

  bool canBuyResearch(int branch) {
    if (!researchOpen || researchLevel(branch) >= researchCap) {
      return false;
    }
    final cost = researchCost(branch);
    if (researchUsesEquity(branch)) {
      return equity >= cost;
    }
    return compliance + 0.001 >= cost;
  }

  void buyResearch(int branch) {
    if (!canBuyResearch(branch)) {
      return;
    }
    final cost = researchCost(branch);
    if (researchUsesEquity(branch)) {
      equity -= cost.ceil();
      if (equity < 0) {
        equity = 0;
      }
    } else {
      compliance = roundMoney(compliance - cost);
    }
    researchLevels[branch] = researchLevel(branch) + 1;
    _touch();
  }

  void claimDailyTaps() {
    if (!questsOpen || tapsToday < 25 || dailyTapClaimed) {
      return;
    }
    dailyTapClaimed = true;
    gold = roundMoney(gold + 25);
    _creditLifetime(25);
    if (streakFreezes < 2) {
      streakFreezes += 1;
    }
    _touch();
  }

  void claimWeeklyBuild() {
    if (!questsOpen || buildsThisWeek < 1 || weeklyBuildClaimed) {
      return;
    }
    weeklyBuildClaimed = true;
    goldTickets += 1;
    _touch();
  }

  void claimWeeklyRecruit() {
    if (!questsOpen || recruitsThisWeek < 3 || weeklyRecruitClaimed) {
      return;
    }
    weeklyRecruitClaimed = true;
    goldTickets += 1;
    _touch();
  }

  void _rollSleepingOrcs() {
    for (final entry in floors.entries) {
      if (entry.key == 0) {
        continue;
      }
      final progress = entry.value;
      if (!progress.running || progress.sleeping || progress.clogged) {
        continue;
      }
      if (_random.nextDouble() < crisisChance) {
        progress.sleeping = true;
      }
    }
  }

  void _autoUpgrade() {
    if (!autoUpgrade || !autoUpgradeUnlocked) {
      return;
    }
    int? bestIndex;
    var bestCost = double.infinity;
    for (final entry in floors.entries) {
      final progress = entry.value;
      if (!progress.running) {
        continue;
      }
      final cost = floorUpgradeCost(entry.key, progress.level);
      if (cost < bestCost) {
        bestCost = cost;
        bestIndex = entry.key;
      }
    }
    if (bestIndex == null || gold + 0.001 < bestCost) {
      return;
    }
    upgradeFloor(bestIndex);
  }

  void _expireEvent(DateTime now) {
    if (officeEvent == OfficeEvent.boom &&
        now.millisecondsSinceEpoch >= eventEndsMs) {
      officeEvent = null;
      eventEndsMs = 0;
    }
  }

  void _rollOfficeEvent() {
    if (officeEvent != null || eventGap <= 0) {
      return;
    }
    _eventWait -= 1;
    if (_eventWait > 0) {
      return;
    }
    _eventWait = eventGap;
    final roll = _random.nextInt(OfficeEvent.values.length);
    officeEvent = OfficeEvent.values[roll];
    if (officeEvent == OfficeEvent.boom) {
      eventEndsMs = _now().millisecondsSinceEpoch + 60 * 1000;
    }
  }

  /// Collects a courier or a party, or switches the lights back on.
  void resolveOfficeEvent() {
    final event = officeEvent;
    if (event == null || event == OfficeEvent.boom) {
      return;
    }
    if (event == OfficeEvent.courier || event == OfficeEvent.party) {
      final payout = eventPayout;
      gold = roundMoney(gold + payout);
      _creditLifetime(payout);
    }
    officeEvent = null;
    eventEndsMs = 0;
    _touch();
  }

  void _rollClogs() {
    for (final entry in floors.entries) {
      if (floorKind(entry.key, prestige: restructures) != FloorKind.clog) {
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
      goldTickets = (map['tickets'] as num?)?.toInt() ?? 0;
      testDiamonds = (map['diamonds'] as num?)?.toInt() ?? 0;
      equity = (map['equity'] as num?)?.toInt() ?? 0;
      muted = (map['muted'] as num?) == 1;
      final storedTutorial = (map['tutorial'] as num?)?.toInt();
      final deskLevelForTutorial = (map['deskLevel'] as num?)?.toInt() ?? 0;
      if (storedTutorial != null) {
        tutorialStep = storedTutorial;
      } else if (gold > 0 || deskLevelForTutorial > 0) {
        // Older saves already played. Don't drop the first-day script on them.
        tutorialStep = 4;
      } else {
        tutorialStep = 0;
      }
      managers.clear();
      final rawManagers = map['managers'];
      if (rawManagers is Map) {
        for (final id in ManagerId.values) {
          final count = rawManagers[id.name];
          if (count is num && count > 0) {
            managers[id] = count.toInt();
          }
        }
      }
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
          if (entry is! List || entry.length < 4) {
            continue;
          }
          try {
            final index = (entry[0] as num).toInt();
            if (index < 0 || index > 100000) {
              continue;
            }
            final progress = FloorProgress.fromTuple(entry);
            if (progress.level < 0) {
              progress.level = 0;
            }
            if (progress.level > 100000) {
              progress.level = 100000;
            }
            floors[index] = progress;
          } catch (_) {
            // One bad floor should not throw away the rest of the save.
          }
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
      if (storedTutorial == null && floors.length > 1) {
        tutorialStep = 4;
      }
      highestDistrict = (map['highestDistrict'] as num?)?.toInt() ?? 0;
      if (highestDistrict < 0) {
        highestDistrict = 0;
      }
      final storedNotice = map['districtNotice'];
      districtNotice = storedNotice is String && storedNotice.isNotEmpty
          ? storedNotice
          : null;
      final storedBoss = (map['bossFloor'] as num?)?.toInt();
      bossFloor = storedBoss != null && storedBoss >= 0 ? storedBoss : null;
      final storedBossEnds = (map['bossEndsMs'] as num?)?.toInt();
      bossEndsMs = storedBossEnds != null && storedBossEnds > 0
          ? storedBossEnds
          : null;
      bossTarget = roundMoney((map['bossTarget'] as num?)?.toDouble() ?? 0);
      _bossStake = roundMoney((map['bossStake'] as num?)?.toDouble() ?? 0);
      if (bossFloor == null || bossEndsMs == null) {
        bossFloor = null;
        bossEndsMs = null;
        bossTarget = 0;
        _bossStake = 0;
      }
      for (final entry in floors.entries) {
        if (entry.value.running) {
          _noteDistrict(entry.key, announce: false);
          discoveredCreatures.add(creatureOnFloor(entry.key));
        }
      }
      _sanitizeLoadedNumbers();
      loginStreak = (map['loginStreak'] as num?)?.toInt() ?? 0;
      streakFreezes = (map['streakFreezes'] as num?)?.toInt() ?? 1;
      if (streakFreezes < 0) {
        streakFreezes = 0;
      }
      if (streakFreezes > 2) {
        streakFreezes = 2;
      }
      questDay = map['questDay'] as String? ?? '';
      questWeek = map['questWeek'] as String? ?? '';
      tapsToday = (map['tapsToday'] as num?)?.toInt() ?? 0;
      buildsThisWeek = (map['buildsThisWeek'] as num?)?.toInt() ?? 0;
      recruitsThisWeek = (map['recruitsThisWeek'] as num?)?.toInt() ?? 0;
      dailyTapClaimed = map['dailyTapClaimed'] == true;
      weeklyBuildClaimed = map['weeklyBuildClaimed'] == true;
      weeklyRecruitClaimed = map['weeklyRecruitClaimed'] == true;
      if (tapsToday < 0) {
        tapsToday = 0;
      }
      final rawResearch = map['research'];
      if (rawResearch is List) {
        for (
          var i = 0;
          i < researchLevels.length && i < rawResearch.length;
          i++
        ) {
          final level = rawResearch[i];
          if (level is num) {
            var value = level.toInt();
            if (value < 0) {
              value = 0;
            }
            if (value > researchCap) {
              value = researchCap;
            }
            researchLevels[i] = value;
          }
        }
      }
      final rawEvent = map['event'];
      officeEvent = rawEvent is String ? officeEventFromName(rawEvent) : null;
      final rawEnds = map['eventEndsMs'];
      eventEndsMs = rawEnds is num ? rawEnds.toInt() : 0;
      if (officeEvent == OfficeEvent.boom &&
          eventEndsMs <= now.millisecondsSinceEpoch) {
        officeEvent = null;
        eventEndsMs = 0;
      }
      if (officeEvent != OfficeEvent.boom) {
        eventEndsMs = 0;
      }
      restructures = (map['restructures'] as num?)?.toInt() ?? 0;
      if (restructures < 0) {
        restructures = 0;
      }
      if (restructures > 100) {
        restructures = 100;
      }
      final rawSkin = map['skin'];
      selectedSkin = rawSkin is String ? rawSkin : 'standard';
      if (towerSkinById(selectedSkin) == null ||
          restructures < (towerSkinById(selectedSkin)?.unlockAt ?? 1)) {
        selectedSkin = 'standard';
      }
      autoUpgrade = (map['autoUpgrade'] as num?) == 1 && restructures >= 3;
      final rawWait = map['eventWait'];
      final wait = rawWait is num ? rawWait.toInt() : null;
      if (wait == null || wait < 0 || wait > eventGap) {
        _eventWait = eventGap;
      } else {
        _eventWait = wait;
      }
      lastLoginDay = map['lastLoginDay'] as String? ?? '';
      pendingLoginGold = roundMoney(
        (map['pendingLoginGold'] as num?)?.toDouble() ?? 0,
      );
      weekendWeek = (map['weekendWeek'] as num?)?.toInt() ?? 0;
      weekendScore = (map['weekendScore'] as num?)?.toInt() ?? 0;
      weekendFiledDay = map['weekendFiledDay'] as String? ?? '';
      marketFoughtDay = map['marketFoughtDay'] as String? ?? '';
      final storedLifetime = (map['lifetimeGold'] as num?)?.toDouble();
      lifetimeGold = storedLifetime ?? roundMoney(gold);
      if (lifetimeGold.isNaN || lifetimeGold.isInfinite || lifetimeGold < 0) {
        lifetimeGold = 0;
      }
      if (lifetimeGold > 1e300) {
        lifetimeGold = 1e300;
      }
      marketWins = (map['marketWins'] as num?)?.toInt() ?? 0;
      if (marketWins < 0) {
        marketWins = 0;
      }
      claimedAchievements.clear();
      final rawAchievements = map['achievements'];
      if (rawAchievements is List) {
        for (final id in rawAchievements) {
          if (id is String && achievementById(id) != null) {
            claimedAchievements.add(id);
          }
        }
      }
      discoveredCreatures.clear();
      final rawCreatures = map['discovered'];
      if (rawCreatures is List) {
        for (final name in rawCreatures) {
          if (name is String && name.isNotEmpty) {
            discoveredCreatures.add(name);
          }
        }
      }
      if (loginStreak < 0) {
        loginStreak = 0;
      }
      if (weekendScore < 0) {
        weekendScore = 0;
      }
    } catch (_) {
      gold = 0;
      compliance = 0;
      policyLevel = 0;
      goldTickets = 0;
      testDiamonds = 0;
      equity = 0;
      managers.clear();
      muted = false;
      tutorialStep = 0;
      loginStreak = 0;
      streakFreezes = 1;
      lastLoginDay = '';
      pendingLoginGold = 0;
      weekendWeek = 0;
      weekendScore = 0;
      weekendFiledDay = '';
      marketFoughtDay = '';
      lifetimeGold = 0;
      marketWins = 0;
      claimedAchievements.clear();
      discoveredCreatures.clear();
      celebration = null;
      highestDistrict = 0;
      districtNotice = null;
      bossFloor = null;
      bossEndsMs = null;
      bossTarget = 0;
      _bossStake = 0;
      officeEvent = null;
      eventEndsMs = 0;
      _eventWait = eventGap;
      for (var i = 0; i < researchLevels.length; i++) {
        researchLevels[i] = 0;
      }
      restructures = 0;
      selectedSkin = 'standard';
      autoUpgrade = false;
      floors
        ..clear()
        ..[0] = FloorProgress(running: true);
      _lastActive = now;
    }
  }

  void _sanitizeLoadedNumbers() {
    gold = roundMoney(gold);
    compliance = roundMoney(compliance);
    pendingOfflineGold = roundMoney(pendingOfflineGold);
    pendingCompliance = roundMoney(pendingCompliance);
    if (goldTickets < 0) {
      goldTickets = 0;
    }
    if (testDiamonds < 0) {
      testDiamonds = 0;
    }
    if (equity < 0) {
      equity = 0;
    }
    if (policyLevel < 0) {
      policyLevel = 0;
    }
    if (pendingOfflineSeconds < 0) {
      pendingOfflineSeconds = 0;
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
          progress.clogged ||
          progress.sleeping;
      if (touched) {
        stored.add(progress.toTuple(index));
      }
    }
    return {
      'version': 2,
      'gold': gold,
      'compliance': compliance,
      'policy': policyLevel,
      'tickets': goldTickets,
      'diamonds': testDiamonds,
      'equity': equity,
      'muted': muted ? 1 : 0,
      'tutorial': tutorialStep,
      'loginStreak': loginStreak,
      'streakFreezes': streakFreezes,
      'questDay': questDay,
      'questWeek': questWeek,
      'tapsToday': tapsToday,
      'buildsThisWeek': buildsThisWeek,
      'recruitsThisWeek': recruitsThisWeek,
      'dailyTapClaimed': dailyTapClaimed,
      'weeklyBuildClaimed': weeklyBuildClaimed,
      'weeklyRecruitClaimed': weeklyRecruitClaimed,
      'research': researchLevels,
      'restructures': restructures,
      'skin': selectedSkin,
      'autoUpgrade': autoUpgrade ? 1 : 0,
      'event': officeEvent?.name ?? '',
      'eventEndsMs': eventEndsMs,
      'eventWait': _eventWait,
      'lastLoginDay': lastLoginDay,
      'pendingLoginGold': pendingLoginGold,
      'weekendWeek': weekendWeek,
      'weekendScore': weekendScore,
      'weekendFiledDay': weekendFiledDay,
      'marketFoughtDay': marketFoughtDay,
      'lifetimeGold': lifetimeGold,
      'marketWins': marketWins,
      'achievements': claimedAchievements.toList(),
      'discovered': discoveredCreatures.toList(),
      'highestDistrict': highestDistrict,
      'districtNotice': districtNotice,
      'bossFloor': bossFloor,
      'bossEndsMs': bossEndsMs,
      'bossTarget': bossTarget,
      'bossStake': _bossStake,
      'managers': {
        for (final entry in managers.entries)
          if (entry.value > 0) entry.key.name: entry.value,
      },
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
    _checkAchievements();
    _lastActive = _now();
    notifyListeners();
    unawaited(persist());
  }

  void _checkAchievements() {
    final unlocked = <String, bool>{
      'synergy': managers.values.where((count) => count > 0).length >= 2,
      'takeover': marketWins >= 1,
      'billion': lifetimeGold >= 1000000000,
      'floor10': highestRunningFloor >= 9,
      'desk25': lobbyLevel >= 25,
    };
    for (final item in achievementCatalog) {
      if (claimedAchievements.contains(item.id)) {
        continue;
      }
      if (unlocked[item.id] == true) {
        claimedAchievements.add(item.id);
        goldTickets += item.tickets;
      }
    }
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
      // A clock jump backwards should not mint gold or a huge debt.
      if (away.isNegative) {
        _lastActive = now;
        unawaited(persist());
        return;
      }
      // Under 30 seconds, pay the gap quietly. The welcome note is for
      // a real absence, still capped at 8 hours.
      if (away < offlineMinimum) {
        _finishConstruction(now);
        _produce(away);
        _lastActive = now;
        notifyListeners();
        unawaited(persist());
        return;
      }
      final earnedGold =
          offlineEarnings(
            goldPerSecond: goldPerSecond,
            away: away,
            cap: offlineResearchCap,
          ) *
          offlineBonus;
      final earnedCompliance =
          offlineEarnings(
            goldPerSecond: compliancePerSecond,
            away: away,
            cap: offlineResearchCap,
          ) *
          offlineBonus;
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
