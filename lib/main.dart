import 'dart:math';

import 'package:flutter/material.dart';

// Colors from the style guide. Named constants keep the widgets easy to read.
const Color _navy = Color(0xFF1E293B);
const Color _slate = Color(0xFF334155);
const Color _cream = Color(0xFFF8FAFC);
const Color _cyan = Color(0xFF06B6D4);
const Color _emerald = Color(0xFF10B981);

const double _cornerRadius = 12;

/// Price of the next Upgrade Desk purchase.
///
/// Upgrade Cost = Base Cost × Multiplier^Level
/// Base cost is 10 gold and the multiplier is 1.10, so level 0 costs 10,
/// level 1 costs 11, level 2 costs 12.1, and so on.
///
/// Rounded to the nearest tenth so the price on the button is the price
/// that is actually spent (binary floating point would otherwise leave
/// dust like 12.1000000001).
double deskUpgradeCost(int level) {
  final rawCost = 10 * pow(1.10, level);
  return (rawCost * 10).round() / 10;
}

/// Shows a number the way a player expects to read gold: "12" or "12.1".
String formatGold(double value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) {
    return rounded.toInt().toString();
  }
  return rounded.toStringAsFixed(1);
}

void main() {
  runApp(const SpireTycoonApp());
}

class SpireTycoonApp extends StatelessWidget {
  const SpireTycoonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spire Tycoon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _navy,
        // Roboto is the font Flutter ships with Material. It is a plain sans-serif.
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(surface: _navy, primary: _emerald),
      ),
      home: const ExecutiveLobbyPage(),
    );
  }
}

class ExecutiveLobbyPage extends StatefulWidget {
  const ExecutiveLobbyPage({super.key});

  @override
  State<ExecutiveLobbyPage> createState() => _ExecutiveLobbyPageState();
}

class _ExecutiveLobbyPageState extends State<ExecutiveLobbyPage>
    with SingleTickerProviderStateMixin {
  // Gold the player has right now. Starts at 0.
  double _gold = 0;

  // How much gold one tap on the goblin gives. Starts at 1 so the first
  // taps earn something before any upgrade is bought.
  int _goldPerTap = 1;

  // How many times Upgrade Desk has been bought. The next purchase uses
  // this as "level" in the cost formula, then we add 1.
  int _deskLevel = 0;

  // Little "+N" labels that float up from the goblin and then disappear.
  final List<_GoldFloater> _floaters = [];
  int _nextFloaterId = 0;

  // Drives the small scale bounce when the goblin is tapped.
  // 0 means normal size, 1 means fully "squashed" outward.
  late final AnimationController _bounce;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _bounce.addStatusListener((status) {
      // Grow, then shrink back. A new tap calls forward(from: 0), which
      // restarts the bounce even if the previous one was still playing.
      if (status == AnimationStatus.completed) {
        _bounce.reverse();
      }
    });
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  bool get _canAffordDesk => _gold + 0.001 >= deskUpgradeCost(_deskLevel);

  void _tapGoblin() {
    setState(() {
      _gold = ((_gold + _goldPerTap) * 10).round() / 10;
      _floaters.add(_GoldFloater(_nextFloaterId, _goldPerTap));
      _nextFloaterId++;
    });
    _bounce.forward(from: 0);
  }

  void _buyDeskUpgrade() {
    final cost = deskUpgradeCost(_deskLevel);
    if (_gold + 0.001 < cost) {
      return;
    }
    setState(() {
      _gold = ((_gold - cost) * 10).round() / 10;
      _deskLevel += 1;
      _goldPerTap += 1;
    });
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
    final upgradeCost = deskUpgradeCost(_deskLevel);
    final canAfford = _canAffordDesk;

    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              // Gold stays at the top and the upgrade stays at the bottom.
              // The lobby takes whatever height is left so a laptop window
              // still shows the button without scrolling.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GoldPanel(gold: _gold, goldPerTap: _goldPerTap),
                  Expanded(
                    child: _Lobby(
                      floaters: _floaters,
                      bounce: _bounce,
                      onTapGoblin: _tapGoblin,
                      onFloaterDone: _removeFloater,
                    ),
                  ),
                  _UpgradeDeskButton(
                    level: _deskLevel,
                    costLabel: formatGold(upgradeCost),
                    canAfford: canAfford,
                    onPressed: _buyDeskUpgrade,
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

class _GoldPanel extends StatelessWidget {
  const _GoldPanel({required this.gold, required this.goldPerTap});

  final double gold;
  final int goldPerTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _slate,
        borderRadius: BorderRadius.circular(_cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GOLD',
            style: TextStyle(
              color: _cream,
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
              color: _cyan,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '+$goldPerTap per tap',
            key: const Key('gold-per-tap'),
            style: const TextStyle(color: _cream, fontSize: 16),
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
          style: TextStyle(color: _cream, fontSize: 14, letterSpacing: 0.6),
        ),
        const SizedBox(height: 4),
        const Text(
          'The Executive Lobby',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _cream,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        // Expanded takes the leftover height, so the goblin stays as large
        // as the window allows (up to 240) and the upgrade button below
        // is never pushed off the screen.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Cap the receptionist so it stays a big tap target on a
              // tall window without covering the gold counter or the button.
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
                        // bounce.value goes 0 -> 1 -> 0. Scale 1.0 to 1.08.
                        final scale = 1 + (0.08 * bounce.value);
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: Material(
                        color: _slate,
                        borderRadius: BorderRadius.circular(_cornerRadius),
                        child: InkWell(
                          key: const Key('goblin'),
                          borderRadius: BorderRadius.circular(_cornerRadius),
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
                                      color: _cream,
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
                  // Floaters ignore taps so the player can keep tapping
                  // while "+N" is still on screen.
                  for (final floater in floaters)
                    Padding(
                      // Nudge each popup sideways so quick taps do not stack
                      // into one unreadable blob.
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
          'Tap the goblin to earn gold',
          style: TextStyle(color: _cream, fontSize: 15),
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
    // Emerald when the player can pay, slate when they cannot.
    // onTap is null in the greyed-out state so the button does nothing.
    final background = canAfford ? _emerald : _slate;
    final textColor = canAfford ? _cream : _cream.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: const Key('upgrade-desk'),
        color: background,
        borderRadius: BorderRadius.circular(_cornerRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(_cornerRadius),
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

/// One "+N" that rises and fades, then tells the page to delete it.
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
    // Wait one frame so the "+N" is painted at full opacity, then animate.
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
            color: _cyan,
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
