import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spire_tycoon/game/floor_catalog.dart';
import 'package:spire_tycoon/game/formulas.dart';
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
    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    await tester.pumpWidget(SpireTycoonApp(game: game));
    await _pumpUntilReady(tester);

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

    expect(find.text('10'), findsOneWidget);
    expect(find.byKey(const Key('dialogue-bubble')), findsOneWidget);
    expect(find.text('Great hustle. The minotaurs noticed.'), findsOneWidget);
    expect(find.text('+1'), findsWidgets);
    expect(_upgradeColor(tester), const Color(0xFF10B981));

    await tester.ensureVisible(find.byKey(const Key('upgrade-desk')));
    await tester.tap(find.byKey(const Key('upgrade-desk')));
    await tester.pump();

    expect(find.text('0'), findsOneWidget);
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
    expect(floorRecipe(11).title, 'Floor 12: Legal Dept II (Minotaurs)');
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
    expect(game.goldTickets, 0);
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
}

void _useTallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
