import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const FactorFinderApp());

// ── Theme colors ──
const kBgColor = Color(0xFF1A0533);
const kGold = Color(0xFFFFD700);
const kParchment = Color(0xFFF5E6C8);
const kCyan = Color(0xFF00E5FF);
const kGreenGlow = Color(0xFF00FF88);
const kRedGlow = Color(0xFFFF4444);

// ── Target numbers ──
const kTargets = [12, 18, 24, 15, 20];

class FactorFinderApp extends StatelessWidget {
  const FactorFinderApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Factor Finder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: kBgColor),
      home: const FactorFinderScreen(),
    );
  }
}

// ── Helpers ──
Set<int> _factors(int n) {
  final f = <int>{};
  for (var i = 1; i <= n; i++) {
    if (n % i == 0) f.add(i);
  }
  return f;
}

List<(int, int)> _factorPairs(int n) {
  final pairs = <(int, int)>[];
  for (var i = 1; i * i <= n; i++) {
    if (n % i == 0) pairs.add((i, n ~/ i));
  }
  return pairs;
}

class FactorFinderScreen extends StatefulWidget {
  const FactorFinderScreen({super.key});
  @override
  State<FactorFinderScreen> createState() => _FactorFinderScreenState();
}

class _FactorFinderScreenState extends State<FactorFinderScreen>
    with TickerProviderStateMixin {
  final _rng = Random();
  int _targetIdx = 0;
  int get _target => kTargets[_targetIdx];

  List<Offset> _scatterPositions = [];
  List<Offset> _gridPositions = [];

  late AnimationController _dotAnim;
  late AnimationController _shakeAnim;
  late AnimationController _sparkleAnim;
  late AnimationController _celebrationAnim;

  Set<int> _foundFactors = {};
  int? _activeCast;
  bool _isFactor = false;
  bool _showResult = false;
  bool _isShaking = false;
  bool _celebrating = false;
  bool _holdingResult = false; // waiting for user to dismiss
  bool _allFound = false;
  String _resultText = '';
  Color _resultColor = kGreenGlow;

  List<_Sparkle> _sparkles = [];
  List<_CelebParticle> _celebParticles = [];

  @override
  void initState() {
    super.initState();
    _dotAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shakeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _sparkleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _celebrationAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _dotAnim.addListener(() => setState(() {}));
    _shakeAnim.addListener(() => setState(() {}));
    _sparkleAnim.addListener(() => setState(() {}));
    _celebrationAnim.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) => _initLevel());
  }

  @override
  void dispose() {
    _dotAnim.dispose();
    _shakeAnim.dispose();
    _sparkleAnim.dispose();
    _celebrationAnim.dispose();
    super.dispose();
  }

  void _initLevel() {
    _foundFactors = {};
    _activeCast = null;
    _showResult = false;
    _isShaking = false;
    _celebrating = false;
    _holdingResult = false;
    _allFound = false;
    _generateScatter();
    setState(() {});
  }

  Rect get _dotArea {
    final sz = MediaQuery.of(context).size;
    return Rect.fromLTWH(24, 120, sz.width - 48, sz.height - 310);
  }

  void _generateScatter() {
    final area = _dotArea;
    _scatterPositions = List.generate(_target, (_) {
      return Offset(
        area.left + _rng.nextDouble() * (area.width - 48),
        area.top + _rng.nextDouble() * (area.height - 48),
      );
    });
    // Spread apart
    for (int pass = 0; pass < 30; pass++) {
      for (int i = 0; i < _scatterPositions.length; i++) {
        for (int j = i + 1; j < _scatterPositions.length; j++) {
          final diff = _scatterPositions[i] - _scatterPositions[j];
          final dist = diff.distance;
          if (dist < 52) {
            final push = dist < 1
                ? Offset(_rng.nextDouble() * 10 - 5, _rng.nextDouble() * 10 - 5)
                : diff / dist * 3;
            _scatterPositions[i] = Offset(
              (_scatterPositions[i].dx + push.dx).clamp(area.left, area.right - 48),
              (_scatterPositions[i].dy + push.dy).clamp(area.top, area.bottom - 48),
            );
            _scatterPositions[j] = Offset(
              (_scatterPositions[j].dx - push.dx).clamp(area.left, area.right - 48),
              (_scatterPositions[j].dy - push.dy).clamp(area.top, area.bottom - 48),
            );
          }
        }
      }
    }
    _gridPositions = List.from(_scatterPositions);
  }

  /// Calculate grid positions that fit within the dot area.
  List<Offset> _computeGridPositions(int rows, int cols, int total) {
    final area = _dotArea;
    const minDot = 28.0;
    const maxDot = 44.0;

    // Calculate spacing to fit within area
    final spacingW = (area.width - 20) / cols;
    final spacingH = (area.height - 20) / rows;
    final spacing = min(spacingW, spacingH).clamp(minDot + 4, maxDot + 8);

    final gridW = (cols - 1) * spacing;
    final gridH = (rows - 1) * spacing;
    final ox = area.left + (area.width - gridW) / 2;
    final oy = area.top + (area.height - gridH) / 2;

    return List.generate(total, (i) {
      final r = i ~/ cols;
      final c = i % cols;
      return Offset(ox + c * spacing, oy + r * spacing);
    });
  }

  void _castSpell(int spell) {
    if (_dotAnim.isAnimating || _isShaking || _celebrating || _holdingResult) return;
    if (_foundFactors.contains(spell)) return;

    _activeCast = spell;
    _isFactor = _target % spell == 0;

    if (_isFactor) {
      final cols = _target ~/ spell;
      _gridPositions = _computeGridPositions(spell, cols, _target);
      _resultText = '$spell × $cols = $_target ✓';
      _resultColor = kGreenGlow;
    } else {
      final cols = _target ~/ spell;
      final remainder = _target % spell;
      final fullCount = spell * cols;

      // Grid for full rows + extra row for remainders
      final allPositions = _computeGridPositions(spell + 1, max(cols, remainder), _target);
      // Recompute: place full grid first, then remainders
      final area = _dotArea;
      const minDot = 28.0;
      const maxDot = 44.0;
      final effCols = max(cols, remainder);
      final spacingW = (area.width - 20) / effCols;
      final spacingH = (area.height - 20) / (spell + 1);
      final spacing = min(spacingW, spacingH).clamp(minDot + 4, maxDot + 8);

      final gridW = (effCols - 1) * spacing;
      final gridH = spell * spacing; // full rows only for centering
      final ox = area.left + (area.width - gridW) / 2;
      final oy = area.top + (area.height - gridH - spacing) / 2;

      _gridPositions = List.generate(_target, (i) {
        if (i < fullCount) {
          final r = i ~/ cols;
          final c = i % cols;
          return Offset(ox + c * spacing, oy + r * spacing);
        } else {
          // Remainders: scatter loosely below the grid, offset and tilted
          // so they clearly don't form a row
          final c = i - fullCount;
          final jitter = (c.isEven ? 8.0 : -6.0) + c * 3.0;
          final yJitter = c.isOdd ? -10.0 : 8.0;
          final xStart = ox + (area.width - gridW) * 0.15; // offset left
          return Offset(
            xStart + c * (spacing * 1.3) + jitter,
            oy + spell * spacing + spacing * 0.3 + yJitter,
          );
        }
      });

      _resultText = '$spell × $cols = ${spell * cols}... $remainder left over!';
      _resultColor = kRedGlow;
    }

    _showResult = true;
    _dotAnim.forward(from: 0).then((_) {
      if (_isFactor) {
        _onFactorFound(spell);
      } else {
        _onNotFactor();
      }
    });

    setState(() {});
  }

  void _onFactorFound(int spell) {
    // Only mark THIS spell as found — complement must be discovered separately
    _foundFactors.add(spell);

    _sparkles = List.generate(20, (_) => _Sparkle(_rng));
    _sparkleAnim.forward(from: 0);

    // Hold the result — user decides when to continue
    _holdingResult = true;
    setState(() {});
  }

  void _dismissResult() {
    if (!_holdingResult) return;
    _holdingResult = false;

    // Check if all factors are found
    final allFactors = _factors(_target);
    if (_foundFactors.containsAll(allFactors)) {
      _allFound = true;
      setState(() {});
      return; // Show "Next" button, don't auto-advance
    }

    // Scatter back for next cast
    _generateScatter();
    _gridPositions = List.from(_scatterPositions);
    _dotAnim.value = 0;
    _showResult = false;
    _activeCast = null;
    setState(() {});
  }

  void _advanceToNext() {
    _celebrating = true;
    _celebParticles = List.generate(60, (_) => _CelebParticle(_rng));
    _celebrationAnim.forward(from: 0).then((_) {
      if (!mounted) return;
      _targetIdx = (_targetIdx + 1) % kTargets.length;
      _initLevel();
    });
    setState(() {});
  }

  void _onNotFactor() {
    _isShaking = true;
    _shakeAnim.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        _isShaking = false;
        _generateScatter();
        _gridPositions = List.from(_scatterPositions);
        _dotAnim.value = 0;
        _showResult = false;
        _activeCast = null;
        setState(() {});
      });
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.2,
                colors: [Color(0xFF2A1050), kBgColor],
              ),
            ),
          ),

          // Title
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  '✦ Factor Finder ✦',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: kGold,
                    shadows: [Shadow(color: kGold.withAlpha(100), blurRadius: 20)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_target Mana Orbs',
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 20,
                    color: kCyan,
                    shadows: [Shadow(color: kCyan.withAlpha(120), blurRadius: 16)],
                  ),
                ),
              ],
            ),
          ),

          // Dots
          ..._buildDots(),

          // Sparkles
          if (_sparkleAnim.isAnimating) ..._buildSparkles(),

          // Result text
          if (_showResult)
            Positioned(
              top: 90,
              left: 0,
              right: 0,
              child: Text(
                _resultText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _resultColor,
                  shadows: [Shadow(color: _resultColor.withAlpha(150), blurRadius: 12)],
                ),
              ),
            ),

          // "Tap to continue" when holding a factor result
          if (_holdingResult)
            Positioned(
              top: _dotArea.bottom + 8,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: _dismissResult,
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Tap anywhere to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: kParchment.withAlpha(180),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),

          // Full-screen tap target when holding result
          if (_holdingResult)
            Positioned.fill(
              child: GestureDetector(
                onTap: _dismissResult,
                behavior: HitTestBehavior.translucent,
              ),
            ),

          // "All Found!" + Next button
          if (_allFound && !_celebrating)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '✨ All Factors Found! ✨',
                    style: GoogleFonts.cinzelDecorative(
                      fontSize: 28,
                      color: kGold,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: kGold, blurRadius: 24)],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _advanceToNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGold.withAlpha(40),
                      foregroundColor: kGold,
                      side: const BorderSide(color: kGold, width: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('Next Number →', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Progress
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: _buildProgress(),
          ),

          // Spell buttons
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: _buildSpellButtons(),
          ),

          // Celebration
          if (_celebrating) ..._buildCelebration(),
        ],
      ),
    );
  }

  List<Widget> _buildDots() {
    final t = _dotAnim.value;
    final shake = _isShaking ? sin(_shakeAnim.value * pi * 6) * 6 : 0.0;

    // Calculate dot display size based on grid spacing
    final area = _dotArea;
    double dotSize = 44.0;
    if (_activeCast != null && _isFactor) {
      final rows = _activeCast!;
      final cols = _target ~/ _activeCast!;
      final spacingW = (area.width - 20) / cols;
      final spacingH = (area.height - 20) / rows;
      final spacing = min(spacingW, spacingH).clamp(32.0, 52.0);
      dotSize = (spacing - 6).clamp(24.0, 44.0);
      // Lerp size during animation
      dotSize = 44.0 + (dotSize - 44.0) * Curves.easeInOut.transform(t);
    } else if (_activeCast != null && !_isFactor) {
      final rows = _activeCast!;
      final cols = _target ~/ _activeCast!;
      final effCols = max(cols, _target % _activeCast!);
      final spacingW = (area.width - 20) / effCols;
      final spacingH = (area.height - 20) / (rows + 1);
      final spacing = min(spacingW, spacingH).clamp(32.0, 52.0);
      dotSize = (spacing - 6).clamp(24.0, 44.0);
      dotSize = 44.0 + (dotSize - 44.0) * Curves.easeInOut.transform(t);
    }

    return List.generate(_target, (i) {
      final from = i < _scatterPositions.length ? _scatterPositions[i] : Offset.zero;
      final to = i < _gridPositions.length ? _gridPositions[i] : Offset.zero;
      final pos = Offset.lerp(from, to, Curves.easeInOutCubic.transform(t))!;

      final isRemainder = _activeCast != null &&
          !_isFactor &&
          i >= (_activeCast! * (_target ~/ _activeCast!));

      return Positioned(
        left: pos.dx + shake - (dotSize - 44) / 2,
        top: pos.dy - (dotSize - 44) / 2,
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRemainder && t > 0.5 ? kRedGlow.withAlpha(180) : kCyan.withAlpha(200),
            boxShadow: [
              BoxShadow(
                color: (isRemainder && t > 0.5 ? kRedGlow : kCyan).withAlpha(120),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: dotSize * 0.36,
              height: dotSize * 0.36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(180),
              ),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildSparkles() {
    final t = _sparkleAnim.value;
    final area = _dotArea;
    final cx = area.center.dx;
    final cy = area.center.dy;

    return _sparkles.map((s) {
      final x = cx + s.dx * t * 120;
      final y = cy + s.dy * t * 120;
      final opacity = (1 - t).clamp(0.0, 1.0);
      return Positioned(
        left: x,
        top: y,
        child: Opacity(
          opacity: opacity,
          child: Text(
            '✦',
            style: TextStyle(
              fontSize: 14 + s.size * 10,
              color: kGold,
              shadows: [Shadow(color: kGold, blurRadius: 8)],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildProgress() {
    final allFactors = _factors(_target);
    final total = allFactors.length;
    final found = _foundFactors.length;

    if (found == 0) {
      return Text(
        'Cast spells to find factors!',
        textAlign: TextAlign.center,
        style: TextStyle(color: kParchment.withAlpha(150), fontSize: 14),
      );
    }

    final pairs = _factorPairs(_target);
    final foundPairTexts = <String>[];
    for (final p in pairs) {
      if (_foundFactors.contains(p.$1) && _foundFactors.contains(p.$2)) {
        foundPairTexts.add('${p.$1}×${p.$2}');
      } else if (_foundFactors.contains(p.$1)) {
        foundPairTexts.add('${p.$1}×?');
      } else if (_foundFactors.contains(p.$2)) {
        foundPairTexts.add('?×${p.$2}');
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Factors: $found / $total found',
          textAlign: TextAlign.center,
          style: const TextStyle(color: kGold, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (foundPairTexts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              foundPairTexts.join('  '),
              textAlign: TextAlign.center,
              style: TextStyle(color: kParchment.withAlpha(180), fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _buildSpellButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(_target, (i) {
          final spell = i + 1;
          final isFound = _foundFactors.contains(spell);
          final isActive = _activeCast == spell;

          Color bgColor;
          Color borderColor;
          if (isActive && _isFactor) {
            bgColor = kGreenGlow.withAlpha(60);
            borderColor = kGreenGlow;
          } else if (isActive && !_isFactor) {
            bgColor = kRedGlow.withAlpha(60);
            borderColor = kRedGlow;
          } else if (isFound) {
            bgColor = kGreenGlow.withAlpha(40);
            borderColor = kGreenGlow.withAlpha(120);
          } else {
            bgColor = kBgColor.withAlpha(180);
            borderColor = kGold.withAlpha(120);
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => _castSpell(spell),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 2),
                  boxShadow: isActive
                      ? [BoxShadow(color: borderColor.withAlpha(120), blurRadius: 16)]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${spell}×',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isFound ? kGreenGlow : kParchment,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildCelebration() {
    final t = _celebrationAnim.value;
    final sz = MediaQuery.of(context).size;

    final particles = _celebParticles.map((p) {
      final x = sz.width * p.x + p.dx * t * 200;
      final y = sz.height * 0.3 + p.dy * t * sz.height * 0.8 - (1 - t) * 200;
      final opacity = t < 0.8 ? 1.0 : ((1 - t) / 0.2).clamp(0.0, 1.0);
      return Positioned(
        left: x,
        top: y,
        child: Opacity(
          opacity: opacity,
          child: Text(p.emoji, style: TextStyle(fontSize: 20 + p.size * 16)),
        ),
      );
    }).toList();

    return [
      Positioned.fill(
        child: AnimatedOpacity(
          opacity: t < 0.8 ? 0.4 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(color: kBgColor),
        ),
      ),
      ...particles,
    ];
  }
}

class _Sparkle {
  final double dx, dy, size;
  _Sparkle(Random rng)
      : dx = rng.nextDouble() * 2 - 1,
        dy = rng.nextDouble() * 2 - 1,
        size = rng.nextDouble();
}

class _CelebParticle {
  final double x, dx, dy, size;
  final String emoji;
  static const _emojis = ['✨', '⭐', '🌟', '💫', '✦', '🔮'];
  _CelebParticle(Random rng)
      : x = rng.nextDouble(),
        dx = rng.nextDouble() * 2 - 1,
        dy = rng.nextDouble(),
        size = rng.nextDouble(),
        emoji = _emojis[rng.nextInt(_emojis.length)];
}
