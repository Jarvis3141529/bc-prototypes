import 'package:flutter/material.dart';
import 'dart:math';

void main() => runApp(const FamilyProgressionApp());

class FamilyProgressionApp extends StatelessWidget {
  const FamilyProgressionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '×2 Family Progression',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF1a1a2e),
        ),
        home: const ProgressionScreen(),
      );
}

// ─────────────────────────────────────────────────────────────
// Top-level phases
// ─────────────────────────────────────────────────────────────
enum GamePhase { towerTome, guidedDoubling, streamlinedBuild, scaffoldedPractice, independentPractice, victory }

// Steps within a guided-doubling round (same as three-panel)
enum GuidedStep { count, shape, tapRow, enumerate, pickProduct, done }

// ─────────────────────────────────────────────────────────────
// Tower Tome frame types
// ─────────────────────────────────────────────────────────────
enum TomeFrameType { narrative, interactive, quickCheck }

class TomeFrame {
  final TomeFrameType type;
  final String title;
  final String body;
  final int? multiplicand;          // for interactive/quickCheck frames
  final List<int>? answerOptions;   // for quickCheck
  TomeFrame({required this.type, required this.title, required this.body,
    this.multiplicand, this.answerOptions});
}

// ─────────────────────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────────────────────
class ProgressionScreen extends StatefulWidget {
  const ProgressionScreen({super.key});
  @override
  State<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends State<ProgressionScreen>
    with TickerProviderStateMixin {
  // ── Overall state ──
  GamePhase phase = GamePhase.towerTome;
  int xp = 0;
  int level = 1;
  final _rng = Random();

  // ── Colours ──
  static const _bg = Color(0xFF1a1a2e);
  static const _gold = Color(0xFFC9A84C);
  static const _parchment = Color(0xFFE8D5B0);
  static const _green = Color(0xFF7BC74D);
  static const _canvas = Color(0xFF2a2a4e);
  static const _orbBlue = Color(0xFF4A6FA5);

  // ═══════════════════════════════════════════════════════════
  // PHASE 1: Tower Tome
  // ═══════════════════════════════════════════════════════════
  late final List<TomeFrame> _tomeFrames;
  int _tomePage = 0;
  int _tomeMaxReached = 0;

  // Interactive frame state
  bool _tomeInterShowDouble = false;
  bool _tomeInterShowProduct = false;

  // Quick check state
  int? _tomeQuickAnswer;
  bool _tomeQuickAnswered = false;
  bool _tomeQuickCorrect = false;
  bool _tomeQuickShowMana = false;

  // ═══════════════════════════════════════════════════════════
  // PHASE 2: Guided Doubling (facts 2×2, 2×3, 2×4, 2×5)
  // ═══════════════════════════════════════════════════════════
  final _guidedMultiplicands = const [2, 3, 4, 5];
  late List<int> _guidedQueue;
  int _guidedQueueIndex = 0;
  int _guidedStreak = 0;
  GuidedStep _guidedStep = GuidedStep.count;

  // Count step
  List<Offset> _scatterPositions = [];
  List<bool> _counted = [];
  Map<int, int> _countOrder = {};
  int _countTaps = 0;

  // Shape step
  List<Offset> _dragPositions = [];
  List<bool> _snapped = [];
  List<Offset> _slotTargets = [];

  // Snap tracking — which slot target each orb snapped to
  Map<int, int> _snapTarget = {};

  // Build/double step
  bool _rowCopied = false;
  bool _draggingRow = false;
  double _dragRowY = 0;

  // Enumerate step
  List<bool> _enumTapped = [];
  Map<int, int> _enumOrder = {};
  int _enumTaps = 0;

  // Pick product
  List<int> _pickerOptions = [];
  int? _selectedProduct;
  bool _wrongPick = false;

  // Animation
  late AnimationController _flashCtrl;

  // ═══════════════════════════════════════════════════════════
  // PHASE 3: Streamlined Build (facts 2×1, 2×6 .. 2×10)
  // ═══════════════════════════════════════════════════════════
  final _streamMultiplicands = const [1, 6, 7, 8, 9, 10];
  late List<int> _streamQueue;
  int _streamQueueIndex = 0;
  int _streamStreak = 0;
  bool _streamBuilt = false;
  bool _streamDragging = false;
  double _streamDragRowY = 0;
  List<int> _streamPickerOptions = [];
  int? _streamSelectedProduct;
  bool _streamWrongPick = false;
  bool _streamDone = false;

  // Optional counting in streamlined build
  List<bool> _streamEnumTapped = [];
  Map<int, int> _streamEnumOrder = {};
  int _streamEnumTaps = 0;

  // ═══════════════════════════════════════════════════════════
  // PHASE 4 & 5: Scaffolded & Independent Practice (all 10 facts)
  // ═══════════════════════════════════════════════════════════
  final _allMultiplicands = const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  // Scaffolded
  late List<int> _scaffQueue;
  int _scaffQueueIndex = 0;
  int _scaffStreak = 0;
  List<int> _scaffPickerOptions = [];
  int? _scaffSelectedProduct;
  bool _scaffWrongPick = false;
  bool _scaffDone = false;
  bool _scaffShowMana = false;

  // Independent
  late List<int> _indepQueue;
  int _indepQueueIndex = 0;
  int _indepStreak = 0;
  List<int> _indepPickerOptions = [];
  int? _indepSelectedProduct;
  bool _indepWrongPick = false;
  bool _indepDone = false;

  int get _scaffMultiplicand => _scaffQueue[_scaffQueueIndex % _scaffQueue.length];
  int get _scaffProduct => 2 * _scaffMultiplicand;
  int get _indepMultiplicand => _indepQueue[_indepQueueIndex % _indepQueue.length];
  int get _indepProduct => 2 * _indepMultiplicand;

  int get _currentMultiplicand => _guidedQueue[_guidedQueueIndex % _guidedQueue.length];
  int get _currentProduct => 2 * _currentMultiplicand;

  int get _streamMultiplicand => _streamQueue[_streamQueueIndex % _streamQueue.length];
  int get _streamProduct => 2 * _streamMultiplicand;

  @override
  void initState() {
    super.initState();
    _flashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _buildTomeFrames();
    _guidedQueue = List.from(_guidedMultiplicands)..shuffle(_rng);
    _streamQueue = List.from(_streamMultiplicands)..shuffle(_rng);
    _scaffQueue = List.from(_allMultiplicands)..shuffle(_rng);
    _indepQueue = List.from(_allMultiplicands)..shuffle(_rng);
    _initGuidedRound();
    _initStreamRound();
    _initScaffRound();
    _initIndepRound();
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    super.dispose();
  }

  void _addXP(int amount) {
    setState(() {
      xp += amount;
      if (xp >= level * 50) level++;
    });
  }

  // ─────────────────────────────────────────────────────────
  // TOME FRAMES DEFINITION
  // ─────────────────────────────────────────────────────────
  void _buildTomeFrames() {
    _tomeFrames = [
      TomeFrame(
        type: TomeFrameType.narrative,
        title: 'The Doubling Spell',
        body: 'Multiplying by 2 means doubling — making two groups of the same size.\n\n'
            'Double your mana. Double your shield. Doubling is the wizard\'s oldest friend.',
      ),
      TomeFrame(
        type: TomeFrameType.interactive,
        title: 'See the Double',
        body: 'Watch what happens when we double 3.',
        multiplicand: 3,
      ),
      TomeFrame(
        type: TomeFrameType.narrative,
        title: 'Two Equal Rows',
        body: '2 × 3 means "two rows of three."\n\n'
            'The top row and the bottom row are the same size. '
            'That\'s what doubling looks like.',
      ),
      TomeFrame(
        type: TomeFrameType.interactive,
        title: 'See the Double',
        body: 'Now let\'s double 5.',
        multiplicand: 5,
      ),
      TomeFrame(
        type: TomeFrameType.interactive,
        title: 'See the Double',
        body: 'And double 2.',
        multiplicand: 2,
      ),
      TomeFrame(
        type: TomeFrameType.quickCheck,
        title: 'Quick Check',
        body: 'What is 2 × 4?',
        multiplicand: 4,
        answerOptions: [6, 8, 10, 12],
      ),
      TomeFrame(
        type: TomeFrameType.quickCheck,
        title: 'Quick Check',
        body: 'What is 2 × 3?',
        multiplicand: 3,
        answerOptions: [5, 6, 7, 9],
      ),
      TomeFrame(
        type: TomeFrameType.narrative,
        title: 'Ready to Practice',
        body: 'You\'ve learned the Doubling Spell!\n\n'
            'Now it\'s time to cast it yourself. '
            'Count the mana, shape it, and double it.',
      ),
    ];
  }

  // ─────────────────────────────────────────────────────────
  // GUIDED ROUND INIT (same mechanics as three-panel)
  // ─────────────────────────────────────────────────────────
  void _initGuidedRound() {
    final n = _currentMultiplicand;
    // Scatter positions (normalised 0..1)
    _scatterPositions = [];
    for (int i = 0; i < n; i++) {
      Offset pos;
      bool overlaps;
      int attempts = 0;
      do {
        pos = Offset(0.15 + _rng.nextDouble() * 0.7, 0.2 + _rng.nextDouble() * 0.5);
        overlaps = _scatterPositions.any((p) => (p - pos).distance < 0.18);
        attempts++;
      } while (overlaps && attempts < 80);
      _scatterPositions.add(pos);
    }
    _counted = List.filled(n, false);
    _countOrder = {};
    _countTaps = 0;

    _dragPositions = List.from(_scatterPositions);
    _snapped = List.filled(n, false);
    _snapTarget = {};
    _slotTargets = [];

    _rowCopied = false;
    _draggingRow = false;
    _dragRowY = 0;

    final total = 2 * n;
    _enumTapped = List.filled(total, false);
    _enumOrder = {};
    _enumTaps = 0;

    _selectedProduct = null;
    _wrongPick = false;
    _generateGuidedPicker();

    _guidedStep = GuidedStep.count;
  }

  void _generateGuidedPicker() {
    final product = _currentProduct;
    Set<int> opts = {product};
    while (opts.length < 4) {
      int d = product + _rng.nextInt(7) - 3;
      if (d > 0 && d != product) opts.add(d);
    }
    _pickerOptions = opts.toList()..shuffle(_rng);
  }

  // ─────────────────────────────────────────────────────────
  // STREAMLINED ROUND INIT
  // ─────────────────────────────────────────────────────────
  void _initStreamRound() {
    final n = _streamMultiplicand;
    _streamBuilt = false;
    _streamDragging = false;
    _streamDragRowY = 0;
    _streamDone = false;
    _streamSelectedProduct = null;
    _streamWrongPick = false;

    final total = 2 * n;
    _streamEnumTapped = List.filled(total, false);
    _streamEnumOrder = {};
    _streamEnumTaps = 0;

    _generateStreamPicker();
  }

  void _generateStreamPicker() {
    final product = _streamProduct;
    Set<int> opts = {product};
    while (opts.length < 4) {
      int d = product + _rng.nextInt(7) - 3;
      if (d > 0 && d != product) opts.add(d);
    }
    _streamPickerOptions = opts.toList()..shuffle(_rng);
  }

  // ─────────────────────────────────────────────────────────
  // GUIDED EVENT HANDLERS (ported from three-panel)
  // ─────────────────────────────────────────────────────────
  void _onCountTap(int i) {
    if (_counted[i] || _guidedStep != GuidedStep.count) return;
    setState(() {
      _counted[i] = true;
      _countTaps++;
      _countOrder[i] = _countTaps;
      if (_countTaps == _currentMultiplicand) {
        _flashCtrl.forward(from: 0);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _guidedStep = GuidedStep.shape);
        });
      }
    });
  }

  // Compute the row layout (pixel coords) — shared between shape & build steps
  // Returns list of center positions for each orb in the bottom row
  List<Offset> _rowCenters(int n, double w, double h, double orbSize) {
    double spacing = 10;
    double totalRowW = n * orbSize + (n - 1) * spacing;
    double startX = (w - totalRowW) / 2 + orbSize / 2;
    double rowY = h * 0.55 + orbSize / 2;
    return List.generate(n, (i) => Offset(startX + i * (orbSize + spacing), rowY));
  }

  // Track whether a meaningful drag occurred
  bool _didDrag = false;

  void _onDragStart(int i) {
    _didDrag = false;
  }

  void _onDragUpdate(int i, DragUpdateDetails d, double w, double h) {
    if (_snapped[i] || _guidedStep != GuidedStep.shape) return;
    _didDrag = true;
    setState(() {
      _dragPositions[i] = Offset(
        (_dragPositions[i].dx + d.delta.dx / w).clamp(0.05, 0.95),
        (_dragPositions[i].dy + d.delta.dy / h).clamp(0.05, 0.95),
      );
    });
  }

  void _onDragEnd(int i, double w, double h) {
    if (_snapped[i] || _guidedStep != GuidedStep.shape) return;
    if (!_didDrag) return; // tap without drag — ignore
    final n = _currentMultiplicand;
    double orbSize = 48;
    final centers = _rowCenters(n, w, h, orbSize);
    // Convert drag position (normalised) to pixels for comparison
    final pixelPos = Offset(_dragPositions[i].dx * w, _dragPositions[i].dy * h);
    
    for (int t = 0; t < n; t++) {
      // Check if this slot is already taken using the snap target map
      bool taken = _snapTarget.values.contains(t);
      double snapDist = orbSize * 1.5;
      if (!taken && (pixelPos - centers[t]).distance < snapDist) {
        setState(() {
          _snapTarget[i] = t;
          _snapped[i] = true;
          if (_snapped.every((s) => s)) {
            _flashCtrl.forward(from: 0);
            Future.delayed(const Duration(milliseconds: 900), () {
              if (mounted) setState(() => _guidedStep = GuidedStep.tapRow);
            });
          }
        });
        return;
      }
    }
  }

  void _onRowDragStart() {
    if (_guidedStep != GuidedStep.tapRow) return;
    setState(() {
      _draggingRow = true;
      _dragRowY = 0.55;
    });
  }

  void _onRowDragUpdate(DragUpdateDetails d, double h) {
    if (!_draggingRow || _guidedStep != GuidedStep.tapRow) return;
    setState(() {
      _dragRowY = (_dragRowY + d.delta.dy / h).clamp(0.05, 0.7);
    });
  }

  void _onRowDragEnd(double h) {
    if (!_draggingRow || _guidedStep != GuidedStep.tapRow) return;
    double row1Y = 0.55;
    if (_dragRowY < row1Y - 0.05) {
      setState(() {
        _draggingRow = false;
        _rowCopied = true;
        _guidedStep = GuidedStep.enumerate;
      });
    } else {
      setState(() {
        _draggingRow = false;
        _dragRowY = 0;
      });
    }
  }

  void _onEnumTap(int i) {
    if (_enumTapped[i] || _guidedStep != GuidedStep.enumerate) return;
    setState(() {
      _enumTapped[i] = true;
      _enumTaps++;
      _enumOrder[i] = _enumTaps;
      if (_enumTaps == _currentProduct) {
        _flashCtrl.forward(from: 0);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _guidedStep = GuidedStep.pickProduct);
        });
      }
    });
  }

  void _onGuidedPick(int v) {
    if (_guidedStep != GuidedStep.pickProduct) return;
    setState(() {
      _selectedProduct = v;
      if (v == _currentProduct) {
        _guidedStep = GuidedStep.done;
        _guidedStreak++;
        _addXP(15);
        _flashCtrl.forward(from: 0);
      } else {
        _guidedStreak = 0;
        _wrongPick = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() { _wrongPick = false; _selectedProduct = null; });
        });
      }
    });
  }

  void _guidedNext() {
    if (_guidedStreak >= 3) {
      setState(() {
        phase = GamePhase.streamlinedBuild;
        _initStreamRound();
      });
      return;
    }
    setState(() {
      _guidedQueueIndex++;
      if (_guidedQueueIndex % _guidedQueue.length == 0) {
        _guidedQueue.shuffle(_rng);
      }
      _initGuidedRound();
    });
  }

  // ─────────────────────────────────────────────────────────
  // STREAMLINED EVENT HANDLERS
  // ─────────────────────────────────────────────────────────
  void _onStreamRowDragStart() {
    if (_streamBuilt) return;
    setState(() {
      _streamDragging = true;
      _streamDragRowY = 0.55;
    });
  }

  void _onStreamRowDragUpdate(DragUpdateDetails d, double h) {
    if (!_streamDragging || _streamBuilt) return;
    setState(() {
      _streamDragRowY = (_streamDragRowY + d.delta.dy / h).clamp(0.05, 0.7);
    });
  }

  void _onStreamRowDragEnd(double h) {
    if (!_streamDragging || _streamBuilt) return;
    double row1Y = 0.55;
    if (_streamDragRowY < row1Y - 0.05) {
      setState(() {
        _streamDragging = false;
        _streamBuilt = true;
      });
    } else {
      setState(() {
        _streamDragging = false;
        _streamDragRowY = 0;
      });
    }
  }

  void _onStreamEnumTap(int i) {
    if (_streamEnumTapped[i] || _streamDone) return;
    setState(() {
      _streamEnumTapped[i] = true;
      _streamEnumTaps++;
      _streamEnumOrder[i] = _streamEnumTaps;
    });
  }

  void _onStreamPick(int v) {
    if (_streamDone) return;
    setState(() {
      _streamSelectedProduct = v;
      if (v == _streamProduct) {
        _streamDone = true;
        _streamStreak++;
        _addXP(10);
        _flashCtrl.forward(from: 0);
      } else {
        _streamStreak = 0;
        _streamWrongPick = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() { _streamWrongPick = false; _streamSelectedProduct = null; });
        });
      }
    });
  }

  void _streamNext() {
    if (_streamStreak >= 3) {
      setState(() {
        phase = GamePhase.scaffoldedPractice;
        _initScaffRound();
      });
      return;
    }
    setState(() {
      _streamQueueIndex++;
      if (_streamQueueIndex % _streamQueue.length == 0) {
        _streamQueue.shuffle(_rng);
      }
      _initStreamRound();
    });
  }

  // ─────────────────────────────────────────────────────────
  // SCAFFOLDED PRACTICE INIT & HANDLERS
  // ─────────────────────────────────────────────────────────
  void _initScaffRound() {
    _scaffDone = false;
    _scaffSelectedProduct = null;
    _scaffWrongPick = false;
    _scaffShowMana = false;
    _generateScaffPicker();
  }

  void _generateScaffPicker() {
    final product = _scaffProduct;
    Set<int> opts = {product};
    while (opts.length < 4) {
      int d = product + _rng.nextInt(7) - 3;
      if (d > 0 && d != product) opts.add(d);
    }
    _scaffPickerOptions = opts.toList()..shuffle(_rng);
  }

  void _onScaffPick(int v) {
    if (_scaffDone) return;
    setState(() {
      _scaffSelectedProduct = v;
      if (v == _scaffProduct) {
        _scaffDone = true;
        _scaffStreak++;
        _addXP(10);
        _flashCtrl.forward(from: 0);
      } else {
        _scaffStreak = 0;
        _scaffWrongPick = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() { _scaffWrongPick = false; _scaffSelectedProduct = null; });
        });
      }
    });
  }

  void _scaffNext() {
    if (_scaffStreak >= 3) {
      setState(() {
        phase = GamePhase.independentPractice;
        _initIndepRound();
      });
      return;
    }
    setState(() {
      _scaffQueueIndex++;
      if (_scaffQueueIndex % _scaffQueue.length == 0) {
        _scaffQueue.shuffle(_rng);
      }
      _initScaffRound();
    });
  }

  // ─────────────────────────────────────────────────────────
  // INDEPENDENT PRACTICE INIT & HANDLERS
  // ─────────────────────────────────────────────────────────
  void _initIndepRound() {
    _indepDone = false;
    _indepSelectedProduct = null;
    _indepWrongPick = false;
    _generateIndepPicker();
  }

  void _generateIndepPicker() {
    final product = _indepProduct;
    Set<int> opts = {product};
    while (opts.length < 4) {
      int d = product + _rng.nextInt(7) - 3;
      if (d > 0 && d != product) opts.add(d);
    }
    _indepPickerOptions = opts.toList()..shuffle(_rng);
  }

  void _onIndepPick(int v) {
    if (_indepDone) return;
    setState(() {
      _indepSelectedProduct = v;
      if (v == _indepProduct) {
        _indepDone = true;
        _indepStreak++;
        _addXP(15);
        _flashCtrl.forward(from: 0);
      } else {
        _indepStreak = 0;
        _indepWrongPick = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() { _indepWrongPick = false; _indepSelectedProduct = null; });
        });
      }
    });
  }

  void _indepNext() {
    if (_indepStreak >= 3) {
      setState(() => phase = GamePhase.victory);
      return;
    }
    setState(() {
      _indepQueueIndex++;
      if (_indepQueueIndex % _indepQueue.length == 0) {
        _indepQueue.shuffle(_rng);
      }
      _initIndepRound();
    });
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildPhaseContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0d0d1a),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_phaseName(),
                style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          const Icon(Icons.star, color: _gold, size: 16),
          const SizedBox(width: 4),
          Text('$xp XP', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(10)),
            child: Text('Lv $level', style: const TextStyle(color: _bg, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _phaseName() {
    switch (phase) {
      case GamePhase.towerTome: return '×2 · Tower Tome';
      case GamePhase.guidedDoubling: return '×2 · Guided Doubling';
      case GamePhase.streamlinedBuild: return '×2 · Build';
      case GamePhase.scaffoldedPractice: return '×2 · Practice';
      case GamePhase.independentPractice: return '×2 · Fluency';
      case GamePhase.victory: return '×2 · Complete!';
    }
  }

  Widget _buildPhaseContent() {
    switch (phase) {
      case GamePhase.towerTome: return _buildTowerTome();
      case GamePhase.guidedDoubling: return _buildGuidedDoubling();
      case GamePhase.streamlinedBuild: return _buildStreamlinedBuild();
      case GamePhase.scaffoldedPractice: return _buildScaffoldedPractice();
      case GamePhase.independentPractice: return _buildIndependentPractice();
      case GamePhase.victory: return _buildVictory();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // PHASE 1: TOWER TOME UI
  // ═══════════════════════════════════════════════════════════
  Widget _buildTowerTome() {
    final frame = _tomeFrames[_tomePage];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Title
          Text(frame.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _gold)),
          const SizedBox(height: 8),
          // Body
          Text(frame.body,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: _parchment, height: 1.4)),
          const SizedBox(height: 16),

          // Frame content
          Expanded(child: _buildTomeFrameContent(frame)),

          const SizedBox(height: 12),

          // Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back
              _tomePage > 0
                  ? IconButton(
                      onPressed: () => setState(() {
                        _tomePage--;
                        _resetTomeInteractive();
                      }),
                      icon: const Icon(Icons.arrow_back_ios, color: _parchment),
                    )
                  : const SizedBox(width: 48),
              // Progress dots
              Row(
                children: List.generate(_tomeFrames.length, (i) => Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _tomePage ? _gold : i <= _tomeMaxReached ? _parchment.withValues(alpha: 0.4) : Colors.white12,
                  ),
                )),
              ),
              // Forward
              _canAdvanceTome()
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          if (_tomePage < _tomeFrames.length - 1) {
                            _tomePage++;
                            if (_tomePage > _tomeMaxReached) _tomeMaxReached = _tomePage;
                            _resetTomeInteractive();
                          } else {
                            // Last page → advance to guided doubling
                            phase = GamePhase.guidedDoubling;
                            _initGuidedRound();
                          }
                        });
                      },
                      icon: Icon(
                        _tomePage == _tomeFrames.length - 1 ? Icons.arrow_forward : Icons.arrow_forward_ios,
                        color: _gold,
                      ),
                    )
                  : const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  bool _canAdvanceTome() {
    final frame = _tomeFrames[_tomePage];
    if (frame.type == TomeFrameType.interactive) {
      return _tomeInterShowProduct;
    }
    if (frame.type == TomeFrameType.quickCheck) {
      return _tomeQuickAnswered;
    }
    return true; // narrative frames always advanceable
  }

  void _resetTomeInteractive() {
    _tomeInterShowDouble = false;
    _tomeInterShowProduct = false;
    _tomeQuickAnswer = null;
    _tomeQuickAnswered = false;
    _tomeQuickCorrect = false;
    _tomeQuickShowMana = false;
  }

  Widget _buildTomeFrameContent(TomeFrame frame) {
    switch (frame.type) {
      case TomeFrameType.narrative:
        return Center(
          child: Icon(
            _tomePage == 0 ? Icons.auto_fix_high
                : _tomePage == _tomeFrames.length - 1 ? Icons.flash_on
                : Icons.auto_awesome,
            size: 64, color: _gold.withValues(alpha: 0.4)),
        );

      case TomeFrameType.interactive:
        return _buildTomeInteractive(frame.multiplicand!);

      case TomeFrameType.quickCheck:
        return _buildTomeQuickCheck(frame);
    }
  }

  Widget _buildTomeInteractive(int n) {
    final product = 2 * n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Array — proper 2-row geometry, labels to the right
          if (_tomeInterShowDouble) ...[
            // Top row (the doubled copy)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...List.generate(n, (_) => _orb(size: 44, done: true)),
                const SizedBox(width: 8),
                Text('$n', style: const TextStyle(fontSize: 14, color: _parchment)),
              ],
            ),
            const SizedBox(height: 6),
          ],
          // Bottom row (always shown)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(n, (_) => _orb(size: 44, done: true)),
              const SizedBox(width: 8),
              Text('$n', style: const TextStyle(fontSize: 14, color: _parchment)),
            ],
          ),

          if (_tomeInterShowDouble) ...[
            const SizedBox(height: 8),
            Text('$n + $n = $product',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _parchment)),
          ],

          if (_tomeInterShowProduct) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('2 × $n = $product',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],

          const SizedBox(height: 16),
          if (!_tomeInterShowDouble)
            _tomeActionButton('Double it', () => setState(() => _tomeInterShowDouble = true))
          else if (!_tomeInterShowProduct)
            _tomeActionButton('Show answer', () {
              setState(() => _tomeInterShowProduct = true);
              _addXP(5);
            }),
        ],
      ),
    );
  }

  Widget _tomeActionButton(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: _bg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTomeQuickCheck(TomeFrame frame) {
    final n = frame.multiplicand!;
    final product = 2 * n;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_tomeQuickAnswered) ...[
          // Show array as feedback
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _canvas,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _tomeQuickCorrect ? _green : Colors.red,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  _tomeQuickCorrect ? '✓ Correct!' : '✗ Not quite',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: _tomeQuickCorrect ? _green : Colors.red,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(n, (_) => _orb(size: 36, done: true)),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(n, (_) => _orb(size: 36, done: true)),
                ),
                const SizedBox(height: 8),
                Text('2 × $n = $product',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _gold)),
              ],
            ),
          ),
        ] else ...[
          // Show Mana hint (optional array reveal)
          if (_tomeQuickShowMana) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _canvas,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(n, (_) => _orb(size: 32, done: true)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(n, (_) => _orb(size: 32, done: true)),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton.icon(
                onPressed: () => setState(() => _tomeQuickShowMana = true),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('Show Mana'),
                style: TextButton.styleFrom(foregroundColor: _gold),
              ),
            ),
          ],
          // Answer buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: frame.answerOptions!.map((opt) => GestureDetector(
              onTap: () {
                setState(() {
                  _tomeQuickAnswer = opt;
                  _tomeQuickAnswered = true;
                  _tomeQuickCorrect = opt == product;
                  if (_tomeQuickCorrect) _addXP(10);
                });
              },
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _canvas,
                  border: Border.all(color: _parchment, width: 2),
                ),
                child: Center(
                  child: Text('$opt', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // PHASE 2: GUIDED DOUBLING UI
  // ═══════════════════════════════════════════════════════════
  Widget _buildGuidedDoubling() {
    final n = _currentMultiplicand;
    final product = _currentProduct;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Step indicators
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _stepDot('COUNT', _guidedStep.index >= GuidedStep.count.index, _guidedStep == GuidedStep.count),
                _stepLine(_guidedStep.index >= GuidedStep.shape.index),
                _stepDot('SHAPE', _guidedStep.index >= GuidedStep.shape.index, _guidedStep == GuidedStep.shape),
                _stepLine(_guidedStep.index >= GuidedStep.tapRow.index),
                _stepDot('BUILD', _guidedStep.index >= GuidedStep.tapRow.index,
                    _guidedStep == GuidedStep.tapRow || _guidedStep == GuidedStep.enumerate || _guidedStep == GuidedStep.pickProduct),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Expression
          _guidedExpressionBar(n, product),
          const SizedBox(height: 4),
          // Instruction
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _guidedInstruction(),
              key: ValueKey(_guidedStep),
              style: const TextStyle(color: _parchment, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          // Streak indicator
          _streakIndicator(_guidedStreak, 3),
          const SizedBox(height: 8),
          // Canvas
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _canvas,
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(builder: _buildGuidedCanvas),
              ),
            ),
          ),
          // Picker
          if (_guidedStep == GuidedStep.pickProduct)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildPickerRow(_pickerOptions, _selectedProduct, _wrongPick, _currentProduct, _guidedStep == GuidedStep.done, _onGuidedPick),
            ),
          // Next button
          if (_guidedStep == GuidedStep.done)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ElevatedButton(
                onPressed: _guidedNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _guidedStreak >= 3 ? 'Continue to Build →' : 'Next Fact',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _guidedExpressionBar(int n, int product) {
    String text;
    if (_guidedStep == GuidedStep.done) {
      text = '2 × $n = $product';
    } else if (_guidedStep.index >= GuidedStep.tapRow.index) {
      text = _rowCopied ? '2 × $n = ?' : '$n → double it!';
    } else if (_guidedStep == GuidedStep.shape) {
      text = _snapped.every((s) => s) ? '$n orbs shaped' : 'Shape the mana';
    } else {
      text = _countTaps == _currentMultiplicand ? '$_countTaps counted!' : 'Count: $_countTaps';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(text, key: ValueKey(text),
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
              color: _guidedStep == GuidedStep.done ? _green : _gold)),
    );
  }

  String _guidedInstruction() {
    switch (_guidedStep) {
      case GuidedStep.count: return 'Tap each orb to count them';
      case GuidedStep.shape: return 'Drag the orbs into the row';
      case GuidedStep.tapRow: return 'Drag the row upward to copy it';
      case GuidedStep.enumerate: return 'Tap each orb to count them all';
      case GuidedStep.pickProduct: return 'How many orbs in total?';
      case GuidedStep.done: return '✨ 2 × $_currentMultiplicand = $_currentProduct';
    }
  }

  Widget _buildGuidedCanvas(BuildContext ctx, BoxConstraints c) {
    double w = c.maxWidth;
    double h = c.maxHeight;
    double orbSize = 48;
    final n = _currentMultiplicand;

    switch (_guidedStep) {
      case GuidedStep.count:
        return Stack(
          children: [
            for (int i = 0; i < n; i++)
              Positioned(
                left: _scatterPositions[i].dx * w - orbSize / 2,
                top: _scatterPositions[i].dy * h - orbSize / 2,
                child: GestureDetector(
                  onTap: () => _onCountTap(i),
                  child: _orb(
                    size: orbSize,
                    active: !_counted[i],
                    done: _counted[i],
                    label: _counted[i] ? '${_countOrder[i]}' : '',
                  ),
                ),
              ),
          ],
        );

      case GuidedStep.shape:
        final centers = _rowCenters(n, w, h, orbSize);
        // orbMargin must match the margin in _orb()
        const double orbMargin = 2;
        final double totalOrbSize = orbSize + orbMargin * 2;
        return Stack(
          children: [
            // Slot targets — same position as build-step bottom row
            for (int i = 0; i < n; i++)
              Positioned(
                left: centers[i].dx - totalOrbSize / 2 - 2,
                top: centers[i].dy - totalOrbSize / 2 - 2,
                child: Container(
                  width: totalOrbSize + 4, height: totalOrbSize + 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _parchment.withValues(alpha: 0.25), width: 2),
                  ),
                ),
              ),
            // Draggable orbs — use pixel coords directly for snapped orbs
            for (int i = 0; i < n; i++)
              Positioned(
                left: _snapped[i]
                    ? centers[_snapTarget[i]!].dx - totalOrbSize / 2
                    : _dragPositions[i].dx * w - totalOrbSize / 2,
                top: _snapped[i]
                    ? centers[_snapTarget[i]!].dy - totalOrbSize / 2
                    : _dragPositions[i].dy * h - totalOrbSize / 2,
                child: GestureDetector(
                  onPanStart: (_) => _onDragStart(i),
                  onPanUpdate: (d) => _onDragUpdate(i, d, w, h),
                  onPanEnd: (_) => _onDragEnd(i, w, h),
                  child: _orb(
                    size: orbSize,
                    active: !_snapped[i],
                    done: _snapped[i],
                    label: '',
                  ),
                ),
              ),
          ],
        );

      case GuidedStep.tapRow:
      case GuidedStep.enumerate:
      case GuidedStep.pickProduct:
      case GuidedStep.done:
        return _buildArrayView(w, h, orbSize, n);
    }
  }

  Widget _buildArrayView(double w, double h, double orbSize, int n) {
    double spacing = 10;
    double totalRowW = n * orbSize + (n - 1) * spacing;
    double startX = (w - totalRowW) / 2;
    double row1Y = h * 0.55;
    double row2Y = row1Y - orbSize - spacing;
    final total = 2 * n;

    return Stack(
      children: [
        // Target zone
        if (_guidedStep == GuidedStep.tapRow)
          Positioned(
            left: startX - 8,
            top: row2Y - 4,
            child: Container(
              width: totalRowW + 16, height: orbSize + 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(orbSize / 2 + 4),
                border: Border.all(
                  color: _parchment.withValues(alpha: _draggingRow ? 0.4 : 0.15),
                  width: 2,
                ),
              ),
            ),
          ),
        // Bottom row
        for (int i = 0; i < n; i++)
          Positioned(
            left: startX + i * (orbSize + spacing),
            top: row1Y,
            child: GestureDetector(
              onVerticalDragStart: _guidedStep == GuidedStep.tapRow ? (_) => _onRowDragStart() : null,
              onVerticalDragUpdate: _guidedStep == GuidedStep.tapRow ? (d) => _onRowDragUpdate(d, h) : null,
              onVerticalDragEnd: _guidedStep == GuidedStep.tapRow ? (_) => _onRowDragEnd(h) : null,
              onTap: _guidedStep == GuidedStep.enumerate ? () => _onEnumTap(i) : null,
              child: _orb(
                size: orbSize,
                active: _guidedStep == GuidedStep.tapRow,
                done: _guidedStep == GuidedStep.done || (_enumTapped.length > i && _enumTapped[i]),
                label: (_enumTapped.length > i && _enumTapped[i]) ? '${_enumOrder[i]}' : '',
                highlight: _guidedStep == GuidedStep.tapRow && !_draggingRow,
              ),
            ),
          ),
        // Ghost row (during drag)
        if (_draggingRow)
          for (int i = 0; i < n; i++)
            Positioned(
              left: startX + i * (orbSize + spacing),
              top: _dragRowY * h - orbSize / 2,
              child: Opacity(
                opacity: 0.7,
                child: _orb(size: orbSize, highlight: true),
              ),
            ),
        // Top row (after copy)
        if (_rowCopied)
          for (int i = 0; i < n; i++)
            Positioned(
              left: startX + i * (orbSize + spacing),
              top: row2Y,
              child: GestureDetector(
                onTap: _guidedStep == GuidedStep.enumerate ? () => _onEnumTap(n + i) : null,
                child: _orb(
                  size: orbSize,
                  done: _guidedStep == GuidedStep.done || (_enumTapped.length > n + i && _enumTapped[n + i]),
                  label: (_enumTapped.length > n + i && _enumTapped[n + i]) ? '${_enumOrder[n + i]}' : '',
                ),
              ),
            ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // PHASE 3: STREAMLINED BUILD UI
  // ═══════════════════════════════════════════════════════════
  Widget _buildStreamlinedBuild() {
    final n = _streamMultiplicand;
    final product = _streamProduct;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Expression
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _streamDone ? '2 × $n = $product' : _streamBuilt ? '2 × $n = ?' : 'Build 2 × $n',
              key: ValueKey('$_streamBuilt$_streamDone$n'),
              style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold,
                color: _streamDone ? _green : _gold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _streamDone ? '✨ Well done!'
                : _streamBuilt ? 'How many orbs in total?' : 'Drag the row upward to double it',
            style: const TextStyle(color: _parchment, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _streakIndicator(_streamStreak, 3),
          const SizedBox(height: 12),

          // Canvas
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: _canvas,
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
              child: LayoutBuilder(builder: (ctx, c) {
                double w = c.maxWidth;
                double h = c.maxHeight;
                double orbSize = n <= 5 ? 44 : n <= 7 ? 38 : 32;
                double spacing = 8;
                double totalRowW = n * orbSize + (n - 1) * spacing;
                double startX = (w - totalRowW) / 2;
                double row1Y = h * 0.55;
                double row2Y = row1Y - orbSize - spacing;
                final total = 2 * n;

                return Stack(
                  children: [
                    // Single outline shape for target row
                    if (!_streamBuilt)
                      Positioned(
                        left: startX - 6,
                        top: row2Y - 4,
                        child: Container(
                          width: totalRowW + 12,
                          height: orbSize + 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(orbSize / 2 + 4),
                            border: Border.all(
                              color: _parchment.withValues(alpha: _streamDragging ? 0.4 : 0.2),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    // Bottom row (original) — draggable when not yet built
                    for (int i = 0; i < n; i++)
                      Positioned(
                        left: startX + i * (orbSize + spacing),
                        top: row1Y,
                        child: GestureDetector(
                          onVerticalDragStart: !_streamBuilt ? (_) => _onStreamRowDragStart() : null,
                          onVerticalDragUpdate: !_streamBuilt ? (d) => _onStreamRowDragUpdate(d, h) : null,
                          onVerticalDragEnd: !_streamBuilt ? (_) => _onStreamRowDragEnd(h) : null,
                          onTap: (_streamBuilt && !_streamDone) ? () => _onStreamEnumTap(i) : null,
                          child: _orb(
                            size: orbSize,
                            active: !_streamBuilt,
                            done: _streamDone || _streamEnumTapped[i],
                            label: _streamEnumTapped[i] ? '${_streamEnumOrder[i]}' : '',
                            highlight: !_streamBuilt && !_streamDragging,
                          ),
                        ),
                      ),
                    // Ghost row (during drag)
                    if (_streamDragging)
                      for (int i = 0; i < n; i++)
                        Positioned(
                          left: startX + i * (orbSize + spacing),
                          top: _streamDragRowY * h - orbSize / 2,
                          child: Opacity(
                            opacity: 0.7,
                            child: _orb(size: orbSize, highlight: true),
                          ),
                        ),
                    // Doubled row (after build — snapped into position)
                    if (_streamBuilt)
                      for (int i = 0; i < n; i++)
                        Positioned(
                          left: startX + i * (orbSize + spacing),
                          top: row2Y,
                          child: GestureDetector(
                            onTap: (!_streamDone) ? () => _onStreamEnumTap(n + i) : null,
                            child: _orb(
                              size: orbSize,
                              done: _streamDone || (_streamEnumTapped.length > n + i && _streamEnumTapped[n + i]),
                              label: (_streamEnumTapped.length > n + i && _streamEnumTapped[n + i])
                                  ? '${_streamEnumOrder[n + i]}' : '',
                            ),
                          ),
                        ),
                  ],
                );
              }),
            ),
          ),

          // Picker
          if (_streamBuilt && !_streamDone)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildPickerRow(_streamPickerOptions, _streamSelectedProduct, _streamWrongPick, _streamProduct, _streamDone, _onStreamPick),
            ),
          // Next button
          if (_streamDone)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ElevatedButton(
                onPressed: _streamNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _streamStreak >= 3 ? 'Complete! →' : 'Next Fact',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // PHASE 4: SCAFFOLDED PRACTICE UI
  // ═══════════════════════════════════════════════════════════
  Widget _buildScaffoldedPractice() {
    final n = _scaffMultiplicand;
    final product = _scaffProduct;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Question
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _scaffDone ? '2 × $n = $product' : '2 × $n = ?',
              key: ValueKey('scaff$n$_scaffDone'),
              style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold,
                color: _scaffDone ? _green : _gold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _scaffDone ? '✓ Correct!' : 'Choose the answer',
            style: TextStyle(color: _scaffDone ? _green : _parchment, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _streakIndicator(_scaffStreak, 3),

          // Show Mana hint area
          Expanded(
            child: Center(
              child: _scaffShowMana
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _canvas,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _gold.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(n, (_) => _orb(size: n <= 5 ? 40 : n <= 7 ? 34 : 28, done: true)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(n, (_) => _orb(size: n <= 5 ? 40 : n <= 7 ? 34 : 28, done: true)),
                          ),
                        ],
                      ),
                    )
                  : _scaffDone
                      ? const Icon(Icons.check_circle, size: 64, color: _green)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.psychology, size: 64, color: _gold),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () => setState(() => _scaffShowMana = true),
                              icon: const Icon(Icons.visibility, size: 18),
                              label: const Text('Show Mana'),
                              style: TextButton.styleFrom(foregroundColor: _gold),
                            ),
                          ],
                        ),
            ),
          ),

          // Picker
          if (!_scaffDone)
            _buildPickerRow(_scaffPickerOptions, _scaffSelectedProduct, _scaffWrongPick, _scaffProduct, _scaffDone, _onScaffPick),
          if (_scaffDone)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ElevatedButton(
                onPressed: _scaffNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _scaffStreak >= 3 ? 'Fluency Challenge →' : 'Next',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // PHASE 5: INDEPENDENT PRACTICE UI
  // ═══════════════════════════════════════════════════════════
  Widget _buildIndependentPractice() {
    final n = _indepMultiplicand;
    final product = _indepProduct;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Question
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _indepDone ? '2 × $n = $product' : '2 × $n = ?',
              key: ValueKey('indep$n$_indepDone'),
              style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold,
                color: _indepDone ? _green : _gold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _indepDone ? '✓ Correct!' : 'No hints — you\'ve got this!',
            style: TextStyle(
              color: _indepDone ? _green : _parchment,
              fontSize: 15,
              fontStyle: _indepDone ? FontStyle.normal : FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          _streakIndicator(_indepStreak, 3),

          // Feedback area
          Expanded(
            child: Center(
              child: _indepDone
                  ? const Icon(Icons.check_circle, size: 64, color: _green)
                  : const Icon(Icons.bolt, size: 64, color: _gold),
            ),
          ),

          // Wrong answer remediation — show array briefly
          if (_indepDone && _indepSelectedProduct == _indepProduct) ...[
            // correct — nothing extra
          ],

          // Picker
          if (!_indepDone)
            _buildPickerRow(_indepPickerOptions, _indepSelectedProduct, _indepWrongPick, _indepProduct, _indepDone, _onIndepPick),
          if (_indepDone)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ElevatedButton(
                onPressed: _indepNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _indepStreak >= 3 ? 'Complete! ✨' : 'Next',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // VICTORY
  // ═══════════════════════════════════════════════════════════
  Widget _buildVictory() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 80, color: _gold),
          const SizedBox(height: 16),
          const Text('×2 Family Mastered!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _gold)),
          const SizedBox(height: 8),
          Text('You earned $xp XP',
              style: const TextStyle(fontSize: 18, color: _parchment)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                phase = GamePhase.towerTome;
                _tomePage = 0;
                _tomeMaxReached = 0;
                xp = 0;
                level = 1;
                _guidedStreak = 0;
                _streamStreak = 0;
                _scaffStreak = 0;
                _indepStreak = 0;
                _guidedQueueIndex = 0;
                _streamQueueIndex = 0;
                _scaffQueueIndex = 0;
                _indepQueueIndex = 0;
                _guidedQueue.shuffle(_rng);
                _streamQueue.shuffle(_rng);
                _scaffQueue.shuffle(_rng);
                _indepQueue.shuffle(_rng);
                _resetTomeInteractive();
                _initGuidedRound();
                _initStreamRound();
                _initScaffRound();
                _initIndepRound();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _bg,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Play Again', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════

  Widget _orb({required double size, bool active = false, bool done = false, String label = '', bool highlight = false}) {
    return Container(
      width: size, height: size,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? _green
            : highlight ? _gold
            : _orbBlue.withValues(alpha: active ? 1.0 : 0.7),
        boxShadow: done || highlight
            ? [BoxShadow(color: (done ? _green : _gold).withValues(alpha: 0.5), blurRadius: 12)]
            : [],
      ),
      child: Center(
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  }

  Widget _buildPickerRow(List<int> options, int? selected, bool wrongPick, int correct, bool isDone, void Function(int) onPick) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: options.map((opt) {
        bool isWrong = wrongPick && selected == opt;
        bool isRight = isDone && opt == correct;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            onTap: () => onPick(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 60, height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isWrong ? Colors.red.shade700 : isRight ? _green : _canvas,
                border: Border.all(color: _parchment, width: 2),
              ),
              child: Center(
                child: Text('$opt', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _streakIndicator(int streak, int target) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Streak: ', style: TextStyle(color: _parchment.withValues(alpha: 0.7), fontSize: 13)),
        ...List.generate(target, (i) => Container(
          width: 12, height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < streak ? _green : Colors.white12,
            border: Border.all(color: i < streak ? _green : _parchment.withValues(alpha: 0.3), width: 1.5),
          ),
        )),
      ],
    );
  }

  Widget _stepDot(String label, bool reached, bool active) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: reached ? (active ? _gold : _green) : _canvas,
            border: Border.all(color: reached ? Colors.transparent : Colors.white24, width: 1.5),
          ),
          child: reached && !active ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
        ),
        const SizedBox(height: 4),
        Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5,
              color: active ? _gold : reached ? _green : Colors.white30)),
      ],
    );
  }

  Widget _stepLine(bool reached) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
        color: reached ? _green : Colors.white12,
      ),
    );
  }
}
