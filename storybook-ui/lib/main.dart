import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:turn_page_transition/turn_page_transition.dart';

void main() => runApp(const StorybookApp());

// Colors
const kPurple = Color(0xFF1a0a2e);
const kGold = Color(0xFFd4a843);
const kParchment = Color(0xFFf4e4c1);
const kLeatherBrown = Color(0xFF5c3a1e);
const kDarkBrown = Color(0xFF2d1810);

class StorybookApp extends StatelessWidget {
  const StorybookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Bognor's Curse",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: kPurple),
      home: const StorybookFlow(),
    );
  }
}

class StorybookFlow extends StatefulWidget {
  const StorybookFlow({super.key});

  @override
  State<StorybookFlow> createState() => _StorybookFlowState();
}

class _StorybookFlowState extends State<StorybookFlow>
    with TickerProviderStateMixin {
  int? _selectedAvatar;
  late TurnPageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = TurnPageController(
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TurnPageView.builder(
        controller: _pageController,
        itemCount: 5,
        useOnTap: true,
        useOnSwipe: true,
        overleafColorBuilder: (index) {
          // Back of cover page = dark leather brown
          if (index == 0) return const Color(0xFF3a2010);
          // Back of inner pages = aged parchment
          return const Color(0xFFd4c4a0);
        },
        animationTransitionPoint: 0.5,
        itemBuilder: (context, index) {
          switch (index) {
            case 0:
              return const BookCoverContent();
            case 1:
              return AvatarSelectionPage(
                selectedAvatar: _selectedAvatar,
                onSelectAvatar: (i) => setState(() => _selectedAvatar = i),
                onNext: () => _pageController.nextPage(),
              );
            case 2:
              return const StoryPage(
                text: 'Long ago, the village of Thornhaven thrived under the protection of ancient magic...',
                dropCap: 'L', pageNum: 1, totalPages: 3,
              );
            case 3:
              return const StoryPage(
                text: 'But the dark wizard Bognor cast a terrible curse, scattering the sacred multiplication spells across the land...',
                dropCap: 'B', pageNum: 2, totalPages: 3,
              );
            case 4:
              return const StoryPage(
                text: 'Master Aldric, the village\'s last wizard, has chosen YOU to recover the lost spells and break the curse forever.',
                dropCap: 'M', pageNum: 3, totalPages: 3, isLast: true,
              );
            default:
              return const SizedBox();
          }
        },
      ),
    );
  }
}

// ─── BOOK COVER CONTENT ───

class BookCoverContent extends StatefulWidget {
  const BookCoverContent({super.key});

  @override
  State<BookCoverContent> createState() => _BookCoverContentState();
}

class _BookCoverContentState extends State<BookCoverContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kPurple,
      child: Center(
        child: AspectRatio(
          aspectRatio: 0.7,
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6b4226), kLeatherBrown, kDarkBrown, kLeatherBrown, Color(0xFF4a2a10)],
                stops: [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(180), blurRadius: 30, offset: const Offset(5, 10)),
                const BoxShadow(color: Color(0x33d4a843), blurRadius: 2, spreadRadius: 1),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: kGold.withAlpha(140), width: 2),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: kGold.withAlpha(80), width: 1),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: kGold.withAlpha(160), size: 32),
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: const [kGold, Color(0xFFf5e6b8), kGold, Color(0xFFf5e6b8), kGold],
                                stops: [0.0, _shimmerController.value * 0.5, _shimmerController.value,
                                  _shimmerController.value * 0.5 + 0.5, 1.0]
                                    .map((s) => s.clamp(0.0, 1.0)).toList(),
                              ).createShader(bounds);
                            },
                            child: Text(
                              "Bognor's\nCurse",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cinzelDecorative(
                                fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Container(width: 80, height: 2, color: kGold.withAlpha(100)),
                      const SizedBox(height: 12),
                      Text(
                        'A Multiplication Adventure',
                        style: GoogleFonts.crimsonText(fontSize: 14, color: kGold.withAlpha(180), fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        width: 40, height: 20,
                        decoration: BoxDecoration(
                          color: kGold.withAlpha(60), borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kGold.withAlpha(120), width: 1.5),
                        ),
                        child: Center(
                          child: Container(width: 8, height: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: kGold.withAlpha(140))),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Tap or swipe to open',
                        style: GoogleFonts.crimsonText(fontSize: 12, color: kGold.withAlpha(120))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── PARCHMENT BACKGROUND ───

class ParchmentBackground extends StatelessWidget {
  final Widget child;
  const ParchmentBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center, radius: 1.2,
          colors: [kParchment, Color(0xFFe8d4a8), Color(0xFFc9b08a)],
          stops: [0.0, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Colors.transparent, Colors.brown.withAlpha(40), Colors.brown.withAlpha(100)],
                  stops: const [0.5, 0.8, 1.0],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ─── AVATAR SELECTION ───

class AvatarSelectionPage extends StatelessWidget {
  final int? selectedAvatar;
  final ValueChanged<int> onSelectAvatar;
  final VoidCallback onNext;

  const AvatarSelectionPage({
    super.key, required this.selectedAvatar, required this.onSelectAvatar, required this.onNext,
  });

  static const _wizardColors = [Color(0xFF6a4c93), Color(0xFF1982c4), Color(0xFF8ac926), Color(0xFFff595e)];
  static const _wizardNames = ['Elara', 'Thornwick', 'Ivy', 'Bramble'];

  @override
  Widget build(BuildContext context) {
    return ParchmentBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Text('Choose Your Wizard',
                style: GoogleFonts.cinzelDecorative(fontSize: 24, fontWeight: FontWeight.bold, color: kDarkBrown)),
              const SizedBox(height: 8),
              Container(width: 60, height: 2, color: kGold),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2, mainAxisSpacing: 20, crossAxisSpacing: 20,
                  childAspectRatio: 0.75, shrinkWrap: true,
                  children: List.generate(4, (i) {
                    final selected = selectedAvatar == i;
                    return GestureDetector(
                      onTap: () => onSelectAvatar(i),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: selected ? kGold : kGold.withAlpha(80), width: selected ? 3 : 2),
                                boxShadow: selected ? [BoxShadow(color: kGold.withAlpha(100), blurRadius: 16, spreadRadius: 2)] : [],
                                color: kParchment.withAlpha(200),
                              ),
                              child: Center(
                                child: Container(width: 64, height: 64,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: _wizardColors[i]),
                                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_wizardNames[i],
                            style: GoogleFonts.cinzel(fontSize: 14, color: kDarkBrown,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              if (selectedAvatar != null)
                ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDarkBrown, foregroundColor: kGold,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: kGold, width: 1)),
                  ),
                  child: Text('Begin Your Journey', style: GoogleFonts.cinzel(fontSize: 16)),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── STORY PAGE ───

class StoryPage extends StatelessWidget {
  final String text;
  final String dropCap;
  final int pageNum;
  final int totalPages;
  final bool isLast;

  const StoryPage({
    super.key, required this.text, required this.dropCap,
    required this.pageNum, required this.totalPages, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final bodyText = text.substring(1);
    return ParchmentBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            children: [
              const Spacer(flex: 3),
              RichText(
                textAlign: TextAlign.left,
                text: TextSpan(children: [
                  TextSpan(text: dropCap,
                    style: GoogleFonts.cinzelDecorative(fontSize: 64, fontWeight: FontWeight.bold, color: kDarkBrown, height: 0.9)),
                  TextSpan(text: bodyText,
                    style: GoogleFonts.ebGaramond(fontSize: 20, color: kDarkBrown.withAlpha(220), height: 1.7)),
                ]),
              ),
              const Spacer(flex: 2),
              if (isLast)
                ElevatedButton(
                  onPressed: () {
                    showDialog(context: context, builder: (ctx) => AlertDialog(
                      backgroundColor: kParchment,
                      title: Text('Your Training Begins!', style: GoogleFonts.cinzel(color: kDarkBrown)),
                      content: Text('This is where the game would begin...', style: GoogleFonts.ebGaramond(color: kDarkBrown, fontSize: 16)),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: TextStyle(color: kDarkBrown)))],
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDarkBrown, foregroundColor: kGold,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: kGold, width: 1)),
                  ),
                  child: Text('Begin Training', style: GoogleFonts.cinzel(fontSize: 16)),
                ),
              if (!isLast)
                Text('Tap or swipe to turn page',
                  style: GoogleFonts.crimsonText(fontSize: 12, color: kDarkBrown.withAlpha(100), fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              Text('$pageNum / $totalPages',
                style: GoogleFonts.crimsonText(fontSize: 11, color: kDarkBrown.withAlpha(80))),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
