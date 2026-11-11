import 'dart:math';

/// Rounds to the nearest tenth so prices and payouts match what we display.
double roundTenths(double value) => (value * 10).round() / 10;

/// "12" or "12.1". Bigger numbers get K/M/B suffixes in a later feature.
String formatGold(double value) {
  final rounded = roundTenths(value);
  if (rounded == rounded.roundToDouble()) {
    return rounded.toInt().toString();
  }
  return rounded.toStringAsFixed(1);
}

/// Price of the next Upgrade Desk purchase.
///
/// Upgrade Cost = Base Cost × Multiplier^Level
/// Base cost is 10 gold and the multiplier is 1.10.
double deskUpgradeCost(int level) =>
    roundTenths((10 * pow(1.10, level)).toDouble());

/// Gold the lobby earns by itself.
///
/// One fifth of a tap, every second. Upgrading the desk raises both
/// tapping and this idle rate.
double idleGoldPerSecond(int goldPerTap) => roundTenths(goldPerTap * 0.2);

/// How long an absence can pay out. Longer gaps are ignored.
const Duration offlineCap = Duration(hours: 8);

/// Shorter than this and we skip the welcome-back note. A quick refresh
/// should not pop a dialog.
const Duration offlineMinimum = Duration(seconds: 30);

/// Gold earned while the tab was closed.
///
/// Returns 0 when [away] is under 30 seconds. Caps the counted time at 8 hours.
double offlineEarnings({
  required double goldPerSecond,
  required Duration away,
}) {
  if (away < offlineMinimum) {
    return 0;
  }
  final counted = away > offlineCap ? offlineCap : away;
  return roundTenths(goldPerSecond * counted.inSeconds);
}

/// "2 h 5 min", used on the welcome-back note.
String formatAway(Duration away) {
  final counted = away > offlineCap ? offlineCap : away;
  final hours = counted.inHours;
  final minutes = counted.inMinutes.remainder(60);
  if (hours > 0 && minutes > 0) {
    return '$hours h $minutes min';
  }
  if (hours > 0) {
    return '$hours h';
  }
  if (minutes > 0) {
    return '$minutes min';
  }
  return '${counted.inSeconds} sec';
}
