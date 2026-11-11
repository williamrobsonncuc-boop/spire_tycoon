import 'formulas.dart';

/// What a floor does once construction finishes.
enum FloorKind {
  /// Steady gold every second. The lobby and most generated floors.
  gold,

  /// Pays nothing most of the time, then a big lump. Necromancy.
  slowBurst,

  /// Gold, but the line can clog until the player taps it. Alchemy.
  clog,

  /// Compliance Points instead of gold. HR & Legal.
  compliance,
}

/// How often the necromancy floor dumps its banked payout.
const int slowBurstSeconds = 15;

/// One designed floor, or one generated floor. Nothing here is saved.
///
/// The endless tower only stores the floors the player has touched
/// (see GameModel). Every other floor is this recipe plus its index,
/// so a prestige reset can wipe the save map and the spire still exists.
class FloorRecipe {
  const FloorRecipe({
    required this.index,
    required this.name,
    required this.emoji,
    required this.blurb,
    required this.kind,
  });

  final int index;
  final String name;
  final String emoji;
  final String blurb;
  final FloorKind kind;

  int get number => index + 1;

  String get title => 'Floor $number: $name';
}

const List<FloorRecipe> _designedFloors = [
  FloorRecipe(
    index: 0,
    name: 'The Executive Lobby',
    emoji: '👺',
    blurb: 'A goblin receptionist. Tap for gold. The desk also earns gold every second.',
    kind: FloorKind.gold,
  ),
  FloorRecipe(
    index: 1,
    name: 'Dragon Forge',
    emoji: '🐂',
    blurb: 'Infrastructure Foundry. Minotaurs hammer cursed blades. High volume, low margin: it pays well, and upgrades get expensive fast.',
    kind: FloorKind.gold,
  ),
  FloorRecipe(
    index: 2,
    name: 'Alchemy Bottling Plant',
    emoji: '🧪',
    blurb: 'Witches and plague doctors bottle mana espresso. About 3% chance each second that the line clogs. Tap the floor to clear it.',
    kind: FloorKind.clog,
  ),
  FloorRecipe(
    index: 3,
    name: 'Necromancy Data Centre',
    emoji: '🧟',
    blurb: 'Liches archive soul data. They pay a lump sum every 15 seconds instead of a steady trickle.',
    kind: FloorKind.slowBurst,
  ),
  FloorRecipe(
    index: 4,
    name: 'HR & Legal',
    emoji: '👻',
    blurb: 'Banshees produce Compliance Points. Spend them on policies that permanently raise gold from every floor.',
    kind: FloorKind.compliance,
  ),
];

/// Generated departments. Five names, so Floor 12 lands on Legal Dept II.
const List<String> _departments = [
  'Marketing',
  'Legal Dept',
  'Research',
  'Accounting',
  'Facilities',
];

/// Floors 1–10 are district 0, 11–20 are district 1, and so on.
int districtIndexForFloor(int floorIndex) {
  if (floorIndex < 0) {
    return 0;
  }
  return floorIndex ~/ 10;
}

class DistrictTheme {
  const DistrictTheme({
    required this.name,
    required this.tint,
    required this.monsters,
    required this.emoji,
  });

  final String name;

  /// Scaffold background. Kept dark so cream text stays readable.
  final int tint;
  final List<String> monsters;
  final List<String> emoji;
}

const List<DistrictTheme> districtThemes = [
  DistrictTheme(
    name: 'Basement Dungeon',
    tint: 0xFF1E293B,
    monsters: [
      'Imps',
      'Goblins',
      'Skeletons',
      'Ghosts',
      'Orcs',
      'Witches',
      'Minotaurs',
      'Banshees',
      'Liches',
      'Slimes',
    ],
    emoji: ['😈', '👺', '💀', '👻', '👹', '🧙', '🐂', '😱', '🧟', '🫧'],
  ),
  DistrictTheme(
    name: 'Corporate Offices',
    tint: 0xFF1E3A5F,
    monsters: [
      'Auditors',
      'Interns',
      'Consultants',
      'Middle Managers',
      'Receptionists',
      'Accountants',
      'Compliance Imps',
      'Board Goblins',
      'HR Shades',
      'Coffee Golems',
    ],
    emoji: ['📎', '🧑', '💼', '🗂️', '🔔', '🧮', '😈', '👺', '👻', '☕'],
  ),
  DistrictTheme(
    name: 'Skyscraper',
    tint: 0xFF0F3A4A,
    monsters: [
      'Gargoyles',
      'Window Wraiths',
      'Elevator Orcs',
      'Penthouse Shades',
      'Crane Giants',
    ],
    emoji: ['🗽', '🪟', '🛗', '👻', '🏗️'],
  ),
  DistrictTheme(
    name: 'Cloud Penthouse',
    tint: 0xFF164E63,
    monsters: ['Cloud Imps', 'Storm Clerks', 'Sky Liches', 'Zephyr Interns'],
    emoji: ['☁️', '⛈️', '🧟', '💨'],
  ),
  DistrictTheme(
    name: 'Space Station',
    tint: 0xFF1E1B4B,
    monsters: ['Void Clerks', 'Asteroid Orcs', 'Nebula Witches', 'Dock Ghosts'],
    emoji: ['🛸', '☄️', '🧙', '👻'],
  ),
  DistrictTheme(
    name: 'Abyssal HQ',
    tint: 0xFF2A1215,
    monsters: [
      'Leviathans',
      'Trench Banshees',
      'Ink Krakens',
      'Pearl Auditors',
    ],
    emoji: ['🦑', '😱', '🐙', '🦪'],
  ),
];

DistrictTheme districtAt(int districtIndex) {
  if (districtIndex < 0) {
    return districtThemes.first;
  }
  if (districtIndex >= districtThemes.length) {
    return districtThemes.last;
  }
  return districtThemes[districtIndex];
}

DistrictTheme districtForFloor(int floorIndex) {
  return districtAt(districtIndexForFloor(floorIndex));
}

const List<String> _products = [
  'brand hexes',
  'liability scrolls',
  'unstable prototypes',
  'cursed ledgers',
  'haunted vents',
  'ward badges',
  'soul coffee',
  'press omens',
  'sealed files',
  'ink contracts',
];

FloorRecipe floorRecipe(int index) {
  if (index < _designedFloors.length) {
    return _designedFloors[index];
  }
  final generated = index - _designedFloors.length;
  final department = _departments[generated % _departments.length];
  final cycle = generated ~/ _departments.length;
  final district = districtForFloor(index);
  final monster = district.monsters[generated % district.monsters.length];
  final emoji = district.emoji[generated % district.emoji.length];
  final product = _products[generated % _products.length];
  final suffix = cycle == 0 ? '' : ' ${_roman(cycle + 1)}';
  return FloorRecipe(
    index: index,
    name: '$department$suffix ($monster)',
    emoji: emoji,
    blurb:
        '${district.name}. A later department bottling $product. Same jobs, bigger numbers.',
    kind: FloorKind.gold,
  );
}

FloorKind floorKind(int index) => floorRecipe(index).kind;

/// Gold (or the average gold, for the slow floor) at upgrade level 0.
double floorBaseGold(int index) {
  if (floorKind(index) == FloorKind.compliance) {
    return 0;
  }
  if (index == 0) {
    return 0.2;
  }
  var base = 0.4 * safePow(1.58, index);
  if (index == 1) {
    // High volume. The low margin shows up in the upgrade price.
    base *= 2.2;
  }
  if (floorKind(index) == FloorKind.slowBurst) {
    base *= 3;
  }
  return base;
}

/// Compliance Points per second at upgrade level 0. Only HR & Legal.
double floorBaseCompliance(int index) {
  if (floorKind(index) != FloorKind.compliance) {
    return 0;
  }
  return 0.2;
}

/// Cost to open a floor. Floor 1 is already built, so it is free.
///
/// Later floors follow cost = 80 × 1.75^index, so the spire gets
/// steep quickly and never runs out of floors to buy.
double floorBuildCost(int index) {
  if (index <= 0) {
    return 0;
  }
  return positiveCost(80 * safePow(1.75, index));
}

/// How long construction takes, in seconds.
///
/// The timer grows with the floor, then stops at about 68 years so a very
/// high floor still has a number Dart can store.
int floorBuildSeconds(int index) {
  if (index <= 0) {
    return 0;
  }
  final raw = 10 * safePow(1.42, index);
  if (raw >= 2000000000) {
    return 2000000000;
  }
  return raw.round();
}

/// Price of the next upgrade on a floor that is already running.
///
/// Floor 1 keeps the original desk formula (10 × 1.10^level).
/// The forge uses 1.15 because its margin is worse.
/// Other floors use 1.12 early and 1.15 once the spire is tall.
double floorUpgradeCost(int index, int level) {
  if (index == 0) {
    return deskUpgradeCost(level);
  }
  final multiplier = index == 1 ? 1.15 : (index < 8 ? 1.12 : 1.15);
  final steps = level < 0 ? 0 : level;
  final base = floorBuildCost(index) * (index == 1 ? 0.85 : 0.55);
  return positiveCost(base * safePow(multiplier, steps));
}

String formatBuildTime(int seconds) {
  if (seconds < 60) {
    return '${seconds}s';
  }
  final minutes = seconds ~/ 60;
  final remain = seconds % 60;
  if (minutes < 60) {
    return '${minutes}m ${remain}s';
  }
  final hours = minutes ~/ 60;
  final remainMinutes = minutes % 60;
  return '${hours}h ${remainMinutes}m';
}

String _roman(int number) {
  const values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
  const glyphs = [
    'M',
    'CM',
    'D',
    'CD',
    'C',
    'XC',
    'L',
    'XL',
    'X',
    'IX',
    'V',
    'IV',
    'I',
  ];
  var left = number;
  final buffer = StringBuffer();
  for (var i = 0; i < values.length; i++) {
    while (left >= values[i]) {
      buffer.write(glyphs[i]);
      left -= values[i];
    }
  }
  return buffer.toString();
}
