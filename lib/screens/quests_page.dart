import 'package:flutter/material.dart';

import '../game/game_model.dart';
import '../theme/app_colors.dart';

/// Daily and weekly jobs. Rewards wait until Floor 3 is open.
class QuestsPage extends StatelessWidget {
  const QuestsPage({super.key, required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: cream,
        title: const Text('Quests'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: game,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  game.questsOpen
                      ? 'Daily and weekly jobs. A streak freeze saves your check-in if you miss a day. You can hold two.'
                      : 'Quests start when Floor 3 is open. Progress you make now still counts.',
                  style: const TextStyle(
                    color: cream,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Streak freezes: ${game.streakFreezes}',
                  key: const Key('streak-freezes'),
                  style: const TextStyle(color: cyan, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _QuestRow(
                  title: 'Tap 25 times today',
                  progress: '${game.tapsToday}/25',
                  reward: '25 gold and a streak freeze if you have room',
                  ready:
                      game.questsOpen &&
                      game.tapsToday >= 25 &&
                      !game.dailyTapClaimed,
                  done: game.dailyTapClaimed,
                  onClaim: game.claimDailyTaps,
                  buttonKey: const Key('claim-daily-taps'),
                ),
                _QuestRow(
                  title: 'Open a floor this week',
                  progress: '${game.buildsThisWeek}/1',
                  reward: '1 Gold Ticket',
                  ready:
                      game.questsOpen &&
                      game.buildsThisWeek >= 1 &&
                      !game.weeklyBuildClaimed,
                  done: game.weeklyBuildClaimed,
                  onClaim: game.claimWeeklyBuild,
                  buttonKey: const Key('claim-weekly-build'),
                ),
                _QuestRow(
                  title: 'Recruit 3 staff this week',
                  progress: '${game.recruitsThisWeek}/3',
                  reward: '1 Gold Ticket',
                  ready:
                      game.questsOpen &&
                      game.recruitsThisWeek >= 3 &&
                      !game.weeklyRecruitClaimed,
                  done: game.weeklyRecruitClaimed,
                  onClaim: game.claimWeeklyRecruit,
                  buttonKey: const Key('claim-weekly-recruit'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.title,
    required this.progress,
    required this.reward,
    required this.ready,
    required this.done,
    required this.onClaim,
    required this.buttonKey,
  });

  final String title;
  final String progress;
  final String reward;
  final bool ready;
  final bool done;
  final VoidCallback onClaim;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
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
            title,
            style: const TextStyle(
              color: cream,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(progress, style: const TextStyle(color: cyan, fontSize: 15)),
          Text(reward, style: const TextStyle(color: cream, fontSize: 14)),
          const SizedBox(height: 8),
          FilledButton(
            key: buttonKey,
            style: FilledButton.styleFrom(
              backgroundColor: ready ? emerald : slate,
              foregroundColor: cream,
            ),
            onPressed: ready ? onClaim : null,
            child: Text(done ? 'Claimed' : 'Claim'),
          ),
        ],
      ),
    );
  }
}
