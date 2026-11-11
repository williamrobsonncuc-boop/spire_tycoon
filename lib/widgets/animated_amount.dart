import 'dart:math';

import 'package:flutter/material.dart';

import '../game/formulas.dart';

/// The digits stay exact. A short pulse shows that the wallet just changed.
class AnimatedAmount extends StatefulWidget {
  const AnimatedAmount({
    super.key,
    required this.value,
    required this.style,
    this.prefix = '',
    this.amountKey,
  });

  final double value;
  final TextStyle style;
  final String prefix;
  final Key? amountKey;

  @override
  State<AnimatedAmount> createState() => _AnimatedAmountState();
}

class _AnimatedAmountState extends State<AnimatedAmount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void didUpdateWidget(AnimatedAmount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) {
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1 + 0.08 * sin(_controller.value * pi);
        return Transform.scale(scale: scale, child: child);
      },
      child: Text(
        '${widget.prefix}${formatNumber(widget.value)}',
        key: widget.amountKey,
        style: widget.style,
      ),
    );
  }
}
