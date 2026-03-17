import 'package:flutter/material.dart';
import 'widgets/flipbook_animation.dart';
import 'demo/guardian_reveal_frames.dart';

void main() {
  runApp(const FlipbookDemoApp());
}

class FlipbookDemoApp extends StatelessWidget {
  const FlipbookDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flipbook Animation - Bognor\'s Curse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Georgia',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B4513),
          brightness: Brightness.dark,
        ),
      ),
      home: const FlipbookDemoPage(),
    );
  }
}

class FlipbookDemoPage extends StatelessWidget {
  const FlipbookDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C1810), Color(0xFF1A0E08)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Flipbook Animation',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD4A574),
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bognor\'s Curse · Storybook UI Prototype',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9B8B7A),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Auto Play
                  _ParchmentCard(
                    title: 'Auto Play (plays once)',
                    child: FlipbookAnimation(
                      frameBuilder: GuardianRevealFrames.build,
                      frameCount: 8,
                      fps: 12,
                      mode: PlaybackMode.autoPlay,
                      width: 280,
                      height: 280,
                      onComplete: () {},
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Loop
                  _ParchmentCard(
                    title: 'Loop (continuous)',
                    child: FlipbookAnimation(
                      frameBuilder: GuardianRevealFrames.build,
                      frameCount: 8,
                      fps: 8,
                      mode: PlaybackMode.loop,
                      width: 280,
                      height: 280,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Scrub
                  _ParchmentCard(
                    title: 'Scrub (drag horizontally)',
                    child: FlipbookAnimation(
                      frameBuilder: GuardianRevealFrames.build,
                      frameCount: 8,
                      mode: PlaybackMode.scrub,
                      width: 280,
                      height: 280,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Guardian Reveal
                  _ParchmentCard(
                    title: 'Guardian Reveal',
                    subtitle: 'Fragments assembling into a guardian silhouette',
                    child: FlipbookAnimation(
                      frameBuilder: GuardianRevealFrames.build,
                      frameCount: 8,
                      fps: 6,
                      mode: PlaybackMode.loop,
                      width: 360,
                      height: 360,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ParchmentCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _ParchmentCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5E6D0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF8B6914), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE8D5B8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
              border: Border(
                bottom: BorderSide(color: Color(0xFFB89B6A), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A3520),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A6B5A),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}
