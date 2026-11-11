import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Short office noises.
///
/// The wav files in assets/sounds were generated for this project as simple
/// sine tones. They are original, not copied from a sound library.
enum SoundEffect { coin, ding, latch, buzz }

class SoundBoard {
  /// Widget tests set this so they never touch the audio plugin.
  static bool suppressForTests = false;

  final Map<SoundEffect, AudioPlayer> _players = {};

  Future<void> play(SoundEffect effect, {required bool muted}) async {
    if (suppressForTests || muted) {
      return;
    }
    try {
      final player = _players.putIfAbsent(effect, AudioPlayer.new);
      await player.stop();
      await player.play(AssetSource(_file(effect)));
    } catch (_) {
      // A missing speaker should not stop the game.
    }
  }

  String _file(SoundEffect effect) {
    switch (effect) {
      case SoundEffect.coin:
        return 'sounds/coin.wav';
      case SoundEffect.ding:
        return 'sounds/ding.wav';
      case SoundEffect.latch:
        return 'sounds/latch.wav';
      case SoundEffect.buzz:
        return 'sounds/buzz.wav';
    }
  }

  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}

/// Lets any screen play a sound without threading the board through every widget.
class OfficeSounds extends InheritedWidget {
  const OfficeSounds({
    super.key,
    required this.board,
    required this.muted,
    required super.child,
  });

  final SoundBoard board;
  final bool muted;

  static OfficeSounds? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OfficeSounds>();
  }

  static void play(BuildContext context, SoundEffect effect) {
    final scope = maybeOf(context);
    if (scope == null) {
      return;
    }
    scope.board.play(effect, muted: scope.muted);
  }

  @override
  bool updateShouldNotify(OfficeSounds oldWidget) {
    return oldWidget.muted != muted || oldWidget.board != board;
  }
}
