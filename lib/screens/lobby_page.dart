import 'dart:math';

import 'package:flutter/material.dart';

import '../game/formulas.dart';
import '../game/game_model.dart';
import '../theme/app_colors.dart';
import '../widgets/welcome_back_dialog.dart';

/// Floor 1. Tap the goblin, watch gold tick up, buy a better desk.
class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key, required this.game});

  final GameModel game;

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage>
    with SingleTickerProviderStateMixin {
  final List<_GoldFloater> _floaters = [];
  int _nextFloaterId = 0;
  late final AnimationController _bounce;
  bool _offlineOpen = false;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _bounce.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _bounce.reverse();
      }
    });
    widget.game.addListener(_maybeShowOffline);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOffline());
  }

  @override
  void dispose() {
    widget.game.removeListener(_maybeShowOffline);
    _bounce.dispose();
    super.dispose();
  }

  void _maybeShowOffline() {
    if (!mounted || _offlineOpen || widget.game.pendingOfflineGold <= 0) {
      return;
    }
    _offlineOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.game.pendingOfflineGold <= 0) {
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

  void _tapGoblin() {
    widget.game.tapGoblin();
    setState(() {
      _floaters.add(_GoldFloater(_nextFloaterId, widget.game.goldPerTap));
      _nextFloaterId++;
    });
    _bounce.forward(from: 0);
  }

  void _removeFloater(int id) {
    if (!mounted) {
      return;
    }
    setState(() {
      _floaters.removeWhere((floater) => floater.id == id);
    });
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
                'Opening the lobby...',
                style: TextStyle(color: cream, fontSize: 18),
              ),
            ),
          );
        }

        return Scaffold(
          key: const Key('game-ready'),
          backgroundColor: navy,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _GoldPanel(
                        gold: game.gold,
                        goldPerTap: game.goldPerTap,
                        goldPerSecond: game.goldPerSecond,
                      ),
                      Expanded(
                        child: _Lobby(
                          floaters: _floaters,
                          bounce: _bounce,
                          onTapGoblin: _tapGoblin,
                          onFloaterDone: _removeFloater,
                        ),
                      ),
                      _UpgradeDeskButton(
                        level: game.deskLevel,
                        costLabel: formatGold(deskUpgradeCost(game.deskLevel)),
                        canAfford: game.canAffordDesk,
                        onPressed: game.buyDesk,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GoldPanel extends StatelessWidget {
  const _GoldPanel({
    required this.gold,
    required this.goldPerTap,
    required this.goldPerSecond,
  });

  final double gold;
  final int goldPerTap;
  final double goldPerSecond;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: slate,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 4),
          Text(
            formatGold(gold),
            key: const Key('gold-amount'),
            style: const TextStyle(
              color: cyan,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '+$goldPerTap per tap',
            key: const Key('gold-per-tap'),
            style: const TextStyle(color: cream, fontSize: 16),
          ),
          Text(
            '+${formatGold(goldPerSecond)} per second',
            key: const Key('gold-per-second'),
            style: const TextStyle(color: cream, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _Lobby extends StatelessWidget {
  const _Lobby({
    required this.floaters,
    required this.bounce,
    required this.onTapGoblin,
    required this.onFloaterDone,
  });

  final List<_GoldFloater> floaters;
  final Animation<double> bounce;
  final VoidCallback onTapGoblin;
  final void Function(int id) onFloaterDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Text(
          'Floor 1',
          style: TextStyle(color: cream, fontSize: 14, letterSpacing: 0.6),
        ),
        const SizedBox(height: 4),
        const Text(
          'The Executive Lobby',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cream,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boxHeight = min(300.0, constraints.maxHeight);
              final emojiSize = min(132.0, boxHeight * 0.48);
              return Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: AnimatedBuilder(
                      animation: bounce,
                      builder: (context, child) {
                        final scale = 1 + (0.08 * bounce.value);
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Material(
                        color: slate,
                        borderRadius: BorderRadius.circular(cornerRadius),
                        child: InkWell(
                          key: const Key('goblin'),
                          borderRadius: BorderRadius.circular(cornerRadius),
                          onTap: onTapGoblin,
                          child: SizedBox(
                            width: 280,
                            height: boxHeight,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '👺',
                                  style: TextStyle(
                                    fontSize: emojiSize,
                                    height: 1,
                                  ),
                                ),
                                if (boxHeight >= 120) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Receptionist',
                                    style: TextStyle(
                                      color: cream,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final floater in floaters)
                    Padding(
                      padding: EdgeInsets.only(
                        top: max(0, (constraints.maxHeight - boxHeight) / 2),
                        left: (floater.id % 3) * 36,
                      ),
                      child: IgnorePointer(
                        child: _GoldPop(
                          key: ValueKey<int>(floater.id),
                          text: '+${floater.amount}',
                          onFinished: () => onFloaterDone(floater.id),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap the goblin. The lobby also earns gold every second.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cream, fontSize: 15),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _UpgradeDeskButton extends StatelessWidget {
  const _UpgradeDeskButton({
    required this.level,
    required this.costLabel,
    required this.canAfford,
    required this.onPressed,
  });

  final int level;
  final String costLabel;
  final bool canAfford;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final background = canAfford ? emerald : slate;
    final textColor = canAfford ? cream : cream.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: const Key('upgrade-desk'),
        color: background,
        borderRadius: BorderRadius.circular(cornerRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(cornerRadius),
          onTap: canAfford ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                Text(
                  'Upgrade Desk',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Level $level',
                  style: TextStyle(color: textColor, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cost $costLabel gold',
                  key: const Key('upgrade-cost'),
                  style: TextStyle(color: textColor, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '+1 gold per tap',
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldPop extends StatefulWidget {
  const _GoldPop({super.key, required this.text, required this.onFinished});

  final String text;
  final VoidCallback onFinished;

  @override
  State<_GoldPop> createState() => _GoldPopState();
}

class _GoldPopState extends State<_GoldPop> {
  bool _flyAway = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _flyAway = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _flyAway ? const Offset(0, -1.4) : Offset.zero,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: _flyAway ? 0 : 1,
        duration: const Duration(milliseconds: 650),
        onEnd: () {
          if (mounted && _flyAway) {
            widget.onFinished();
          }
        },
        child: Text(
          widget.text,
          style: const TextStyle(
            color: cyan,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _GoldFloater {
  _GoldFloater(this.id, this.amount);

  final int id;
  final int amount;
}
