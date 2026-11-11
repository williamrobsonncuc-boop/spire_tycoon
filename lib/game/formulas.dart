import 'dart:math';

/// Rounds to the nearest tenth so prices and payouts match what we display.
double roundTenths(double value) => (value * 10).round() / 10;

/// Small amounts stay exact: "12" or "12.1".
///
/// From 1,000 upward the game uses short suffixes: 1.2K, 3.4M, 5.6B, 7.8T,
/// then aa, ab, ac... so an endless tower can show huge costs.
String formatNumber(double value) {
  if (value.isNaN || value.isInfinite) {
    return '0';
  }
  final sign = value < 0 ? '-' : '';
  var magnitude = value.abs();
  if (magnitude < 1000) {
    return sign + _formatSmall(magnitude);
  }

  var tier = 0;
  while (magnitude >= 1000 && tier < 400) {
    magnitude /= 1000;
    tier += 1;
  }

  var shown = (magnitude * 10).round() / 10;
  // 999.95K rounds to 1000.0K, which should read as 1.0M.
  if (shown >= 1000) {
    shown = 1;
    tier += 1;
  }
  return '$sign${shown.toStringAsFixed(1)}${_suffixForTier(tier)}';
}

String _formatSmall(double value) {
  final rounded = roundTenths(value);
  if (rounded == rounded.roundToDouble()) {
    return rounded.toInt().toString();
  }
  return rounded.toStringAsFixed(1);
}

/// Kept so older call sites stay easy to read. Same rules as [formatNumber].
String formatGold(double value) => formatNumber(value);

String _suffixForTier(int tier) {
  const named = ['', 'K', 'M', 'B', 'T'];
  if (tier < named.length) {
    return named[tier];
  }
  // tier 5 is the first "aa" group (1,000^5 = 1 quadrillion).
  final index = tier - named.length;
  final first = String.fromCharCode(97 + (index ~/ 26) % 26);
  final second = String.fromCharCode(97 + (index % 26));
  return '$first$second';
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
