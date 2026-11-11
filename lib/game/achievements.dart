import 'formulas.dart';

/// Levels that double a floor's speed. 10, 25, 50, 100, 200, then the same
/// pattern scaled up so a long run still has something to hit.
const List<int> milestoneLevels = [
  10,
  25,
  50,
  100,
  200,
  500,
  1000,
  2000,
  5000,
  10000,
];

/// How many speed doubles this upgrade level has earned.
int milestoneDoubles(int level) {
  if (level <= 0) {
    return 0;
  }
  var count = 0;
  for (final mark in milestoneLevels) {
    if (level >= mark) {
      count += 1;
    }
  }
  return count;
}

/// 1 at level 9, 2 at level 10, 4 at level 25, and so on. Capped so it stays finite.
double milestoneSpeed(int level) {
  final doubles = milestoneDoubles(level);
  if (doubles <= 0) {
    return 1;
  }
  return safePow(2, doubles > 20 ? 20 : doubles);
}

bool crossedMilestone(int previousLevel, int newLevel) {
  for (final mark in milestoneLevels) {
    if (previousLevel < mark && newLevel >= mark) {
      return true;
    }
  }
  return false;
}

class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.detail,
    required this.tickets,
  });

  final String id;
  final String title;
  final String detail;
  final int tickets;
}

const List<AchievementDef> achievementCatalog = [
  AchievementDef(
    id: 'synergy',
    title: 'Synergy Achieved',
    detail: 'Have two different staff on the payroll at once.',
    tickets: 1,
  ),
  AchievementDef(
    id: 'takeover',
    title: 'Hostile Takeover',
    detail: 'Win a market campaign.',
    tickets: 2,
  ),
  AchievementDef(
    id: 'billion',
    title: 'First Billion',
    detail: 'Earn 1,000,000,000 gold over your career.',
    tickets: 5,
  ),
  AchievementDef(
    id: 'floor10',
    title: 'District Manager',
    detail: 'Open floor 10.',
    tickets: 1,
  ),
  AchievementDef(
    id: 'desk25',
    title: 'Corner Office',
    detail: 'Upgrade the lobby desk to level 25.',
    tickets: 1,
  ),
];

AchievementDef? achievementById(String id) {
  for (final item in achievementCatalog) {
    if (item.id == id) {
      return item;
    }
  }
  return null;
}
