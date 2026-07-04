import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/cast_flow.dart';
import '../core/encounter.dart';
import '../core/session.dart';
import '../core/spells.dart';
import '../core/widgets.dart';

/// Side-view scroller: the fortress as a storybook cross-section.
/// Walk left→right toward the throne room; obstacles physically block the
/// path until the right spell (and the math) clears them; enemy towers
/// pepper you while you're in range.
class SideScrollShell extends StatefulWidget {
  const SideScrollShell({super.key, required this.session});

  final GameSession session;

  @override
  State<SideScrollShell> createState() => _SideScrollShellState();
}

class _PlacedEncounter {
  _PlacedEncounter(this.encounter, this.x);
  final Encounter encounter;
  final double x; // world x
}

class _Projectile {
  _Projectile({required this.fromX, required this.fromY, required this.toX});
  final double fromX, fromY, toX;
}

class _SideScrollShellState extends State<SideScrollShell> {
  static const double worldW = 4200;
  static const double interactRange = 170;
  static const double walkSpeed = 4.2; // px per tick (60hz)

  late final List<_PlacedEncounter> placed;
  final List<_Projectile> projectiles = [];

  double playerX = 160;
  SpellType? armed;
  Timer? _walkTimer;
  int _walkDir = 0;
  Timer? _volleyTimer;
  bool _hitFlash = false;
  bool _victory = false;
  final List<Widget> _bursts = [];
  int _burstKey = 0;

  GameSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    placed = [
      _PlacedEncounter(EncounterFactory.sealedGate(3, 4), 640),
      _PlacedEncounter(EncounterFactory.brokenBridge(6, 4), 1280),
      _PlacedEncounter(EncounterFactory.guardTower(7, 6), 1900),
      _PlacedEncounter(EncounterFactory.curtainWall(8, 4), 2500),
      _PlacedEncounter(EncounterFactory.missileTrap(9, 3), 3000),
      _PlacedEncounter(EncounterFactory.magicWard(7, 8), 3450),
      _PlacedEncounter(EncounterFactory.throneDoor(9, 7), 3950),
    ];
    // Enemy volleys tick while the player stands in a danger zone.
    _volleyTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted || _victory) return;
      for (final p in placed) {
        final e = p.encounter;
        if (e.kind == EncounterKind.enemy &&
            !e.solved &&
            (playerX - p.x).abs() < e.dangerRadius) {
          _fireVolley(p);
        }
      }
    });
  }

  @override
  void dispose() {
    _walkTimer?.cancel();
    _volleyTimer?.cancel();
    super.dispose();
  }

  void _fireVolley(_PlacedEncounter tower) {
    final proj = _Projectile(fromX: tower.x, fromY: -170, toX: playerX);
    setState(() => projectiles.add(proj));
  }

  void _projectileLanded(_Projectile p) {
    projectiles.remove(p);
    if (_victory) return;
    // Hit if the player is still near where the bolt was aimed.
    if ((playerX - p.toX).abs() < 55) {
      session.loseHeart();
      setState(() => _hitFlash = true);
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _hitFlash = false);
      });
      if (session.defeated) _onDefeat();
    } else {
      setState(() {});
    }
  }

  // ── Movement ──

  void _step(double dx) {
    setState(() {
      var next = playerX + dx;
      // Unsolved obstacles are hard blockers from the left side.
      for (final p in placed) {
        final e = p.encounter;
        if (e.kind == EncounterKind.obstacle && !e.solved) {
          final blockAt = p.x - 90;
          if (playerX <= blockAt && next > blockAt) next = blockAt;
        }
      }
      playerX = next.clamp(60.0, worldW - 60.0);
    });
  }

  void _startWalk(int dir) {
    _walkDir = dir;
    _walkTimer?.cancel();
    // A single tap steps immediately; holding keeps walking.
    _step(dir * walkSpeed * 9);
    _walkTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      _step(_walkDir * walkSpeed);
    });
  }

  void _stopWalk() {
    _walkTimer?.cancel();
    _walkTimer = null;
  }

  // ── Casting ──

  Future<void> _tapEncounter(_PlacedEncounter p) async {
    if ((playerX - p.x).abs() > interactRange) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Walk closer to reach it.'),
            backgroundColor: kMidPurple,
            duration: Duration(milliseconds: 900),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    await attemptCast(
      context,
      armed: armed,
      encounter: p.encounter,
      session: session,
      onSolved: () => _onSolved(p),
      onDefeat: _onDefeat,
    );
  }

  void _onSolved(_PlacedEncounter p) {
    final spell = Spell.of(p.encounter.primarySpell);
    final key = _burstKey++;
    setState(() {
      _bursts.add(_WorldBurst(
        key: ValueKey('burst$key'),
        worldX: p.x,
        color: spell.color,
        incantation: '${spell.incantation}!',
        onDone: () {
          if (mounted) {
            setState(() =>
                _bursts.removeWhere((w) => w.key == ValueKey('burst$key')));
          }
        },
      ));
    });
    // The bridge is the mid-run checkpoint.
    if (p.encounter.name == 'Broken Bridge') {
      session.reachCheckpoint(p.encounter.id);
    }
    if (placed.every((pl) => pl.encounter.solved)) {
      setState(() => _victory = true);
    }
  }

  void _onDefeat() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: kDeepPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: kGold),
        ),
        title: const Text('💔  The fortress repels you…',
            style: TextStyle(color: kParchment, fontSize: 18)),
        content: const Text(
          'Catch your breath, apprentice. Everything you cleared stays '
          'cleared — try the crossing again!',
          style: TextStyle(color: kParchment),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                session.retryFromCheckpoint();
                projectiles.clear();
                // Return to checkpoint (bridge) or the start.
                final cp = session.checkpointId;
                final cpX = cp == null
                    ? 160.0
                    : placed
                        .firstWhere((p) => p.encounter.id == cp)
                        .x;
                playerX = cpX;
              });
            },
            child: const Text('Try Again',
                style: TextStyle(color: kBrightGold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // ── Rendering ──

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final viewportW = size.width;
    final cameraX =
        (playerX - viewportW * 0.42).clamp(0.0, worldW - viewportW);

    return Scaffold(
      backgroundColor: const Color(0xFF120A20),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Parallax layers
                _parallaxLayer(cameraX, 0.25, _farLayer(size)),
                _parallaxLayer(cameraX, 0.55, _midLayer(size)),
                // World layer
                Positioned(
                  left: -cameraX,
                  top: 0,
                  bottom: 0,
                  width: worldW,
                  child: _worldLayer(size),
                ),
                // Hit flash
                if (_hitFlash)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                          color: kErrorRed.withOpacity(0.25)),
                    ),
                  ),
                // HUD
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  child: SessionHud(
                      session: session,
                      total: placed.length,
                      armedSpell: armed),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 12,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: kGold),
                  ),
                ),
                // Walk controls
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: _walkButton(Icons.arrow_back, -1),
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _walkButton(Icons.arrow_forward, 1),
                ),
                // Victory overlay
                if (_victory) _victoryOverlay(),
              ],
            ),
          ),
          SpellBar(
            armed: armed,
            onArm: (s) => setState(() => armed = s),
          ),
        ],
      ),
    );
  }

  Widget _parallaxLayer(double cameraX, double factor, Widget child) {
    return Positioned(
      left: -cameraX * factor,
      top: 0,
      bottom: 0,
      width: worldW,
      child: IgnorePointer(child: child),
    );
  }

  Widget _farLayer(Size size) {
    // Distant fortress silhouettes.
    return Stack(
      children: [
        for (double x = 200; x < worldW; x += 600)
          Positioned(
            left: x,
            bottom: size.height * 0.30,
            child: Text('🏯',
                style: TextStyle(
                    fontSize: 64,
                    color: Colors.white.withOpacity(0.15))),
          ),
        Positioned(
          left: 60,
          top: 60,
          child: Text('🌙',
              style: TextStyle(
                  fontSize: 40, color: Colors.white.withOpacity(0.6))),
        ),
      ],
    );
  }

  Widget _midLayer(Size size) {
    // Battlement wall silhouette running behind the action.
    return Stack(
      children: [
        for (double x = 0; x < worldW; x += 260)
          Positioned(
            left: x,
            bottom: size.height * 0.24,
            child: Container(
              width: 200,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF241539).withOpacity(0.8),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _worldLayer(Size size) {
    final groundTop = size.height * 0.68;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ground
        Positioned(
          left: 0,
          right: 0,
          top: groundTop,
          bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2D1B45), Color(0xFF19102B)],
              ),
            ),
          ),
        ),
        // Moat gap under the bridge (visual)
        for (final p in placed.where(
            (p) => p.encounter.primarySpell == SpellType.repair))
          Positioned(
            left: p.x - 110,
            top: groundTop,
            width: 220,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0E2C4A).withOpacity(0.9),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ),
          ),
        // Danger zones
        for (final p in placed.where((p) =>
            p.encounter.kind == EncounterKind.enemy &&
            !p.encounter.solved))
          Positioned(
            left: p.x - p.encounter.dangerRadius,
            top: groundTop - 180,
            child: IgnorePointer(
              child: Container(
                width: p.encounter.dangerRadius * 2,
                height: 220,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      kErrorRed.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Encounters
        for (final p in placed)
          Positioned(
            left: p.x - 44,
            top: groundTop - 96,
            child: Semantics(
              button: true,
              label: p.encounter.name,
              child: GestureDetector(
                onTap: () => _tapEncounter(p),
                child: EncounterSprite(
                  encounter: p.encounter,
                  size: 88,
                  highlight: (playerX - p.x).abs() <= interactRange &&
                      !p.encounter.solved,
                ),
              ),
            ),
          ),
        // Projectiles
        for (final proj in List.of(projectiles))
          _ProjectileWidget(
            key: ObjectKey(proj),
            projectile: proj,
            groundTop: groundTop,
            onLanded: () => _projectileLanded(proj),
          ),
        // Spell bursts
        for (final b in _bursts)
          Positioned(
            left: (b as _WorldBurst).worldX - 80,
            top: groundTop - 190,
            child: b,
          ),
        // Player
        AnimatedPositioned(
          duration: const Duration(milliseconds: 60),
          left: playerX - 22,
          top: groundTop - 58,
          child: Transform.flip(
            flipX: _walkDir < 0,
            child: const Text('🧙', style: TextStyle(fontSize: 46)),
          ),
        ),
      ],
    );
  }

  Widget _walkButton(IconData icon, int dir) {
    return Semantics(
      button: true,
      label: dir < 0 ? 'Walk left' : 'Walk right',
      onTap: () {
        _step(dir * walkSpeed * 9);
      },
      child: GestureDetector(
        onTapDown: (_) => _startWalk(dir),
        onTapUp: (_) => _stopWalk(),
        onTapCancel: _stopWalk,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: kMidPurple.withOpacity(0.85),
            shape: BoxShape.circle,
            border: Border.all(color: kGold, width: 2),
          ),
          child: Icon(icon, color: kBrightGold, size: 30),
        ),
      ),
    );
  }

  Widget _victoryOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kDeepPurple,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: kBrightGold, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚔️', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text(
                  'The Throne Door swings open…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: kBrightGold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bognor awaits. (Finale handoff — battle design TBD.)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kParchment, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kMidPurple,
                    foregroundColor: kBrightGold,
                  ),
                  child: const Text('Back to Menu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A burst positioned in world coordinates (wrapper adds worldX metadata).
class _WorldBurst extends StatelessWidget {
  const _WorldBurst({
    super.key,
    required this.worldX,
    required this.color,
    required this.incantation,
    required this.onDone,
  });

  final double worldX;
  final Color color;
  final String incantation;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return CastBurst(color: color, incantation: incantation, onDone: onDone);
  }
}

/// A bolt lobbed from a tower toward where the player was standing.
class _ProjectileWidget extends StatelessWidget {
  const _ProjectileWidget({
    super.key,
    required this.projectile,
    required this.groundTop,
    required this.onLanded,
  });

  final _Projectile projectile;
  final double groundTop;
  final VoidCallback onLanded;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 950),
      onEnd: onLanded,
      builder: (_, t, __) {
        final x = projectile.fromX +
            (projectile.toX - projectile.fromX) * t;
        // Arc: start high on the tower, land at ground level.
        final y = groundTop - 150 + 120 * t - 60 * math.sin(t * math.pi);
        return Positioned(
          left: x - 7,
          top: y,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kErrorRed,
              boxShadow: [
                BoxShadow(
                    color: kErrorRed.withOpacity(0.7), blurRadius: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
