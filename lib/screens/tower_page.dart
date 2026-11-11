import 'package:flutter/material.dart';

import '../game/formulas.dart';
import '../game/game_model.dart';
import '../theme/app_colors.dart';
import '../widgets/floor_card.dart';
import '../widgets/welcome_back_dialog.dart';

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
          backgroundColor: navy,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: [
                      _TowerHeader(game: game),
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
          const Text(
            'GOLD',
            style: TextStyle(
              color: cream,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
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
