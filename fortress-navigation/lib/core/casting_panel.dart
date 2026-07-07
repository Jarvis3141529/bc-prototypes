import 'dart:math';

import 'package:flutter/material.dart';

import 'encounter.dart';
import 'session.dart';
import 'spells.dart';

/// The ritual casting panel — the heart of the activity.
///
/// Opens only after the player has ARMED the right spell and tapped a valid
/// target (spell selection is part of the gameplay; it is never automatic).
/// Shows the spell sigil + incantation, the fact with its orb-array
/// visualization, six product options, and a fluency timer. The timer IS the
/// mastery test: fluency means fast recall.
///
/// Returns true if the cast succeeded. Wrong answers and timeouts cost a
/// heart (gently); the panel allows retries until time runs out.
Future<bool> showCastingPanel(
  BuildContext context, {
  required Spell spell,
  required Encounter encounter,
  required GameSession session,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CastingSheet(
      spell: spell,
      encounter: encounter,
      session: session,
    ),
  );
  return result ?? false;
}

class _CastingSheet extends StatefulWidget {
  const _CastingSheet({
    required this.spell,
    required this.encounter,
    required this.session,
  });

  final Spell spell;
  final Encounter encounter;
  final GameSession session;

  @override
  State<_CastingSheet> createState() => _CastingSheetState();
}

class _CastingSheetState extends State<_CastingSheet>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFD4A843);
  static const _brightGold = Color(0xFFFFD700);
  static const _deepPurple = Color(0xFF1A0A2E);
  static const _midPurple = Color(0xFF2D1B69);
  static const _errorRed = Color(0xFFCF4444);

  late final AnimationController _timer;
  late final List<int> _options;
  final Random _rng = Random();

  int? _wrongTap; // last wrong option, flashes red briefly
  bool _resolved = false;

  Encounter get enc => widget.encounter;

  @override
  void initState() {
    super.initState();
    _options = _generateOptions();
    _timer = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            (enc.castSeconds * widget.session.timerScale * 1000).round(),
      ),
    )..forward();
    _timer.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_resolved && mounted) {
        // Timeout — the spell fizzles. Kind feedback, costs a heart.
        _resolved = true;
        widget.session.loseHeart();
        Navigator.of(context).pop(false);
      }
    });
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  List<int> _generateOptions() {
    final correct = enc.product;
    final a = enc.factor1, b = enc.factor2;
    final opts = <int>{correct};
    // Near-miss distractors first (most instructive), then fill.
    for (final c in [a * (b + 1), a * (b - 1), (a + 1) * b, (a - 1) * b,
        correct + 1, correct - 1]) {
      if (opts.length >= 6) break;
      if (c > 0 && c != correct) opts.add(c);
    }
    var offset = 2;
    while (opts.length < 6) {
      final c = _rng.nextBool() ? correct + offset : correct - offset;
      if (c > 0) opts.add(c);
      offset++;
    }
    final list = opts.toList()..shuffle(_rng);
    return list;
  }

  void _onTap(int value) {
    if (_resolved) return;
    if (value == enc.product) {
      _resolved = true;
      _timer.stop();
      Navigator.of(context).pop(true);
    } else {
      // Wrong answer: gentle sting — heart lost, flash, but keep trying
      // while time remains.
      widget.session.loseHeart();
      setState(() => _wrongTap = value);
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _wrongTap = null);
      });
      if (widget.session.defeated && !_resolved) {
        _resolved = true;
        _timer.stop();
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spell = widget.spell;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: _deepPurple,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: spell.color, width: 2),
          boxShadow: [
            BoxShadow(
              color: spell.color.withOpacity(0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sigil + incantation header
            Row(
              children: [
                Text(spell.emoji, style: const TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spell.incantation,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          color: spell.color,
                        ),
                      ),
                      Text(
                        '${spell.name} · ${enc.name}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xAAF5E6C8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Hearts (cost is visible where the risk is taken)
                AnimatedBuilder(
                  animation: widget.session,
                  builder: (_, __) => Row(
                    children: List.generate(widget.session.maxHearts, (i) {
                      final filled = i < widget.session.hearts;
                      return Icon(
                        filled ? Icons.favorite : Icons.favorite_border,
                        color: filled
                            ? _errorRed
                            : _errorRed.withOpacity(0.3),
                        size: 14,
                      );
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // The fact + its array visualization
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _midPurple.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _gold.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  Text(
                    '${enc.factor1} × ${enc.factor2} = ?',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: _brightGold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 72),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _orbArray(
                          enc.factor1, enc.factor2, spell.color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Fluency timer — the mastery test
            AnimatedBuilder(
              animation: _timer,
              builder: (_, __) {
                final remaining = (1.0 - _timer.value).clamp(0.0, 1.0);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: remaining,
                    minHeight: 7,
                    backgroundColor: _midPurple,
                    valueColor: AlwaysStoppedAnimation(
                      remaining > 0.35 ? _gold : _errorRed,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Answer options
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: _options.map((o) {
                final isWrongFlash = _wrongTap == o;
                return SizedBox(
                  width: 86,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _onTap(o),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isWrongFlash ? _errorRed : _midPurple,
                      foregroundColor: _brightGold,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _gold.withOpacity(0.6),
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Text(
                      '$o',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Orb-array visualization (ported pattern from the main game's
  /// foundation_shared.buildOrbGrid).
  Widget _orbArray(int rows, int cols, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (r) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(cols, (c) {
            return Padding(
              padding: const EdgeInsets.all(1.5),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.85),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}
