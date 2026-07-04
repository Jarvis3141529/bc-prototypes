import 'package:flutter/material.dart';

import 'core/session.dart';
import 'core/widgets.dart';
import 'sidescroll/sidescroll_shell.dart';
import 'topdown/topdown_shell.dart';

void main() {
  runApp(const FortressCompoundApp());
}

/// Fortress Compound prototype v2 — two playable perspectives (side-view
/// scroller vs. top-down compound) sharing one mechanics core: spell-first
/// selection, ritual casting panel, fluency timer, hearts + checkpoints.
/// (The original v1 free-roam mockup lives in git history on main.)
class FortressCompoundApp extends StatelessWidget {
  const FortressCompoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bognor\'s Fortress — Compound Prototype',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kDeepPurple,
        snackBarTheme: const SnackBarThemeData(
          contentTextStyle: TextStyle(color: kParchment),
        ),
      ),
      home: const MenuScreen(),
    );
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  /// Fluency timer scale: lower = faster/harder. Stands in for real mastery
  /// data during prototyping.
  double _timerScale = 1.0;

  void _launch(Widget Function(GameSession) builder) {
    final session = GameSession(timerScale: _timerScale);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => builder(session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('🏯',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 8),
                  const Text(
                    'Bognor\'s Fortress',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: kBrightGold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Text(
                    'Compound prototype v2 — perspective comparison',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: kParchment),
                  ),
                  const SizedBox(height: 28),

                  _ShellCard(
                    emoji: '🏰',
                    title: 'Side-View Scroller',
                    subtitle:
                        'Walk the fortress cross-section left to right — '
                        'gates, moat bridge, towers, the Throne Door.',
                    onTap: () =>
                        _launch((s) => SideScrollShell(session: s)),
                  ),
                  const SizedBox(height: 14),
                  _ShellCard(
                    emoji: '🗺️',
                    title: 'Top-Down Compound',
                    subtitle:
                        'Overhead view of the grounds — drag to roam, '
                        'pick your route through the compound.',
                    onTap: () => _launch((s) => TopDownShell(session: s)),
                  ),

                  const SizedBox(height: 28),
                  Text(
                    'Fluency timer: ${_timerScale.toStringAsFixed(2)}× '
                    '(${_timerScale < 1 ? "faster = harder" : _timerScale > 1 ? "gentler" : "standard"})',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: kGold),
                  ),
                  Slider(
                    value: _timerScale,
                    min: 0.75,
                    max: 1.5,
                    divisions: 6,
                    activeColor: kGold,
                    onChanged: (v) => setState(() => _timerScale = v),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Both shells share the same core: choose your spell, '
                    'tap the target, beat the clock. Wrong spell fizzles — '
                    'spell choice is part of the puzzle.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0x99F5E6C8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellCard extends StatelessWidget {
  const _ShellCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kMidPurple.withOpacity(0.55),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kGold.withOpacity(0.6), width: 1.5),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kBrightGold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: kParchment,
                          height: 1.35),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: kGold),
            ],
          ),
        ),
      ),
    );
  }
}
