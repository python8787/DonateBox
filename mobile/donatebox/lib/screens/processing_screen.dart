import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Full-screen processing overlay shown while the payment
/// is being verified with the backend.
///
/// Features:
/// - Animated pulsing ring
/// - Rotating gradient arc
/// - Status text updates
class ProcessingScreen extends StatefulWidget {
  final double amount;
  final String currencySymbol;
  final String currency;

  const ProcessingScreen({
    super.key,
    required this.amount,
    required this.currencySymbol,
    required this.currency,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _rotateController;
  late final AnimationController _pulseController;
  int _statusIndex = 0;

  final List<String> _statusMessages = [
    'Processing your donation...',
    'Verifying payment...',
    'Almost there...',
  ];

  @override
  void initState() {
    super.initState();

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Cycle through status messages
    _cycleStatus();
  }

  Future<void> _cycleStatus() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _statusIndex = (_statusIndex + 1) % _statusMessages.length;
        });
      }
    }
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated processing indicator
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing outer ring
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final scale = 1.0 + _pulseController.value * 0.15;
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.primaryPurple.withValues(
                                      alpha: 0.2 + _pulseController.value * 0.1,
                                    ),
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Rotating gradient arc
                        AnimatedBuilder(
                          animation: _rotateController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotateController.value * 2 * pi,
                              child: CustomPaint(
                                size: const Size(110, 110),
                                painter: _ArcPainter(),
                              ),
                            );
                          },
                        ),

                        // Center icon
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.buttonGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.payment_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingXl),

                  // Amount being processed
                  Text(
                    '${widget.currencySymbol}${widget.amount.toStringAsFixed(2)} ${widget.currency}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: AppTheme.spacingLg),

                  // Cycling status message
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      _statusMessages[_statusIndex],
                      key: ValueKey(_statusIndex),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingXxl),

                  // Safety note
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Please do not close the app or press back.\nThis may take a few moments.',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
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

/// Paints a gradient arc for the loading indicator.
class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const gradient = SweepGradient(
      startAngle: 0,
      endAngle: pi * 1.5,
      colors: [
        Colors.transparent,
        AppTheme.primaryPurple,
        AppTheme.accentTeal,
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect.deflate(2),
      0,
      pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
