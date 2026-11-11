import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spire_tycoon/main.dart';

void main() {
  test('desk upgrade cost is 10 × 1.10^level', () {
    expect(deskUpgradeCost(0), 10);
    expect(deskUpgradeCost(1), 11);
    expect(deskUpgradeCost(2), 12.1);
    expect(deskUpgradeCost(3), 13.3);
  });

  testWidgets('tapping the goblin earns gold and Upgrade Desk raises it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SpireTycoonApp());

    expect(find.text('The Executive Lobby'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('+1 per tap'), findsOneWidget);

    // Not enough gold yet, so the button stays slate and does nothing.
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

    // 10 gold spent, gold per tap goes from 1 to 2, next cost is 11.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('+2 per tap'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Cost 11 gold'), findsOneWidget);
    expect(_upgradeColor(tester), const Color(0xFF334155));
  });
}

Color _upgradeColor(WidgetTester tester) {
  return tester.widget<Material>(find.byKey(const Key('upgrade-desk'))).color!;
}
