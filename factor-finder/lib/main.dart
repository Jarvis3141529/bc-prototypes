import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const FactorFinderApp());

// ── Theme colors ──
const kBgColor = Color(0xFF1A0533);
const kGold = Color(0xFFFFD700);
const kParchment = Color(0xFFF5E6C8);
const kCyan = Color(0xFF00E5FF);
const kCyanDim = Color(0xFF0088AA);
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

/// Factor pairs where a <= b
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

  // Dot positions: scattered and grid
  List<Offset> _scatterPositions = [];
  List<Offset> _gridPositions = [];

  // Animation
  late AnimationController _dotAnim;
  late AnimationController _shakeAnim;
  late AnimationController _sparkleAnim;
  late AnimationController _celebrationAnim;

  // State
  Set<int> _foundFactors = {};
  int? _activeCast; // currently cast spell number
  bool _isFactor = false;
  bool _showResult = false;
  bool _isShaking = false;
  bool _celebrating = false;
  String _resultText = '';
  Color _resultColor = kGreenGlow;

  // Sparkle particles
  List<_Sparkle> _sparkles = [];

  // Celebration particles
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
    _generateScatter();
    setState(() {});
  }

  Rect get _dotArea {
    final sz = MediaQuery.of(context).size;
    // Leave space for title top and buttons bottom
    return Rect.fromLTWH(40, 120, sz.width - 80, sz.height - 300);
  }

  void _generateScatter() {
    final area = _dotArea;
    _scatterPositions = List.generate(_target, (_) {
      return Offset(
        area.left + _rng.nextDouble() * (area.width - 48),
        area.top + _rng.nextDouble() * (area.height - 48),
      );
    });
    _gridPositions = List.from(_scatterPositions);
  }

  void _castSpell(int spell) {
    if (_dotAnim.isAnimating || _isShaking || _celebrating) return;
    if (_foundFactors.contains(spell)) return; // already found

    _activeCast = spell;
    _isFactor = _target % spell == 0;

    final area = _dotArea;
    final dotSize = 44.0;

    if (_isFactor) {
      final rows = spell;
      final cols = _target ~/ spell;
      // Center the grid
      final gridW = cols * (dotSize + 8.0) - 8;
      final gridH = rows * (dotSize + 8.0) - 8;
      final ox = area.left + (area.width - gridW) / 2;
      final oy = area.top + (area.height - gridH) / 2;

      _gridPositions = List.generate(_target, (i) {
        final r = i ~/ cols;
        final c = i % cols;
        return Offset(ox + c * (dotSize + 8), oy + r * (dotSize + 8));
      });

      _resultText = '$spell × ${cols} = $_target ✓';
      _resultColor = kGreenGlow;
    } else {
      final rows = spell;
      final cols = _target ~/ spell;
      final remainder = _target % spell;
      final fullCount = rows * cols;

      final gridW = max(cols, remainder) * (dotSize + 8.0) - 8;
      final gridH = (rows + 1) * (dotSize + 8.0) - 8;
      final ox = area.left + (area.width - gridW) / 2;
      final oy = area.top + (area.height - gridH) / 2;

      _gridPositions = List.generate(_target, (i) {
        if (i < fullCount) {
          final r = i ~/ cols;
          final c = i % cols;
          return Offset(ox + c * (dotSize + 8), oy + r * (dotSize + 8));
        } else {
          // Remainder dots on extra row
          final c = i - fullCount;
          return Offset(ox + c * (dotSize + 8), oy + rows * (dotSize + 8));
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
    // Add both the spell and its complement
    _foundFactors.add(spell);
    final complement = _target ~/ spell;
    _foundFactors.add(complement);

    // Sparkles
    _sparkles = List.generate(20, (_) => _Sparkle(_rng));
    _sparkleAnim.forward(from: 0);

    // Check completion
    final allFactors = _factors(_target);
    if (_foundFactors.containsAll(allFactors)) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        _startCelebration();
      });
    }

    setState(() {});
  }

  void _onNotFactor() {
    _isShaking = true;
    _shakeAnim.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        _isShaking = false;
        // Scatter back
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

  void _startCelebration() {
    _celebrating = true;
    _celebParticles = List.generate(60, (_) => _CelebParticle(_rng));
    _celebrationAnim.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _targetIdx = (_targetIdx + 1) % kTargets.length;
        _initLevel();
      });
    });
    setState(() {});
  }

  void _resetAfterFactor() {
    // After a short delay, scatter dots back for next cast
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _generateScatter();
      _gridPositions = List.from(_scatterPositions);
      _dotAnim.value = 0;
      _showResult = false;
      _activeCast = null;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // If factor found and sparkle done, reset
    if (_isFactor &&
        _activeCast != null &&
        _dotAnim.isCompleted &&
        !_sparkleAnim.isAnimating &&
        !_celebrating) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resetAfterFactor());
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
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
                    shadows: [
                      Shadow(color: kGold.withAlpha(100), blurRadius: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_target Mana Orbs',
                  style: GoogleFonts.cinzelDecorative(
                    fontSize: 20,
                    color: kCyan,
                    shadows: [
                      Shadow(color: kCyan.withAlpha(120), blurRadius: 16),
                    ],
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
                  shadows: [
                    Shadow(color: _resultColor.withAlpha(150), blurRadius: 12),
                  ],
                ),
              ),
            ),

          // Progress - factors found
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
    final shake =
        _isShaking ? sin(_shakeAnim.value * pi * 6) * 6 : 0.0;

    return List.generate(_target, (i) {
      final from = i < _scatterPositions.length
          ? _scatterPositions[i]
          : Offset.zero;
      final to =
          i < _gridPositions.length ? _gridPositions[i] : Offset.zero;
      final pos = Offset.lerp(from, to, Curves.easeInOutCubic.transform(t))!;

      final isRemainder = _activeCast != null &&
          !_isFactor &&
          i >= (_activeCast! * (_target ~/ _activeCast!));

      return Positioned(
        left: pos.dx + shake,
        top: pos.dy,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRemainder && t > 0.5
                ? kRedGlow.withAlpha(180)
                : kCyan.withAlpha(200),
            boxShadow: [
              BoxShadow(
                color: (isRemainder && t > 0.5 ? kRedGlow : kCyan)
                    .withAlpha(120),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
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
    final pairs = _factorPairs(_target);
    final foundPairs = pairs.where((p) => _foundFactors.contains(p.$1)).toList();

    if (foundPairs.isEmpty) {
      return Text(
        'Cast spells to find factors!',
        textAlign: TextAlign.center,
        style: TextStyle(color: kParchment.withAlpha(150), fontSize: 14),
      );
    }

    final pairTexts = foundPairs.map((p) => '${p.$1}×${p.$2}').join('  ');
    return Text(
      'Factors found: $pairTexts',
      textAlign: TextAlign.center,
      style: const TextStyle(color: kGold, fontSize: 15, fontWeight: FontWeight.w600),
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
                      ? [
                          BoxShadow(
                            color: borderColor.withAlpha(120),
                            blurRadius: 16,
                          )
                        ]
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
          child: Text(
            p.emoji,
            style: TextStyle(fontSize: 20 + p.size * 16),
          ),
        ),
      );
    }).toList();

    return [
      // Overlay
      Positioned.fill(
        child: AnimatedOpacity(
          opacity: t < 0.8 ? 0.4 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(color: kBgColor),
        ),
      ),
      // Text
      if (t < 0.85)
        Center(
          child: Text(
            '✨ All Factors Found! ✨',
            style: GoogleFonts.cinzelDecorative(
              fontSize: 32,
              color: kGold,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: kGold, blurRadius: 24)],
            ),
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
