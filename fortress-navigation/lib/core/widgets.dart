import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'encounter.dart';
import 'session.dart';
import 'spells.dart';

const kGold = Color(0xFFD4A843);
const kBrightGold = Color(0xFFFFD700);
const kDeepPurple = Color(0xFF1A0A2E);
const kMidPurple = Color(0xFF2D1B69);
const kErrorRed = Color(0xFFCF4444);
const kParchment = Color(0xFFF5E6C8);

/// The player's spell book quick-bar. Arming a spell is part of the gameplay:
/// the player chooses, the game never auto-selects.
class SpellBar extends StatelessWidget {
  const SpellBar({super.key, required this.armed, required this.onArm});

  final SpellType? armed;
  final ValueChanged<SpellType> onArm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: kDeepPurple.withOpacity(0.95),
        border: const Border(top: BorderSide(color: kGold, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: Spell.all.map((spell) {
            final selected = armed == spell.type;
            return GestureDetector(
              onTap: () => onArm(spell.type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 46,
                height: 58,
                decoration: BoxDecoration(
                  color: selected
                      ? spell.color.withOpacity(0.35)
                      : kMidPurple.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? spell.color : spell.color.withOpacity(0.4),
                    width: selected ? 2.5 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: spell.color.withOpacity(0.6),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(spell.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 2),
                    Text(
                      spell.name,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : spell.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Hearts + solved-count HUD row.
class SessionHud extends StatelessWidget {
  const SessionHud({
    super.key,
    required this.session,
    required this.total,
    this.armedSpell,
  });

  final GameSession session;
  final int total;
  final SpellType? armedSpell;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(session.maxHearts, (i) {
              final filled = i < session.hearts;
              return Icon(
                filled ? Icons.favorite : Icons.favorite_border,
                color: filled ? kErrorRed : kErrorRed.withOpacity(0.35),
                size: 18,
              );
            }),
            const SizedBox(width: 10),
            Text(
              '${session.solvedCount}/$total',
              style: const TextStyle(
                color: kParchment,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (armedSpell != null) ...[
              const SizedBox(width: 10),
              Text(
                Spell.of(armedSpell!).emoji,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders an encounter in the world with a solve transition. Iteration-1
/// art: emoji sprite + spell-colored frame; blocked → solved crossfades and
/// the specific art gets bespoke animation passes in later iterations.
class EncounterSprite extends StatelessWidget {
  const EncounterSprite({
    super.key,
    required this.encounter,
    this.size = 72,
    this.highlight = false,
  });

  final Encounter encounter;
  final double size;
  final bool highlight;

  String get _blockedEmoji => switch (encounter.primarySpell) {
        SpellType.unlock => '🚪',
        SpellType.shield => '🏹',
        SpellType.fireball => '🧊',
        SpellType.repair => '🌉',
        SpellType.shatter =>
          encounter.kind == EncounterKind.enemy ? '🗼' : '🧱',
        SpellType.fog => '🗼',
        SpellType.dispel => '🔮',
      };

  String get _solvedEmoji => switch (encounter.primarySpell) {
        SpellType.unlock => '🎊',
        SpellType.shield => '✅',
        SpellType.fireball => '💧',
        SpellType.repair => '🌉',
        SpellType.shatter => '🪨',
        SpellType.fog => '🌫️',
        SpellType.dispel => '✨',
      };

  @override
  Widget build(BuildContext context) {
    final spell = Spell.of(encounter.primarySpell);
    final solved = encounter.solved;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: solved
            ? Colors.green.withOpacity(0.15)
            : kMidPurple.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: solved
              ? Colors.green.withOpacity(0.7)
              : (highlight ? kBrightGold : spell.color),
          width: highlight && !solved ? 3 : 2,
        ),
        boxShadow: highlight && !solved
            ? [BoxShadow(color: spell.color.withOpacity(0.6), blurRadius: 14)]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Text(
              solved ? _solvedEmoji : _blockedEmoji,
              key: ValueKey(solved),
              style: TextStyle(fontSize: size * 0.38),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            solved
                ? 'Clear!'
                : '${encounter.factor1}×${encounter.factor2}',
            style: TextStyle(
              fontSize: size * 0.16,
              fontWeight: FontWeight.bold,
              color: solved ? Colors.greenAccent : kParchment,
            ),
          ),
        ],
      ),
    );
  }
}

/// Play-once radial spell burst: expanding ring + stars + rising incantation.
/// Ported (simplified) from the main game's SpellCastBurst.
class CastBurst extends StatefulWidget {
  const CastBurst({
    super.key,
    required this.color,
    required this.incantation,
    this.onDone,
  });

  final Color color;
  final String incantation;
  final VoidCallback? onDone;

  @override
  State<CastBurst> createState() => _CastBurstState();
}

class _CastBurstState extends State<CastBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )
      ..forward()
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: const Size(160, 160),
          painter: _BurstPainter(
            progress: _c.value,
            color: widget.color,
            incantation: widget.incantation,
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.progress,
    required this.color,
    required this.incantation,
  });

  final double progress;
  final Color color;
  final String incantation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final fade = (1.0 - progress).clamp(0.0, 1.0);
    final r = size.shortestSide * 0.48 * Curves.easeOut.transform(progress);

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = color.withOpacity(0.6 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    final starPaint = Paint()..color = color.withOpacity(0.9 * fade);
    for (int i = 0; i < 6; i++) {
      final angle = i / 6 * 2 * math.pi - math.pi / 2;
      final pos = center +
          Offset(math.cos(angle), math.sin(angle)) * (r * 0.85);
      canvas.drawCircle(pos, 4 * fade, starPaint);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: incantation,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
          color: Colors.white.withOpacity(fade),
          shadows: [Shadow(color: color, blurRadius: 10)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rise = 26.0 * Curves.easeOut.transform(progress);
    tp.paint(
      canvas,
      center - Offset(tp.width / 2, tp.height / 2 + rise),
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}

/// Gentle in-world cue when the armed spell doesn't fit the target — part of
/// the puzzle, never auto-corrected, never harsh.
void showFizzle(BuildContext context, Spell armed, Encounter enc) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          'The ${enc.name} resists ${armed.incantation}… '
          'perhaps another spell?',
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
        backgroundColor: kMidPurple,
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
