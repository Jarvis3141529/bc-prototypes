import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const SpellCraftingApp());
}

class SpellCraftingApp extends StatelessWidget {
  const SpellCraftingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spell Crafting',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Georgia',
        scaffoldBackgroundColor: const Color(0xFFFAF0DC),
      ),
      home: const SpellCraftingScreen(),
    );
  }
}

class SpellData {
  final String name;
  final IconData icon;
  final int multiplier; // number of rows (left operand)
  final int multiplicand; // items per row (right operand)
  final Color orbColor;

  const SpellData({
    required this.name,
    required this.icon,
    required this.multiplier,
    required this.multiplicand,
    required this.orbColor,
  });

  int get product => multiplier * multiplicand;
}

const spells = [
  SpellData(name: 'Shield', icon: Icons.shield, multiplier: 4, multiplicand: 3, orbColor: Color(0xFF4FC3F7)),
  SpellData(name: 'Fireball', icon: Icons.local_fire_department, multiplier: 2, multiplicand: 6, orbColor: Color(0xFFFF7043)),
  SpellData(name: 'Sleep', icon: Icons.dark_mode, multiplier: 3, multiplicand: 5, orbColor: Color(0xFF9C27B0)),
  SpellData(name: 'Repair', icon: Icons.build, multiplier: 5, multiplicand: 4, orbColor: Color(0xFF8D6E63)),
];

class SpellCraftingScreen extends StatefulWidget {
  const SpellCraftingScreen({super.key});

  @override
  State<SpellCraftingScreen> createState() => _SpellCraftingScreenState();
}

class _SpellCraftingScreenState extends State<SpellCraftingScreen> with TickerProviderStateMixin {
  int selectedSpellIndex = 0;
  // Order: multiplicand first (second box visually), then multiplier (first box), then product
  // But visually: [multiplier] × [multiplicand] = [product]
  // Entry order: multiplicand (right) → multiplier (left) → product
  int? multiplicand; // items per row — entered FIRST
  int? multiplier;   // number of rows — entered SECOND
  int? productVal;
  
  // 0 = entering multiplicand, 1 = entering multiplier, 2 = entering product, 3 = done
  int entryStep = 0;
  
  bool casting = false;
  bool castSuccess = false;
  bool showCompletion = false;
  int energizeCount = 0;
  bool energizing = false;
  Set<int> completedSpells = {};

  late AnimationController _castController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  // Track which boxes should shake: 0=multiplicand, 1=multiplier, 2=product
  Set<int> _shakingBoxes = {};

  SpellData get currentSpell => spells[selectedSpellIndex];

  @override
  void initState() {
    super.initState();
    _castController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _castController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void selectSpell(int index) {
    if (casting) return;
    setState(() {
      selectedSpellIndex = index;
      _resetInputs();
    });
  }

  void _resetInputs() {
    multiplicand = null;
    multiplier = null;
    productVal = null;
    entryStep = 0;
    energizeCount = 0;
    energizing = false;
    castSuccess = false;
    showCompletion = false;
  }

  void _onValueSelected(int val) {
    setState(() {
      if (entryStep == 0) {
        multiplicand = val;
        entryStep = 1;
      } else if (entryStep == 1) {
        multiplier = val;
        entryStep = 2;
      } else if (entryStep == 2) {
        productVal = val;
        entryStep = 3;
        _startEnergize();
      }
    });
  }

  void _startEnergize() {
    if (productVal == null) return;
    energizing = true;
    energizeCount = 0;
    int total = productVal!;
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        energizeCount++;
        if (energizeCount >= total) {
          timer.cancel();
          energizing = false;
        }
      });
    });
  }

  bool get isCorrect =>
      multiplicand == currentSpell.multiplicand &&
      multiplier == currentSpell.multiplier &&
      productVal == currentSpell.product;

  bool get canCast => entryStep == 3 && !casting && !energizing;

  void castSpell() {
    if (!canCast) return;
    setState(() { casting = true; });

    if (isCorrect) {
      _castController.forward(from: 0).then((_) {
        setState(() {
          castSuccess = true;
          completedSpells.add(selectedSpellIndex);
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          int next = -1;
          for (int i = 0; i < spells.length; i++) {
            if (!completedSpells.contains(i)) { next = i; break; }
          }
          setState(() {
            casting = false;
            if (next >= 0) {
              selectedSpellIndex = next;
              _resetInputs();
            } else {
              showCompletion = true;
            }
          });
        });
      });
    } else {
      // Check each component independently
      bool mdWrong = multiplicand != currentSpell.multiplicand;
      bool mlWrong = multiplier != currentSpell.multiplier;
      // Product checked against the expression they actually entered
      bool prWrong = productVal != (multiplier! * multiplicand!);
      
      // Mark all wrong boxes for shake+red
      _shakingBoxes = {};
      if (mdWrong) _shakingBoxes.add(0);
      if (mlWrong) _shakingBoxes.add(1);
      if (prWrong) _shakingBoxes.add(2);
      
      _shakeController.forward(from: 0).then((_) {
        setState(() {
          casting = false;
          _shakingBoxes = {};
          // Always clear product if anything is wrong
          productVal = null;
          energizeCount = 0;
          // Clear wrong operands, keep correct ones
          if (mdWrong) {
            multiplicand = null;
            // If multiplicand is cleared, multiplier must re-enter too
            multiplier = null;
            entryStep = 0;
          } else if (mlWrong) {
            multiplier = null;
            entryStep = 1;
          } else {
            entryStep = 2;
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showCompletion) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF0DC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 80, color: Color(0xFFD4A843)),
              const SizedBox(height: 16),
              const Text('All Spells Cast!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A0A2E))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() {
                  completedSpells.clear();
                  showCompletion = false;
                  _resetInputs();
                  selectedSpellIndex = 0;
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A0A2E),
                  foregroundColor: const Color(0xFFFFD700),
                ),
                child: const Text('Play Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF0DC),
      body: SafeArea(
        child: Column(
          children: [
            // Target Array
            Expanded(flex: 25, child: _buildTargetArray()),
            // Spell Scroll
            Expanded(flex: 22, child: _buildSpellScroll()),
            // Expression display
            _buildExpression(),
            const SizedBox(height: 4),
            // Crafting Area
            SizedBox(height: 70, child: _buildCraftingArea()),
            const SizedBox(height: 4),
            // Cast Button
            _buildCastButton(),
            // Spell Select Bar
            SizedBox(height: 90, child: _buildSpellBar()),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetArray() {
    final spell = currentSpell;
    return AnimatedBuilder(
      animation: _castController,
      builder: (context, child) {
        double opacity = castSuccess ? (1.0 - _castController.value) : 1.0;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF0DC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4A843), width: 2),
              boxShadow: [BoxShadow(color: Colors.brown.withValues(alpha: 0.2), blurRadius: 8)],
            ),
            child: Column(
              children: [
                Text('Target Spell',
                    style: TextStyle(fontSize: 12, color: Colors.brown.shade400, fontStyle: FontStyle.italic)),
                const SizedBox(height: 2),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildOrbGrid(spell.multiplier, spell.multiplicand, spell.orbColor, 1.0),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrbGrid(int rows, int cols, Color color, double opacity,
      {bool showNumbers = false, int numberedCount = 0, int totalForCardinality = 0}) {
    const double orbSize = 32;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (r) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(cols, (c) {
              int index = r * cols + c;
              bool numbered = showNumbers && index < numberedCount;
              bool isLast = showNumbers && index == totalForCardinality - 1 && index < numberedCount;
              bool lit = numbered;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lit ? color : color.withValues(alpha: opacity * 0.7),
                    boxShadow: lit
                        ? [
                            BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2),
                            BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.4), blurRadius: 12),
                          ]
                        : null,
                  ),
                  child: numbered
                      ? Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: isLast ? 16 : 11,
                              fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                              color: Colors.white,
                              shadows: isLast ? [const Shadow(color: Color(0xFFFFD700), blurRadius: 8)] : null,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildSpellScroll() {
    final spell = currentSpell;
    bool hasMultiplicand = multiplicand != null;
    bool hasMultiplier = multiplier != null;
    bool hasProduct = productVal != null;

    int showRows = 0;
    int showCols = 0;
    bool showNums = false;

    if (hasMultiplicand) {
      showCols = multiplicand!;
      showRows = 1;
    }
    if (hasMultiplier) {
      showRows = multiplier!;
    }
    if (hasProduct) {
      showNums = true;
    }

    bool matchesTarget = hasMultiplicand && hasMultiplier && hasProduct &&
        multiplicand == spell.multiplicand &&
        multiplier == spell.multiplier &&
        productVal == spell.product;
    bool wrong = hasProduct && !energizing && !matchesTarget;

    Color borderColor = wrong
        ? Colors.red
        : (matchesTarget && !energizing ? const Color(0xFFFFD700) : const Color(0xFFD4A843));
    double borderWidth = (matchesTarget && !energizing) ? 3 : 2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: wrong ? const Color(0xFFFDE0DC) : const Color(0xFFF5E6C8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: matchesTarget && !energizing
            ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 2)]
            : [BoxShadow(color: Colors.brown.withValues(alpha: 0.15), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Text('Spell Scroll',
              style: TextStyle(fontSize: 11, color: Colors.brown.shade400, fontStyle: FontStyle.italic)),
          Expanded(
            child: Center(
              child: hasMultiplicand
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _buildOrbGrid(
                        showRows,
                        showCols,
                        spell.orbColor,
                        hasProduct ? 1.0 : 0.5,
                        showNumbers: showNums,
                        numberedCount: energizeCount,
                        totalForCardinality: productVal ?? 0,
                      ),
                    )
                  : Text('Select values to craft...',
                      style: TextStyle(color: Colors.brown.shade300, fontStyle: FontStyle.italic)),
            ),
          ),
          if (castSuccess)
            const Text('✨ Spell Cast! ✨',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD4A843))),
        ],
      ),
    );
  }

  Widget _buildExpression() {
    // Visual order: [multiplier] × [multiplicand] = [product]
    // Entry order: multiplicand first, then multiplier, then product
    String mlStr = multiplier != null ? '$multiplier' : '_';
    String mdStr = multiplicand != null ? '$multiplicand' : '_';
    String prStr = productVal != null ? '$productVal' : '_';

    // Build progressively based on entry step
    String expr;
    if (entryStep == 0) {
      expr = '_ × _ = _';
    } else if (entryStep == 1) {
      // Multiplicand entered, goes in second slot
      expr = '_ × $mdStr = _';
    } else if (entryStep == 2) {
      expr = '$mlStr × $mdStr = _';
    } else {
      expr = '$mlStr × $mdStr = $prStr';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(expr,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A0A2E), letterSpacing: 2)),
    );
  }

  Widget _buildCraftingArea() {
    // Visual layout: [multiplier] × [multiplicand] = [product]
    // But entry order: multiplicand(step 0) → multiplier(step 1) → product(step 2)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Multiplier box (entered second, step 1)
          Expanded(child: _shakeableBox(1, _buildInputBox(
            value: multiplier,
            active: entryStep == 1,
            locked: entryStep < 1 && multiplier == null,
            label: 'rows',
            shaking: _shakingBoxes.contains(1),
            onTap: entryStep == 1 ? () => _showNumberPicker('How many rows?', 12) : null,
          ))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('×', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A0A2E))),
          ),
          // Multiplicand box (entered first, step 0)
          Expanded(child: _shakeableBox(0, _buildInputBox(
            value: multiplicand,
            active: entryStep == 0,
            locked: false,
            label: 'each row',
            shaking: _shakingBoxes.contains(0),
            onTap: entryStep == 0 ? () => _showNumberPicker('How many in each row?', 12) : null,
          ))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('=', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A0A2E))),
          ),
          // Product box (entered third, step 2)
          Expanded(child: _shakeableBox(2, _buildInputBox(
            value: productVal,
            active: entryStep == 2,
            locked: entryStep < 2 && productVal == null,
            label: 'total',
            shaking: _shakingBoxes.contains(2),
            onTap: entryStep == 2 ? () => _showNumberPicker('What\'s the total?', 144) : null,
          ))),
        ],
      ),
    );
  }

  Widget _shakeableBox(int boxIndex, Widget child) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, _) {
        bool shouldShake = _shakeController.isAnimating && _shakingBoxes.contains(boxIndex);
        return Transform.translate(
          offset: Offset(shouldShake ? sin(_shakeController.value * pi * 4) * 10 : 0, 0),
          child: child,
        );
      },
    );
  }

  Widget _buildInputBox({
    required int? value,
    required bool active,
    required bool locked,
    required String label,
    bool shaking = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 65,
        decoration: BoxDecoration(
          color: locked ? const Color(0xFFE0D5C0) : const Color(0xFFFAF0DC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: shaking
                ? Colors.red
                : (active
                    ? const Color(0xFFFFD700)
                    : (value != null ? const Color(0xFFD4A843) : const Color(0xFFBBA87A))),
            width: active || shaking ? 3 : 2,
          ),
          boxShadow: active
              ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.4), blurRadius: 8)]
              : null,
        ),
        child: Center(
          child: locked
              ? Icon(Icons.lock, color: Colors.brown.shade300, size: 18)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value != null ? '$value' : '?',
                      style: TextStyle(
                        fontSize: value != null ? 28 : 22,
                        fontWeight: FontWeight.bold,
                        color: value != null ? const Color(0xFF1A0A2E) : const Color(0xFFD4A843),
                      ),
                    ),
                    if (active)
                      Text(label,
                          style: TextStyle(fontSize: 9, color: Colors.brown.shade400)),
                  ],
                ),
        ),
      ),
    );
  }

  void _showNumberPicker(String title, int maxVal) {
    if (maxVal > 12) {
      _showWheelPicker(title, maxVal);
    } else {
      _showGridPicker(title, maxVal);
    }
  }

  void _showGridPicker(String title, int maxVal) {
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
                      _onValueSelected(val);
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

  void _showWheelPicker(String title, int maxVal) {
    // Start at a random position to avoid hinting at the answer
    int startVal = Random().nextInt(maxVal) + 1;
    int selectedVal = startVal;
    final controller = FixedExtentScrollController(
        initialItem: startVal - 1);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF5E6C8),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SizedBox(
              height: 320,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.brown.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A0A2E))),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        // Selection highlight band
                        Center(
                          child: Container(
                            height: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 60),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A0A2E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD4A843), width: 2),
                            ),
                          ),
                        ),
                        // Wheel
                        ListWheelScrollView.useDelegate(
                          controller: controller,
                          itemExtent: 50,
                          diameterRatio: 1.5,
                          perspective: 0.003,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setSheetState(() {
                              selectedVal = index + 1;
                            });
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: maxVal,
                            builder: (context, index) {
                              int val = index + 1;
                              bool isSelected = val == selectedVal;
                              return Center(
                                child: Text(
                                  '$val',
                                  style: TextStyle(
                                    fontSize: isSelected ? 32 : 22,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? const Color(0xFF1A0A2E)
                                        : const Color(0xFF1A0A2E).withValues(alpha: 0.4),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 8, 40, 16),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _onValueSelected(selectedVal);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A0A2E),
                        foregroundColor: const Color(0xFFFFD700),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 4,
                      ),
                      child: Text('Select $selectedVal',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCastButton() {
    bool enabled = canCast;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
      child: AnimatedBuilder(
        animation: _castController,
        builder: (context, child) {
          bool flashing = casting && isCorrect;
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled || casting ? 1.0 : 0.5,
            child: Container(
              decoration: flashing
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: _castController.value),
                            blurRadius: 30,
                            spreadRadius: 5)
                      ],
                    )
                  : null,
              child: ElevatedButton(
                onPressed: enabled ? castSpell : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A0A2E),
                  foregroundColor: const Color(0xFFFFD700),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 20),
                    const SizedBox(width: 8),
                    Text(casting ? 'Casting...' : 'Cast Spell',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          );
        },
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
              boxShadow: selected
                  ? [BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.3), blurRadius: 8)]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(s.icon, size: 24,
                    color: completed || selected ? const Color(0xFFFFD700) : const Color(0xFF1A0A2E)),
                const SizedBox(height: 2),
                Text(s.name,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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
