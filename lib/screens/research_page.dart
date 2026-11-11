import 'package:flutter/material.dart';

import '../game/game_model.dart';
import '../game/formulas.dart';
import '../theme/app_colors.dart';

/// Permanent labs. Compliance Points and Shareholder Equity only.
class ResearchPage extends StatelessWidget {
  const ResearchPage({super.key, required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    const names = [
      'Faster floors',
      'Longer offline',
      'Cheaper builds',
      'Heavier taps',
    ];
    const details = [
      '+5% gold per level. Paid with Compliance Points.',
      '+1 hour of offline pay per level, up to 24. Paid with Shareholder Equity.',
      'Builds cost 3% less per level, up to 30%. Paid with Compliance Points.',
      'Taps are worth 2% more per level. Paid with Shareholder Equity.',
    ];
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: cream,
        title: const Text('Research'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: game,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  game.researchOpen
                      ? 'These upgrades stay after a restructuring. Nothing here asks for real money.'
                      : 'Research opens when Floor 10 is running.',
                  style: const TextStyle(
                    color: cream,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Compliance ${formatNumber(game.compliance)} · Equity ${game.equity}',
                  style: const TextStyle(color: cyan, fontSize: 15),
                ),
                const SizedBox(height: 12),
                for (var branch = 0; branch < names.length; branch++)
                  _Branch(
                    game: game,
                    branch: branch,
                    name: names[branch],
                    detail: details[branch],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Branch extends StatelessWidget {
  const _Branch({
    required this.game,
    required this.branch,
    required this.name,
    required this.detail,
  });

  final GameModel game;
  final int branch;
  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final level = game.researchLevel(branch);
    final ready = game.canBuyResearch(branch);
    final currency = game.researchUsesEquity(branch) ? 'equity' : 'compliance';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slate,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name · level $level/${GameModel.researchCap}',
            style: const TextStyle(
              color: cream,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(color: cream, fontSize: 14)),
          const SizedBox(height: 8),
          FilledButton(
            key: Key('buy-research-$branch'),
            style: FilledButton.styleFrom(
              backgroundColor: ready ? emerald : slate,
              foregroundColor: cream,
            ),
            onPressed: ready ? () => game.buyResearch(branch) : null,
            child: Text(
              level >= GameModel.researchCap
                  ? 'Maxed'
                  : 'Buy · ${formatNumber(game.researchCost(branch))} $currency',
            ),
          ),
        ],
      ),
    );
  }
}
