/// A cosmetic background. Tint 0 means "use the district colour".
class TowerSkin {
  const TowerSkin({
    required this.id,
    required this.name,
    required this.tint,
    required this.unlockAt,
  });

  final String id;
  final String name;
  final int tint;

  /// How many restructurings are required before this skin can be worn.
  final int unlockAt;
}

const List<TowerSkin> towerSkins = [
  TowerSkin(id: 'standard', name: 'Spire Standard', tint: 0, unlockAt: 0),
  TowerSkin(
    id: 'brass',
    name: 'Brass After Hours',
    tint: 0xFF3F2E1E,
    unlockAt: 1,
  ),
  TowerSkin(id: 'aurora', name: 'Aurora Glass', tint: 0xFF12343A, unlockAt: 4),
];

TowerSkin? towerSkinById(String id) {
  for (final skin in towerSkins) {
    if (skin.id == id) {
      return skin;
    }
  }
  return null;
}

/// Something new that a restructuring unlocks. Equity is separate.
class PrestigeReward {
  const PrestigeReward({
    required this.at,
    required this.title,
    required this.detail,
  });

  /// Unlocked once the player has restructured this many times.
  final int at;
  final String title;
  final String detail;
}

const List<PrestigeReward> prestigeRewards = [
  PrestigeReward(
    at: 1,
    title: 'Brass After Hours',
    detail: 'A cosmetic tower skin. It does not change income.',
  ),
  PrestigeReward(
    at: 2,
    title: 'Night Shift floors',
    detail: 'Some later floors pay 50% more gold.',
  ),
  PrestigeReward(
    at: 3,
    title: 'Auto-upgrade',
    detail: 'A toggle that buys the cheapest floor upgrade once a second.',
  ),
  PrestigeReward(
    at: 4,
    title: 'Aurora Glass',
    detail: 'A second cosmetic skin.',
  ),
];
