import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(FortressNavigationApp());
}

class FortressNavigationApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bognor\'s Fortress Navigation',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF2F3542),
        primaryColor: Color(0xFFFFD700),
      ),
      home: FortressScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Spell types from our refined lore system
enum SpellType {
  unlock,     // Reserare - Universal utility
  shield,     // Aegis Telorum - Defense
  fireball,   // Ignisfera - Offense
  repair,     // Reficere - Construction
  shatter,    // Frangere - Destruction
  fogCloud,   // Nebula - Concealment
  dispel,     // Dissolvere - Counter-magic
}

class Spell {
  final SpellType type;
  final String name;
  final String description;
  final Color color;
  final IconData icon;

  const Spell({
    required this.type,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
  });

  static const List<Spell> allSpells = [
    Spell(
      type: SpellType.unlock,
      name: 'Unlock',
      description: 'Reserare',
      color: Color(0xFFFFD700),
      icon: Icons.lock_open,
    ),
    Spell(
      type: SpellType.shield,
      name: 'Shield',
      description: 'Aegis Telorum',
      color: Color(0xFF4FC3F7),
      icon: Icons.shield,
    ),
    Spell(
      type: SpellType.fireball,
      name: 'Fireball',
      description: 'Ignisfera',
      color: Color(0xFFFF5722),
      icon: Icons.local_fire_department,
    ),
    Spell(
      type: SpellType.repair,
      name: 'Repair',
      description: 'Reficere',
      color: Color(0xFF4CAF50),
      icon: Icons.build,
    ),
    Spell(
      type: SpellType.shatter,
      name: 'Shatter',
      description: 'Frangere',
      color: Color(0xFF9C27B0),
      icon: Icons.broken_image,
    ),
    Spell(
      type: SpellType.fogCloud,
      name: 'Fog',
      description: 'Nebula',
      color: Color(0xFF607D8B),
      icon: Icons.cloud,
    ),
    Spell(
      type: SpellType.dispel,
      name: 'Dispel',
      description: 'Dissolvere',
      color: Color(0xFFE91E63),
      icon: Icons.auto_fix_high,
    ),
  ];

  static Spell fromType(SpellType type) {
    return allSpells.firstWhere((spell) => spell.type == type);
  }
}

class Obstacle {
  final int x, y;
  final SpellType requiredSpell;
  final int factor1, factor2;
  final String description;
  final bool solved;

  const Obstacle({
    required this.x,
    required this.y,
    required this.requiredSpell,
    required this.factor1,
    required this.factor2,
    required this.description,
    this.solved = false,
  });

  int get product => factor1 * factor2;

  Obstacle copyWith({bool? solved}) => Obstacle(
    x: x,
    y: y,
    requiredSpell: requiredSpell,
    factor1: factor1,
    factor2: factor2,
    description: description,
    solved: solved ?? this.solved,
  );

  String get obstacleText {
    switch (requiredSpell) {
      case SpellType.unlock:
        return 'Sealed Gate\n${factor1}×${factor2} locks';
      case SpellType.shield:
        return 'Missile Trap\n${factor1}×${factor2} projectiles';
      case SpellType.fireball:
        return 'Ice Barrier\n${factor1}×${factor2} thickness';
      case SpellType.repair:
        return 'Broken Bridge\n${factor1}×${factor2} pieces';
      case SpellType.shatter:
        return 'Stone Wall\n${factor1}×${factor2} blocks';
      case SpellType.fogCloud:
        return 'Guard Tower\n${factor1}×${factor2} watchers';
      case SpellType.dispel:
        return 'Magic Ward\n${factor1}×${factor2} layers';
    }
  }
}

class FortressScreen extends StatefulWidget {
  @override
  _FortressScreenState createState() => _FortressScreenState();
}

class _FortressScreenState extends State<FortressScreen> with TickerProviderStateMixin {
  // Player position
  double playerX = 0;
  double playerY = 0;
  
  // Camera offset
  double offsetX = 0;
  double offsetY = 0;
  
  // Game state
  List<Obstacle> obstacles = [];
  Obstacle? activeObstacle;
  SpellType? selectedSpell;
  List<int> productOptions = [];
  
  // Animation controllers
  late AnimationController spellEffectController;
  late Animation<double> spellEffectAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    spellEffectController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    spellEffectAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: spellEffectController, curve: Curves.easeInOut),
    );
    
    generateObstacles();
  }
  
  @override
  void dispose() {
    spellEffectController.dispose();
    super.dispose();
  }
  
  void generateObstacles() {
    final random = Random();
    obstacles.clear();
    
    // Generate obstacles covering all multiplication facts 1-10
    for (int i = 1; i <= 10; i++) {
      for (int j = 1; j <= 10; j++) {
        if (random.nextBool() && obstacles.length < 25) { // More obstacles for better coverage
          obstacles.add(Obstacle(
            x: random.nextInt(1200) - 600,
            y: random.nextInt(1200) - 600,
            requiredSpell: SpellType.values[random.nextInt(SpellType.values.length)],
            factor1: i,
            factor2: j,
            description: 'A magical obstacle blocks your path',
          ));
        }
      }
    }
    
    // Ensure we have at least one of each spell type
    for (var spellType in SpellType.values) {
      if (!obstacles.any((o) => o.requiredSpell == spellType)) {
        obstacles.add(Obstacle(
          x: random.nextInt(1200) - 600,
          y: random.nextInt(1200) - 600,
          requiredSpell: spellType,
          factor1: random.nextInt(10) + 1,
          factor2: random.nextInt(10) + 1,
          description: 'A magical obstacle blocks your path',
        ));
      }
    }
    
    setState(() {});
  }
  
  void movePlayer(double dx, double dy) {
    setState(() {
      playerX = (playerX + dx).clamp(-1200.0, 1200.0);
      playerY = (playerY + dy).clamp(-1200.0, 1200.0);
      
      // Update camera to follow player
      offsetX = -playerX + 200; // Center player on screen
      offsetY = -playerY + 200;
    });
  }
  
  void selectSpell(SpellType spell) {
    setState(() {
      selectedSpell = spell;
      // Clear any active obstacle when switching spells
      activeObstacle = null;
      productOptions.clear();
    });
  }
  
  void selectObstacle(Obstacle obstacle) {
    if (obstacle.solved) return;
    if (selectedSpell == null) {
      // Show hint to select spell first
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Select a spell first!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    
    setState(() {
      activeObstacle = obstacle;
      generateProductOptions();
    });
    
    // Check if correct spell
    if (selectedSpell != obstacle.requiredSpell) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wrong spell! This obstacle requires ${Spell.fromType(obstacle.requiredSpell).name}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      // Clear after delay
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            activeObstacle = null;
            productOptions.clear();
          });
        }
      });
    }
  }
  
  void generateProductOptions() {
    final correct = activeObstacle!.product;
    final random = Random();
    productOptions = [correct];
    
    // Add wrong answers
    while (productOptions.length < 6) {
      int wrong = random.nextInt(100) + 1;
      if (!productOptions.contains(wrong)) {
        productOptions.add(wrong);
      }
    }
    
    productOptions.shuffle();
  }
  
  void selectProduct(int product) {
    if (activeObstacle == null) return;
    
    if (product == activeObstacle!.product) {
      // Correct! Play animation and solve obstacle
      spellEffectController.forward().then((_) {
        setState(() {
          obstacles = obstacles.map((o) => 
            o == activeObstacle ? o.copyWith(solved: true) : o
          ).toList();
          
          activeObstacle = null;
          productOptions.clear();
        });
        spellEffectController.reset();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Success! ${Spell.fromType(selectedSpell!).name} spell cast!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      // Wrong answer
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wrong mana amount! Try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }
  
  Widget buildSpellBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Color(0xFF2F3542).withOpacity(0.95),
        border: Border(top: BorderSide(color: Color(0xFFFFD700), width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: Spell.allSpells.map((spell) {
          bool isSelected = selectedSpell == spell.type;
          return GestureDetector(
            onTap: () => selectSpell(spell.type),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected ? spell.color : spell.color.withOpacity(0.2),
                border: Border.all(
                  color: spell.color,
                  width: isSelected ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    spell.icon,
                    color: isSelected ? Colors.white : spell.color,
                    size: 20,
                  ),
                  Text(
                    spell.name.substring(0, 3),
                    style: TextStyle(
                      color: isSelected ? Colors.white : spell.color,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget buildProductOverlay() {
    if (activeObstacle == null || 
        selectedSpell != activeObstacle!.requiredSpell || 
        productOptions.isEmpty) {
      return SizedBox.shrink();
    }
    
    // Position overlay near the obstacle
    double overlayX = activeObstacle!.x + offsetX + 70;
    double overlayY = activeObstacle!.y + offsetY - 20;
    
    // Keep overlay on screen
    overlayX = overlayX.clamp(10.0, MediaQuery.of(context).size.width - 200);
    overlayY = overlayY.clamp(10.0, MediaQuery.of(context).size.height - 180);
    
    return Positioned(
      left: overlayX,
      top: overlayY,
      child: Container(
        width: 180,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFF2F3542).withOpacity(0.95),
          border: Border.all(color: Color(0xFFFFD700), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '${Spell.fromType(selectedSpell!).name} Mana:',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${activeObstacle!.factor1} × ${activeObstacle!.factor2} = ?',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: productOptions.map((product) => 
                GestureDetector(
                  onTap: () => selectProduct(product),
                  child: Container(
                    width: 35,
                    height: 25,
                    decoration: BoxDecoration(
                      color: Color(0xFFFFD700).withOpacity(0.2),
                      border: Border.all(color: Color(0xFFFFD700), width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        '$product',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bognor\'s Fortress'),
        backgroundColor: Color(0xFF2F3542),
        centerTitle: true,
        actions: [
          Container(
            padding: EdgeInsets.all(8),
            child: Center(
              child: Text(
                'Solved: ${obstacles.where((o) => o.solved).length}/${obstacles.length}',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main fortress view
          Expanded(
            child: Container(
              color: Color(0xFF1A1A2E),
              child: Stack(
                children: [
                  // Fortress background pattern
                  CustomPaint(
                    size: Size(double.infinity, double.infinity),
                    painter: FortressPainter(offsetX: offsetX, offsetY: offsetY),
                  ),
                  
                  // Obstacles
                  ...obstacles.map((obstacle) => Positioned(
                    left: obstacle.x + offsetX,
                    top: obstacle.y + offsetY,
                    child: GestureDetector(
                      onTap: () => selectObstacle(obstacle),
                      child: AnimatedBuilder(
                        animation: spellEffectAnimation,
                        builder: (context, child) {
                          bool isActive = obstacle == activeObstacle;
                          bool isAnimating = isActive && spellEffectController.isAnimating;
                          bool correctSpell = selectedSpell == obstacle.requiredSpell;
                          
                          return Transform.scale(
                            scale: isAnimating ? 1.0 + spellEffectAnimation.value * 0.4 : 1.0,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: obstacle.solved 
                                  ? Colors.green.withOpacity(0.3)
                                  : isActive 
                                    ? (correctSpell ? Colors.green.withOpacity(0.6) : Colors.red.withOpacity(0.6))
                                    : Colors.red.withOpacity(0.4),
                                border: Border.all(
                                  color: obstacle.solved 
                                    ? Colors.green 
                                    : isActive 
                                      ? (correctSpell ? Colors.green : Colors.red)
                                      : Spell.fromType(obstacle.requiredSpell).color,
                                  width: isActive ? 3 : 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    obstacle.solved 
                                      ? Icons.check 
                                      : Spell.fromType(obstacle.requiredSpell).icon,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  Text(
                                    '${obstacle.factor1}×${obstacle.factor2}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  )),
                  
                  // Player character
                  Positioned(
                    left: playerX + offsetX,
                    top: playerY + offsetY,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(0xFFFFD700),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        Icons.person,
                        color: Color(0xFF2F3542),
                        size: 20,
                      ),
                    ),
                  ),
                  
                  // Movement controls
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Column(
                      children: [
                        // Up arrow
                        Container(
                          margin: EdgeInsets.only(bottom: 5),
                          child: FloatingActionButton(
                            mini: true,
                            onPressed: () => movePlayer(0, -50),
                            backgroundColor: Color(0xFFFFD700),
                            child: Icon(Icons.keyboard_arrow_up, color: Color(0xFF2F3542)),
                          ),
                        ),
                        Row(
                          children: [
                            // Left arrow
                            Container(
                              margin: EdgeInsets.only(right: 5),
                              child: FloatingActionButton(
                                mini: true,
                                onPressed: () => movePlayer(-50, 0),
                                backgroundColor: Color(0xFFFFD700),
                                child: Icon(Icons.keyboard_arrow_left, color: Color(0xFF2F3542)),
                              ),
                            ),
                            // Right arrow
                            FloatingActionButton(
                              mini: true,
                              onPressed: () => movePlayer(50, 0),
                              backgroundColor: Color(0xFFFFD700),
                              child: Icon(Icons.keyboard_arrow_right, color: Color(0xFF2F3542)),
                            ),
                          ],
                        ),
                        // Down arrow
                        Container(
                          margin: EdgeInsets.only(top: 5),
                          child: FloatingActionButton(
                            mini: true,
                            onPressed: () => movePlayer(0, 50),
                            backgroundColor: Color(0xFFFFD700),
                            child: Icon(Icons.keyboard_arrow_down, color: Color(0xFF2F3542)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Product selection overlay
                  buildProductOverlay(),
                  
                  // Status display
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Position: (${playerX.toInt()}, ${playerY.toInt()})',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          if (selectedSpell != null)
                            Text(
                              'Selected: ${Spell.fromType(selectedSpell!).name}',
                              style: TextStyle(color: Spell.fromType(selectedSpell!).color, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Persistent spell bar
          buildSpellBar(),
        ],
      ),
    );
  }
}

class FortressPainter extends CustomPainter {
  final double offsetX, offsetY;
  
  FortressPainter({required this.offsetX, required this.offsetY});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..strokeWidth = 1;
    
    // Draw grid pattern for fortress floor
    for (int i = -50; i <= 50; i++) {
      double x = i * 50 + offsetX;
      double y = i * 50 + offsetY;
      
      if (x >= -100 && x <= size.width + 100) {
        canvas.drawLine(
          Offset(x, -100),
          Offset(x, size.height + 100),
          paint,
        );
      }
      
      if (y >= -100 && y <= size.height + 100) {
        canvas.drawLine(
          Offset(-100, y),
          Offset(size.width + 100, y),
          paint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}