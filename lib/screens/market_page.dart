import 'package:flutter/material.dart';

import '../game/formulas.dart';
import '../game/game_model.dart';
import '../theme/app_colors.dart';

/// Auto-resolved boardroom campaign. Not a live match against other people.
class MarketPage extends StatelessWidget {
  const MarketPage({super.key, required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: cream,
        title: const Text('Market'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: game,
          builder: (context, _) {
            final fight = game.lastMarketFight;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Market domination',
                  style: TextStyle(
                    color: cream,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Five pitches resolve on their own. Your tower income is your strength. This is a boardroom simulation, not a live match.',
                  style: TextStyle(color: cream, fontSize: 15, height: 1.35),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('run-market-fight'),
                  style: FilledButton.styleFrom(
                    backgroundColor: game.canFightMarket ? emerald : slate,
                    foregroundColor: cream,
                  ),
                  onPressed: game.canFightMarket ? game.fightMarket : null,
                  child: Text(
                    game.canFightMarket
                        ? 'Run the campaign'
                        : 'Campaign already run today',
                  ),
                ),
                if (fight == null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'No campaign yet today. One run, whenever you want it.',
                    key: Key('empty-market'),
                    style: TextStyle(color: cyan, fontSize: 16, height: 1.35),
                  ),
                ],
                if (fight != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    fight.won
                        ? 'Won · +${formatNumber(fight.reward)} gold'
                        : 'Lost · no prize',
                    key: const Key('market-result'),
                    style: const TextStyle(
                      color: cyan,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final line in fight.log)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: cream,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
