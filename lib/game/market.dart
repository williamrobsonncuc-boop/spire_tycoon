/// A boardroom campaign. Five automatic rounds, then a gold prize if you win.
class MarketFight {
  const MarketFight({
    required this.log,
    required this.won,
    required this.reward,
  });

  final List<String> log;
  final bool won;
  final double reward;
}

/// [power] is the tower's gold per second. A bad number is treated as zero.
///
/// The reward is finite and never negative. A huge tower is capped so one
/// win cannot print an infinite balance.
MarketFight runMarketFight({required double power, required int seed}) {
  final safePower = power.isNaN || power.isInfinite || power < 0 ? 0.0 : power;
  final rivalPower = 0.25 + safePower * (0.55 + (seed.abs() % 5) * 0.12);
  var roundsWon = 0;
  final log = <String>[];

  for (var round = 1; round <= 5; round++) {
    final playerSwing = 0.8 + ((seed + round * 17).abs() % 40) / 100;
    final rivalSwing = 0.8 + ((seed + round * 13).abs() % 40) / 100;
    final playerScore = (safePower + 0.2) * playerSwing;
    final rivalScore = rivalPower * rivalSwing;
    final tookThePitch = playerScore >= rivalScore;
    if (tookThePitch) {
      roundsWon += 1;
    }
    log.add(
      tookThePitch
          ? 'Round $round: Spire Corp takes the pitch.'
          : 'Round $round: the rival keeps the account.',
    );
  }

  final won = roundsWon >= 3;
  var reward = 0.0;
  if (won) {
    final raw = safePower * 30;
    reward = raw < 5 ? 5 : raw;
    if (reward.isNaN || reward.isInfinite || reward > 1e12) {
      reward = 1e12;
    }
  }

  log.add(
    won
        ? 'The campaign lands. Prize ${reward.toStringAsFixed(0)} gold.'
        : 'The rival keeps the quarter. No prize.',
  );
  return MarketFight(log: log, won: won, reward: reward);
}
