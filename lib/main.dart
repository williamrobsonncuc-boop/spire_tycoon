import 'package:flutter/material.dart';

import 'game/game_model.dart';
import 'game/sound_board.dart';
import 'screens/tower_page.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(const SpireTycoonApp());
}

class SpireTycoonApp extends StatefulWidget {
  const SpireTycoonApp({super.key, this.game});

  /// Tests can pass their own model. The app creates one when this is null.
  final GameModel? game;

  @override
  State<SpireTycoonApp> createState() => _SpireTycoonAppState();
}

class _SpireTycoonAppState extends State<SpireTycoonApp> {
  late final GameModel _game;
  late final bool _ownsGame;
  final SoundBoard _sounds = SoundBoard();

  @override
  void initState() {
    super.initState();
    _ownsGame = widget.game == null;
    _game = widget.game ?? GameModel();
    _game.load();
  }

  @override
  void dispose() {
    _sounds.dispose();
    if (_ownsGame) {
      _game.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _game,
      builder: (context, _) {
        return OfficeSounds(board: _sounds, muted: _game.muted, child: _app());
      },
    );
  }

  MaterialApp _app() {
    return MaterialApp(
      title: 'Spire Tycoon',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: TowerPage(game: _game),
    );
  }
}
