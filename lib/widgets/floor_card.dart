import 'dart:math';

import 'package:flutter/material.dart';

import '../game/floor_catalog.dart';
import '../game/formulas.dart';
import '../game/game_model.dart';
import '../game/sound_board.dart';
import '../theme/app_colors.dart';
import 'sponsor_memo.dart';

/// One floor in the scrolling tower. ListView builds only the ones on screen.
class FloorCard extends StatelessWidget {
  const FloorCard({super.key, required this.game, required this.index});

  final GameModel game;
  final int index;

  @override
  Widget build(BuildContext context) {
    final recipe = floorRecipe(index, prestige: game.restructures);
    final progress = game.progressOf(index);
    final previousReady = index == 0 || game.isRunning(index - 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: slate,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            recipe.title,
            style: const TextStyle(
              color: cream,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            recipe.blurb,
            style: const TextStyle(color: cream, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 12),
          if (index == 0) ...[
            _LobbyTap(game: game),
            const SizedBox(height: 8),
            Text(
              'Crit ${(game.critChance * 100).round()}% for ×10. A combo builds for 2 seconds.',
              key: const Key('crit-odds'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: cream, fontSize: 13, height: 1.3),
            ),
            if (game.combo > 1) ...[
              const SizedBox(height: 4),
              Text(
                game.comboLabel,
                key: const Key('combo-meter'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: cyan,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (game.lastQuip != null) ...[
              const SizedBox(height: 8),
              Container(
                key: const Key('dialogue-bubble'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
                child: Text(
                  game.lastQuip!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: cream,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ] else
            Center(
              child: Text(recipe.emoji, style: const TextStyle(fontSize: 48)),
            ),
          const SizedBox(height: 12),
          if (progress.running) ...[
            if (progress.clogged)
              _ClogBanner(onClear: () => game.clearClog(index))
            else if (progress.sleeping)
              _SleepBanner(onWake: () => game.wakeFloor(index))
            else
              _RunningSummary(game: game, index: index),
            const SizedBox(height: 8),
            if (recipe.kind == FloorKind.compliance) ...[
              _PolicyButton(game: game),
              const SizedBox(height: 8),
            ],
            _UpgradeButton(game: game, index: index),
          ] else if (game.bossFloor == index)
            _BossBanner(game: game, index: index)
          else if (progress.isBuilding)
            _BuildingBanner(game: game, index: index)
          else
            _BuildButton(
              game: game,
              index: index,
              previousReady: previousReady,
            ),
        ],
      ),
    );
  }
}

class _RunningSummary extends StatelessWidget {
  const _RunningSummary({required this.game, required this.index});

  final GameModel game;
  final int index;

  @override
  Widget build(BuildContext context) {
    final kind = floorKind(index, prestige: game.restructures);
    final String line;
    if (kind == FloorKind.compliance) {
      final rate = game.complianceRateFor(index);
      line = '+${formatNumber(rate)} compliance / sec';
    } else if (kind == FloorKind.slowBurst) {
      final lump = game.goldRateFor(index) * slowBurstSeconds;
      line = 'Lump every ${slowBurstSeconds}s: ${formatNumber(lump)} gold';
    } else {
      line = '+${formatNumber(game.goldRateFor(index))} gold / sec';
    }
    return Text(
      'Level ${game.progressOf(index).level} · $line',
      style: const TextStyle(
        color: cyan,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LobbyTap extends StatefulWidget {
  const _LobbyTap({required this.game});

  final GameModel game;

  @override
  State<_LobbyTap> createState() => _LobbyTapState();
}

class _LobbyTapState extends State<_LobbyTap> with TickerProviderStateMixin {
  final List<_Pop> _pops = [];
  int _nextId = 0;
  late final AnimationController _bounce;
  late final AnimationController _shake;

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
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _bounce.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _tap() {
    OfficeSounds.play(context, SoundEffect.coin);
    final gained = widget.game.tapLobby();
    setState(() {
      _pops.add(_Pop(_nextId, gained, widget.game.lastTapWasCrit));
      _nextId += 1;
    });
    _bounce.forward(from: 0);
    if (widget.game.lastTapWasCrit) {
      _shake.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedBuilder(
              animation: Listenable.merge([_bounce, _shake]),
              builder: (context, child) {
                final scale = 1 + (0.08 * _bounce.value);
                final wobble =
                    sin(_shake.value * pi * 6) * 8 * (1 - _shake.value);
                return Transform.translate(
                  offset: Offset(wobble, 0),
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: Material(
                color: navy,
                borderRadius: BorderRadius.circular(cornerRadius),
                child: InkWell(
                  key: const Key('goblin'),
                  borderRadius: BorderRadius.circular(cornerRadius),
                  onTap: _tap,
                  child: const SizedBox(
                    width: 220,
                    height: 140,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('👺', style: TextStyle(fontSize: 64, height: 1)),
                        SizedBox(height: 6),
                        Text(
                          'Receptionist',
                          style: TextStyle(color: cream, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          for (final pop in _pops)
            Padding(
              padding: EdgeInsets.only(left: (pop.id % 3) * 28),
              child: IgnorePointer(
                child: _GoldPop(
                  key: ValueKey<int>(pop.id),
                  text: '+${formatNumber(pop.amount)}',
                  crit: pop.crit,
                  onFinished: () {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _pops.removeWhere((item) => item.id == pop.id);
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BossBanner extends StatelessWidget {
  const _BossBanner({required this.game, required this.index});

  final GameModel game;
  final int index;

  @override
  Widget build(BuildContext context) {
    final left = game.bossSecondsLeft ?? 0;
    return Container(
      key: Key('boss-floor-$index'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Column(
        children: [
          Text(
            bossChallengeName(index),
            style: const TextStyle(
              color: cream,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reach ${formatNumber(game.bossTarget)} gold per second. You are at ${formatNumber(game.goldPerSecond)}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: cream, fontSize: 14, height: 1.3),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatBuildTime(left)} left. If you miss it, the gold is returned.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: cyan, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _BuildButton extends StatelessWidget {
  const _BuildButton({
    required this.game,
    required this.index,
    required this.previousReady,
  });

  final GameModel game;
  final int index;
  final bool previousReady;

  @override
  Widget build(BuildContext context) {
    final cost = game.buildPrice(index);
    final affordable = game.canBuild(index);
    final background = affordable ? emerald : slate;
    final textColor = affordable ? cream : cream.withValues(alpha: 0.55);
    final boss = isBossFloor(index);
    final String detail;
    if (!previousReady) {
      detail = 'Build the floor below first';
    } else if (boss) {
      detail =
          '${bossChallengeName(index)}. Cost ${formatNumber(cost)} gold. Reach a higher income within 45s. Fail and the gold comes back.';
    } else {
      detail =
          'Cost ${formatNumber(cost)} gold · ${formatBuildTime(game.constructionSeconds(index))}';
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(cornerRadius),
      child: InkWell(
        key: Key('build-floor-$index'),
        borderRadius: BorderRadius.circular(cornerRadius),
        onTap: affordable
            ? () {
                OfficeSounds.play(context, SoundEffect.ding);
                game.startBuild(index);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            children: [
              Text(
                boss ? 'Start ${bossChallengeName(index)}' : 'Build floor',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildingBanner extends StatelessWidget {
  const _BuildingBanner({required this.game, required this.index});

  final GameModel game;
  final int index;

  @override
  Widget build(BuildContext context) {
    final left = game.buildSecondsLeft(index) ?? 0;
    final canSkip = game.testDiamonds >= 1;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Column(
        children: [
          Text(
            'Under construction · ${formatBuildTime(left)} left',
            key: Key('building-$index'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: cyan,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: Key('skip-diamond-$index'),
            onPressed: canSkip ? () => game.skipBuildWithDiamond(index) : null,
            child: Text(
              canSkip
                  ? 'Spend 1 TEST diamond to finish'
                  : 'Need 1 TEST diamond to finish now',
            ),
          ),
          TextButton(
            key: Key('halve-build-$index'),
            onPressed: () async {
              await showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (context) => const SponsorMemo(),
              );
              game.halveBuild(index);
            },
            child: const Text('Watch sponsor memo to halve the timer'),
          ),
        ],
      ),
    );
  }
}

class _SleepBanner extends StatelessWidget {
  const _SleepBanner({required this.onWake});

  final VoidCallback onWake;

  @override
  Widget build(BuildContext context) {
    return _Buzz(
      child: Material(
        color: crimson,
        borderRadius: BorderRadius.circular(cornerRadius),
        child: InkWell(
          key: const Key('wake-orc'),
          borderRadius: BorderRadius.circular(cornerRadius),
          onTap: onWake,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              '! Sleeping orc. Tap to wake the crew.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cream,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClogBanner extends StatelessWidget {
  const _ClogBanner({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _Buzz(
      child: Material(
        color: crimson,
        borderRadius: BorderRadius.circular(cornerRadius),
        child: InkWell(
          key: const Key('clear-clog'),
          borderRadius: BorderRadius.circular(cornerRadius),
          onTap: onClear,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              'Clogged pipe. Tap to clear it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cream,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Buzz extends StatefulWidget {
  const _Buzz({required this.child});

  final Widget child;

  @override
  State<_Buzz> createState() => _BuzzState();
}

class _BuzzState extends State<_Buzz> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        OfficeSounds.play(context, SoundEffect.buzz);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({required this.game, required this.index});

  final GameModel game;
  final int index;

  @override
  Widget build(BuildContext context) {
    final level = game.progressOf(index).level;
    final cost = floorUpgradeCost(index, level);
    final affordable = game.canUpgrade(index);
    final background = affordable ? emerald : slate;
    final textColor = affordable ? cream : cream.withValues(alpha: 0.55);
    final title = index == 0 ? 'Upgrade Desk' : 'Upgrade floor';
    final effect = index == 0
        ? '+1 gold per tap'
        : floorKind(index, prestige: game.restructures) == FloorKind.compliance
        ? '+compliance each second'
        : '+gold each second';

    return Material(
      key: index == 0 ? const Key('upgrade-desk') : Key('upgrade-floor-$index'),
      color: background,
      borderRadius: BorderRadius.circular(cornerRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(cornerRadius),
        onTap: affordable
            ? () {
                OfficeSounds.play(context, SoundEffect.ding);
                game.upgradeFloor(index);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Level $level',
                style: TextStyle(color: textColor, fontSize: 14),
              ),
              Text(
                'Cost ${formatNumber(cost)} gold',
                key: index == 0 ? const Key('upgrade-cost') : null,
                style: TextStyle(color: textColor, fontSize: 14),
              ),
              Text(effect, style: TextStyle(color: textColor, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyButton extends StatelessWidget {
  const _PolicyButton({required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    final affordable = game.canBuyPolicy;
    final background = affordable ? emerald : navy;
    final textColor = affordable ? cream : cream.withValues(alpha: 0.7);
    final bonus = game.policyLevel * 10;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(cornerRadius),
      child: InkWell(
        key: const Key('buy-policy'),
        borderRadius: BorderRadius.circular(cornerRadius),
        onTap: affordable ? game.buyPolicy : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              Text(
                'File a policy',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Policies ${game.policyLevel} · +$bonus% gold everywhere',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 13),
              ),
              Text(
                'Cost ${formatNumber(game.policyCost)} compliance',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoldPop extends StatefulWidget {
  const _GoldPop({
    super.key,
    required this.text,
    required this.onFinished,
    this.crit = false,
  });

  final String text;
  final VoidCallback onFinished;
  final bool crit;

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
      offset: _flyAway ? const Offset(0, -1.2) : Offset.zero,
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
          style: TextStyle(
            color: widget.crit ? crimson : cyan,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Pop {
  _Pop(this.id, this.amount, this.crit);
  final int id;
  final double amount;
  final bool crit;
}
