/// Staff you can pull from the briefcase.
enum ManagerId { gary, karen, brutus, vlad, lich }

enum ManagerRarity { common, rare, epic, legendary }

class ManagerCard {
  const ManagerCard({
    required this.id,
    required this.name,
    required this.rarity,
    required this.effect,
  });

  final ManagerId id;
  final String name;
  final ManagerRarity rarity;
  final String effect;
}

const List<ManagerCard> managerRoster = [
  ManagerCard(
    id: ManagerId.gary,
    name: 'Gary the Goblin',
    rarity: ManagerRarity.common,
    effect: 'Each copy adds 2% gold speed. The first copy also doubles Dragon Forge income.',
  ),
  ManagerCard(
    id: ManagerId.karen,
    name: 'Karen',
    rarity: ManagerRarity.rare,
    effect: 'Each copy shortens construction by 15%.',
  ),
  ManagerCard(
    id: ManagerId.brutus,
    name: 'Brutus the Minotaur',
    rarity: ManagerRarity.epic,
    effect: 'Each copy adds 40% income on heavy floors (the forge, then every 5th floor).',
  ),
  ManagerCard(
    id: ManagerId.vlad,
    name: 'Vlad the CFO',
    rarity: ManagerRarity.legendary,
    effect: 'Each copy adds 300% to gold earned while you are away.',
  ),
  ManagerCard(
    id: ManagerId.lich,
    name: 'Corporate Overlord Lich',
    rarity: ManagerRarity.legendary,
    effect: 'Each copy cuts construction timers by 50%.',
  ),
];

ManagerCard managerCard(ManagerId id) {
  return managerRoster.firstWhere((card) => card.id == id);
}

String rarityLabel(ManagerRarity rarity) {
  switch (rarity) {
    case ManagerRarity.common:
      return 'Common';
    case ManagerRarity.rare:
      return 'Rare';
    case ManagerRarity.epic:
      return 'Epic';
    case ManagerRarity.legendary:
      return 'Legendary';
  }
}

/// Posted odds. These are the numbers shown on the recruitment screen.
///
/// Common 75%, Rare 18%, Epic 6%, Legendary 1%.
ManagerRarity rarityForRoll(double roll) {
  if (roll < 0.75) {
    return ManagerRarity.common;
  }
  if (roll < 0.93) {
    return ManagerRarity.rare;
  }
  if (roll < 0.99) {
    return ManagerRarity.epic;
  }
  return ManagerRarity.legendary;
}

/// Turns a 0–1 roll into a person. Legendary is split evenly between Vlad and the Lich.
ManagerId managerForRoll(double roll) {
  switch (rarityForRoll(roll)) {
    case ManagerRarity.common:
      return ManagerId.gary;
    case ManagerRarity.rare:
      return ManagerId.karen;
    case ManagerRarity.epic:
      return ManagerId.brutus;
    case ManagerRarity.legendary:
      return roll < 0.995 ? ManagerId.vlad : ManagerId.lich;
  }
}

/// Heavy floors are the forge (floor index 1) and the same slot every cycle.
bool isHeavyFloor(int index) => index % 5 == 1;
