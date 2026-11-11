import 'package:flutter/material.dart';

import '../game/formulas.dart';
import '../game/game_model.dart';
import '../theme/app_colors.dart';
import '../widgets/floor_card.dart';
import '../widgets/restructure_dialog.dart';
import '../widgets/welcome_back_dialog.dart';
import 'recruitment_page.dart';
import 'achievements_page.dart';
import 'market_page.dart';
import 'quests_page.dart';
import 'shop_page.dart';
import 'weekend_page.dart';

/// The whole spire. The list is lazy: Flutter only builds cards you can see,
/// and scrolling near the bottom reveals more generated floors.
class TowerPage extends StatefulWidget {
  const TowerPage({super.key, required this.game});

  final GameModel game;

  @override
  State<TowerPage> createState() => _TowerPageState();
}

class _TowerPageState extends State<TowerPage> {
  /// How many floors the list is willing to show. This grows as you scroll.
  int _shown = 10;
  bool _offlineOpen = false;

  @override
  void initState() {
    super.initState();
    widget.game.addListener(_maybeShowOffline);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOffline());
  }

  @override
  void dispose() {
    widget.game.removeListener(_maybeShowOffline);
    super.dispose();
  }

  void _maybeShowOffline() {
    final waiting =
        widget.game.pendingOfflineGold > 0 || widget.game.pendingCompliance > 0;
    if (!mounted || _offlineOpen || !waiting) {
      return;
    }
    _offlineOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _offlineOpen = false;
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => WelcomeBackDialog(game: widget.game),
      );
      _offlineOpen = false;
    });
  }

  void _revealMoreIfNeeded(ScrollMetrics metrics) {
    // A short list that does not scroll would report "near the end" forever.
    if (metrics.maxScrollExtent <= 0 || metrics.extentAfter > 240) {
      return;
    }
    setState(() => _shown += 8);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.game,
      builder: (context, _) {
        final game = widget.game;
        if (!game.ready) {
          return const Scaffold(
            backgroundColor: navy,
            body: Center(
              child: Text(
                'Opening the spire...',
                style: TextStyle(color: cream, fontSize: 18),
              ),
            ),
          );
        }

        return Scaffold(
          key: const Key('game-ready'),
          backgroundColor: Color(game.districtTint),
          body: Stack(
            children: [
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        children: [
                          _TowerHeader(game: game),
                          if (game.districtNotice != null) ...[
                            const SizedBox(height: 8),
                            Material(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(cornerRadius),
                              child: InkWell(
                                key: const Key('district-notice'),
                                borderRadius: BorderRadius.circular(
                                  cornerRadius,
                                ),
                                onTap: game.dismissDistrictNotice,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    game.districtNotice!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: cyan,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (game.celebration != null) ...[
                            const SizedBox(height: 8),
                            Material(
                              color: emerald,
                              borderRadius: BorderRadius.circular(cornerRadius),
                              child: InkWell(
                                key: const Key('celebration'),
                                borderRadius: BorderRadius.circular(
                                  cornerRadius,
                                ),
                                onTap: game.dismissCelebration,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    game.celebration!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: cream,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (game.tutorialStep > 0 &&
                              game.tutorialStep < 4) ...[
                            const SizedBox(height: 8),
                            _TutorialBanner(game: game),
                          ],
                          const SizedBox(height: 12),
                          Expanded(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification is ScrollUpdateNotification) {
                                  _revealMoreIfNeeded(notification.metrics);
                                }
                                return false;
                              },
                              child: ListView.builder(
                                key: const Key('tower-list'),
                                itemCount: _shown,
                                itemBuilder: (context, index) {
                                  return FloorCard(game: game, index: index);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (game.tutorialStep == 0)
                _AppointmentNotice(onAccept: game.acceptAppointment),
            ],
          ),
        );
      },
    );
  }
}

class _TowerHeader extends StatelessWidget {
  const _TowerHeader({required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    final showCompliance =
        game.compliance > 0 ||
        game.compliancePerSecond > 0 ||
        game.policyLevel > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: slate,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'GOLD',
                style: TextStyle(
                  color: cream,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              IconButton(
                key: const Key('mute-toggle'),
                tooltip: game.muted ? 'Unmute' : 'Mute',
                onPressed: game.toggleMute,
                icon: Icon(
                  game.muted ? Icons.volume_off : Icons.volume_up,
                  color: cream,
                ),
              ),
              TextButton(
                key: const Key('open-restructure'),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => RestructureDialog(game: game),
                  );
                },
                child: const Text('Restructure'),
              ),
              TextButton(
                key: const Key('open-quests'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => QuestsPage(game: game),
                    ),
                  );
                },
                child: const Text('Quests'),
              ),
              TextButton(
                key: const Key('open-achievements'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => AchievementsPage(game: game),
                    ),
                  );
                },
                child: const Text('Trophies'),
              ),
              TextButton(
                key: const Key('open-market'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => MarketPage(game: game),
                    ),
                  );
                },
                child: const Text('Market'),
              ),
              TextButton(
                key: const Key('open-weekend'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => WeekendPage(game: game),
                    ),
                  );
                },
                child: const Text('Weekend'),
              ),
              TextButton(
                key: const Key('open-shop'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => ShopPage(game: game),
                    ),
                  );
                },
                child: const Text('Shop'),
              ),
              TextButton(
                key: const Key('open-recruitment'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => RecruitmentPage(game: game),
                    ),
                  );
                },
                child: const Text('Briefcase'),
              ),
            ],
          ),
          Text(
            formatNumber(game.gold),
            key: const Key('gold-amount'),
            style: const TextStyle(
              color: cyan,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          Text(
            '+${game.goldPerTap} per tap',
            key: const Key('gold-per-tap'),
            style: const TextStyle(color: cream, fontSize: 15),
          ),
          Text(
            '+${formatNumber(game.goldPerSecond)} per second',
            key: const Key('gold-per-second'),
            style: const TextStyle(color: cream, fontSize: 15),
          ),
          Text(
            'Tickets ${game.goldTickets} · TEST diamonds ${game.testDiamonds}',
            style: const TextStyle(color: cream, fontSize: 13),
          ),
          if (showCompliance) ...[
            const SizedBox(height: 6),
            Text(
              'Compliance ${formatNumber(game.compliance)} · +${formatNumber(game.compliancePerSecond)} / sec · policies +${game.policyLevel * 10}%',
              style: const TextStyle(color: cream, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppointmentNotice extends StatelessWidget {
  const _AppointmentNotice({required this.onAccept});

  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xF20F172A),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: slate,
                borderRadius: BorderRadius.circular(cornerRadius),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'PHONE',
                    style: TextStyle(
                      color: cream,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'CONGRATULATIONS: You have been appointed CEO of Spire Corp.',
                    key: Key('tutorial-appointment'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cream,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The lights are off. The goblin is waiting. This is your first day.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cream, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('tutorial-accept'),
                    style: FilledButton.styleFrom(
                      backgroundColor: emerald,
                      foregroundColor: cream,
                    ),
                    onPressed: onAccept,
                    child: const Text('Accept the appointment'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialBanner extends StatelessWidget {
  const _TutorialBanner({required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    final step = game.tutorialStep;
    final String message;
    if (step == 1) {
      message = 'Tap the receptionist. That hires your first intern.';
    } else if (step == 2) {
      message = 'Build Floor 2, the Dragon Forge.';
    } else {
      message =
          'Your welcome briefcase is guaranteed Epic. Brutus is in there.';
    }

    return Container(
      key: const Key('tutorial-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: slate,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: const TextStyle(color: cream, fontSize: 15, height: 1.3),
          ),
          if (step == 3) ...[
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('welcome-briefcase'),
              style: FilledButton.styleFrom(
                backgroundColor: emerald,
                foregroundColor: cream,
              ),
              onPressed: game.openWelcomeBriefcase,
              child: const Text('Open welcome briefcase'),
            ),
          ],
        ],
      ),
    );
  }
}
