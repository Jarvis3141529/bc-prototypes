import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const PageTurnApp());

class PageTurnApp extends StatelessWidget {
  const PageTurnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Page Turn Prototype',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const PageTurnDemo(),
    );
  }
}

// ── Storybook colours (matching Bognor's Curse) ──
class _Colors {
  static const deepPurple = Color(0xFF1A0A2E);
  static const gold = Color(0xFFFFD700);
  static const brightGold = Color(0xFFFFE066);
  static const parchment = Color(0xFFF5E6D3);
  static const curseRed = Color(0xFFFF4444);
  static const warmAmber = Color(0xFFFFAB00);
  static const pageBg = Color(0xFF1E1033);
}

// ── Demo pages ──
class _StoryPage {
  final String title;
  final String body;
  final Color? highlightColor;

  const _StoryPage(this.title, this.body, {this.highlightColor});
}

const _pages = [
  _StoryPage(
    'The Village',
    'Welcome, Apprentice. I am Master Aldric.\n\n'
        'You have arrived at a village on the edge of the Whispering Wood. '
        'Once, this was a place of great magic — where wizards studied '
        'the ancient art of spellcraft.',
  ),
  _StoryPage(
    'The Curse',
    'But a dark wizard named Bognor cast a terrible curse upon the land. '
        'One by one, the village\'s spells have been fading. '
        'The protective wards grow weaker by the day.',
    highlightColor: _Colors.curseRed,
  ),
  _StoryPage(
    'The Call',
    'I have sent for you because I believe you have the gift — '
        'the ability to learn the ancient foundations of spellcraft '
        'and restore what was lost.',
  ),
  _StoryPage(
    'How Magic Works',
    'All spells are crafted from mana — the raw magical energy that flows '
        'through our world. To cast a spell, you must first learn to collect '
        'and shape this energy.',
    highlightColor: _Colors.brightGold,
  ),
  _StoryPage(
    'Shaping Mana',
    'Shaping mana is the heart of spellcraft. You must gather mana '
        'into a single layer, then decide how many copies of that layer '
        'to weave together. The pattern you create determines the spell.',
  ),
  _StoryPage(
    'Begin Training',
    'Before you can face Bognor, you must master these foundations — '
        'collecting, counting, and shaping mana into powerful patterns.\n\n'
        'Come. Your training begins now.',
  ),
];

class PageTurnDemo extends StatefulWidget {
  const PageTurnDemo({super.key});

  @override
  State<PageTurnDemo> createState() => _PageTurnDemoState();
}

class _PageTurnDemoState extends State<PageTurnDemo>
    with TickerProviderStateMixin {
  int _currentPage = 0;
  late AnimationController _turnController;
  bool _isTurning = false;
  bool _turningForward = true;

  @override
  void initState() {
    super.initState();
    _turnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _turnController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1 && !_isTurning) {
      setState(() {
        _isTurning = true;
        _turningForward = true;
      });
      _turnController.forward(from: 0).then((_) {
        setState(() {
          _currentPage++;
          _isTurning = false;
        });
      });
    }
  }

  void _prevPage() {
    if (_currentPage > 0 && !_isTurning) {
      setState(() {
        _isTurning = true;
        _turningForward = false;
      });
      _turnController.forward(from: 0).then((_) {
        setState(() {
          _currentPage--;
          _isTurning = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D0221), _Colors.deepPurple, Color(0xFF16082A)],
              ),
            ),
          ),
          // Particles
          const _ManaParticles(),
          // Pages
          SafeArea(
            child: Column(
              children: [
                // Title bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Page Turn Prototype',
                    style: TextStyle(
                      color: _Colors.gold.withValues(alpha: 0.6),
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                // Page area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ClipRect(
                      child: Stack(
                        children: [
                          // Revealed page (underneath)
                          if (_isTurning) _buildPageContent(
                            _turningForward ? _currentPage + 1 : _currentPage - 1,
                          ),
                          // Current/turning page
                          AnimatedBuilder(
                            animation: _turnController,
                            builder: (context, child) {
                              if (!_isTurning) return child!;
                              final t = Curves.easeInOut.transform(
                                _turnController.value,
                              );
                              // Rotate from left spine toward the viewer
                              final angle = _turningForward
                                  ? -t * pi * 0.5  // current page turns away left
                                  : -(1.0 - t) * pi * 0.5; // prev page turns back in
                              final matrix = Matrix4.identity()
                                ..setEntry(3, 2, 0.0015) // perspective
                                ..rotateY(angle);

                              final opacity = _turningForward
                                  ? (1.0 - t * 0.7).clamp(0.0, 1.0)
                                  : (0.3 + t * 0.7).clamp(0.0, 1.0);

                              return Transform(
                                alignment: Alignment.centerLeft,
                                transform: matrix,
                                child: Opacity(opacity: opacity, child: child),
                              );
                            },
                            child: _isTurning && !_turningForward
                                ? _buildPageContent(_currentPage - 1)
                                : _buildPageContent(_currentPage),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Navigation
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      // Page dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == i ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == i
                                  ? _Colors.gold
                                  : _Colors.gold.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      // Nav buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _currentPage > 0 ? _prevPage : null,
                            icon: Icon(
                              Icons.arrow_back_ios,
                              color: _currentPage > 0
                                  ? _Colors.gold
                                  : _Colors.gold.withValues(alpha: 0.2),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Text(
                            '${_currentPage + 1} / ${_pages.length}',
                            style: TextStyle(
                              color: _Colors.gold.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            onPressed: _currentPage < _pages.length - 1
                                ? _nextPage
                                : null,
                            icon: Icon(
                              Icons.arrow_forward_ios,
                              color: _currentPage < _pages.length - 1
                                  ? _Colors.gold
                                  : _Colors.gold.withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(int index) {
    if (index < 0 || index >= _pages.length) return const SizedBox.shrink();
    final page = _pages[index];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _Colors.pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _Colors.gold.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _nextPage,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Text(
                page.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _Colors.brightGold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(
                page.body,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.7,
                  color: _Colors.parchment,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Floating mana particles ──
class _ManaParticles extends StatefulWidget {
  const _ManaParticles();

  @override
  State<_ManaParticles> createState() => _ManaParticlesState();
}

class _ManaParticlesState extends State<_ManaParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 25; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 3 + 1,
        speed: _random.nextDouble() * 0.3 + 0.1,
        opacity: _random.nextDouble() * 0.4 + 0.1,
      ));
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(_particles, _controller.value),
        );
      },
    );
  }
}

class _Particle {
  final double x, y, size, speed, opacity;
  const _Particle({
    required this.x, required this.y, required this.size,
    required this.speed, required this.opacity,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double time;
  _ParticlePainter(this.particles, this.time);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y - time * p.speed) % 1.0;
      final x = p.x + sin(time * 2 * pi + p.y * 10) * 0.02;
      final flicker = p.opacity * (0.5 + 0.5 * sin(time * 2 * pi * p.speed + p.x * 20));
      final paint = Paint()
        ..color = _Colors.gold.withValues(alpha: flicker.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
