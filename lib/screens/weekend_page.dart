import 'package:flutter/material.dart';

import '../game/formulas.dart';
import '../game/game_model.dart';
import '../game/weekend.dart';
import '../theme/app_colors.dart';

/// The subsidiary tower. The other names on the board are local stand-ins.
class WeekendPage extends StatelessWidget {
  const WeekendPage({super.key, required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: cream,
        title: const Text('Subsidiary'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: game,
          builder: (context, _) {
            game.prepareCalendar();
            final now = game.currentTime;
            final open = isWeekend(now);
            final board = weekendBoard(
              week: game.weekendWeek,
              playerScore: game.weekendScore,
            );
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  subsidiaryName(game.weekendWeek),
                  style: const TextStyle(
                    color: cream,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  open
                      ? 'The weekend subsidiary is open. File one report a day. It is worth one minute of your main tower.'
                      : 'The subsidiary office is closed until Saturday. The board below is still your local stand-in.',
                  style: const TextStyle(
                    color: cream,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('file-weekend-report'),
                  style: FilledButton.styleFrom(
                    backgroundColor: game.canFileWeekendReport
                        ? emerald
                        : slate,
                    foregroundColor: cream,
                  ),
                  onPressed: game.canFileWeekendReport
                      ? game.fileWeekendReport
                      : null,
                  child: Text(
                    game.canFileWeekendReport
                        ? 'File weekend report'
                        : open
                        ? 'Report already filed today'
                        : 'Closed on weekdays',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Local stand-in. These other companies are not real players and this is not an online server.',
                  key: Key('stand-in-note'),
                  style: TextStyle(color: cream, fontSize: 14, height: 1.35),
                ),
                const SizedBox(height: 8),
                for (final row in board)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: slate,
                      borderRadius: BorderRadius.circular(cornerRadius),
                    ),
                    child: Text(
                      '${row.name} · ${formatNumber(row.score.toDouble())}${row.standIn ? ' · stand-in' : ''}',
                      style: TextStyle(
                        color: row.standIn ? cream : cyan,
                        fontSize: 16,
                        fontWeight: row.standIn
                            ? FontWeight.w500
                            : FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  game.pendingLoginGold > 0
                      ? 'Daily check-in, day ${game.loginStreak}. ${formatNumber(game.pendingLoginGold)} gold is waiting.'
                      : 'Daily check-in, day ${game.loginStreak}. Already claimed today.',
                  style: const TextStyle(color: cream, fontSize: 15),
                ),
                if (game.pendingLoginGold > 0) ...[
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('claim-login'),
                    style: FilledButton.styleFrom(
                      backgroundColor: emerald,
                      foregroundColor: cream,
                    ),
                    onPressed: game.collectLoginBonus,
                    child: const Text('Claim daily gold'),
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
