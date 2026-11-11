import 'package:flutter/material.dart';

import '../game/formulas.dart';
import '../game/game_model.dart';
import '../theme/app_colors.dart';
import 'sponsor_memo.dart';

/// Pops up when the lobby earned gold while the game was closed.
class WelcomeBackDialog extends StatelessWidget {
  const WelcomeBackDialog({super.key, required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    final amount = formatGold(game.pendingOfflineGold);
    final away = formatAway(Duration(seconds: game.pendingOfflineSeconds));

    return Dialog(
      backgroundColor: slate,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome back',
              key: Key('welcome-back'),
              style: TextStyle(
                color: cream,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The spire kept working for $away.',
              style: const TextStyle(color: cream, fontSize: 16, height: 1.35),
            ),
            const SizedBox(height: 12),
            Text(
              amount,
              key: const Key('offline-gold'),
              style: const TextStyle(
                color: cyan,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'gold waiting',
              style: TextStyle(color: cream, fontSize: 16),
            ),
            if (game.pendingCompliance > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${formatGold(game.pendingCompliance)} compliance waiting',
                style: const TextStyle(color: cyan, fontSize: 16),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Offline pay stops after 8 hours.',
              style: TextStyle(color: cream, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('collect-offline'),
              style: FilledButton.styleFrom(
                backgroundColor: emerald,
                foregroundColor: cream,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
              ),
              onPressed: () {
                game.collectOffline();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Collect',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('watch-sponsor-memo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cream,
                side: const BorderSide(color: cream),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
              ),
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const SponsorMemo(),
                );
                if (!context.mounted) {
                  return;
                }
                game.collectOffline(doubled: true);
                Navigator.of(context).pop();
              },
              child: const Text(
                'Watch sponsor memo to double',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Practice ad. No real company is paying for it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cream, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
