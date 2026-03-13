import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const ScatterArrayApp());
}

class ScatterArrayApp extends StatelessWidget {
  const ScatterArrayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scatter to Array',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Georgia',
        scaffoldBackgroundColor: const Color(0xFFFAF0DC),
      ),
      home: const ScatterArrayScreen(),
    );
  }
}

class SpellData {
  final String name;
  final IconData icon;
  final int rows;
  final int cols;
  final Color orbColor;

  const SpellData({
    required this.name,
    required this.icon,
    required this.rows,
    required this.cols,
    required this.orbColor,
  });

  int get total => rows * cols;
}

const spells = [
  SpellData(name: 'Shield', icon: Icons.shield, rows: 3, cols: 4, orbColor: Color(0xFF4FC3F7)),
  SpellData(name: 'Fireball', icon: Icons.local_fire_department, rows: 2, cols: 6, orbColor: Color(0xFFFF7043)),
  SpellData(name: 'Sleep', icon: Icons.dark_mode, rows: 3, cols: 5, orbColor: Color(0xFF9C27B0)),
  SpellData(name: 'Repair', icon: Icons.build, rows: 5, cols: 4, orbColor: Color(0xFF8D6E63)),
];

// Represents a single mana cube with position
class ManaCube {
  Offset scatterPos;   // random scattered position (normalized 0-1)
  Offset arrayPos;     // final array position (normalized 0-1)
  int? tapNumber;      // number shown when tapped
  bool tapped;

  ManaCube({
    required this.scatterPos,
    required this.arrayPos,
    this.tapNumber,
    this.tapped = false,
  });
}

enum Phase {
  counting,       // cubes scattered, player counts & taps
  submitCount,    // player enters count
  revealArray,    // target cubes animate into array
  enterExpression,// player enters rows × cols
  castSpell,      // animate comparison
  success,        // spell cast successfully
}

class ScatterArrayScreen extends StatefulWidget {
  const ScatterArrayScreen({super.key});

  @override
  State<ScatterArrayScreen> createState() => _ScatterArrayScreenState();
}

class _ScatterArrayScreenState extends State<ScatterArrayScreen>
    with TickerProviderStateMixin {
  int selectedSpellIndex = 0;
  Phase phase = Phase.counting;
  List<ManaCube> targetCubes = [];
  List<ManaCube> playerCubes = [];
  int tapCounter = 0;
  int? submittedCount;
  int? enteredRows;
  int? enteredCols;
  int expressionStep = 0; // 0=rows, 1=cols
  bool countWrong = false;
  Set<int> completedSpells = {};

  late AnimationController _arrayAnimController;
  late AnimationController _compareAnimController;
  late AnimationController _shakeController;

  final Random _rng = Random();

  SpellData get currentSpell => spells[selectedSpellIndex];

  @override
  void initState() {
    super.initState();
    _arrayAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _compareAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _setupSpell();
  }

  @override
  void dispose() {
    _arrayAnimController.dispose();
    _compareAnimController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _setupSpell() {
    final spell = currentSpell;
    tapCounter = 0;
    submittedCount = null;
    enteredRows = null;
    enteredCols = null;
    expressionStep = 0;
    countWrong = false;
    phase = Phase.counting;

    // Generate scattered positions (normalized 0-1, with some padding)
    targetCubes = List.generate(spell.total, (i) {
      int row = i ~/ spell.cols;
      int col = i % spell.cols;
      return ManaCube(
        scatterPos: Offset(
          0.1 + _rng.nextDouble() * 0.8,
          0.1 + _rng.nextDouble() * 0.8,
        ),
        arrayPos: Offset(
          (col + 0.5) / spell.cols,
          (row + 0.5) / spell.rows,
        ),
        tapped: false,
      );
    });

    // Ensure no cubes overlap too much — spread them out
    for (int pass = 0; pass < 20; pass++) {
      for (int i = 0; i < targetCubes.length; i++) {
        for (int j = i + 1; j < targetCubes.length; j++) {
          final diff = targetCubes[i].scatterPos - targetCubes[j].scatterPos;
          double dist = diff.distance;
          if (dist < 0.12) {
            // Push apart
            final push = dist < 0.001
                ? Offset(_rng.nextDouble() * 0.1 - 0.05, _rng.nextDouble() * 0.1 - 0.05)
                : diff / dist * 0.02;
            targetCubes[i].scatterPos = Offset(
              (targetCubes[i].scatterPos.dx + push.dx).clamp(0.08, 0.92),
              (targetCubes[i].scatterPos.dy + push.dy).clamp(0.08, 0.92),
            );
            targetCubes[j].scatterPos = Offset(
              (targetCubes[j].scatterPos.dx - push.dx).clamp(0.08, 0.92),
              (targetCubes[j].scatterPos.dy - push.dy).clamp(0.08, 0.92),
            );
          }
        }
      }
    }

    playerCubes = [];
  }

  void _onCubeTapped(int index) {
    if (phase != Phase.counting) return;
    if (targetCubes[index].tapped) return;
    setState(() {
      tapCounter++;
      targetCubes[index].tapped = true;
      targetCubes[index].tapNumber = tapCounter;
    });
  }

  void _submitCount(int count) {
    setState(() {
      submittedCount = count;
      if (count == currentSpell.total) {
        // Correct! Move to reveal phase
        phase = Phase.revealArray;
        // Copy cubes to player area (scattered initially)
        playerCubes = List.generate(currentSpell.total, (i) {
          return ManaCube(
            scatterPos: Offset(
              0.1 + _rng.nextDouble() * 0.8,
              0.1 + _rng.nextDouble() * 0.8,
            ),
            arrayPos: targetCubes[i].arrayPos,
          );
        });
        // Animate target cubes into array
        _arrayAnimController.forward(from: 0).then((_) {
          setState(() {
            phase = Phase.enterExpression;
          });
        });
      } else {
        // Wrong count — shake and let them try again
        countWrong = true;
        _shakeController.forward(from: 0).then((_) {
          setState(() {
            countWrong = false;
            submittedCount = null;
          });
        });
      }
    });
  }

  void _onExpressionValue(int val) {
    setState(() {
      if (expressionStep == 0) {
        enteredRows = val;
        expressionStep = 1;
      } else {
        enteredCols = val;
        expressionStep = 2;
      }
    });
  }

  void _castSpell() {
    if (enteredRows == null || enteredCols == null) return;

    bool correct = enteredRows == currentSpell.rows &&
        enteredCols == currentSpell.cols;

    setState(() {
      phase = Phase.castSpell;
      // Arrange player cubes into the expression they entered
      int pRows = enteredRows!;
      int pCols = enteredCols!;
      for (int i = 0; i < playerCubes.length && i < pRows * pCols; i++) {
        int r = i ~/ pCols;
        int c = i % pCols;
        playerCubes[i].arrayPos = Offset(
          (c + 0.5) / pCols,
          (r + 0.5) / pRows,
        );
      }
    });

    _compareAnimController.forward(from: 0).then((_) {
      if (correct) {
        setState(() {
          phase = Phase.success;
          completedSpells.add(selectedSpellIndex);
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          // Move to next spell
          int next = -1;
          for (int i = 0; i < spells.length; i++) {
            if (!completedSpells.contains(i)) { next = i; break; }
          }
          setState(() {
            if (next >= 0) {
              selectedSpellIndex = next;
              _setupSpell();
            }
          });
        });
      } else {
        // Wrong expression — shake and reset to expression entry
        _shakeController.forward(from: 0).then((_) {
          setState(() {
            phase = Phase.enterExpression;
            enteredRows = null;
            enteredCols = null;
            expressionStep = 0;
            // Reset player cubes to scattered
            for (var c in playerCubes) {
              c.arrayPos = c.scatterPos;
            }
          });
        });
      }
    });
  }

  void selectSpell(int index) {
    if (phase == Phase.castSpell) return;
    setState(() {
      selectedSpellIndex = index;
      _setupSpell();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0DC),
      body: SafeArea(
        child: Column(
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _phaseTitle(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A0A2E),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            // Target area
            Expanded(flex: 35, child: _buildTargetArea()),
            // Player area / input
            Expanded(flex: 35, child: _buildPlayerArea()),
            // Action area
            SizedBox(height: 60, child: _buildActionArea()),
            // Spell bar
            SizedBox(height: 80, child: _buildSpellBar()),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  String _phaseTitle() {
    switch (phase) {
      case Phase.counting:
        return 'Count the mana cubes — tap to number them';
      case Phase.submitCount:
        return 'How many cubes?';
      case Phase.revealArray:
        return 'Watch the cubes form an array...';
      case Phase.enterExpression:
        return 'Enter rows × columns to match';
      case Phase.castSpell:
        return 'Casting...';
      case Phase.success:
        return '✨ Spell Cast! ✨';
    }
  }

  Widget _buildTargetArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6C8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4A843), width: 2),
        boxShadow: [BoxShadow(color: Colors.brown.withValues(alpha: 0.2), blurRadius: 8)],
      ),
      child: Stack(
        children: [
          // Label
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Center(
              child: Text('Target',
                  style: TextStyle(fontSize: 11, color: Colors.brown.shade400,
                      fontStyle: FontStyle.italic)),
            ),
          ),
          // Cubes
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              const cubeSize = 32.0;

              return Stack(
                children: List.generate(targetCubes.length, (i) {
                  final cube = targetCubes[i];
                  // Interpolate position based on phase
                  Offset pos;
                  if (phase == Phase.counting || phase == Phase.submitCount) {
                    pos = cube.scatterPos;
                  } else if (phase == Phase.revealArray) {
                    // Animate from scatter to array
                    final t = _arrayAnimController.value;
                    final curve = Curves.easeInOutCubic.transform(t);
                    pos = Offset.lerp(cube.scatterPos, cube.arrayPos, curve)!;
                  } else {
                    pos = cube.arrayPos;
                  }

                  final x = pos.dx * (w - cubeSize * 2) + cubeSize * 0.5;
                  final y = pos.dy * (h - cubeSize * 2) + cubeSize * 0.5;

                  return AnimatedBuilder(
                    animation: _arrayAnimController,
                    builder: (context, child) {
                      // Recalc for animation
                      Offset aPos;
                      if (phase == Phase.revealArray) {
                        final t = Curves.easeInOutCubic.transform(
                            _arrayAnimController.value);
                        aPos = Offset.lerp(cube.scatterPos, cube.arrayPos, t)!;
                      } else if (phase == Phase.counting || phase == Phase.submitCount) {
                        aPos = cube.scatterPos;
                      } else {
                        aPos = cube.arrayPos;
                      }
                      final ax = aPos.dx * (w - cubeSize * 2) + cubeSize * 0.5;
                      final ay = aPos.dy * (h - cubeSize * 2) + cubeSize * 0.5;

                      return Positioned(
                        left: ax - cubeSize / 2,
                        top: ay - cubeSize / 2,
                        child: GestureDetector(
                          onTap: () => _onCubeTapped(i),
                          child: Container(
                            width: cubeSize,
                            height: cubeSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cube.tapped
                                  ? currentSpell.orbColor
                                  : currentSpell.orbColor.withValues(alpha: 0.7),
                              boxShadow: cube.tapped
                                  ? [
                                      BoxShadow(
                                          color: currentSpell.orbColor.withValues(alpha: 0.6),
                                          blurRadius: 8,
                                          spreadRadius: 2),
                                    ]
                                  : null,
                            ),
                            child: cube.tapped && cube.tapNumber != null
                                ? Center(
                                    child: Text(
                                      '${cube.tapNumber}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerArea() {
    if (phase == Phase.counting || phase == Phase.submitCount) {
      return _buildCountInput();
    } else if (phase == Phase.enterExpression || phase == Phase.castSpell || phase == Phase.success) {
      return _buildPlayerCubesAndExpression();
    } else {
      // revealArray — show player cubes scattered, waiting
      return _buildPlayerCubesScattered();
    }
  }

  Widget _buildCountInput() {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        double shakeX = _shakeController.isAnimating && countWrong
            ? sin(_shakeController.value * pi * 4) * 10
            : 0;
        return Transform.translate(
          offset: Offset(shakeX, 0),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            decoration: BoxDecoration(
              color: countWrong ? const Color(0xFFFDE0DC) : const Color(0xFFFAF0DC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: countWrong ? Colors.red : const Color(0xFFD4A843),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tapCounter > 0
                      ? 'You\'ve tapped $tapCounter cube${tapCounter == 1 ? '' : 's'}'
                      : 'Tap cubes above to count them',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.brown.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'How many mana cubes?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A0A2E),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: _buildCountGrid(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountGrid() {
    // Show numbers 1-20 (covers our range) in a scrollable row
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 30,
      itemBuilder: (context, i) {
        int val = i + 1;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () => _submitCount(val),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '$val',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerCubesScattered() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF0DC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBA87A), width: 2),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4, left: 0, right: 0,
            child: Center(
              child: Text('Your Work Area',
                  style: TextStyle(fontSize: 11, color: Colors.brown.shade400,
                      fontStyle: FontStyle.italic)),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              const cubeSize = 28.0;
              return Stack(
                children: List.generate(playerCubes.length, (i) {
                  final cube = playerCubes[i];
                  final x = cube.scatterPos.dx * (w - cubeSize * 2) + cubeSize * 0.5;
                  final y = cube.scatterPos.dy * (h - cubeSize * 2) + cubeSize * 0.5;
                  return Positioned(
                    left: x - cubeSize / 2,
                    top: y - cubeSize / 2,
                    child: Container(
                      width: cubeSize,
                      height: cubeSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentSpell.orbColor.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCubesAndExpression() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: phase == Phase.success
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFAF0DC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: phase == Phase.success
              ? const Color(0xFFFFD700)
              : const Color(0xFFD4A843),
          width: phase == Phase.success ? 3 : 2,
        ),
        boxShadow: phase == Phase.success
            ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                blurRadius: 16, spreadRadius: 2)]
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Your Work Area',
                style: TextStyle(fontSize: 11, color: Colors.brown.shade400,
                    fontStyle: FontStyle.italic)),
          ),
          // Player cubes visualization
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (phase == Phase.castSpell || phase == Phase.success) {
                  return _buildAnimatedPlayerCubes(constraints);
                }
                // Scattered
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                const cubeSize = 28.0;
                return Stack(
                  children: List.generate(playerCubes.length, (i) {
                    final cube = playerCubes[i];
                    final x = cube.scatterPos.dx * (w - cubeSize * 2) + cubeSize * 0.5;
                    final y = cube.scatterPos.dy * (h - cubeSize * 2) + cubeSize * 0.5;
                    return Positioned(
                      left: x - cubeSize / 2,
                      top: y - cubeSize / 2,
                      child: Container(
                        width: cubeSize,
                        height: cubeSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: currentSpell.orbColor.withValues(alpha: 0.5),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          // Expression input
          if (phase == Phase.enterExpression) _buildExpressionInput(),
          if (phase == Phase.castSpell || phase == Phase.success)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${enteredRows} × ${enteredCols} = ${enteredRows! * enteredCols!}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A0A2E),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedPlayerCubes(BoxConstraints constraints) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    const cubeSize = 28.0;

    return AnimatedBuilder(
      animation: _compareAnimController,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(_compareAnimController.value);
        return Stack(
          children: List.generate(playerCubes.length, (i) {
            final cube = playerCubes[i];
            final pos = Offset.lerp(cube.scatterPos, cube.arrayPos, t)!;
            final x = pos.dx * (w - cubeSize * 2) + cubeSize * 0.5;
            final y = pos.dy * (h - cubeSize * 2) + cubeSize * 0.5;
            return Positioned(
              left: x - cubeSize / 2,
              top: y - cubeSize / 2,
              child: Container(
                width: cubeSize,
                height: cubeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentSpell.orbColor,
                  boxShadow: [
                    BoxShadow(
                      color: currentSpell.orbColor.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildExpressionInput() {
    String rowsStr = enteredRows != null ? '$enteredRows' : '?';
    String colsStr = enteredCols != null ? '$enteredCols' : '?';

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildExprBox(
                value: enteredRows,
                label: 'rows',
                active: expressionStep == 0,
                onTap: expressionStep == 0
                    ? () => _showGridPicker('How many rows?', 12, (v) {
                          _onExpressionValue(v);
                        })
                    : null,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('×',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                        color: Color(0xFF1A0A2E))),
              ),
              _buildExprBox(
                value: enteredCols,
                label: 'columns',
                active: expressionStep == 1,
                onTap: expressionStep == 1
                    ? () => _showGridPicker('How many columns?', 12, (v) {
                          _onExpressionValue(v);
                        })
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExprBox({
    required int? value,
    required String label,
    required bool active,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 55,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF0DC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0xFFFFD700) : const Color(0xFFD4A843),
            width: active ? 3 : 2,
          ),
          boxShadow: active
              ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.4), blurRadius: 8)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value != null ? '$value' : '?',
              style: TextStyle(
                fontSize: value != null ? 26 : 20,
                fontWeight: FontWeight.bold,
                color: value != null ? const Color(0xFF1A0A2E) : const Color(0xFFD4A843),
              ),
            ),
            if (active)
              Text(label, style: TextStyle(fontSize: 9, color: Colors.brown.shade400)),
          ],
        ),
      ),
    );
  }

  void _showGridPicker(String title, int maxVal, Function(int) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF5E6C8),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.brown.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A0A2E))),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.5,
                ),
                itemCount: maxVal,
                itemBuilder: (context, i) {
                  int val = i + 1;
                  return ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onSelect(val);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A0A2E),
                      foregroundColor: const Color(0xFFFFD700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text('$val',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionArea() {
    if (phase == Phase.enterExpression && expressionStep == 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: ElevatedButton(
          onPressed: _castSpell,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A0A2E),
            foregroundColor: const Color(0xFFFFD700),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            elevation: 6,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 20),
              SizedBox(width: 8),
              Text('Cast Spell',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSpellBar() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: spells.length,
      itemBuilder: (context, i) {
        final s = spells[i];
        bool selected = i == selectedSpellIndex;
        bool completed = completedSpells.contains(i);
        return GestureDetector(
          onTap: () => selectSpell(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 85,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: completed
                  ? const Color(0xFF2E7D32)
                  : (selected ? const Color(0xFF1A0A2E) : const Color(0xFFF5E6C8)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? const Color(0xFFFFD700) : const Color(0xFFD4A843),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(s.icon, size: 22,
                    color: completed || selected ? const Color(0xFFFFD700) : const Color(0xFF1A0A2E)),
                const SizedBox(height: 2),
                Text(s.name,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: completed || selected ? Colors.white : const Color(0xFF1A0A2E))),
                if (completed) const Icon(Icons.check_circle, size: 12, color: Color(0xFFFFD700)),
              ],
            ),
          ),
        );
      },
    );
  }
}
