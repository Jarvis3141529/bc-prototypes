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
      description: 'Reserare - Opens sealed passages',
      color: Color(0xFFFFD700),
      icon: Icons.lock_open,
    ),
    Spell(
      type: SpellType.shield,
      name: 'Shield',
      description: 'Aegis Telorum - Magical defense',
      color: Color(0xFF4FC3F7),
      icon: Icons.shield,
    ),
    Spell(
      type: SpellType.fireball,
      name: 'Fireball',
      description: 'Ignisfera - Destructive flames',
      color: Color(0xFFFF5722),
      icon: Icons.local_fire_department,
    ),
    Spell(
      type: SpellType.repair,
      name: 'Repair',
      description: 'Reficere - Mends broken things',
      color: Color(0xFF4CAF50),
      icon: Icons.build,
    ),
    Spell(
      type: SpellType.shatter,
      name: 'Shatter',
      description: 'Frangere - Breaks barriers',
      color: Color(0xFF9C27B0),
      icon: Icons.broken_image,
    ),
    Spell(
      type: SpellType.fogCloud,
      name: 'Fog Cloud',
      description: 'Nebula - Concealing mist',
      color: Color(0xFF607D8B),
      icon: Icons.cloud,
    ),
    Spell(
      type: SpellType.dispel,
      name: 'Dispel',
      description: 'Dissolvere - Removes enchantments',
      color: Color(0xFFE91E63),
      icon: Icons.auto_fix_high,
    ),
  ];
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
        return 'Sentinel Guards\n${factor1}×${factor2} watchers';
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
  Obstacle? selectedObstacle;
  SpellType? selectedSpell;
  bool showSpellMenu = false;
  bool showProductMenu = false;
  List<int> productOptions = [];
  
  // Animation controllers
  late AnimationController spellEffectController;
  late Animation<double> spellEffectAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    spellEffectController = AnimationController(
      duration: Duration(milliseconds: 1000),
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
        if (random.nextBool() && obstacles.length < 20) { // Limit obstacles for prototype
          obstacles.add(Obstacle(
            x: random.nextInt(1000) - 500,
            y: random.nextInt(1000) - 500,
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
          x: random.nextInt(1000) - 500,
          y: random.nextInt(1000) - 500,
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
      playerX = (playerX + dx).clamp(-1000.0, 1000.0);
      playerY = (playerY + dy).clamp(-1000.0, 1000.0);
      
      // Update camera to follow player
      offsetX = -playerX + 200; // Center player on screen
      offsetY = -playerY + 200;
    });
  }
  
  void selectObstacle(Obstacle obstacle) {
    if (obstacle.solved) return;
    
    setState(() {
      selectedObstacle = obstacle;
      showSpellMenu = true;
      selectedSpell = null;
      showProductMenu = false;
    });
  }
  
  void selectSpell(SpellType spell) {
    setState(() {
      selectedSpell = spell;
      showSpellMenu = false;
      
      if (spell == selectedObstacle?.requiredSpell) {
        generateProductOptions();
        showProductMenu = true;
      } else {
        // Wrong spell - show error and reset
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wrong spell! This obstacle requires ${selectedObstacle?.requiredSpell.toString().split('.').last}'),
            backgroundColor: Colors.red,
          ),
        );
        selectedObstacle = null;
        selectedSpell = null;
      }
    });
  }
  
  void generateProductOptions() {
    final correct = selectedObstacle!.product;
    final random = Random();
    productOptions = [correct];
    
    // Add wrong answers
    while (productOptions.length < 4) {
      int wrong = random.nextInt(100) + 1;
      if (!productOptions.contains(wrong)) {
        productOptions.add(wrong);
      }
    }
    
    productOptions.shuffle();
  }
  
  void selectProduct(int product) {
    if (product == selectedObstacle!.product) {
      // Correct! Play animation and solve obstacle
      spellEffectController.forward().then((_) {
        setState(() {
          obstacles = obstacles.map((o) => 
            o == selectedObstacle ? o.copyWith(solved: true) : o
          ).toList();
          
          selectedObstacle = null;
          selectedSpell = null;
          showProductMenu = false;
        });
        spellEffectController.reset();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Success! Obstacle overcome with ${selectedSpell.toString().split('.').last}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Wrong answer
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wrong answer! Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bognor\'s Fortress'),
        backgroundColor: Color(0xFF2F3542),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Main fortress view
          Container(
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
                        bool isSelected = obstacle == selectedObstacle;
                        bool isAnimating = isSelected && spellEffectController.isAnimating;
                        
                        return Transform.scale(
                          scale: isAnimating ? 1.0 + spellEffectAnimation.value * 0.3 : 1.0,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: obstacle.solved 
                                ? Colors.green.withOpacity(0.3)
                                : isSelected 
                                  ? Colors.yellow.withOpacity(0.7)
                                  : Colors.red.withOpacity(0.7),
                              border: Border.all(
                                color: obstacle.solved ? Colors.green : Colors.red,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  obstacle.solved ? Icons.check : Icons.block,
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
              ],
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
          
          // Spell selection menu
          if (showSpellMenu && selectedObstacle != null) ...[
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  width: 400,
                  height: 500,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF2F3542),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Color(0xFFFFD700), width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Choose Your Spell',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        selectedObstacle!.obstacleText,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      SizedBox(height: 20),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          childAspectRatio: 2,
                          children: Spell.allSpells.map((spell) => 
                            GestureDetector(
                              onTap: () => selectSpell(spell.type),
                              child: Container(
                                margin: EdgeInsets.all(5),
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: spell.color.withOpacity(0.2),
                                  border: Border.all(color: spell.color, width: 2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(spell.icon, color: spell.color, size: 24),
                                    SizedBox(height: 5),
                                    Text(
                                      spell.name,
                                      style: TextStyle(
                                        color: spell.color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ).toList(),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          showSpellMenu = false;
                          selectedObstacle = null;
                        }),
                        child: Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          
          // Product selection menu
          if (showProductMenu && selectedObstacle != null) ...[
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  width: 300,
                  height: 400,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF2F3542),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Color(0xFFFFD700), width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Cast ${selectedSpell.toString().split('.').last.toUpperCase()}',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'How much mana?\n${selectedObstacle!.factor1} × ${selectedObstacle!.factor2} = ?',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      SizedBox(height: 20),
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          children: productOptions.map((product) => 
                            GestureDetector(
                              onTap: () => selectProduct(product),
                              child: Container(
                                margin: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Color(0xFFFFD700).withOpacity(0.2),
                                  border: Border.all(color: Color(0xFFFFD700), width: 2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '$product',
                                    style: TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ).toList(),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          showProductMenu = false;
                          selectedObstacle = null;
                          selectedSpell = null;
                        }),
                        child: Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          
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
                    style: TextStyle(color: Colors.white),
                  ),
                  Text(
                    'Obstacles solved: ${obstacles.where((o) => o.solved).length}/${obstacles.length}',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
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