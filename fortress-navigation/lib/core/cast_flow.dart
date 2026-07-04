import 'package:flutter/material.dart';

import 'casting_panel.dart';
import 'encounter.dart';
import 'session.dart';
import 'spells.dart';
import 'widgets.dart';

/// The one true casting flow, shared by every shell:
///
/// 1. No spell armed → nudge to open the spell book (never auto-select).
/// 2. Armed spell doesn't fit the target → in-world fizzle (part of the
///    puzzle: choosing the right spell is the wizard fantasy).
/// 3. Right spell → ritual casting panel (timed math). Success solves the
///    encounter; failure may end the run if hearts are gone.
Future<void> attemptCast(
  BuildContext context, {
  required SpellType? armed,
  required Encounter encounter,
  required GameSession session,
  required VoidCallback onSolved,
  required VoidCallback onDefeat,
}) async {
  if (encounter.solved) return;

  if (armed == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Choose a spell from your spell book first!'),
          backgroundColor: kMidPurple,
          duration: Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
    return;
  }

  final spell = Spell.of(armed);
  if (!encounter.accepts(armed)) {
    showFizzle(context, spell, encounter);
    return;
  }

  final success = await showCastingPanel(
    context,
    spell: spell,
    encounter: encounter,
    session: session,
  );

  if (success) {
    encounter.state = EncounterState.solved;
    session.solve(encounter.id);
    onSolved();
  } else if (session.defeated) {
    onDefeat();
  }
}
