import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:math';

import 'package:spire_tycoon/game/achievements.dart';
import 'package:spire_tycoon/game/events.dart';
import 'package:spire_tycoon/game/floor_catalog.dart';
import 'package:spire_tycoon/game/formulas.dart';
import 'package:spire_tycoon/game/market.dart';
import 'package:spire_tycoon/game/weekend.dart';
import 'package:spire_tycoon/game/game_model.dart';
import 'package:spire_tycoon/game/sound_board.dart';
import 'package:spire_tycoon/game/managers.dart';
import 'package:spire_tycoon/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SoundBoard.suppressForTests = true;
  });

  test('desk upgrade cost is 10 × 1.10^level', () {
    expect(deskUpgradeCost(0), 10);
    expect(deskUpgradeCost(1), 11);
    expect(deskUpgradeCost(2), 12.1);
    expect(deskUpgradeCost(3), 13.3);
  });

  test('offline earnings wait 30 seconds and cap at 8 hours', () {
    expect(
      offlineEarnings(goldPerSecond: 0.2, away: const Duration(seconds: 29)),
      0,
    );
    expect(
      offlineEarnings(goldPerSecond: 0.2, away: const Duration(seconds: 30)),
      6,
    );
    expect(
      offlineEarnings(goldPerSecond: 0.2, away: const Duration(hours: 9)),
      offlineEarnings(goldPerSecond: 0.2, away: const Duration(hours: 8)),
    );
  });

  test('load restores gold and queues two minutes of idle pay', () async {
    final clock = DateTime.utc(2026, 1, 1, 12);
    final past = clock.subtract(const Duration(minutes: 2));
    SharedPreferences.setMockInitialValues({
      saveKey: jsonEncode({
        'version': 1,
        'gold': 50,
        'deskLevel': 0,
        'pendingOfflineGold': 0,
        'pendingOfflineSeconds': 0,
        'lastActiveMs': past.millisecondsSinceEpoch,
      }),
    });

    final game = GameModel(enableIdleTicks: false, now: () => clock);
    addTearDown(game.dispose);
    await game.load();

    expect(game.gold, 50);
    expect(game.lobbyLevel, 0);
    // 120 seconds * 0.2 gold per second.
    expect(game.pendingOfflineGold, 24);
    expect(game.goldPerTap, 1);
  });

  testWidgets('tapping the goblin earns gold and Upgrade Desk raises it', (
    WidgetTester tester,
  ) async {
    _useTallWindow(tester);
    final game = GameModel(enableIdleTicks: false, critChanceOverride: 0);
    addTearDown(game.dispose);
    await tester.pumpWidget(SpireTycoonApp(game: game));
    await _pumpUntilReady(tester);
    await _acceptAppointment(tester);

    expect(find.text('Floor 1: The Executive Lobby'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('+1 per tap'), findsOneWidget);
    expect(find.text('+0.2 per second'), findsOneWidget);

    expect(_upgradeColor(tester), const Color(0xFF334155));
    final disabledTap = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const Key('upgrade-desk')),
        matching: find.byType(InkWell),
      ),
    );
    expect(disabledTap.onTap, isNull);
    expect(find.text('Level 0'), findsOneWidget);

    for (var tap = 0; tap < 10; tap++) {
      await tester.tap(find.byKey(const Key('goblin')));
      await tester.pump();
    }

    expect(find.text('12.5'), findsOneWidget);
    expect(find.byKey(const Key('combo-meter')), findsOneWidget);
    expect(find.byKey(const Key('dialogue-bubble')), findsOneWidget);
    expect(find.text('Great hustle. The minotaurs noticed.'), findsOneWidget);
    expect(find.text('+1'), findsWidgets);
    expect(_upgradeColor(tester), const Color(0xFF10B981));

    await tester.ensureVisible(find.byKey(const Key('upgrade-desk')));
    await tester.tap(find.byKey(const Key('upgrade-desk')));
    await tester.pump();

    expect(find.text('2.5'), findsOneWidget);
    expect(find.text('+2 per tap'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Cost 11 gold'), findsOneWidget);
    expect(_upgradeColor(tester), const Color(0xFF334155));
  });

  testWidgets('welcome back pays offline gold, and the memo doubles it', (
    WidgetTester tester,
  ) async {
    final clock = DateTime.utc(2026, 1, 1, 12);
    final past = clock.subtract(const Duration(minutes: 2));
    SharedPreferences.setMockInitialValues({
      saveKey: jsonEncode({
        'version': 1,
        'gold': 50,
        'deskLevel': 0,
        'pendingOfflineGold': 0,
        'pendingOfflineSeconds': 0,
        'lastActiveMs': past.millisecondsSinceEpoch,
      }),
    });

    final game = GameModel(enableIdleTicks: false, now: () => clock);
    addTearDown(game.dispose);
    await tester.pumpWidget(SpireTycoonApp(game: game));
    await _pumpUntilReady(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('welcome-back')), findsOneWidget);
    expect(find.text('24'), findsOneWidget);

    await tester.tap(find.byKey(const Key('collect-offline')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('welcome-back')), findsNothing);
    expect(find.text('74'), findsOneWidget);
  });

  testWidgets('the sponsor memo is a 3 second practice ad that doubles pay', (
    WidgetTester tester,
  ) async {
    final clock = DateTime.utc(2026, 1, 1, 12);
    final past = clock.subtract(const Duration(minutes: 2));
    SharedPreferences.setMockInitialValues({
      saveKey: jsonEncode({
        'version': 1,
        'gold': 10,
        'deskLevel': 0,
        'pendingOfflineGold': 0,
        'pendingOfflineSeconds': 0,
        'lastActiveMs': past.millisecondsSinceEpoch,
      }),
    });

    final game = GameModel(enableIdleTicks: false, now: () => clock);
    addTearDown(game.dispose);
    await tester.pumpWidget(SpireTycoonApp(game: game));
    await _pumpUntilReady(tester);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('watch-sponsor-memo')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('PRACTICE AD'), findsOneWidget);
    expect(find.text('Sponsor memo'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('PRACTICE AD'), findsNothing);
    // 10 gold already in the wallet, plus 24 * 2 from the memo.
    expect(find.text('58'), findsOneWidget);
  });

  test('big numbers use K M B T then aa', () {
    expect(formatNumber(12.1), '12.1');
    expect(formatNumber(1200), '1.2K');
    expect(formatNumber(3.4e6), '3.4M');
    expect(formatNumber(5.6e9), '5.6B');
    expect(formatNumber(7.8e12), '7.8T');
    expect(formatNumber(1.2e15), '1.2aa');
    expect(formatNumber(3.4e18), '3.4ab');
  });

  test('the first five floors are designed and the rest are generated', () {
    expect(floorRecipe(5).name, 'Marketing (Imps)');
    expect(floorRecipe(11).title, 'Floor 12: Legal Dept II (Compliance Imps)');
    expect(floorKind(2), FloorKind.clog);
    expect(floorKind(3), FloorKind.slowBurst);
    expect(floorKind(4), FloorKind.compliance);
    expect(floorBuildCost(0), 0);
    expect(floorBuildCost(3), greaterThan(floorBuildCost(2) * 1.7));
    expect(floorBuildSeconds(8), greaterThan(floorBuildSeconds(2)));
    expect(floorBaseGold(9), greaterThan(floorBaseGold(6)));
  });

  test(
    'only touched floors are saved, and construction finishes on time',
    () async {
      final clock = DateTime.utc(2026, 6, 1, 9);
      var now = clock;
      SharedPreferences.setMockInitialValues({});
      final game = GameModel(enableIdleTicks: false, now: () => now);
      addTearDown(game.dispose);
      await game.load();

      game.gold = 100000;
      game.startBuild(1);
      await game.persist();

      final prefs = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(prefs.getString(saveKey)!) as Map<String, dynamic>;
      final storedFloors = saved['floors'] as List;
      expect(storedFloors.length, 2);
      expect(game.isBuilding(1), isTrue);

      now = now.add(Duration(seconds: floorBuildSeconds(1)));
      game.advanceOneSecond();
      expect(game.isRunning(1), isTrue);

      final cloggy = GameModel(
        enableIdleTicks: false,
        clogChance: 1,
        now: () => now,
      );
      addTearDown(cloggy.dispose);
      cloggy.floors[2] = FloorProgress(running: true);
      cloggy.advanceOneSecond();
      expect(cloggy.floors[2]!.clogged, isTrue);
      cloggy.clearClog(2);
      expect(cloggy.floors[2]!.clogged, isFalse);
    },
  );

  testWidgets('far floors are not built until they scroll into view', (
    WidgetTester tester,
  ) async {
    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    await tester.pumpWidget(SpireTycoonApp(game: game));
    await _pumpUntilReady(tester);

    expect(find.text('Floor 1: The Executive Lobby'), findsOneWidget);
    expect(find.textContaining('Legal Dept II'), findsNothing);
    expect(find.textContaining('Floor 30'), findsNothing);
  });

  test(
    'diamonds finish a build, ads halve it, and a sleeping orc pauses pay',
    () {
      final clock = DateTime.utc(2026, 4, 1, 10);
      var now = clock;
      final game = GameModel(
        enableIdleTicks: false,
        now: () => now,
        crisisChance: 1,
      );
      addTearDown(game.dispose);
      game.floors[0] = FloorProgress(running: true);
      game.gold = 100000;
      game.testDiamonds = 1;
      game.startBuild(1);
      final full = game.buildSecondsLeft(1)!;
      game.halveBuild(1);
      expect(game.buildSecondsLeft(1), (full / 2).ceil());

      game.skipBuildWithDiamond(1);
      expect(game.isRunning(1), isTrue);
      expect(game.testDiamonds, 0);
      expect(game.goldTickets, 1);

      game.advanceOneSecond();
      expect(game.floors[1]!.sleeping, isTrue);
      expect(game.goldRateFor(1), 0);
      game.wakeFloor(1);
      expect(game.floors[1]!.sleeping, isFalse);
      expect(game.goldRateFor(1), greaterThan(0));
    },
  );

  test('restructuring resets the tower and keeps equity', () {
    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    game.floors[0] = FloorProgress(running: true, level: 4);
    game.floors[1] = FloorProgress(running: true);
    game.floors[12] = FloorProgress(running: true);
    game.gold = 5000;
    game.goldTickets = 3;
    game.testDiamonds = 4;
    game.managers[ManagerId.gary] = 2;
    game.policyLevel = 2;

    expect(game.restructuringEquity, 12);
    game.restructure();

    expect(game.equity, 12);
    expect(game.gold, 0);
    expect(game.goldTickets, 0);
    expect(game.testDiamonds, 4);
    expect(game.copies(ManagerId.gary), 0);
    expect(game.lobbyLevel, 0);
    expect(game.isRunning(0), isTrue);
    expect(game.isRunning(12), isFalse);
    expect(game.isRunning(1), isFalse);
    // 12 equity points is +120% gold, so the lobby's 0.2/sec becomes 0.44.
    expect(game.goldPerSecond, closeTo(0.44, 0.001));
    expect(game.restructures, 1);
  });

  test('mute is saved with the rest of the game', () async {
    SharedPreferences.setMockInitialValues({});
    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    await game.load();
    game.toggleMute();
    await game.persist();

    final again = GameModel(enableIdleTicks: false);
    addTearDown(again.dispose);
    await again.load();
    expect(again.muted, isTrue);
  });

  test('a test purchase adds TEST diamonds and no real charge', () {
    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    game.grantTestDiamonds(5);
    expect(game.testDiamonds, 5);
    game.grantTestDiamonds(40);
    expect(game.testDiamonds, 45);
  });

  test('first day ends with a guaranteed epic briefcase', () async {
    SharedPreferences.setMockInitialValues({});
    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    await game.load();
    expect(game.tutorialStep, 0);
    game.acceptAppointment();
    game.tapLobby();
    expect(game.tutorialStep, 2);
    game.gold = 100000;
    game.startBuild(1);
    expect(game.tutorialStep, 3);
    game.openWelcomeBriefcase();
    expect(game.tutorialStep, 4);
    expect(game.copies(ManagerId.brutus), 1);
    expect(game.goldTickets, 0);
  });

  test('briefcase odds match the posted 75 / 18 / 6 / 1 split', () {
    expect(rarityForRoll(0), ManagerRarity.common);
    expect(rarityForRoll(0.749), ManagerRarity.common);
    expect(rarityForRoll(0.75), ManagerRarity.rare);
    expect(rarityForRoll(0.929), ManagerRarity.rare);
    expect(rarityForRoll(0.93), ManagerRarity.epic);
    expect(rarityForRoll(0.989), ManagerRarity.epic);
    expect(rarityForRoll(0.99), ManagerRarity.legendary);
    expect(managerForRoll(0.2), ManagerId.gary);
    expect(managerForRoll(0.8), ManagerId.karen);
    expect(managerForRoll(0.95), ManagerId.brutus);
    expect(managerForRoll(0.992), ManagerId.vlad);
    expect(managerForRoll(0.997), ManagerId.lich);
  });

  test('a briefcase hires staff and Vlad multiplies offline gold', () async {
    final clock = DateTime.utc(2026, 3, 1, 8);
    final past = clock.subtract(const Duration(minutes: 2));
    SharedPreferences.setMockInitialValues({
      saveKey: jsonEncode({
        'version': 3,
        'gold': 0,
        'deskLevel': 0,
        'pendingOfflineGold': 0,
        'pendingOfflineSeconds': 0,
        'lastActiveMs': past.millisecondsSinceEpoch,
        'tickets': 1,
        'managers': {'vlad': 1},
      }),
    });
    final game = GameModel(enableIdleTicks: false, now: () => clock);
    addTearDown(game.dispose);
    await game.load();

    // 120s * 0.2 gold/sec * 4 from one Vlad.
    expect(game.pendingOfflineGold, 96);
    expect(game.copies(ManagerId.vlad), 1);
    game.openBriefcase(roll: 0.1);
    expect(game.lastHire, ManagerId.gary);
    expect(game.copies(ManagerId.gary), 1);
    // Spending the ticket hires Gary. Vlad was already on staff, so
    // Synergy Achieved pays that ticket back.
    expect(game.goldTickets, 1);
    expect(game.claimedAchievements, contains('synergy'));
    expect(game.constructionSeconds(1), floorBuildSeconds(1));
    game.managers[ManagerId.lich] = 1;
    expect(game.constructionSeconds(1), (floorBuildSeconds(1) * 0.5).round());
  });

  testWidgets('the recruitment screen shows the odds', (tester) async {
    _useTallWindow(tester);
    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    await tester.pumpWidget(SpireTycoonApp(game: game));
    await _pumpUntilReady(tester);
    await _acceptAppointment(tester);

    await tester.ensureVisible(find.byKey(const Key('open-recruitment')));
    await tester.tap(find.byKey(const Key('open-recruitment')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('odds-table')), findsOneWidget);
    expect(find.textContaining('Common 75%'), findsOneWidget);
    expect(find.textContaining('Rare 18%'), findsOneWidget);
    expect(find.textContaining('Epic 6%'), findsOneWidget);
    expect(find.textContaining('Legendary 1%'), findsOneWidget);
    expect(find.text('Need 1 Gold Ticket'), findsOneWidget);
  });

  testWidgets('the practice shop shows prices and grants TEST diamonds', (
    tester,
  ) async {
    _useTallWindow(tester);
    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    await tester.pumpWidget(SpireTycoonApp(game: game));
    await _pumpUntilReady(tester);
    await _acceptAppointment(tester);

    await tester.tap(find.byKey(const Key('open-shop')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('practice-shop')), findsOneWidget);
    expect(find.textContaining('£1.99'), findsOneWidget);
    expect(find.textContaining('£14.99'), findsOneWidget);
    expect(find.textContaining('£89.99'), findsOneWidget);
    expect(find.textContaining('£4.99/mo'), findsOneWidget);
    expect(find.textContaining('£9.99/mo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('test-buy-intern')));
    await tester.pump();
    expect(game.testDiamonds, 5);
  });

  test('huge, tiny, and broken numbers stay finite', () {
    expect(formatNumber(double.nan), '0');
    expect(formatNumber(double.infinity), '0');
    expect(formatNumber(-1500), '-1.5K');
    expect(formatNumber(double.maxFinite), isNot('0'));
    expect(deskUpgradeCost(5000).isFinite, isTrue);
    expect(deskUpgradeCost(5000), greaterThan(deskUpgradeCost(10)));
    expect(floorBuildCost(400).isFinite, isTrue);
    expect(floorBuildCost(400), greaterThan(0));
    expect(floorBuildSeconds(400), 2000000000);
    expect(
      offlineEarnings(
        goldPerSecond: double.nan,
        away: const Duration(hours: 2),
      ),
      0,
    );
    expect(
      offlineEarnings(goldPerSecond: -5, away: const Duration(hours: 2)),
      0,
    );
    expect(
      offlineEarnings(goldPerSecond: 1e20, away: const Duration(hours: 9)),
      offlineEarnings(goldPerSecond: 1e20, away: const Duration(hours: 8)),
    );
    expect(rarityForRoll(double.nan), ManagerRarity.common);
    expect(roundMoney(-12), 0);
    expect(roundMoney(double.nan), 0);
  });

  test('a corrupted or negative save still opens on Floor 1', () async {
    SharedPreferences.setMockInitialValues({saveKey: '{'});
    final broken = GameModel(enableIdleTicks: false);
    addTearDown(broken.dispose);
    await broken.load();
    expect(broken.gold, 0);
    expect(broken.isRunning(0), isTrue);

    final past = DateTime.utc(2026, 1, 2, 12);
    SharedPreferences.setMockInitialValues({
      saveKey: jsonEncode({
        'version': 2,
        'gold': -40,
        'compliance': -8,
        'tickets': -3,
        'deskLevel': 2,
        'floors': [
          [0, 2, 1, 0],
          'nope',
          [1],
        ],
        'lastActiveMs': past.millisecondsSinceEpoch,
      }),
    });
    final game = GameModel(enableIdleTicks: false, now: () => past);
    addTearDown(game.dispose);
    await game.load();
    expect(game.gold, 0);
    expect(game.goldTickets, 0);
    expect(game.lobbyLevel, 2);
    expect(game.isRunning(0), isTrue);
  });

  test('a crit pays ten times and a pause resets the combo', () {
    var now = DateTime.utc(2026, 8, 1, 12);
    final calm = GameModel(
      enableIdleTicks: false,
      critChanceOverride: 0,
      now: () => now,
    );
    addTearDown(calm.dispose);
    calm.floors[0] = FloorProgress(running: true);
    expect(calm.tapLobby(), 1);
    expect(calm.tapLobby(), closeTo(1.1, 0.001));
    expect(calm.combo, 2);
    now = now.add(const Duration(seconds: 3));
    expect(calm.tapLobby(), 1);
    expect(calm.combo, 1);
    now = now.subtract(const Duration(minutes: 5));
    expect(calm.tapLobby(), 1);
    expect(calm.combo, 1);

    final crit = GameModel(enableIdleTicks: false, critChanceOverride: 1);
    addTearDown(crit.dispose);
    crit.floors[0] = FloorProgress(running: true);
    expect(crit.tapLobby(), 10);
    expect(crit.lastTapWasCrit, isTrue);
    expect(crit.critShake, 1);

    final huge = GameModel(enableIdleTicks: false, critChanceOverride: 1);
    addTearDown(huge.dispose);
    huge.floors[0] = FloorProgress(level: 1000000000000, running: true);
    expect(huge.tapLobby(), 1e12);
    expect(huge.gold.isFinite, isTrue);

    final lab = GameModel(enableIdleTicks: false);
    addTearDown(lab.dispose);
    expect(lab.critChance, closeTo(0.05, 0.0001));
    lab.researchLevels[3] = 3;
    expect(lab.critChance, closeTo(0.08, 0.0001));
    lab.researchLevels[3] = 100;
    expect(lab.critChance, closeTo(0.15, 0.0001));
    final pinned = GameModel(enableIdleTicks: false, critChanceOverride: -1);
    addTearDown(pinned.dispose);
    expect(pinned.critChance, 0);
  });

  test('fifty quick taps add fifty gold', () async {
    SharedPreferences.setMockInitialValues({});
    final game = GameModel(enableIdleTicks: false, critChanceOverride: 0);
    addTearDown(game.dispose);
    await game.load();
    for (var i = 0; i < 50; i++) {
      game.tapLobby();
    }
    // Quick taps build a combo. The bonus stops at ×1.95, which rounds to 2.
    expect(game.gold, 90);
    expect(game.combo, 50);
  });

  test('a short background gap is paid and a long one is capped', () async {
    var now = DateTime.utc(2026, 5, 2, 12);
    SharedPreferences.setMockInitialValues({});
    final game = GameModel(enableIdleTicks: false, now: () => now);
    addTearDown(game.dispose);
    await game.load();
    now = now.add(const Duration(seconds: 20));
    game.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(game.pendingOfflineGold, 0);
    expect(game.gold, closeTo(4, 0.05));

    SharedPreferences.setMockInitialValues({});
    var later = DateTime.utc(2026, 5, 3, 12);
    final away = GameModel(enableIdleTicks: false, now: () => later);
    addTearDown(away.dispose);
    await away.load();
    final goldBefore = away.gold;
    later = later.add(const Duration(hours: 9));
    away.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(away.gold, goldBefore);
    expect(away.pendingOfflineGold, closeTo(0.2 * 8 * 3600, 0.5));
  });

  test('Saturday files one report and the board is a local stand-in', () async {
    final saturday = DateTime.utc(2026, 11, 14, 15);
    SharedPreferences.setMockInitialValues({});
    final game = GameModel(enableIdleTicks: false, now: () => saturday);
    addTearDown(game.dispose);
    await game.load();
    expect(isWeekend(saturday), isTrue);
    expect(game.canFileWeekendReport, isTrue);
    game.fileWeekendReport();
    final score = game.weekendScore;
    expect(score, greaterThan(0));
    game.fileWeekendReport();
    expect(game.weekendScore, score);
    final board = weekendBoard(week: game.weekendWeek, playerScore: score);
    expect(board.where((row) => row.standIn).length, 4);
    expect(board.any((row) => row.name.contains('you')), isTrue);

    final monday = DateTime.utc(2026, 11, 16, 9);
    final closed = GameModel(enableIdleTicks: false, now: () => monday);
    addTearDown(closed.dispose);
    await closed.load();
    expect(closed.canFileWeekendReport, isFalse);
  });

  test('the daily streak grows, then resets after a missed day', () async {
    var now = DateTime.utc(2026, 11, 11, 9);
    final game = GameModel(enableIdleTicks: false, now: () => now);
    addTearDown(game.dispose);
    await game.load();
    expect(game.loginStreak, 1);
    expect(game.pendingLoginGold, 10);
    game.collectLoginBonus();
    expect(game.gold, 10);

    now = now.add(const Duration(days: 1));
    game.prepareCalendar();
    expect(game.loginStreak, 2);
    expect(game.pendingLoginGold, 20);

    now = now.add(const Duration(days: 3));
    game.prepareCalendar();
    // The free streak freeze absorbs this gap.
    expect(game.loginStreak, 2);
    expect(game.streakFreezes, 0);

    now = now.add(const Duration(days: 3));
    game.prepareCalendar();
    expect(game.loginStreak, 1);
  });

  testWidgets('a narrow phone width does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    await tester.pumpWidget(SpireTycoonApp(game: game));
    await _pumpUntilReady(tester);
    await _acceptAppointment(tester);
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('tower-list')),
      const Offset(0, -400),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('open-market')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('run-market-fight')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('a market campaign stays finite and cannot be farmed the same day', () {
    final weak = runMarketFight(power: 0, seed: 1);
    expect(weak.log.length, 6);
    expect(weak.reward.isFinite, isTrue);
    expect(weak.reward, greaterThanOrEqualTo(0));

    final broken = runMarketFight(power: double.nan, seed: 4);
    expect(broken.reward.isFinite, isTrue);
    expect(broken.reward, greaterThanOrEqualTo(0));

    final huge = runMarketFight(power: double.maxFinite, seed: 2);
    expect(huge.reward, lessThanOrEqualTo(1000000000000));

    final now = DateTime.utc(2026, 11, 11, 10);
    final game = GameModel(enableIdleTicks: false, now: () => now);
    addTearDown(game.dispose);
    game.floors[0] = FloorProgress(running: true);
    game.fightMarket();
    final gold = game.gold;
    game.fightMarket();
    expect(game.canFightMarket, isFalse);
    expect(game.gold, gold);
  });

  test('milestones double speed and achievements pay tickets once', () {
    expect(milestoneSpeed(9), 1);
    expect(milestoneSpeed(10), 2);
    expect(milestoneSpeed(25), 4);
    expect(crossedMilestone(9, 10), isTrue);
    expect(crossedMilestone(10, 11), isFalse);

    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    game.floors[0] = FloorProgress(running: true, level: 9);
    game.gold = 100000000;
    game.upgradeFloor(0);
    expect(game.lobbyLevel, 10);
    expect(game.celebration, contains('Speed doubled'));
    expect(game.goldRateFor(0), closeTo(0.2 * 11 * 2, 0.01));

    game.managers[ManagerId.gary] = 1;
    game.managers[ManagerId.karen] = 1;
    game.lifetimeGold = 1000000000;
    final tickets = game.goldTickets;
    game.tapLobby();
    expect(game.claimedAchievements, containsAll(['synergy', 'billion']));
    expect(game.goldTickets, tickets + 6);
    game.tapLobby();
    expect(game.goldTickets, tickets + 6);
  });

  test('districts change every 10 floors and announce once', () {
    expect(districtForFloor(0).name, 'Basement Dungeon');
    expect(districtForFloor(9).name, 'Basement Dungeon');
    expect(districtForFloor(10).name, 'Corporate Offices');
    expect(districtForFloor(20).name, 'Skyscraper');
    expect(districtForFloor(50).name, 'Abyssal HQ');
    expect(districtForFloor(500).name, 'Abyssal HQ');
    expect(floorRecipe(5).name, 'Marketing (Imps)');

    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    game.floors[0] = FloorProgress(running: true);
    game.gold = 1e20;
    game.testDiamonds = 20;
    for (var index = 1; index <= 10; index++) {
      game.startBuild(index);
      game.skipBuildWithDiamond(index);
    }
    expect(game.isRunning(10), isTrue);
    expect(game.districtNotice, 'New District Unlocked: Corporate Offices');
    expect(game.districtTint, 0xFF1E3A5F);
    game.dismissDistrictNotice();
    expect(game.districtNotice, isNull);
    game.skipBuildWithDiamond(10);
    expect(game.districtNotice, isNull);
  });

  test(
    'a boss floor refunds a failed audit and pays a rare manager on success',
    () {
      expect(isBossFloor(24), isTrue);
      expect(isBossFloor(49), isTrue);
      expect(isBossFloor(23), isFalse);
      expect(bossChallengeName(24), 'Audit');
      expect(bossChallengeName(49), 'Hostile Takeover');

      var now = DateTime.utc(2026, 8, 1, 12);
      final game = GameModel(enableIdleTicks: false, now: () => now);
      addTearDown(game.dispose);
      game.floors[0] = FloorProgress(running: true);
      for (var index = 1; index < 24; index++) {
        game.floors[index] = FloorProgress(running: true, sleeping: true);
      }
      game.gold = 1e15;
      final before = game.gold;
      game.startBuild(24);
      expect(game.bossFloor, 24);
      expect(game.isRunning(24), isFalse);
      final during = game.gold;
      expect(during, lessThan(before));

      now = now.add(const Duration(seconds: 46));
      game.advanceOneSecond();
      expect(game.bossFloor, isNull);
      expect(game.gold, closeTo(before, 1));
      expect(game.copies(ManagerId.karen), 0);

      game.gold = 1e15;
      game.startBuild(24);
      game.floors[0]!.level = 50;
      game.advanceOneSecond();
      expect(game.isRunning(24), isTrue);
      expect(game.copies(ManagerId.karen), 1);
      expect(game.gold.isFinite, isTrue);
      expect(game.gold, greaterThanOrEqualTo(0));
    },
  );

  test('quests pay once and a streak freeze forgives one missed day', () async {
    var now = DateTime.utc(2026, 11, 10, 9);
    final game = GameModel(enableIdleTicks: false, now: () => now);
    addTearDown(game.dispose);
    await game.load();
    expect(game.streakFreezes, 1);
    expect(game.questsOpen, isFalse);
    for (var i = 0; i < 25; i++) {
      game.tapLobby();
    }
    game.claimDailyTaps();
    expect(game.dailyTapClaimed, isFalse);

    game.floors[1] = FloorProgress(running: true);
    game.floors[2] = FloorProgress(running: true);
    expect(game.questsOpen, isTrue);
    game.claimDailyTaps();
    expect(game.dailyTapClaimed, isTrue);
    expect(game.streakFreezes, 2);
    game.claimDailyTaps();
    expect(game.streakFreezes, 2);

    now = now.add(const Duration(days: 3));
    final streak = game.loginStreak;
    game.prepareCalendar();
    expect(game.loginStreak, streak);
    expect(game.streakFreezes, 1);
  });

  test(
    'a sixth manager star becomes a ticket and a full set adds 5 percent',
    () {
      final game = GameModel(enableIdleTicks: false);
      addTearDown(game.dispose);
      game.floors[0] = FloorProgress(running: true);
      game.managers[ManagerId.gary] = 5;
      game.goldTickets = 1;
      game.openBriefcase(roll: 0.1);
      expect(game.copies(ManagerId.gary), 5);
      expect(game.goldTickets, 1);

      final before = game.goldRateFor(0);
      for (final name in districtAt(0).monsters) {
        game.discoveredCreatures.add(name);
      }
      expect(completedDistrictSets(game.discoveredCreatures), 1);
      expect(game.goldRateFor(0), closeTo(before * 1.05, 0.001));
    },
  );

  test('research is locked until floor 10 and stays after a reset', () {
    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    game.floors[0] = FloorProgress(running: true);
    game.compliance = 1000;
    expect(game.researchOpen, isFalse);
    game.buyResearch(0);
    expect(game.researchLevel(0), 0);

    game.floors[9] = FloorProgress(running: true);
    expect(game.researchOpen, isTrue);
    final before = game.goldRateFor(0);
    game.buyResearch(0);
    expect(game.researchLevel(0), 1);
    expect(game.goldRateFor(0), closeTo(before * 1.05, 0.001));
    expect(game.compliance, lessThan(1000));

    game.equity = 100;
    game.buyResearch(1);
    expect(game.offlineResearchCap, const Duration(hours: 9));
    game.restructure();
    expect(game.researchLevel(0), 1);
    expect(game.researchLevel(1), 1);
    game.researchLevels[0] = -4;
    expect(game.researchLevel(0), 0);
    expect(offlineCapFor(100), const Duration(hours: 24));
  });

  test(
    'office events pay, pause, or double, and a bad name is ignored',
    () async {
      final courier = GameModel(
        enableIdleTicks: false,
        eventGap: 1,
        random: _QueueRandom([0]),
      );
      addTearDown(courier.dispose);
      courier.floors[0] = FloorProgress(running: true);
      courier.advanceOneSecond();
      expect(courier.officeEvent, OfficeEvent.courier);
      courier.resolveOfficeEvent();
      expect(courier.gold, closeTo(5.2, 0.001));
      courier.resolveOfficeEvent();
      expect(courier.gold, closeTo(5.2, 0.001));

      final outage = GameModel(
        enableIdleTicks: false,
        eventGap: 1,
        random: _QueueRandom([3]),
      );
      addTearDown(outage.dispose);
      outage.floors[0] = FloorProgress(running: true);
      outage.advanceOneSecond();
      expect(outage.officeEvent, OfficeEvent.outage);
      final paused = outage.gold;
      outage.advanceOneSecond();
      expect(outage.gold, paused);
      expect(outage.liveGoldPerSecond, 0);
      outage.resolveOfficeEvent();
      expect(outage.officeEvent, isNull);
      outage.advanceOneSecond();
      expect(outage.gold, greaterThan(paused));

      var clock = DateTime.utc(2026, 3, 1, 12);
      final boom = GameModel(
        enableIdleTicks: false,
        eventGap: 1,
        now: () => clock,
        random: _QueueRandom([1]),
      );
      addTearDown(boom.dispose);
      boom.floors[0] = FloorProgress(running: true);
      boom.advanceOneSecond();
      expect(boom.officeEvent, OfficeEvent.boom);
      expect(boom.gold, closeTo(0.2, 0.001));
      clock = clock.add(const Duration(seconds: 1));
      boom.advanceOneSecond();
      expect(boom.gold, closeTo(0.6, 0.001));
      expect(boom.liveGoldPerSecond, closeTo(0.4, 0.001));
      boom.resolveOfficeEvent();
      expect(boom.officeEvent, OfficeEvent.boom);
      clock = clock.add(const Duration(seconds: 60));
      boom.advanceOneSecond();
      expect(boom.gold, closeTo(0.8, 0.001));

      final rich = GameModel(enableIdleTicks: false);
      addTearDown(rich.dispose);
      rich.floors[0] = FloorProgress(level: 1000000000, running: true);
      rich.officeEvent = OfficeEvent.party;
      expect(rich.eventPayout, 1e12);
      rich.resolveOfficeEvent();
      expect(rich.gold, 1e12);

      SharedPreferences.setMockInitialValues({});
      final saved = GameModel(
        enableIdleTicks: false,
        eventGap: 1,
        random: _QueueRandom([0]),
      );
      addTearDown(saved.dispose);
      await saved.load();
      saved.advanceOneSecond();
      expect(saved.officeEvent, OfficeEvent.courier);
      await saved.persist();

      final loaded = GameModel(enableIdleTicks: false);
      addTearDown(loaded.dispose);
      await loaded.load();
      expect(loaded.officeEvent, OfficeEvent.courier);

      final prefs = await SharedPreferences.getInstance();
      final map = jsonDecode(prefs.getString(saveKey)!) as Map<String, dynamic>;
      map['event'] = 4;
      map['eventWait'] = -5;
      await prefs.setString(saveKey, jsonEncode(map));
      final weird = GameModel(enableIdleTicks: false);
      addTearDown(weird.dispose);
      await weird.load();
      expect(weird.officeEvent, isNull);

      final reset = GameModel(
        enableIdleTicks: false,
        eventGap: 1,
        random: _QueueRandom([3]),
      );
      addTearDown(reset.dispose);
      reset.floors[0] = FloorProgress(running: true);
      reset.floors[2] = FloorProgress(running: true);
      reset.advanceOneSecond();
      expect(reset.officeEvent, OfficeEvent.outage);
      reset.restructure();
      expect(reset.officeEvent, isNull);
    },
  );

  testWidgets('an office event note fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    await tester.pumpWidget(SpireTycoonApp(game: game));
    await _pumpUntilReady(tester);
    await _acceptAppointment(tester);
    game.officeEvent = OfficeEvent.outage;
    game.notifyListeners();
    await tester.pump();
    expect(find.byKey(const Key('office-event')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('office-event')));
    await tester.pump();
    expect(game.officeEvent, isNull);
    expect(tester.takeException(), isNull);
  });

  test(
    'restructuring unlocks a skin, night shift, then auto-upgrade',
    () async {
      expect(isNightShiftFloor(49), isFalse);
      expect(floorRecipe(21).kind, FloorKind.gold);
      expect(floorRecipe(5, prestige: 4).name, 'Marketing (Imps)');
      expect(
        floorBaseGold(21, prestige: 2),
        closeTo(floorBaseGold(21) * 1.5, 0.001),
      );
      expect(floorRecipe(21, prestige: 2).kind, FloorKind.nightShift);

      final game = GameModel(enableIdleTicks: false);
      addTearDown(game.dispose);
      game.floors[0] = FloorProgress(running: true);
      game.floors[1] = FloorProgress(running: true);
      expect(game.nextPrestigePreview, contains('Brass'));
      game.restructure();
      expect(game.restructures, 1);
      expect(game.nextPrestigePreview, contains('Night Shift'));
      game.selectSkin('aurora');
      expect(game.selectedSkin, 'standard');
      game.selectSkin('brass');
      expect(game.districtTint, 0xFF3F2E1E);
      game.selectSkin('nope');
      expect(game.selectedSkin, 'brass');

      game.restructures = 2;
      game.floors[21] = FloorProgress(running: true);
      expect(
        game.goldRateFor(21),
        closeTo(floorBaseGold(21, prestige: 2) * game.equityMultiplier, 0.001),
      );

      game.gold = 1000;
      game.autoUpgrade = true;
      game.advanceOneSecond();
      expect(game.lobbyLevel, 0);

      game.restructures = 3;
      game.autoUpgrade = true;
      game.floors.remove(21);
      game.advanceOneSecond();
      expect(game.lobbyLevel, 1);
      game.gold = 0;
      game.advanceOneSecond();
      expect(game.lobbyLevel, 1);

      game.restructures = 4;
      expect(game.nextPrestigePreview, contains('Shareholder Equity'));

      SharedPreferences.setMockInitialValues({
        saveKey: jsonEncode({
          'restructures': -4,
          'skin': 'aurora',
          'autoUpgrade': 1,
          'gold': 3,
        }),
      });
      final loaded = GameModel(enableIdleTicks: false);
      addTearDown(loaded.dispose);
      await loaded.load();
      expect(loaded.restructures, 0);
      expect(loaded.selectedSkin, 'standard');
      expect(loaded.autoUpgrade, isFalse);
      expect(loaded.gold, 3);
    },
  );

  testWidgets('the restructure dialog previews the next reward', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    await tester.pumpWidget(SpireTycoonApp(game: game));
    await _pumpUntilReady(tester);
    await _acceptAppointment(tester);
    await tester.tap(find.byKey(const Key('open-restructure')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('next-prestige')), findsOneWidget);
    expect(find.textContaining('Brass After Hours'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('stats keep lifetime numbers and a short net-worth chart', () async {
    expect(formatPlayTime(3), '3s');
    expect(formatPlayTime(90), '1m 30s');
    expect(formatPlayTime(3700), '1h 1m');
    expect(formatPlayTime(-5), '0s');

    final game = GameModel(enableIdleTicks: false, netWorthEvery: 1);
    addTearDown(game.dispose);
    game.floors[0] = FloorProgress(running: true);
    expect(game.floorsBuilt, 1);
    game.gold = 50;
    game.equity = 2;
    expect(game.netWorth, 2050);
    game.gold = double.nan;
    expect(game.netWorth, 0);
    game.gold = 0;

    for (var i = 0; i < 45; i++) {
      game.advanceOneSecond();
    }
    expect(game.playSeconds, 45);
    expect(game.netWorthHistory.length, 40);

    game.equity = 0;
    game.floors[1] = FloorProgress(running: true);
    game.restructure();
    expect(game.floorsBuilt, 1);
    expect(game.playSeconds, 45);
    expect(game.netWorthHistory.length, 40);
    expect(game.equity, 1);
    expect(game.netWorth, 1000);

    SharedPreferences.setMockInitialValues({
      saveKey: jsonEncode({
        'version': 2,
        'gold': 4,
        'floorsBuilt': -3,
        'playSeconds': -8,
        'netWorth': [10, 'nope', -4],
        'floors': [
          [0, 0, 1, 0],
          [1, 0, 1, 0],
        ],
      }),
    });
    final loaded = GameModel(enableIdleTicks: false);
    addTearDown(loaded.dispose);
    await loaded.load();
    expect(loaded.floorsBuilt, 0);
    expect(loaded.playSeconds, 0);
    expect(loaded.netWorthHistory, [10]);
    expect(loaded.gold, 4);

    SharedPreferences.setMockInitialValues({
      saveKey: jsonEncode({
        'version': 2,
        'floors': [
          [0, 0, 1, 0],
          [1, 0, 1, 0],
        ],
      }),
    });
    final older = GameModel(enableIdleTicks: false);
    addTearDown(older.dispose);
    await older.load();
    expect(older.floorsBuilt, 2);
  });

  testWidgets('the stats screen fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    await tester.pumpWidget(SpireTycoonApp(game: game));
    await _pumpUntilReady(tester);
    await _acceptAppointment(tester);
    await tester.tap(find.byKey(const Key('open-stats')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stat-net-worth')), findsOneWidget);
    expect(find.byKey(const Key('stat-lifetime')), findsOneWidget);
    expect(find.byKey(const Key('stat-floors')), findsOneWidget);
    expect(find.byKey(const Key('stat-play-time')), findsOneWidget);
    expect(find.byKey(const Key('net-worth-chart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _QueueRandom implements Random {
  _QueueRandom(this.values);

  final List<int> values;
  int index = 0;

  @override
  int nextInt(int max) {
    final value = values[index % values.length];
    index += 1;
    return value % max;
  }

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

void _useTallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _acceptAppointment(WidgetTester tester) async {
  final button = find.byKey(const Key('tutorial-accept'));
  if (button.evaluate().isEmpty) {
    return;
  }
  await tester.tap(button);
  await tester.pump();
}

Future<void> _pumpUntilReady(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump();
    if (find.byKey(const Key('game-ready')).evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Game did not finish loading');
}

Color _upgradeColor(WidgetTester tester) {
  return tester.widget<Material>(find.byKey(const Key('upgrade-desk'))).color!;
}
