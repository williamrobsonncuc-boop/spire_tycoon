import 'package:flutter/material.dart';

import '../game/game_model.dart';
import '../game/managers.dart';
import '../game/sound_board.dart';
import '../theme/app_colors.dart';

/// Briefcase gacha. The odds stay on screen. Nothing here costs real money.
class RecruitmentPage extends StatelessWidget {
  const RecruitmentPage({super.key, required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: cream,
        title: const Text('Briefcase'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: game,
          builder: (context, _) {
            final canOpen = game.goldTickets >= 1;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  key: const Key('odds-table'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: slate,
                    borderRadius: BorderRadius.circular(cornerRadius),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Briefcase odds',
                        style: TextStyle(
                          color: cream,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Common 75% — Gary the Goblin',
                        style: TextStyle(color: cream, fontSize: 15),
                      ),
                      Text(
                        'Rare 18% — Karen',
                        style: TextStyle(color: cream, fontSize: 15),
                      ),
                      Text(
                        'Epic 6% — Brutus the Minotaur',
                        style: TextStyle(color: cream, fontSize: 15),
                      ),
                      Text(
                        'Legendary 1% — Vlad the CFO or Corporate Overlord Lich',
                        style: TextStyle(color: cream, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Gold Tickets ${game.goldTickets} · TEST diamonds ${game.testDiamonds} · Shareholder Equity ${game.equity}',
                  style: const TextStyle(color: cream, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tickets drop when a floor finishes building. TEST diamonds are a practice currency, not a real purchase. Shareholder Equity arrives when you restructure the company.',
                  style: TextStyle(color: cream, fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 12),
                Material(
                  color: canOpen ? emerald : slate,
                  borderRadius: BorderRadius.circular(cornerRadius),
                  child: InkWell(
                    key: const Key('open-briefcase'),
                    borderRadius: BorderRadius.circular(cornerRadius),
                    onTap: canOpen
                        ? () {
                            OfficeSounds.play(context, SoundEffect.latch);
                            game.openBriefcase();
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        canOpen
                            ? 'Open briefcase (1 Gold Ticket)'
                            : 'Need 1 Gold Ticket',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: canOpen
                              ? cream
                              : cream.withValues(alpha: 0.55),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                if (game.lastHire != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Hired ${managerCard(game.lastHire!).name} (${rarityLabel(managerCard(game.lastHire!).rarity)})',
                    key: const Key('last-hire'),
                    style: const TextStyle(
                      color: cyan,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'On staff',
                  style: TextStyle(
                    color: cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final card in managerRoster)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${card.name} ×${game.copies(card.id)} · ${rarityLabel(card.rarity)}\n${card.effect}',
                      style: const TextStyle(
                        color: cream,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
