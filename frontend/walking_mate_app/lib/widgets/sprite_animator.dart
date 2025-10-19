import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:walking_mate_app/models/character_model.dart';
import 'dart:math';

class SpriteAnimator extends StatefulWidget {
  final ui.Image image;
  final List<FrameData> frames;
  final Duration frameDuration;

  const SpriteAnimator({
    super.key,
    required this.image,
    required this.frames,
    this.frameDuration = const Duration(milliseconds: 200),
  });

  @override
  State<SpriteAnimator> createState() => _SpriteAnimatorState();
}

class _SpriteAnimatorState extends State<SpriteAnimator> {
  int _currentFrame = 0;
  Timer? _timer;
  Size _maxFrameSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _calculateMaxFrameSize();
    _startAnimation();
  }

  @override
  void didUpdateWidget(covariant SpriteAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image || widget.frames != oldWidget.frames) {
      _calculateMaxFrameSize();
      _restartAnimation();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateMaxFrameSize() {
    if (widget.frames.isEmpty) {
      _maxFrameSize = Size.zero;
      return;
    }
    double maxWidth = 0;
    double maxHeight = 0;
    for (var frame in widget.frames) {
      maxWidth = max(maxWidth, frame.width.toDouble());
      maxHeight = max(maxHeight, frame.height.toDouble());
    }
    _maxFrameSize = Size(maxWidth, maxHeight);
  }

  void _startAnimation() {
    if (widget.frames.isEmpty) return;
    _timer = Timer.periodic(widget.frameDuration, (timer) {
      if (mounted) {
        setState(() {
          _currentFrame = (_currentFrame + 1) % widget.frames.length;
        });
      }
    });
  }
  
  void _restartAnimation() {
    _timer?.cancel();
    setState(() {
      _currentFrame = 0;
    });
    _startAnimation();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.frames.isEmpty) {
      return const SizedBox.expand();
    }
    
    return CustomPaint(
      painter: _SpritePainter(
        image: widget.image,
        frame: widget.frames[_currentFrame],
        maxFrameSize: _maxFrameSize,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SpritePainter extends CustomPainter {
  final ui.Image image;
  final FrameData frame;
  final Size maxFrameSize;

  _SpritePainter({
    required this.image,
    required this.frame,
    required this.maxFrameSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (maxFrameSize == Size.zero) return;

    final srcRect = Rect.fromLTWH(
      frame.x.toDouble(),
      frame.y.toDouble(),
      frame.width.toDouble(),
      frame.height.toDouble(),
    );

    final fittedSizes = applyBoxFit(BoxFit.contain, maxFrameSize, size);
    final overallDstSize = fittedSizes.destination;
    final overallDstRect = Rect.fromLTWH(
      (size.width - overallDstSize.width) / 2,
      (size.height - overallDstSize.height) / 2,
      overallDstSize.width,
      overallDstSize.height
    );
    
    final scale = overallDstRect.width / maxFrameSize.width;

    final actualDstSize = Size(frame.width * scale, frame.height * scale);

    final finalDstRect = Rect.fromLTWH(
      overallDstRect.left + (overallDstRect.width - actualDstSize.width) / 2,
      overallDstRect.top + (overallDstRect.height - actualDstSize.height) / 2,
      actualDstSize.width,
      actualDstSize.height,
    );

    canvas.drawImageRect(image, srcRect, finalDstRect, Paint());
  }

  @override
  bool shouldRepaint(covariant _SpritePainter oldDelegate) {
    return oldDelegate.frame != frame || 
           oldDelegate.image != image ||
           oldDelegate.maxFrameSize != maxFrameSize;
  }
}