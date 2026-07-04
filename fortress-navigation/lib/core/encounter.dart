import 'spells.dart';

/// Whether this encounter is a passive obstacle or an active threat.
enum EncounterKind { obstacle, enemy }

enum EncounterState { blocked, solved }

/// A castable challenge in the fortress: an obstacle blocking progress or an
/// enemy that attacks while the player is in range. Position is shell-specific
/// (each shell wraps encounters with its own coordinates).
class Encounter {
  final String id;
  final String name; // 'Sealed Gate'
  final String flavor; // one-line description shown in the casting panel
  final SpellType primarySpell;

  /// Spells that work on this encounter (usually just the primary; a guard
  /// tower accepts Shatter OR Fog — spell choice is part of the puzzle).
  final Set<SpellType> acceptedSpells;

  final int factor1, factor2;
  final EncounterKind kind;

  /// Enemies only: radius (world px) of the danger zone and seconds between
  /// projectile volleys while the player stays inside it.
  final double dangerRadius;
  final double volleySeconds;

  EncounterState state;

  Encounter({
    required this.id,
    required this.name,
    required this.flavor,
    required this.primarySpell,
    Set<SpellType>? acceptedSpells,
    required this.factor1,
    required this.factor2,
    this.kind = EncounterKind.obstacle,
    this.dangerRadius = 0,
    this.volleySeconds = 2.5,
    this.state = EncounterState.blocked,
  }) : acceptedSpells = acceptedSpells ?? {primarySpell};

  int get product => factor1 * factor2;
  bool get solved => state == EncounterState.solved;

  /// Fluency window: harder facts get a little more time. The difficulty
  /// knob on the menu screen scales this further.
  double get castSeconds =>
      product <= 20 ? 6.0 : (product <= 50 ? 7.0 : 8.0);

  bool accepts(SpellType spell) => acceptedSpells.contains(spell);
}

/// The canonical encounter archetypes, one per spell (plus enemy variants).
/// Shells position instances of these to lay out their compound.
class EncounterFactory {
  static int _n = 0;
  static String _id() => 'enc${_n++}';

  static Encounter sealedGate(int a, int b) => Encounter(
        id: _id(),
        name: 'Sealed Gate',
        flavor: 'Bognor\'s lock binds the gate with $a×$b wards.',
        primarySpell: SpellType.unlock,
        factor1: a,
        factor2: b,
      );

  static Encounter brokenBridge(int a, int b) => Encounter(
        id: _id(),
        name: 'Broken Bridge',
        flavor: 'The moat crossing is shattered into $a×$b planks.',
        primarySpell: SpellType.repair,
        factor1: a,
        factor2: b,
      );

  static Encounter guardTower(int a, int b) => Encounter(
        id: _id(),
        name: 'Guard Tower',
        flavor: 'Watchers rain missiles — shatter the tower or fog their eyes.',
        primarySpell: SpellType.shatter,
        acceptedSpells: {SpellType.shatter, SpellType.fog},
        factor1: a,
        factor2: b,
        kind: EncounterKind.enemy,
        dangerRadius: 240,
        volleySeconds: 2.8,
      );

  static Encounter curtainWall(int a, int b) => Encounter(
        id: _id(),
        name: 'Stone Wall',
        flavor: 'A wall of $a×$b enchanted blocks bars the way.',
        primarySpell: SpellType.shatter,
        factor1: a,
        factor2: b,
      );

  static Encounter iceBarrier(int a, int b) => Encounter(
        id: _id(),
        name: 'Ice Barrier',
        flavor: 'Cursed ice, $a×$b layers thick. Burn it away.',
        primarySpell: SpellType.fireball,
        factor1: a,
        factor2: b,
      );

  static Encounter missileTrap(int a, int b) => Encounter(
        id: _id(),
        name: 'Missile Trap',
        flavor: 'A volley of $a×$b bolts — raise your shield in time.',
        primarySpell: SpellType.shield,
        factor1: a,
        factor2: b,
        kind: EncounterKind.enemy,
        dangerRadius: 200,
        volleySeconds: 2.2,
      );

  static Encounter magicWard(int a, int b) => Encounter(
        id: _id(),
        name: 'Magic Ward',
        flavor: 'Bognor\'s ward hums with $a×$b threads of curse-light.',
        primarySpell: SpellType.dispel,
        factor1: a,
        factor2: b,
      );

  static Encounter throneDoor(int a, int b) => Encounter(
        id: _id(),
        name: 'Throne Door',
        flavor: 'The final door. Every lesson led here.',
        primarySpell: SpellType.unlock,
        factor1: a,
        factor2: b,
      );
}
