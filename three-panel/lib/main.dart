import 'package:flutter/material.dart';
import 'dart:math';

void main() => runApp(const ThreePanelApp());

class ThreePanelApp extends StatelessWidget {
  const ThreePanelApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Introduction — Count · Shape · Build',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        ),
        home: const IntroScreen(),
      );
}

// Steps: 0=count scattered, 1=drag into row, 2=tap row to copy, 3=enumerate all, 4=pick product, 5=done
enum Step { count, shape, tapRow, enumerate, pickProduct, done }

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with TickerProviderStateMixin {
  final int multiplier = 2;
  final int multiplicand = 3;
  int get total => multiplier * multiplicand;

  Step step = Step.count;

  // Count step
  List<Offset> scatteredPositions = [];
  List<bool> counted = [];
  Map<int, int> countOrder = {};
  int countTaps = 0;

  // Shape step
  List<Offset> dragPositions = [];
  List<bool> snapped = [];
  List<Offset> slotTargets = [];

  // Build step — drag row copy
  bool rowCopied = false;
  bool draggingRow = false;
  double dragRowY = 0; // normalised Y of the dragged ghost row
  List<bool> enumTapped = [];
  Map<int, int> enumOrder = {};
  int enumTaps = 0;

  // Pick product
  List<int> pickerOptions = [];
  int? selectedProduct;
  bool wrongPick = false;

  // Animation
  late AnimationController _flashCtrl;
  late Animation<double> _flash;

  final _rng = Random(42);

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _flash = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut);
    _initRound();
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  void _initRound() {
    // Scattered positions (normalised 0-1)
    scatteredPositions = [];
    for (int i = 0; i < multiplicand; i++) {
      Offset pos;
      bool overlaps;
      int attempts = 0;
      do {
        pos = Offset(0.15 + _rng.nextDouble() * 0.7, 0.2 + _rng.nextDouble() * 0.5);
        overlaps = scatteredPositions.any((p) => (p - pos).distance < 0.18);
        attempts++;
      } while (overlaps && attempts < 80);
      scatteredPositions.add(pos);
    }
    counted = List.filled(multiplicand, false);
    countOrder = {};
    countTaps = 0;

    dragPositions = List.from(scatteredPositions);
    snapped = List.filled(multiplicand, false);
    slotTargets = List.generate(multiplicand, (i) {
      double x = multiplicand == 1 ? 0.5 : 0.2 + i * 0.6 / (multiplicand - 1);
      return Offset(x, 0.45);
    });

    rowCopied = false;
    draggingRow = false;
    dragRowY = 0;
    enumTapped = List.filled(total, false);
    enumOrder = {};
    enumTaps = 0;

    selectedProduct = null;
    wrongPick = false;
    _generatePicker();

    step = Step.count;
  }

  void _generatePicker() {
    Set<int> opts = {total};
    while (opts.length < 4) {
      int d = total + _rng.nextInt(7) - 3;
      if (d > 0 && d != total) opts.add(d);
    }
    pickerOptions = opts.toList()..shuffle(_rng);
  }

  // ──────── Event handlers ────────

  void _onCountTap(int i) {
    if (counted[i] || step != Step.count) return;
    setState(() {
      counted[i] = true;
      countTaps++;
      countOrder[i] = countTaps;
      if (countTaps == multiplicand) {
        _flashCtrl.forward(from: 0);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => step = Step.shape);
        });
      }
    });
  }

  void _onDragUpdate(int i, DragUpdateDetails d, double w, double h) {
    if (snapped[i] || step != Step.shape) return;
    setState(() {
      dragPositions[i] = Offset(
        (dragPositions[i].dx + d.delta.dx / w).clamp(0.05, 0.95),
        (dragPositions[i].dy + d.delta.dy / h).clamp(0.05, 0.95),
      );
    });
  }

  void _onDragEnd(int i) {
    if (snapped[i] || step != Step.shape) return;
    for (int t = 0; t < multiplicand; t++) {
      bool taken = false;
      for (int j = 0; j < multiplicand; j++) {
        if (j != i && snapped[j] && (dragPositions[j] - slotTargets[t]).distance < 0.01) {
          taken = true;
          break;
        }
      }
      if (!taken && (dragPositions[i] - slotTargets[t]).distance < 0.13) {
        setState(() {
          dragPositions[i] = slotTargets[t];
          snapped[i] = true;
          if (snapped.every((s) => s)) {
            _flashCtrl.forward(from: 0);
            Future.delayed(const Duration(milliseconds: 900), () {
              if (mounted) setState(() => step = Step.tapRow);
            });
          }
        });
        return;
      }
    }
  }

  void _onRowDragStart(double h) {
    if (step != Step.tapRow) return;
    setState(() {
      draggingRow = true;
      dragRowY = 0.55; // start at same Y as original row
    });
  }

  void _onRowDragUpdate(DragUpdateDetails d, double h) {
    if (!draggingRow || step != Step.tapRow) return;
    setState(() {
      dragRowY = (dragRowY + d.delta.dy / h).clamp(0.05, 0.7);
    });
  }

  void _onRowDragEnd(double h) {
    if (!draggingRow || step != Step.tapRow) return;
    // Target zone: above the original row
    double orbSize = 48;
    double spacing = 10;
    double row1Y = 0.55;
    double targetY = row1Y - (orbSize + spacing) / h;
    
    if (dragRowY < row1Y - 0.05) {
      // Close enough above — snap into place
      setState(() {
        draggingRow = false;
        rowCopied = true;
        step = Step.enumerate;
      });
    } else {
      // Snap back
      setState(() {
        draggingRow = false;
        dragRowY = 0;
      });
    }
  }

  void _onEnumTap(int i) {
    if (enumTapped[i] || step != Step.enumerate) return;
    setState(() {
      enumTapped[i] = true;
      enumTaps++;
      enumOrder[i] = enumTaps;
      if (enumTaps == total) {
        _flashCtrl.forward(from: 0);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => step = Step.pickProduct);
        });
      }
    });
  }

  void _onPick(int v) {
    if (step != Step.pickProduct) return;
    setState(() {
      selectedProduct = v;
      if (v == total) {
        step = Step.done;
        _flashCtrl.forward(from: 0);
      } else {
        wrongPick = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() { wrongPick = false; selectedProduct = null; });
        });
      }
    });
  }

  // ──────── UI ────────

  String get _instruction {
    switch (step) {
      case Step.count:
        return 'Tap each orb to count them';
      case Step.shape:
        return 'Drag the orbs into the row';
      case Step.tapRow:
        return 'Drag the row upward to copy it';
      case Step.enumerate:
        return 'Tap each orb to count them all';
      case Step.pickProduct:
        return 'How many orbs in total?';
      case Step.done:
        return '✨ $multiplier × $multiplicand = $total';
    }
  }

  String get _stepLabel {
    switch (step) {
      case Step.count:
        return 'COUNT';
      case Step.shape:
        return 'SHAPE';
      case Step.tapRow:
      case Step.enumerate:
      case Step.pickProduct:
        return 'BUILD';
      case Step.done:
        return 'COMPLETE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  // Step indicators
                  _stepDot('COUNT', step.index >= Step.count.index, step == Step.count),
                  _stepLine(step.index >= Step.shape.index),
                  _stepDot('SHAPE', step.index >= Step.shape.index, step == Step.shape),
                  _stepLine(step.index >= Step.tapRow.index),
                  _stepDot('BUILD', step.index >= Step.tapRow.index,
                      step == Step.tapRow || step == Step.enumerate || step == Step.pickProduct),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Expression building
            _expressionBar(),
            const SizedBox(height: 4),
            // Instruction
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _instruction,
                key: ValueKey(step),
                style: const TextStyle(color: Color(0xFFE8D5B0), fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            // Main canvas
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xFF2a2a4e),
                  border: Border.all(color: const Color(0xFFC9A84C).withValues(alpha: 0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LayoutBuilder(builder: _buildCanvas),
                ),
              ),
            ),
            // Picker row
            if (step == Step.pickProduct)
              _pickerRow(),
            // Reset button
            if (step == Step.done)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: () => setState(_initRound),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Try Again', style: TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7BC74D),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _expressionBar() {
    String text;
    if (step == Step.done) {
      text = '$multiplier × $multiplicand = $total';
    } else if (step.index >= Step.tapRow.index) {
      text = rowCopied ? '$multiplier × $multiplicand = ?' : '1 × $multiplicand → ?';
    } else if (step == Step.shape) {
      text = snapped.every((s) => s) ? '1 × $multiplicand' : '? × ?';
    } else {
      text = countTaps == multiplicand ? '$multiplicand' : '?';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        text,
        key: ValueKey(text),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: step == Step.done ? const Color(0xFF7BC74D) : const Color(0xFFC9A84C),
        ),
      ),
    );
  }

  Widget _buildCanvas(BuildContext ctx, BoxConstraints c) {
    double w = c.maxWidth;
    double h = c.maxHeight;
    double orbSize = 48;

    switch (step) {
      case Step.count:
        return Stack(
          children: [
            for (int i = 0; i < multiplicand; i++)
              Positioned(
                left: scatteredPositions[i].dx * w - orbSize / 2,
                top: scatteredPositions[i].dy * h - orbSize / 2,
                child: GestureDetector(
                  onTap: () => _onCountTap(i),
                  child: _orb(
                    size: orbSize,
                    active: !counted[i],
                    done: counted[i],
                    label: counted[i] ? '${countOrder[i]}' : '',
                  ),
                ),
              ),
          ],
        );

      case Step.shape:
        return Stack(
          children: [
            // Slot targets
            for (int i = 0; i < multiplicand; i++)
              Positioned(
                left: slotTargets[i].dx * w - (orbSize + 4) / 2,
                top: slotTargets[i].dy * h - (orbSize + 4) / 2,
                child: Container(
                  width: orbSize + 4,
                  height: orbSize + 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE8D5B0).withValues(alpha: 0.25), width: 2),
                  ),
                ),
              ),
            // Draggable orbs
            for (int i = 0; i < multiplicand; i++)
              Positioned(
                left: dragPositions[i].dx * w - orbSize / 2,
                top: dragPositions[i].dy * h - orbSize / 2,
                child: GestureDetector(
                  onPanUpdate: (d) => _onDragUpdate(i, d, w, h),
                  onPanEnd: (_) => _onDragEnd(i),
                  child: _orb(
                    size: orbSize,
                    active: !snapped[i],
                    done: snapped[i],
                    label: '',
                  ),
                ),
              ),
          ],
        );

      case Step.tapRow:
      case Step.enumerate:
      case Step.pickProduct:
      case Step.done:
        return _buildArrayView(w, h, orbSize);
    }
  }

  Widget _buildArrayView(double w, double h, double orbSize) {
    double spacing = 10;
    double totalRowW = multiplicand * orbSize + (multiplicand - 1) * spacing;
    double startX = (w - totalRowW) / 2;
    double row1Y = h * 0.55;
    double row2Y = row1Y - orbSize - spacing;

    return Stack(
      children: [
        // Target zone indicator (when dragging)
        if (step == Step.tapRow)
          Positioned(
            left: startX - 8,
            top: row2Y - 4,
            child: Container(
              width: totalRowW + 16,
              height: orbSize + 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(orbSize / 2 + 4),
                border: Border.all(
                  color: const Color(0xFFE8D5B0).withValues(alpha: draggingRow ? 0.4 : 0.15),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignCenter,
                ),
              ),
            ),
          ),
        // Bottom row (original — always shown)
        for (int i = 0; i < multiplicand; i++)
          Positioned(
            left: startX + i * (orbSize + spacing),
            top: row1Y,
            child: GestureDetector(
              onVerticalDragStart: step == Step.tapRow ? (_) => _onRowDragStart(h) : null,
              onVerticalDragUpdate: step == Step.tapRow ? (d) => _onRowDragUpdate(d, h) : null,
              onVerticalDragEnd: step == Step.tapRow ? (_) => _onRowDragEnd(h) : null,
              onTap: step == Step.enumerate ? () => _onEnumTap(i) : null,
              child: _orb(
                size: orbSize,
                active: step == Step.tapRow,
                done: step == Step.done || (step == Step.enumerate && enumTapped[i]) || (step == Step.pickProduct && enumTapped[i]),
                label: (enumTapped.length > i && enumTapped[i]) ? '${enumOrder[i]}' : '',
                highlight: step == Step.tapRow && !draggingRow,
              ),
            ),
          ),
        // Ghost row (while dragging)
        if (draggingRow)
          for (int i = 0; i < multiplicand; i++)
            Positioned(
              left: startX + i * (orbSize + spacing),
              top: dragRowY * h - orbSize / 2,
              child: Opacity(
                opacity: 0.7,
                child: _orb(
                  size: orbSize,
                  active: false,
                  done: false,
                  label: '',
                  highlight: true,
                ),
              ),
            ),
        // Top row (after drop — snapped into place)
        if (rowCopied)
          for (int i = 0; i < multiplicand; i++)
            Positioned(
              left: startX + i * (orbSize + spacing),
              top: row2Y,
              child: GestureDetector(
                onTap: step == Step.enumerate
                    ? () => _onEnumTap(multiplicand + i)
                    : null,
                child: _orb(
                  size: orbSize,
                  active: false,
                  done: step == Step.done || (enumTapped.length > multiplicand + i && enumTapped[multiplicand + i]),
                  label: (enumTapped.length > multiplicand + i && enumTapped[multiplicand + i])
                      ? '${enumOrder[multiplicand + i]}'
                      : '',
                ),
              ),
            ),
      ],
    );
  }

  Widget _pickerRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: pickerOptions.map((opt) {
          bool isWrong = wrongPick && selectedProduct == opt;
          bool isRight = step == Step.done && opt == total;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GestureDetector(
              onTap: () => _onPick(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isWrong
                      ? Colors.red.shade700
                      : isRight
                          ? const Color(0xFF7BC74D)
                          : const Color(0xFF2a2a4e),
                  border: Border.all(color: const Color(0xFFE8D5B0), width: 2),
                ),
                child: Center(
                  child: Text('$opt', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _orb({required double size, required bool active, required bool done, required String label, bool highlight = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? const Color(0xFF7BC74D)
            : highlight
                ? const Color(0xFFC9A84C)
                : const Color(0xFF4A6FA5).withValues(alpha: active ? 1.0 : 0.7),
        boxShadow: done || highlight
            ? [BoxShadow(color: (done ? const Color(0xFF7BC74D) : const Color(0xFFC9A84C)).withValues(alpha: 0.5), blurRadius: 12)]
            : [],
      ),
      child: Center(
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
    );
  }

  Widget _stepDot(String label, bool reached, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: reached ? (active ? const Color(0xFFC9A84C) : const Color(0xFF7BC74D)) : const Color(0xFF2a2a4e),
            border: Border.all(color: reached ? Colors.transparent : Colors.white24, width: 1.5),
          ),
          child: reached && !active
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: active ? const Color(0xFFC9A84C) : reached ? const Color(0xFF7BC74D) : Colors.white30,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(bool reached) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
        color: reached ? const Color(0xFF7BC74D) : Colors.white12,
      ),
    );
  }
}
