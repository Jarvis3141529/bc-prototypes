import 'package:flutter/material.dart';

enum PlaybackMode { autoPlay, loop, scrub }

/// A flipbook animation widget that cycles through frames.
///
/// Frames are built on-demand via [frameBuilder] which receives
/// the frame index and size. This avoids needing actual image assets.
class FlipbookAnimation extends StatefulWidget {
  /// Builds a widget for the given frame index (0-based).
  final Widget Function(int frameIndex, Size size) frameBuilder;

  /// Total number of frames.
  final int frameCount;

  /// Frames per second (ignored in scrub mode).
  final int fps;

  /// Playback mode.
  final PlaybackMode mode;

  /// Display dimensions.
  final double width;
  final double height;

  /// Called when autoPlay finishes.
  final VoidCallback? onComplete;

  const FlipbookAnimation({
    super.key,
    required this.frameBuilder,
    required this.frameCount,
    this.fps = 12,
    this.mode = PlaybackMode.autoPlay,
    this.width = 300,
    this.height = 300,
    this.onComplete,
  });

  @override
  State<FlipbookAnimation> createState() => _FlipbookAnimationState();
}

class _FlipbookAnimationState extends State<FlipbookAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentFrame = 0;
  double _scrubPosition = 0;

  @override
  void initState() {
    super.initState();
    final duration = Duration(
      milliseconds: ((widget.frameCount / widget.fps) * 1000).round(),
    );
    _controller = AnimationController(vsync: this, duration: duration);

    _controller.addListener(_onTick);

    if (widget.mode == PlaybackMode.autoPlay) {
      _controller.forward().then((_) => widget.onComplete?.call());
    } else if (widget.mode == PlaybackMode.loop) {
      _controller.repeat();
    }
  }

  void _onTick() {
    if (widget.mode == PlaybackMode.scrub) return;
    final frame = (_controller.value * (widget.frameCount - 1)).round();
    if (frame != _currentFrame) {
      setState(() => _currentFrame = frame);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDrag(DragUpdateDetails details) {
    if (widget.mode != PlaybackMode.scrub) return;
    setState(() {
      _scrubPosition = (_scrubPosition + details.delta.dx / widget.width)
          .clamp(0.0, 1.0);
      _currentFrame =
          (_scrubPosition * (widget.frameCount - 1)).round();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(widget.width, widget.height);

    Widget content = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF4A3520), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          widget.frameBuilder(_currentFrame, size),
          // Frame counter
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_currentFrame + 1}/${widget.frameCount}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          if (widget.mode == PlaybackMode.scrub)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '← drag →',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.mode == PlaybackMode.scrub) {
      content = GestureDetector(
        onHorizontalDragUpdate: _onHorizontalDrag,
        child: content,
      );
    }

    return content;
  }
}
