/// Local weekend event helpers. Nothing here talks to a server.
bool isWeekend(DateTime time) {
  return time.weekday == DateTime.saturday || time.weekday == DateTime.sunday;
}

/// `202647` style key: year plus the week of that year.
int weekKey(DateTime time) {
  final day = DateTime(time.year, time.month, time.day);
  final start = DateTime(day.year, 1, 1);
  final week = day.difference(start).inDays ~/ 7;
  return day.year * 100 + week;
}

String dayKey(DateTime time) {
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  return '${time.year}-$month-$day';
}

String yesterdayKey(DateTime time) {
  return dayKey(time.subtract(const Duration(days: 1)));
}

const List<String> subsidiaryNames = [
  'Hex Annex',
  'Forge Outlet',
  'Banshee Branch',
  'Lich Capital West',
  'Imp Marketing',
];

String subsidiaryName(int week) {
  final index = week.abs() % subsidiaryNames.length;
  return subsidiaryNames[index];
}

/// One minute of the main tower, kept inside an int so the board cannot overflow.
int weekendReportPoints(double goldPerSecond) {
  if (goldPerSecond.isNaN || goldPerSecond.isInfinite || goldPerSecond <= 0) {
    return 1;
  }
  final raw = goldPerSecond * 60;
  if (raw >= 1000000000) {
    return 1000000000;
  }
  final points = raw.round();
  return points < 1 ? 1 : points;
}

int addScore(int current, int gain) {
  if (gain <= 0) {
    return current < 0 ? 0 : current;
  }
  if (current < 0) {
    current = 0;
  }
  if (current > 2000000000 - gain) {
    return 2000000000;
  }
  return current + gain;
}

class BoardRow {
  const BoardRow({
    required this.name,
    required this.score,
    required this.standIn,
  });

  final String name;
  final int score;

  /// True for the fake companies. They are not other players.
  final bool standIn;
}

const List<String> standInCompanies = [
  'Hex & Co',
  'Banshee LLP',
  'Forge United',
  'Lich Capital',
];

/// Player plus four fixed rivals. The rivals change a little each week.
List<BoardRow> weekendBoard({required int week, required int playerScore}) {
  final rows = <BoardRow>[
    BoardRow(
      name: 'Spire Corp (you)',
      score: playerScore < 0 ? 0 : playerScore,
      standIn: false,
    ),
    for (var i = 0; i < standInCompanies.length; i++)
      BoardRow(
        name: standInCompanies[i],
        score: 120 + (week.abs() % 40) * 2 + i * 85,
        standIn: true,
      ),
  ];
  rows.sort((a, b) => b.score.compareTo(a.score));
  return rows;
}
