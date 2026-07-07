import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/cast_flow.dart';
import '../core/encounter.dart';
import '../core/session.dart';
import '../core/spells.dart';
import '../core/widgets.dart';

/// Top-down compound: overhead view of the fortress grounds with a designed
/// layout (outer gate → moat → courtyard → keep). Drag anywhere to walk;
/// tap a nearby encounter to cast. Enemy towers project danger zones that
/// volley at you while you're inside them.
class TopDownShell extends StatefulWidget {
  const TopDownShell({super.key, required this.session});

  final GameSession session;

  @override
  State<TopDownShell> createState() => _TopDownShellState();
}

class _Placed {
  _Placed(this.encounter, this.x, this.y);
  final Encounter encounter;
  final double x, y; // world coordinates (encounter center)
}

class _Bolt {
  _Bolt({required this.fromX, required this.fromY, required this.toX, required this.toY});
  final double fromX, fromY, toX, toY;
}

class _TopDownShellState extends State<TopDownShell> {
  static const double worldW = 1700;
  static const double worldH = 1300;
  static const double interactRange = 150;

  late final List<_Placed> placed;
  final List<_Bolt> bolts = [];

  double playerX = 330, playerY = 1000;
  SpellType? armed;
  Timer? _volleyTimer;
  bool _hitFlash = false;
  bool _victory = false;
  final List<Widget> _bursts = [];
  int _burstKey = 0;

  GameSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    // Designed compound: enter bottom-left, wind through the grounds to the
    // keep at the top-right.
    placed = [
      _Placed(EncounterFactory.sealedGate(3, 4), 480, 1050), // outer gate
      _Placed(EncounterFactory.brokenBridge(6, 4), 780, 900), // moat crossing
      _Placed(EncounterFactory.guardTower(7, 6), 1050, 720), // courtyard tower
      _Placed(EncounterFactory.missileTrap(9, 3), 620, 560), // west trap
      _Placed(EncounterFactory.iceBarrier(4, 8), 340, 380), // frozen store
      _Placed(EncounterFactory.curtainWall(8, 4), 950, 380), // inner wall
      _Placed(EncounterFactory.magicWard(7, 8), 1250, 460), // ward
      _Placed(EncounterFactory.throneDoor(9, 7), 1420, 200), // the keep
    ];
    _volleyTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted || _victory) return;
      for (final p in placed) {
        final e = p.encounter;
        if (e.kind == EncounterKind.enemy && !e.solved) {
          final d = _dist(playerX, playerY, p.x, p.y);
          if (d < e.dangerRadius) {
            setState(() => bolts.add(_Bolt(
                fromX: p.x, fromY: p.y, toX: playerX, toY: playerY)));
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _volleyTimer?.cancel();
    super.dispose();
  }

  double _dist(double x1, double y1, double x2, double y2) =>
      math.sqrt(math.pow(x1 - x2, 2) + math.pow(y1 - y2, 2)).toDouble();

  void _boltLanded(_Bolt b) {
    bolts.remove(b);
    if (_victory) return;
    if (_dist(playerX, playerY, b.toX, b.toY) < 60) {
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

  void _drag(DragUpdateDetails d) {
    setState(() {
      playerX = (playerX + d.delta.dx).clamp(40.0, worldW - 40.0);
      playerY = (playerY + d.delta.dy).clamp(40.0, worldH - 40.0);
    });
  }

  Future<void> _tapEncounter(_Placed p) async {
    if (_dist(playerX, playerY, p.x, p.y) > interactRange) {
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

  void _onSolved(_Placed p) {
    final spell = Spell.of(p.encounter.primarySpell);
    final key = _burstKey++;
    setState(() {
      _bursts.add(_PlacedBurst(
        key: ValueKey('burst$key'),
        worldX: p.x,
        worldY: p.y,
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
          'cleared — back to the last safe spot!',
          style: TextStyle(color: kParchment),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                session.retryFromCheckpoint();
                bolts.clear();
                final cp = session.checkpointId;
                if (cp == null) {
                  playerX = 220;
                  playerY = 1080;
                } else {
                  final p =
                      placed.firstWhere((pl) => pl.encounter.id == cp);
                  playerX = p.x;
                  playerY = p.y + 90;
                }
              });
            },
            child: const Text('Try Again',
                style: TextStyle(color: kBrightGold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120A20),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final viewW = constraints.maxWidth;
              final viewH = constraints.maxHeight;
              final camX =
                  (playerX - viewW / 2).clamp(0.0, worldW - viewW);
              final camY =
                  (playerY - viewH / 2).clamp(0.0, worldH - viewH);
              return GestureDetector(
              onPanUpdate: _drag,
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: -camX,
                      top: -camY,
                      width: worldW,
                      height: worldH,
                      child: _world(),
                    ),
                    if (_hitFlash)
                      Positioned.fill(
                        child: IgnorePointer(
                          child:
                              Container(color: kErrorRed.withOpacity(0.25)),
                        ),
                      ),
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
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Text(
                            'Drag anywhere to walk · tap a nearby obstacle to cast',
                            style: TextStyle(
                              color: kParchment.withOpacity(0.45),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_victory) _victoryOverlay(),
                  ],
                ),
              ),
            );
            }),
          ),
          SpellBar(armed: armed, onArm: (s) => setState(() => armed = s)),
        ],
      ),
    );
  }

  Widget _world() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Grounds
        Positioned.fill(
          child: CustomPaint(painter: _CompoundPainter()),
        ),
        // Danger zones
        for (final p in placed.where((p) =>
            p.encounter.kind == EncounterKind.enemy && !p.encounter.solved))
          Positioned(
            left: p.x - p.encounter.dangerRadius,
            top: p.y - p.encounter.dangerRadius,
            child: IgnorePointer(
              child: Container(
                width: p.encounter.dangerRadius * 2,
                height: p.encounter.dangerRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    kErrorRed.withOpacity(0.14),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
        // Encounters
        for (final p in placed)
          Positioned(
            left: p.x - 40,
            top: p.y - 40,
            child: Semantics(
              button: true,
              label: p.encounter.name,
              child: GestureDetector(
                onTap: () => _tapEncounter(p),
                child: EncounterSprite(
                  encounter: p.encounter,
                  size: 80,
                  highlight:
                      _dist(playerX, playerY, p.x, p.y) <= interactRange &&
                          !p.encounter.solved,
                ),
              ),
            ),
          ),
        // Bolts
        for (final b in List.of(bolts))
          _BoltWidget(
            key: ObjectKey(b),
            bolt: b,
            onLanded: () => _boltLanded(b),
          ),
        // Bursts
        for (final w in _bursts)
          Positioned(
            left: (w as _PlacedBurst).worldX - 80,
            top: w.worldY - 80,
            child: w,
          ),
        // Player
        Positioned(
          left: playerX - 20,
          top: playerY - 24,
          child: const IgnorePointer(
            child: Text('🧙', style: TextStyle(fontSize: 40)),
          ),
        ),
      ],
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

class _PlacedBurst extends StatelessWidget {
  const _PlacedBurst({
    super.key,
    required this.worldX,
    required this.worldY,
    required this.color,
    required this.incantation,
    required this.onDone,
  });

  final double worldX, worldY;
  final Color color;
  final String incantation;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return CastBurst(color: color, incantation: incantation, onDone: onDone);
  }
}

class _BoltWidget extends StatelessWidget {
  const _BoltWidget({super.key, required this.bolt, required this.onLanded});

  final _Bolt bolt;
  final VoidCallback onLanded;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      onEnd: onLanded,
      builder: (_, t, __) {
        final x = bolt.fromX + (bolt.toX - bolt.fromX) * t;
        final y = bolt.fromY + (bolt.toY - bolt.fromY) * t;
        return Positioned(
          left: x - 7,
          top: y - 7,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kErrorRed,
              boxShadow: [
                BoxShadow(color: kErrorRed.withOpacity(0.7), blurRadius: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fortress grounds: stone floor grid, outer walls, moat band, keep plateau.
class _CompoundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Floor
    final floor = Paint()..color = const Color(0xFF1C1130);
    canvas.drawRect(Offset.zero & size, floor);

    // Stone grid
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 80) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 80) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Moat band (crosses the compound diagonally under the bridge site)
    final moat = Paint()..color = const Color(0xFF0E2C4A).withOpacity(0.85);
    final moatPath = Path()
      ..moveTo(560, size.height)
      ..lineTo(700, 700)
      ..lineTo(880, 700)
      ..lineTo(1000, size.height)
      ..close();
    canvas.drawPath(moatPath, moat);

    // Outer wall
    final wall = Paint()
      ..color = const Color(0xFF3A2A55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(30, 30, size.width - 60, size.height - 60),
        const Radius.circular(24),
      ),
      wall,
    );

    // Keep plateau (top-right)
    final keep = Paint()..color = const Color(0xFF241539);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1180, 60, 460, 320),
        const Radius.circular(20),
      ),
      keep,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
