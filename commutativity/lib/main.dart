import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:js_interop';

void main() {
  runApp(const CommutativityApp());
}

class CommutativityApp extends StatelessWidget {
  const CommutativityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Commutativity',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Georgia',
        scaffoldBackgroundColor: const Color(0xFFFAF0DC),
      ),
      home: const CommutativityScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Phase 1: Commutative Pairs (split screen)
// Phase 2: Factor Finder (all expressions for a product)
// ─────────────────────────────────────────────────────────────

class CommutativityScreen extends StatefulWidget {
  const CommutativityScreen({super.key});

  @override
  State<CommutativityScreen> createState() => _CommutativityScreenState();
}

class _CommutativityScreenState extends State<CommutativityScreen>
    with TickerProviderStateMixin {
  // Which phase: commutative pairs or factor finder
  int gamePhase = 0; // 0 = pairs, 1 = factor finder

  // ── Phase 1: Commutative Pairs ──
  static const pairChallenges = [
    (rows: 2, cols: 3),
    (rows: 4, cols: 5),
    (rows: 3, cols: 7),
    (rows: 6, cols: 2),
  ];
  int pairIndex = 0;
  int? enteredRows;
  int? enteredCols;
  int pairEntryStep = 0; // 0=rows, 1=cols
  bool pairShowCompare = false;
  bool pairCorrect = false;

  late AnimationController _rotateController;
  late AnimationController _overlayController;

  // ── Phase 2: Factor Finder ──
  static const factorTargets = [6, 12, 8, 24];
  int factorIndex = 0;
  List<(int, int)> foundPairs = [];
  int? inputA;
  int? inputB;
  int factorEntryStep = 0; // 0=first operand, 1=second operand

  int get currentTarget => factorTargets[factorIndex];

  ({int rows, int cols}) get currentPair => pairChallenges[pairIndex];

  Color get orbColor {
    const colors = [
      Color(0xFF4FC3F7),
      Color(0xFFFF7043),
      Color(0xFF9C27B0),
      Color(0xFF8D6E63),
    ];
    return colors[(gamePhase == 0 ? pairIndex : factorIndex) % colors.length];
  }

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _overlayController.dispose();
    super.dispose();
  }

  // ── Phase 1 methods ──

  void _onPairValue(int val) {
    setState(() {
      if (pairEntryStep == 0) {
        enteredRows = val;
        pairEntryStep = 1;
      } else {
        enteredCols = val;
        pairEntryStep = 2;
      }
    });
  }

  void _onPairDone() {
    if (enteredRows == null || enteredCols == null) return;
    final pair = currentPair;
    bool correct = enteredRows == pair.cols && enteredCols == pair.rows;

    setState(() {
      pairCorrect = correct;
      pairShowCompare = true;
    });

    _rotateController.forward(from: 0).then((_) {
      _overlayController.forward(from: 0);
    });
  }

  void _nextPair() {
    setState(() {
      if (pairIndex < pairChallenges.length - 1) {
        pairIndex++;
      } else {
        // Move to phase 2
        gamePhase = 1;
      }
      enteredRows = null;
      enteredCols = null;
      pairEntryStep = 0;
      pairShowCompare = false;
      pairCorrect = false;
      _rotateController.reset();
      _overlayController.reset();
    });
  }

  void _retryPair() {
    setState(() {
      enteredRows = null;
      enteredCols = null;
      pairEntryStep = 0;
      pairShowCompare = false;
      pairCorrect = false;
      _rotateController.reset();
      _overlayController.reset();
    });
  }

  // ── Phase 2 methods ──

  List<(int, int)> _allFactorPairs(int n) {
    List<(int, int)> pairs = [];
    for (int i = 1; i <= n; i++) {
      if (n % i == 0) {
        pairs.add((i, n ~/ i));
      }
    }
    return pairs;
  }

  void _onFactorValue(int val) {
    setState(() {
      if (factorEntryStep == 0) {
        inputA = val;
        factorEntryStep = 1;
      } else {
        inputB = val;
        factorEntryStep = 2;
      }
    });
  }

  void _submitFactorPair() {
    if (inputA == null || inputB == null) return;
    if (inputA! * inputB! != currentTarget) {
      // Wrong product — shake
      setState(() {
        inputA = null;
        inputB = null;
        factorEntryStep = 0;
      });
      return;
    }
    // Check if already found
    final pair = (inputA!, inputB!);
    bool alreadyFound = foundPairs.any((p) => p.$1 == pair.$1 && p.$2 == pair.$2);
    if (!alreadyFound) {
      setState(() {
        foundPairs.add(pair);
      });
    }
    setState(() {
      inputA = null;
      inputB = null;
      factorEntryStep = 0;
    });
  }

  bool get _allFactorsFound {
    final all = _allFactorPairs(currentTarget);
    return foundPairs.length >= all.length;
  }

  void _nextFactorTarget() {
    setState(() {
      if (factorIndex < factorTargets.length - 1) {
        factorIndex++;
        foundPairs.clear();
        inputA = null;
        inputB = null;
        factorEntryStep = 0;
      }
    });
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    if (gamePhase == 0) {
      return _buildPairPhase();
    } else {
      return _buildFactorPhase();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PHASE 1: Commutative Pairs
  // ═══════════════════════════════════════════════════════════

  Widget _buildPairPhase() {
    final pair = currentPair;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF0DC),
      body: SafeArea(
        child: Column(
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                pairShowCompare
                    ? (pairCorrect ? '✨ They\'re equal! ✨' : 'Not quite — try again')
                    : 'Build the commutative pair',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: pairShowCompare && !pairCorrect
                      ? Colors.red
                      : const Color(0xFF1A0A2E),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Split screen: left (given) = right (build)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Left: given array + expression
                    Expanded(child: _buildGivenSide(pair)),
                    // Equals sign
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('=',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1A0A2E).withValues(alpha: 0.6))),
                    ),
                    // Right: player builds complement
                    Expanded(child: _buildPlayerSide(pair)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Action buttons
            if (!pairShowCompare && pairEntryStep == 2)
              _buildButton('Done', Icons.check_circle_outline, _onPairDone),
            if (pairShowCompare && pairCorrect)
              _buildButton(
                pairIndex < pairChallenges.length - 1 ? 'Next' : 'Factor Finder →',
                Icons.arrow_forward,
                _nextPair,
              ),
            if (pairShowCompare && !pairCorrect)
              _buildButton('Try Again', Icons.refresh, _retryPair),
            if (!pairShowCompare && pairEntryStep < 2)
              const SizedBox(height: 52), // placeholder for alignment

            // Progress dots
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pairChallenges.length, (i) {
                  return Container(
                    width: 10, height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < pairIndex
                          ? const Color(0xFF2E7D32)
                          : (i == pairIndex
                              ? const Color(0xFFD4A843)
                              : const Color(0xFFE0D5C0)),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        ),
    );
  }

  Widget _buildGivenSide(({int rows, int cols}) pair) {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (context, child) {
        // Rotate the array 90° when comparing
        double angle = 0;
        if (pairShowCompare) {
          angle = Curves.easeInOutCubic.transform(_rotateController.value) * pi / 2;
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5E6C8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD4A843), width: 2),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Given',
                    style: TextStyle(fontSize: 11, color: Colors.brown.shade400,
                        fontStyle: FontStyle.italic)),
              ),
              Expanded(
                child: Center(
                  child: Transform.rotate(
                    angle: angle,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _buildOrbGrid(pair.rows, pair.cols, orbColor),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${pair.rows} × ${pair.cols}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A0A2E),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerSide(({int rows, int cols}) pair) {
    bool hasRows = enteredRows != null;
    bool hasCols = enteredCols != null;

    return Container(
      decoration: BoxDecoration(
        color: pairShowCompare && pairCorrect
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFAF0DC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pairShowCompare && pairCorrect
              ? const Color(0xFFFFD700)
              : const Color(0xFFD4A843),
          width: pairShowCompare && pairCorrect ? 3 : 2,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Your pair',
                style: TextStyle(fontSize: 11, color: Colors.brown.shade400,
                    fontStyle: FontStyle.italic)),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Player's array
                if (hasRows && hasCols)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildOrbGrid(
                        enteredRows!, enteredCols!, orbColor.withValues(alpha: 0.6)),
                  ),
                if (!hasRows || !hasCols)
                  Text('Enter expression',
                      style: TextStyle(color: Colors.brown.shade300,
                          fontStyle: FontStyle.italic, fontSize: 12)),
                // Ghost overlay — fades in centered over the player's array
                if (pairShowCompare)
                  AnimatedBuilder(
                    animation: _overlayController,
                    builder: (context, child) {
                      final t = Curves.easeInOut.transform(_overlayController.value);
                      return Opacity(
                        opacity: t * 0.55,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildOrbGrid(
                            pair.cols, pair.rows,
                            const Color(0xFFFFD700),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildPairExpression(),
          ),
        ],
      ),
    );
  }

  Widget _buildPairExpression() {
    return GestureDetector(
      onTap: pairEntryStep < 2 ? () => _showGridPicker(
        pairEntryStep == 0 ? 'How many rows?' : 'How many columns?',
        12,
        _onPairValue,
      ) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _miniBox(enteredRows, pairEntryStep == 0),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('×', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: Color(0xFF1A0A2E))),
          ),
          _miniBox(enteredCols, pairEntryStep == 1),
        ],
      ),
    );
  }

  Widget _miniBox(int? value, bool active) {
    return GestureDetector(
      onTap: active ? () => _showGridPicker(
        'Select a number',
        12,
        _onPairValue,
      ) : null,
      child: Container(
        width: 40,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF0DC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFFFFD700) : const Color(0xFFD4A843),
            width: active ? 2.5 : 1.5,
          ),
        ),
        child: Center(
          child: Text(
            value != null ? '$value' : '?',
            style: TextStyle(
              fontSize: value != null ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: value != null ? const Color(0xFF1A0A2E) : const Color(0xFFD4A843),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // PHASE 2: Factor Finder
  // ═══════════════════════════════════════════════════════════

  Widget _buildFactorPhase() {
    final allPairs = _allFactorPairs(currentTarget);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF0DC),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Target number
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF5E6C8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD4A843), width: 2),
                boxShadow: [BoxShadow(color: Colors.brown.withValues(alpha: 0.15), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  Text('Find all expressions for',
                      style: TextStyle(fontSize: 13, color: Colors.brown.shade400,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                  Text('$currentTarget',
                      style: const TextStyle(
                          fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF1A0A2E))),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Found pairs grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5E6C8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD4A843), width: 2),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Found: ${foundPairs.length} / ${allPairs.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _allFactorsFound
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF1A0A2E),
                          ),
                        ),
                      ),
                      Expanded(
                        child: foundPairs.isEmpty
                            ? Center(
                                child: Text('Enter expressions below',
                                    style: TextStyle(color: Colors.brown.shade300,
                                        fontStyle: FontStyle.italic)),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: foundPairs.length,
                                itemBuilder: (context, i) {
                                  final p = foundPairs[i];
                                  return _buildFoundPairTile(p.$1, p.$2);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Input area
            if (!_allFactorsFound) _buildFactorInput(),

            if (_allFactorsFound)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    const Text('🎉 All expressions found!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32))),
                    const SizedBox(height: 8),
                    if (factorIndex < factorTargets.length - 1)
                      _buildButton('Next Number', Icons.arrow_forward, _nextFactorTarget),
                  ],
                ),
              ),

            // Progress dots
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(factorTargets.length, (i) {
                  return Container(
                    width: 10, height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < factorIndex
                          ? const Color(0xFF2E7D32)
                          : (i == factorIndex
                              ? const Color(0xFFD4A843)
                              : const Color(0xFFE0D5C0)),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoundPairTile(int a, int b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF0DC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4A843), width: 1.5),
      ),
      child: Row(
        children: [
          // Mini array visualization
          SizedBox(
            width: 60,
            height: 40,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _buildOrbGrid(a, b, orbColor, orbSize: 10),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$a × $b = $currentTarget',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A0A2E),
            ),
          ),
          const Spacer(),
          const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20),
        ],
      ),
    );
  }

  Widget _buildFactorInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _factorInputBox(inputA, factorEntryStep == 0, () {
            _showGridPicker('First number', 12, _onFactorValue);
          }),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('×', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                color: Color(0xFF1A0A2E))),
          ),
          _factorInputBox(inputB, factorEntryStep == 1, () {
            _showGridPicker('Second number', 12, _onFactorValue);
          }),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('=', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                color: Color(0xFF1A0A2E))),
          ),
          Text('$currentTarget',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                  color: Color(0xFF1A0A2E))),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: factorEntryStep == 2 ? _submitFactorPair : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A0A2E),
              foregroundColor: const Color(0xFFFFD700),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Icon(Icons.check, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _factorInputBox(int? value, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        width: 50,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF0DC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFFFFD700) : const Color(0xFFD4A843),
            width: active ? 3 : 2,
          ),
          boxShadow: active
              ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.3), blurRadius: 6)]
              : null,
        ),
        child: Center(
          child: Text(
            value != null ? '$value' : '?',
            style: TextStyle(
              fontSize: value != null ? 22 : 16,
              fontWeight: FontWeight.bold,
              color: value != null ? const Color(0xFF1A0A2E) : const Color(0xFFD4A843),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Shared widgets
  // ═══════════════════════════════════════════════════════════

  Widget _buildOrbGrid(int rows, int cols, Color color, {double orbSize = 24}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (r) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(cols, (c) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 3,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildButton(String label, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A0A2E),
          foregroundColor: const Color(0xFFFFD700),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showGridPicker(String title, int maxVal, Function(int) onSelect) {
    showModalBottomSheet(
      context: context,
      enableDrag: false,
      backgroundColor: const Color(0xFFF5E6C8),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 20),
                    style: IconButton.styleFrom(foregroundColor: const Color(0xFF1A0A2E)),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                  Expanded(
                    child: Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A0A2E))),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
              const SizedBox(height: 12),
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
}
