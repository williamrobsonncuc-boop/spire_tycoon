import 'package:flutter/material.dart';

import 'game/game_model.dart';
import 'screens/lobby_page.dart';
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

  @override
  void initState() {
    super.initState();
    _ownsGame = widget.game == null;
    _game = widget.game ?? GameModel();
    _game.load();
  }

  @override
  void dispose() {
    if (_ownsGame) {
      _game.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spire Tycoon',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: LobbyPage(game: _game),
    );
  }
}
