import 'package:flutter/material.dart';

import '../game/achievements.dart';
import '../game/game_model.dart';
import '../theme/app_colors.dart';

/// Career trophies. Each one pays Gold Tickets once.
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key, required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: cream,
        title: const Text('Achievements'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: game,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Hit these once. The ticket reward is not repeated.',
                  style: TextStyle(color: cream, fontSize: 15, height: 1.35),
                ),
                const SizedBox(height: 12),
                for (final item in achievementCatalog)
                  _AchievementRow(
                    item: item,
                    earned: game.claimedAchievements.contains(item.id),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.item, required this.earned});

  final AchievementDef item;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('achievement-${item.id}'),
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
            item.title,
            style: TextStyle(
              color: earned ? cyan : cream,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.detail,
            style: const TextStyle(color: cream, fontSize: 14, height: 1.3),
          ),
          const SizedBox(height: 4),
          Text(
            earned
                ? 'Claimed · ${item.tickets} Gold Tickets'
                : 'Pays ${item.tickets} Gold Tickets',
            style: const TextStyle(color: cream, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
