import 'package:flutter/material.dart';

import '../game/game_model.dart';
import '../theme/app_colors.dart';

/// Corporate Restructuring. Explains the reset before it happens.
class RestructureDialog extends StatelessWidget {
  const RestructureDialog({super.key, required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    final gain = game.restructuringEquity;
    final can = gain > 0;
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
              'Corporate Restructuring',
              style: TextStyle(
                color: cream,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              can ? 'Sign away this run for $gain Shareholder Equity.' : 'Open at least the Dragon Forge before you can restructure.',
              style: const TextStyle(color: cream, fontSize: 16, height: 1.35),
            ),
            const SizedBox(height: 8),
            const Text(
              'This resets gold, floors, tickets, policies, and staff. The tower can be built again from Floor 1. Equity stays, and each point adds 10% gold from every floor. TEST diamonds are kept.',
              style: TextStyle(color: cream, fontSize: 14, height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              'You have ${game.equity} equity now (+${game.equity * 10}% gold).',
              style: const TextStyle(color: cyan, fontSize: 15),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('confirm-restructure'),
              style: FilledButton.styleFrom(
                backgroundColor: can ? emerald : slate,
                foregroundColor: cream,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
              ),
              onPressed: can
                  ? () {
                      game.restructure();
                      Navigator.of(context).pop();
                    }
                  : null,
              child: const Text(
                'Sign the restructuring',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
