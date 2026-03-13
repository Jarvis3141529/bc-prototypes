import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

@JS('recognizeDigit')
external JSPromise<JSString> _recognizeDigitJS(
    JSString strokesJson, JSNumber canvasWidth, JSNumber canvasHeight);

Future<({int digit, double confidence})> recognizeDigit(
    List<List<Offset>> strokes, double width, double height) async {
  final data =
      strokes.map((s) => s.map((p) => [p.dx, p.dy]).toList()).toList();
  final json = jsonEncode(data);
  final result =
      await _recognizeDigitJS(json.toJS, width.toJS, height.toJS).toDart;
  final parsed = jsonDecode(result.toDart) as Map<String, dynamic>;
  return (
    digit: (parsed['digit'] as num).toInt(),
    confidence: (parsed['confidence'] as num).toDouble()
  );
}

void main() {
  runApp(const DigitDrawApp());
}

class DigitDrawApp extends StatelessWidget {
  const DigitDrawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digit Draw',
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
  final int multiplier;
  final int multiplicand;
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
  SpellData(
      name: 'Shield',
      icon: Icons.shield,
      multiplier: 4,
      multiplicand: 3,
      orbColor: Color(0xFF4FC3F7)),
  SpellData(
      name: 'Fireball',
      icon: Icons.local_fire_department,
      multiplier: 2,
      multiplicand: 6,
      orbColor: Color(0xFFFF7043)),
  SpellData(
      name: 'Sleep',
      icon: Icons.dark_mode,
      multiplier: 3,
      multiplicand: 5,
      orbColor: Color(0xFF9C27B0)),
  SpellData(
      name: 'Repair',
      icon: Icons.build,
      multiplier: 7,
      multiplicand: 8,
      orbColor: Color(0xFF8D6E63)),
];

class SpellCraftingScreen extends StatefulWidget {
  const SpellCraftingScreen({super.key});

  @override
  State<SpellCraftingScreen> createState() => _SpellCraftingScreenState();
}

class _SpellCraftingScreenState extends State<SpellCraftingScreen>
    with TickerProviderStateMixin {
  int selectedSpellIndex = 0;
  int? multiplicand;
  int? multiplier;
  int? productVal;
  int entryStep = 0; // 0=multiplicand, 1=multiplier, 2=product, 3=done

  bool casting = false;
  bool castSuccess = false;
  bool showCompletion = false;
  int energizeCount = 0;
  bool energizing = false;
  Set<int> completedSpells = {};
  Set<int> _shakingBoxes = {};

  late AnimationController _castController;
  late AnimationController _shakeController;

  SpellData get currentSpell => spells[selectedSpellIndex];

  @override
  void initState() {
    super.initState();
    _castController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
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
    _shakingBoxes = {};
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
      if (!mounted) {
        timer.cancel();
        return;
      }
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
    setState(() => casting = true);

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
            if (!completedSpells.contains(i)) {
              next = i;
              break;
            }
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
      bool mdWrong = multiplicand != currentSpell.multiplicand;
      bool mlWrong = multiplier != currentSpell.multiplier;
      bool prWrong = productVal != (multiplier! * multiplicand!);

      _shakingBoxes = {};
      if (mdWrong) _shakingBoxes.add(0);
      if (mlWrong) _shakingBoxes.add(1);
      if (prWrong) _shakingBoxes.add(2);

      _shakeController.forward(from: 0).then((_) {
        setState(() {
          casting = false;
          _shakingBoxes = {};
          productVal = null;
          energizeCount = 0;
          if (mdWrong) {
            multiplicand = null;
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

  String _currentLabel() {
    if (entryStep == 0) return 'Draw how many in each row';
    if (entryStep == 1) return 'Draw how many rows';
    if (entryStep == 2) return 'Draw the total';
    return '';
  }

  int _currentMaxVal() {
    if (entryStep <= 1) return 12;
    return 100; // product can be up to 100
  }

  void _openDrawInput() {
    if (entryStep > 2) return;
    final label = _currentLabel();
    final maxDigits = entryStep == 2 ? 3 : 2;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false, // prevent drag-to-dismiss conflicting with drawing
      backgroundColor: const Color(0xFFF5E6C8),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DrawingInputSheet(
          title: label,
          maxDigits: maxDigits,
          maxValue: _currentMaxVal(),
          onSubmit: (val) {
            Navigator.pop(ctx);
            _onValueSelected(val);
          },
          onFallbackPicker: () {
            Navigator.pop(ctx);
            _openFallbackPicker();
          },
          onCancel: () => Navigator.pop(ctx),
        );
      },
    );
  }

  void _openFallbackPicker() {
    final label = _currentLabel();
    final maxVal = _currentMaxVal();

    if (maxVal > 12) {
      _showWheelPicker(label, maxVal);
    } else {
      _showGridPicker(label, maxVal);
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
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.brown.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A0A2E))),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text('$val',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
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
    int startVal = Random().nextInt(maxVal) + 1;
    int selectedVal = startVal;
    final controller =
        FixedExtentScrollController(initialItem: startVal - 1);

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
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.brown.shade300,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A0A2E))),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            height: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 60),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A0A2E)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFD4A843), width: 2),
                            ),
                          ),
                        ),
                        ListWheelScrollView.useDelegate(
                          controller: controller,
                          itemExtent: 50,
                          diameterRatio: 1.5,
                          perspective: 0.003,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setSheetState(() => selectedVal = index + 1);
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
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? const Color(0xFF1A0A2E)
                                        : const Color(0xFF1A0A2E)
                                            .withValues(alpha: 0.4),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                      child: Text('Select $selectedVal',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    if (showCompletion) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF0DC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome,
                  size: 80, color: Color(0xFFD4A843)),
              const SizedBox(height: 16),
              const Text('All Spells Cast!',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A0A2E))),
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
            Expanded(flex: 25, child: _buildTargetArray()),
            Expanded(flex: 22, child: _buildSpellScroll()),
            _buildExpression(),
            const SizedBox(height: 4),
            SizedBox(height: 70, child: _buildCraftingArea()),
            const SizedBox(height: 4),
            _buildCastButton(),
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
              boxShadow: [
                BoxShadow(
                    color: Colors.brown.withValues(alpha: 0.2), blurRadius: 8)
              ],
            ),
            child: Column(
              children: [
                Text('Target Spell',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.brown.shade400,
                        fontStyle: FontStyle.italic)),
                const SizedBox(height: 2),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildOrbGrid(spell.multiplier, spell.multiplicand,
                        spell.orbColor, 1.0),
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
      {bool showNumbers = false,
      int numberedCount = 0,
      int totalForCardinality = 0}) {
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
              bool isLast = showNumbers &&
                  index == totalForCardinality - 1 &&
                  index < numberedCount;
              bool lit = numbered;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        lit ? color : color.withValues(alpha: opacity * 0.7),
                    boxShadow: lit
                        ? [
                            BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 2),
                            BoxShadow(
                                color: const Color(0xFFFFD700)
                                    .withValues(alpha: 0.4),
                                blurRadius: 12),
                          ]
                        : null,
                  ),
                  child: numbered
                      ? Center(
                          child: Text('${index + 1}',
                              style: TextStyle(
                                fontSize: isLast ? 16 : 11,
                                fontWeight:
                                    isLast ? FontWeight.bold : FontWeight.normal,
                                color: Colors.white,
                                shadows: isLast
                                    ? [
                                        const Shadow(
                                            color: Color(0xFFFFD700),
                                            blurRadius: 8)
                                      ]
                                    : null,
                              )))
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

    int showRows = 0, showCols = 0;
    bool showNums = false;
    if (hasMultiplicand) {
      showCols = multiplicand!;
      showRows = 1;
    }
    if (hasMultiplier) showRows = multiplier!;
    if (hasProduct) showNums = true;

    bool matchesTarget = hasMultiplicand &&
        hasMultiplier &&
        hasProduct &&
        multiplicand == spell.multiplicand &&
        multiplier == spell.multiplier &&
        productVal == spell.product;
    bool wrong = hasProduct && !energizing && !matchesTarget;

    Color borderColor = wrong
        ? Colors.red
        : (matchesTarget && !energizing
            ? const Color(0xFFFFD700)
            : const Color(0xFFD4A843));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: wrong ? const Color(0xFFFDE0DC) : const Color(0xFFF5E6C8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: borderColor,
            width: matchesTarget && !energizing ? 3 : 2),
        boxShadow: matchesTarget && !energizing
            ? [
                BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2)
              ]
            : [
                BoxShadow(
                    color: Colors.brown.withValues(alpha: 0.15), blurRadius: 6)
              ],
      ),
      child: Column(
        children: [
          Text('Spell Scroll',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.brown.shade400,
                  fontStyle: FontStyle.italic)),
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
                  : Text('Draw your answers to craft...',
                      style: TextStyle(
                          color: Colors.brown.shade300,
                          fontStyle: FontStyle.italic)),
            ),
          ),
          if (castSuccess)
            const Text('✨ Spell Cast! ✨',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD4A843))),
        ],
      ),
    );
  }

  Widget _buildExpression() {
    String mlStr = multiplier != null ? '$multiplier' : '_';
    String mdStr = multiplicand != null ? '$multiplicand' : '_';
    String prStr = productVal != null ? '$productVal' : '_';
    String expr;
    if (entryStep == 0) {
      expr = '_ × _ = _';
    } else if (entryStep == 1) {
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A0A2E),
              letterSpacing: 2)),
    );
  }

  Widget _shakeableBox(int boxIndex, Widget child) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, _) {
        bool shouldShake =
            _shakeController.isAnimating && _shakingBoxes.contains(boxIndex);
        return Transform.translate(
          offset: Offset(
              shouldShake ? sin(_shakeController.value * pi * 4) * 10 : 0, 0),
          child: child,
        );
      },
    );
  }

  Widget _buildCraftingArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: MediaQuery.of(context).size.width - 24,
          child: Row(
            children: [
              Expanded(
                  child: _shakeableBox(
                      1,
                      _buildInputBox(
                        value: multiplier,
                        active: entryStep == 1,
                        locked: entryStep < 1 && multiplier == null,
                        label: 'rows',
                        shaking: _shakingBoxes.contains(1),
                        onTap: entryStep == 1 ? _openDrawInput : null,
                      ))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('×',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A0A2E))),
              ),
              Expanded(
                  child: _shakeableBox(
                      0,
                      _buildInputBox(
                        value: multiplicand,
                        active: entryStep == 0,
                        locked: false,
                        label: 'each row',
                        shaking: _shakingBoxes.contains(0),
                        onTap: entryStep == 0 ? _openDrawInput : null,
                      ))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('=',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A0A2E))),
              ),
              Expanded(
                  child: _shakeableBox(
                      2,
                      _buildInputBox(
                        value: productVal,
                        active: entryStep == 2,
                        locked: entryStep < 2 && productVal == null,
                        label: 'total',
                        shaking: _shakingBoxes.contains(2),
                        onTap: entryStep == 2 ? _openDrawInput : null,
                      ))),
            ],
          ),
        ),
      ),
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
        height: 60,
        decoration: BoxDecoration(
          color: locked ? const Color(0xFFE0D5C0) : const Color(0xFFFAF0DC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: shaking
                ? Colors.red
                : (active
                    ? const Color(0xFFFFD700)
                    : (value != null
                        ? const Color(0xFFD4A843)
                        : const Color(0xFFBBA87A))),
            width: active || shaking ? 3 : 2,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                      blurRadius: 8)
                ]
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
                        fontSize: value != null ? 26 : 20,
                        fontWeight: FontWeight.bold,
                        color: value != null
                            ? const Color(0xFF1A0A2E)
                            : const Color(0xFFD4A843),
                      ),
                    ),
                    if (active)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.draw, color: Color(0xFFD4A843), size: 11),
                          const SizedBox(width: 2),
                          Text(label,
                              style: TextStyle(
                                  fontSize: 9, color: Colors.brown.shade400)),
                        ],
                      ),
                  ],
                ),
        ),
      ),
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
                            color: const Color(0xFFFFD700)
                                .withValues(alpha: _castController.value),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 20),
                    const SizedBox(width: 8),
                    Text(casting ? 'Casting...' : 'Cast Spell',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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
                  : (selected
                      ? const Color(0xFF1A0A2E)
                      : const Color(0xFFF5E6C8)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? const Color(0xFFFFD700)
                    : const Color(0xFFD4A843),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(s.icon,
                    size: 24,
                    color: completed || selected
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1A0A2E)),
                const SizedBox(height: 2),
                Text(s.name,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: completed || selected
                            ? Colors.white
                            : const Color(0xFF1A0A2E))),
                if (completed)
                  const Icon(Icons.check_circle,
                      size: 12, color: Color(0xFFFFD700)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Drawing Input Sheet — bottom sheet with drag disabled
// ─────────────────────────────────────────────────────────────

class DrawingInputSheet extends StatefulWidget {
  final String title;
  final int maxDigits;
  final int maxValue;
  final ValueChanged<int> onSubmit;
  final VoidCallback onFallbackPicker;
  final VoidCallback onCancel;

  const DrawingInputSheet({
    super.key,
    required this.title,
    required this.maxDigits,
    required this.maxValue,
    required this.onSubmit,
    required this.onFallbackPicker,
    required this.onCancel,
  });

  @override
  State<DrawingInputSheet> createState() => _DrawingInputSheetState();
}

class _DrawingInputSheetState extends State<DrawingInputSheet> {
  List<List<Offset>> strokes = [];
  List<Offset> currentStroke = [];
  List<int> digits = []; // accumulated digits for multi-digit numbers
  String get recognizedText =>
      digits.isEmpty ? '' : digits.join();
  bool recognizing = false;
  bool lastRecogFailed = false;
  double canvasWidth = 0;
  double canvasHeight = 0;
  Timer? _recognizeTimer;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      currentStroke = [details.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      currentStroke.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      strokes.add(List.from(currentStroke));
      currentStroke = [];
    });
    _scheduleRecognition();
  }

  void _scheduleRecognition() {
    _recognizeTimer?.cancel();
    _recognizeTimer = Timer(const Duration(milliseconds: 600), _runRecognition);
  }

  Future<void> _runRecognition() async {
    if (strokes.isEmpty) return;
    setState(() {
      recognizing = true;
      lastRecogFailed = false;
    });

    try {
      final result = await recognizeDigit(strokes, canvasWidth, canvasHeight);
      if (!mounted) return;

      if (result.confidence > 0.3) {
        setState(() {
          digits.add(result.digit);
          // Clear canvas for next digit
          strokes.clear();
          recognizing = false;
        });
      } else {
        setState(() {
          lastRecogFailed = true;
          recognizing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        lastRecogFailed = true;
        recognizing = false;
      });
    }
  }

  void _clear() {
    setState(() {
      strokes.clear();
      currentStroke.clear();
      digits.clear();
      lastRecogFailed = false;
    });
  }

  void _backspace() {
    setState(() {
      if (digits.isNotEmpty) {
        digits.removeLast();
      }
      strokes.clear();
      currentStroke.clear();
      lastRecogFailed = false;
    });
  }

  void _submit() {
    final text = recognizedText;
    if (text.isEmpty) return;
    final val = int.tryParse(text);
    if (val != null && val >= 1 && val <= widget.maxValue) {
      widget.onSubmit(val);
    }
  }

  @override
  void dispose() {
    _recognizeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row with close and fallback
          Row(
            children: [
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, size: 20),
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFF1A0A2E),
                ),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
              Expanded(
                child: Text(widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A0A2E))),
              ),
              TextButton.icon(
                onPressed: widget.onFallbackPicker,
                icon: const Icon(Icons.grid_view, size: 16),
                label: const Text('Picker', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1A0A2E),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Drawing canvas
          LayoutBuilder(
            builder: (context, constraints) {
              canvasWidth = constraints.maxWidth;
              canvasHeight = 180;
              return Container(
                height: canvasHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD4A843), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.brown.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: CustomPaint(
                      painter: StrokePainter(
                        strokes: strokes,
                        currentStroke: currentStroke,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Recognition result + actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Clear all
              IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Clear all',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE0D5C0),
                  foregroundColor: const Color(0xFF1A0A2E),
                  minimumSize: const Size(40, 40),
                ),
              ),
              const SizedBox(width: 6),

              // Backspace
              IconButton(
                onPressed: digits.isNotEmpty ? _backspace : null,
                icon: const Icon(Icons.backspace_outlined, size: 20),
                tooltip: 'Delete last digit',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFE0D5C0),
                  foregroundColor: const Color(0xFF1A0A2E),
                  minimumSize: const Size(40, 40),
                ),
              ),
              const SizedBox(width: 8),

              // Recognized number display
              Container(
                constraints: const BoxConstraints(minWidth: 72),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF0DC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: lastRecogFailed
                        ? Colors.red
                        : const Color(0xFFD4A843),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: recognizing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFD4A843)))
                      : Text(
                          recognizedText.isEmpty
                              ? '—'
                              : recognizedText,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: lastRecogFailed
                                ? Colors.red
                                : const Color(0xFF1A0A2E),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),

              // Submit
              ElevatedButton(
                onPressed: recognizedText.isNotEmpty && !recognizing
                    ? _submit
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A0A2E),
                  foregroundColor: const Color(0xFFFFD700),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Submit',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Draw a number • tap Picker for buttons',
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.brown.shade400,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  StrokePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A0A2E)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    if (currentStroke.length >= 2) {
      final path = Path()
        ..moveTo(currentStroke[0].dx, currentStroke[0].dy);
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Subtle guide text when empty
    if (strokes.isEmpty && currentStroke.isEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'Draw here',
          style: TextStyle(
            color: Colors.grey.shade300,
            fontSize: 28,
            fontStyle: FontStyle.italic,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          Offset((size.width - tp.width) / 2,
              (size.height - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(covariant StrokePainter old) => true;
}
