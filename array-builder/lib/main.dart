import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(const ArrayBuilderApp());
}

class ArrayBuilderApp extends StatelessWidget {
  const ArrayBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Array Builder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Georgia',
        scaffoldBackgroundColor: const Color(0xFFFAF0DC),
      ),
      home: const ArrayBuilderScreen(),
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

  int get product => rows * cols;
}

const spells = [
  SpellData(name: 'Shield', icon: Icons.shield, rows: 3, cols: 4, orbColor: Color(0xFF4FC3F7)),
  SpellData(name: 'Fireball', icon: Icons.local_fire_department, rows: 2, cols: 6, orbColor: Color(0xFFFF7043)),
  SpellData(name: 'Sleep', icon: Icons.dark_mode, rows: 5, cols: 3, orbColor: Color(0xFF9C27B0)),
  SpellData(name: 'Repair', icon: Icons.build, rows: 4, cols: 7, orbColor: Color(0xFF8D6E63)),
];

enum Phase {
  building,    // user is placing cubes
  comparing,   // animating target expression → array
  success,     // correct
  incorrect,   // wrong, showing both arrays
}

class ArrayBuilderScreen extends StatefulWidget {
  const ArrayBuilderScreen({super.key});

  @override
  State<ArrayBuilderScreen> createState() => _ArrayBuilderScreenState();
}

class _ArrayBuilderScreenState extends State<ArrayBuilderScreen>
    with TickerProviderStateMixin {
  int selectedSpellIndex = 0;
  Phase phase = Phase.building;
  Set<int> completedSpells = {};

  // Grid dimensions — larger than any answer to avoid hints
  static const int gridRows = 10;
  static const int gridCols = 10;

  // Which cells the player has filled
  late List<List<bool>> playerGrid;

  late AnimationController _revealController;

  SpellData get currentSpell => spells[selectedSpellIndex];

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _resetGrid();
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  void _resetGrid() {
    playerGrid = List.generate(gridRows, (_) => List.filled(gridCols, false));
    phase = Phase.building;
  }

  void _toggleCell(int row, int col) {
    if (phase != Phase.building) return;
    setState(() {
      playerGrid[row][col] = !playerGrid[row][col];
    });
  }

  int get _placedCount {
    int count = 0;
    for (final row in playerGrid) {
      for (final cell in row) {
        if (cell) count++;
      }
    }
    return count;
  }

  // Check if player's grid forms a valid rectangle matching the target
  bool get _isCorrect {
    final spell = currentSpell;
    // Find bounding box of placed cubes
    int minR = gridRows, maxR = -1, minC = gridCols, maxC = -1;
    int count = 0;
    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        if (playerGrid[r][c]) {
          count++;
          minR = min(minR, r);
          maxR = max(maxR, r);
          minC = min(minC, c);
          maxC = max(maxC, c);
        }
      }
    }
    if (count != spell.product) return false;
    // Check it's a filled rectangle of the right dimensions
    int bRows = maxR - minR + 1;
    int bCols = maxC - minC + 1;
    if (bRows != spell.rows || bCols != spell.cols) return false;
    // Check every cell in the bounding box is filled
    for (int r = minR; r <= maxR; r++) {
      for (int c = minC; c <= maxC; c++) {
        if (!playerGrid[r][c]) return false;
      }
    }
    return true;
  }

  void _onDone() {
    if (phase != Phase.building) return;
    setState(() {
      phase = Phase.comparing;
    });
    _revealController.forward(from: 0).then((_) {
      setState(() {
        if (_isCorrect) {
          phase = Phase.success;
          completedSpells.add(selectedSpellIndex);
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;
            int next = -1;
            for (int i = 0; i < spells.length; i++) {
              if (!completedSpells.contains(i)) { next = i; break; }
            }
            setState(() {
              if (next >= 0) {
                selectedSpellIndex = next;
                _resetGrid();
              }
            });
          });
        } else {
          phase = Phase.incorrect;
        }
      });
    });
  }

  void _retry() {
    setState(() {
      _resetGrid();
    });
  }

  void selectSpell(int index) {
    if (phase == Phase.comparing) return;
    setState(() {
      selectedSpellIndex = index;
      _resetGrid();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF0DC),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 4),
            // Target expression area
            _buildTargetArea(),
            const SizedBox(height: 6),
            // Workspace grid
            Expanded(child: _buildWorkspace()),
            const SizedBox(height: 4),
            // Count indicator
            _buildCountIndicator(),
            const SizedBox(height: 4),
            // Action button
            _buildActionButton(),
            const SizedBox(height: 4),
            // Spell bar
            SizedBox(height: 80, child: _buildSpellBar()),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetArea() {
    final spell = currentSpell;
    bool showArray = phase == Phase.comparing || phase == Phase.success || phase == Phase.incorrect;

    return AnimatedBuilder(
      animation: _revealController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5E6C8),
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
                : [BoxShadow(color: Colors.brown.withValues(alpha: 0.15), blurRadius: 6)],
          ),
          child: Column(
            children: [
              Text('Target',
                  style: TextStyle(fontSize: 11, color: Colors.brown.shade400,
                      fontStyle: FontStyle.italic)),
              const SizedBox(height: 4),
              if (!showArray)
                // Show expression
                Text(
                  '${spell.rows} × ${spell.cols} = ${spell.product}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A0A2E),
                    letterSpacing: 2,
                  ),
                )
              else
                // Animate to array
                _buildTargetArray(spell),
              if (phase == Phase.success)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('✨ Perfect Match! ✨',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: Color(0xFFD4A843))),
                ),
              if (phase == Phase.incorrect)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Not quite — compare the arrays',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                          color: Colors.red)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTargetArray(SpellData spell) {
    final t = Curves.easeInOutCubic.transform(_revealController.value);
    const orbSize = 28.0;

    return Opacity(
      opacity: t,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(spell.rows, (r) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(spell.cols, (c) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    width: orbSize,
                    height: orbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: spell.orbColor,
                      boxShadow: [
                        BoxShadow(
                          color: spell.orbColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWorkspace() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF0DC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4A843), width: 2),
        boxShadow: [BoxShadow(color: Colors.brown.withValues(alpha: 0.1), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Your Array — tap to place cubes',
                style: TextStyle(fontSize: 11, color: Colors.brown.shade400,
                    fontStyle: FontStyle.italic)),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: gridCols / gridRows,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cellW = constraints.maxWidth / gridCols;
                    final cellH = constraints.maxHeight / gridRows;
                    final cellSize = min(cellW, cellH);

                    return Center(
                      child: SizedBox(
                        width: cellSize * gridCols,
                        height: cellSize * gridRows,
                        child: Stack(
                          children: [
                            // Grid lines
                            CustomPaint(
                              size: Size(cellSize * gridCols, cellSize * gridRows),
                              painter: GridPainter(
                                rows: gridRows,
                                cols: gridCols,
                                cellSize: cellSize,
                              ),
                            ),
                            // Cells
                            ...List.generate(gridRows * gridCols, (index) {
                              final r = index ~/ gridCols;
                              final c = index % gridCols;
                              final filled = playerGrid[r][c];
                              return Positioned(
                                left: c * cellSize,
                                top: r * cellSize,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _toggleCell(r, c),
                                  child: Container(
                                    width: cellSize,
                                    height: cellSize,
                                    child: filled
                                        ? Center(
                                            child: Container(
                                              width: cellSize * 0.78,
                                              height: cellSize * 0.78,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: currentSpell.orbColor,
                                                border: Border.all(
                                                  color: currentSpell.orbColor.withValues(alpha: 0.4),
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: currentSpell.orbColor.withValues(alpha: 0.5),
                                                    blurRadius: 4,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCountIndicator() {
    final target = currentSpell.product;
    final placed = _placedCount;
    final color = placed == target
        ? const Color(0xFF2E7D32)
        : (placed > target ? Colors.red : const Color(0xFF1A0A2E));

    return Text(
      'Cubes placed: $placed / $target',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  Widget _buildActionButton() {
    if (phase == Phase.incorrect) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: ElevatedButton(
          onPressed: _retry,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A0A2E),
            foregroundColor: const Color(0xFFFFD700),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, size: 20),
              SizedBox(width: 8),
              Text('Try Again', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    bool canSubmit = phase == Phase.building && _placedCount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: canSubmit ? 1.0 : 0.4,
        child: ElevatedButton(
          onPressed: canSubmit ? _onDone : null,
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
              Icon(Icons.check_circle_outline, size: 20),
              SizedBox(width: 8),
              Text('Done', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
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
                if (completed)
                  const Icon(Icons.check_circle, size: 12, color: Color(0xFFFFD700)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class GridPainter extends CustomPainter {
  final int rows;
  final int cols;
  final double cellSize;

  GridPainter({required this.rows, required this.cols, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4A843).withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw grid lines
    for (int r = 0; r <= rows; r++) {
      canvas.drawLine(
        Offset(0, r * cellSize),
        Offset(cols * cellSize, r * cellSize),
        paint,
      );
    }
    for (int c = 0; c <= cols; c++) {
      canvas.drawLine(
        Offset(c * cellSize, 0),
        Offset(c * cellSize, rows * cellSize),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter old) =>
      old.rows != rows || old.cols != cols || old.cellSize != cellSize;
}
