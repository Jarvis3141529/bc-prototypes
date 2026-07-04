import 'package:flutter/material.dart';

/// The seven learned spells — mirrors the main game's `lib/data/spell_data.dart`.
enum SpellType { unlock, shield, fireball, repair, shatter, fog, dispel }

class Spell {
  final SpellType type;
  final String name;
  final String incantation;
  final String emoji;
  final Color color;
  final IconData icon;

  const Spell({
    required this.type,
    required this.name,
    required this.incantation,
    required this.emoji,
    required this.color,
    required this.icon,
  });

  static const List<Spell> all = [
    Spell(
      type: SpellType.unlock,
      name: 'Unlock',
      incantation: 'Reserare',
      emoji: '🗝️',
      color: Color(0xFFD4A843),
      icon: Icons.lock_open,
    ),
    Spell(
      type: SpellType.shield,
      name: 'Shield',
      incantation: 'Aegis Telorum',
      emoji: '🛡️',
      color: Color(0xFF4488FF),
      icon: Icons.shield,
    ),
    Spell(
      type: SpellType.fireball,
      name: 'Fireball',
      incantation: 'Ignisfera',
      emoji: '🔥',
      color: Color(0xFFFF8C00),
      icon: Icons.local_fire_department,
    ),
    Spell(
      type: SpellType.repair,
      name: 'Repair',
      incantation: 'Reficere',
      emoji: '🔨',
      color: Color(0xFFB87333),
      icon: Icons.build,
    ),
    Spell(
      type: SpellType.shatter,
      name: 'Shatter',
      incantation: 'Frangere',
      emoji: '💥',
      color: Color(0xFF9966FF),
      icon: Icons.broken_image,
    ),
    Spell(
      type: SpellType.fog,
      name: 'Fog',
      incantation: 'Nebula',
      emoji: '🌫️',
      color: Color(0xFF7BAF9E),
      icon: Icons.cloud,
    ),
    Spell(
      type: SpellType.dispel,
      name: 'Dispel',
      incantation: 'Dissolvere',
      emoji: '✨',
      color: Color(0xFF7FDBFF),
      icon: Icons.auto_fix_high,
    ),
  ];

  static Spell of(SpellType type) => all.firstWhere((s) => s.type == type);
}
