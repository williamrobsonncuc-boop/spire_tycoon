import 'package:flutter/material.dart';

import '../game/floor_catalog.dart';
import '../game/game_model.dart';
import '../theme/app_colors.dart';

/// Every monster in the tower. Undiscovered ones stay as silhouettes.
class CollectionPage extends StatelessWidget {
  const CollectionPage({super.key, required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: cream,
        title: const Text('Collection'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: game,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Complete a district set for +5% gold. Sets done: ${completedDistrictSets(game.discoveredCreatures)}.',
                  style: const TextStyle(
                    color: cream,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                if (game.discoveredCreatures.isEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'You have not met anyone yet. Open a floor and the silhouettes fill in.',
                    key: Key('empty-codex'),
                    style: TextStyle(color: cyan, fontSize: 15, height: 1.35),
                  ),
                ],
                const SizedBox(height: 12),
                for (var i = 0; i < districtThemes.length; i++)
                  _DistrictSet(
                    theme: districtThemes[i],
                    discovered: game.discoveredCreatures,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DistrictSet extends StatelessWidget {
  const _DistrictSet({required this.theme, required this.discovered});

  final DistrictTheme theme;
  final Set<String> discovered;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: slate,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            theme.name,
            style: const TextStyle(
              color: cream,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < theme.monsters.length; i++)
                _Creature(
                  name: theme.monsters[i],
                  emoji: theme.emoji[i % theme.emoji.length],
                  known: discovered.contains(theme.monsters[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Creature extends StatelessWidget {
  const _Creature({
    required this.name,
    required this.emoji,
    required this.known,
  });

  final String name;
  final String emoji;
  final bool known;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: known ? 1 : 0.35,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
        child: Text(
          known ? '$emoji $name' : '▮ ???',
          style: const TextStyle(color: cream, fontSize: 13),
        ),
      ),
    );
  }
}
