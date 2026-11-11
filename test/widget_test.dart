import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spire_tycoon/game/formulas.dart';
import 'package:spire_tycoon/game/game_model.dart';
import 'package:spire_tycoon/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
    expect(game.deskLevel, 0);
    // 120 seconds * 0.2 gold per second.
    expect(game.pendingOfflineGold, 24);
    expect(game.goldPerTap, 1);
  });

  testWidgets('tapping the goblin earns gold and Upgrade Desk raises it', (
    WidgetTester tester,
  ) async {
    final game = GameModel(enableIdleTicks: false);
    addTearDown(game.dispose);
    await tester.pumpWidget(SpireTycoonApp(game: game));
    await _pumpUntilReady(tester);

    expect(find.text('The Executive Lobby'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('+1 per tap'), findsOneWidget);
    expect(find.text('+0.2 per second'), findsOneWidget);

    expect(_upgradeColor(tester), const Color(0xFF334155));
    await tester.tap(find.byKey(const Key('upgrade-desk')));
    await tester.pump();
    expect(find.text('+1 per tap'), findsOneWidget);
    expect(find.text('Level 0'), findsOneWidget);

    for (var tap = 0; tap < 10; tap++) {
      await tester.tap(find.byKey(const Key('goblin')));
      await tester.pump();
    }

    expect(find.text('10'), findsOneWidget);
    expect(find.text('+1'), findsWidgets);
    expect(_upgradeColor(tester), const Color(0xFF10B981));

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
