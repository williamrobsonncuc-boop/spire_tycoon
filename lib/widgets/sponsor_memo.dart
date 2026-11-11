import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A 3 second practice ad. Nothing is sold and no ad network is contacted.
class SponsorMemo extends StatefulWidget {
  const SponsorMemo({super.key});

  @override
  State<SponsorMemo> createState() => _SponsorMemoState();
}

class _SponsorMemoState extends State<SponsorMemo> {
  int _secondsLeft = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        Navigator.of(context).pop();
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: navy,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                key: const Key('sponsor-memo'),
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: slate,
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: crimson,
                        borderRadius: BorderRadius.circular(cornerRadius),
                      ),
                      child: const Text(
                        'PRACTICE AD',
                        style: TextStyle(
                          color: cream,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sponsor memo',
                      style: TextStyle(
                        color: cream,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This is not a real advertisement. No company paid for this screen, and nothing is being sold.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cream, fontSize: 16, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '$_secondsLeft',
                      key: const Key('sponsor-countdown'),
                      style: const TextStyle(
                        color: cyan,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Please wait. The memo ends by itself.',
                      style: TextStyle(color: cream, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
