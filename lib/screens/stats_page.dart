import 'package:flutter/material.dart';

import '../game/formulas.dart';
import '../game/game_model.dart';
import '../theme/app_colors.dart';

/// Lifetime numbers and a net-worth chart. Nothing here is a real account.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key, required this.game});

  final GameModel game;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: cream,
        title: const Text('Stats'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: game,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Net worth is the gold in your wallet plus 1,000 for each Shareholder Equity point. A restructuring spends the gold and keeps the equity, so the line does not pretend the company vanished.',
                  style: TextStyle(color: cream, fontSize: 15, height: 1.35),
                ),
                const SizedBox(height: 12),
                _Stat(
                  label: 'Net worth',
                  value: formatNumber(game.netWorth),
                  statKey: 'stat-net-worth',
                ),
                _Stat(
                  label: 'Lifetime gold',
                  value: formatNumber(game.lifetimeGold),
                  statKey: 'stat-lifetime',
                ),
                _Stat(
                  label: 'Floors built',
                  value: formatNumber(game.floorsBuilt.toDouble()),
                  statKey: 'stat-floors',
                ),
                _Stat(
                  label: 'Time played',
                  value: formatPlayTime(game.playSeconds),
                  statKey: 'stat-play-time',
                ),
                const SizedBox(height: 12),
                Text(
                  game.netWorthHistory.isEmpty
                      ? 'The chart fills in as you play. Each point is ${game.netWorthEvery} seconds with the game open.'
                      : 'Each point is ${game.netWorthEvery} seconds with the game open.',
                  key: const Key('stat-chart-note'),
                  style: const TextStyle(
                    color: cream,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  key: const Key('net-worth-chart'),
                  height: 160,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: slate,
                    borderRadius: BorderRadius.circular(cornerRadius),
                  ),
                  child: CustomPaint(
                    painter: _NetWorthPainter(game.netWorthHistory),
                    child: const SizedBox.expand(),
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

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.statKey,
  });

  final String label;
  final String value;
  final String statKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$label: $value',
        key: Key(statKey),
        style: const TextStyle(
          color: cyan,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NetWorthPainter extends CustomPainter {
  _NetWorthPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..color = cream.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      axis,
    );
    if (values.isEmpty) {
      return;
    }
    var minValue = values.first;
    var maxValue = values.first;
    for (final value in values) {
      if (value < minValue) {
        minValue = value;
      }
      if (value > maxValue) {
        maxValue = value;
      }
    }
    final span = maxValue - minValue < 0.001 ? 1.0 : maxValue - minValue;
    final line = Paint()
      ..color = cyan
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y =
          size.height - 4 - ((values[i] - minValue) / span) * (size.height - 8);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_NetWorthPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
