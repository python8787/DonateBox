import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/glassmorphic_card.dart';

/// Animated success screen shown after a successful donation.
///
/// Features:
/// - Floating particle effect (celebration)
/// - Animated checkmark with elastic bounce
/// - Donation summary
/// - "Make Another" and "Done" buttons
class ThankYouScreen extends StatefulWidget {
  final double amount;
  final String currencySymbol;
  final String currency;
  final String? donorName;
  final String? donationId;

  const ThankYouScreen({
    super.key,
    required this.amount,
    required this.currencySymbol,
    required this.currency,
    this.donorName,
    this.donationId,
  });

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen>
    with TickerProviderStateMixin {
  late final AnimationController _particleController;
  final List<_Particle> _particles = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Generate celebration particles
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 6 + 2,
        speed: _random.nextDouble() * 0.5 + 0.2,
        color: [
          AppTheme.primaryPurple,
          AppTheme.accentTeal,
          AppTheme.accentPink,
          AppTheme.successGreen,
          AppTheme.warningAmber,
        ][_random.nextInt(5)],
      ));
    }
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            // Background
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppTheme.backgroundGradient,
              ),
            ),

            // Floating particles
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return CustomPaint(
                  size: MediaQuery.of(context).size,
                  painter: _ParticlePainter(
                    particles: _particles,
                    progress: _particleController.value,
                  ),
                );
              },
            ),

            // Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Success checkmark
                      _buildCheckmark(),
                      const SizedBox(height: AppTheme.spacingXl),

                      // Thank you text
                      Text(
                        'Thank You${widget.donorName != null ? ', ${widget.donorName}' : ''}!',
                        style: Theme.of(context).textTheme.displayMedium,
                        textAlign: TextAlign.center,
                      ).animate(delay: 400.ms).fadeIn(duration: 500.ms),

                      const SizedBox(height: AppTheme.spacingSm),

                      const Text(
                        'Your generosity makes a difference',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ).animate(delay: 500.ms).fadeIn(duration: 500.ms),

                      const SizedBox(height: AppTheme.spacingXl),

                      // Donation summary card
                      GlassmorphicCard(
                        child: Column(
                          children: [
                            const Text(
                              'Donation Summary',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingMd),
                            Text(
                              '${widget.currencySymbol}${widget.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.accentTeal,
                              ),
                            ),
                            Text(
                              widget.currency,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 14,
                              ),
                            ),
                            if (widget.donationId != null) ...[
                              const SizedBox(height: AppTheme.spacingMd),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: AppTheme.glassWhite,
                                ),
                                child: Text(
                                  'ID: ${widget.donationId!.substring(0, min(8, widget.donationId!.length))}...',
                                  style: const TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ).animate(delay: 600.ms).fadeIn(duration: 500.ms).slideY(
                            begin: 0.1,
                            end: 0,
                            duration: 500.ms,
                          ),

                      const SizedBox(height: AppTheme.spacingXl),

                      // Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            gradient: AppTheme.buttonGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                            icon: const Icon(Icons.favorite, color: Colors.white, size: 20),
                            label: const Text(
                              'Donate Again',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              ),
                            ),
                          ),
                        ),
                      ).animate(delay: 800.ms).fadeIn(duration: 400.ms),

                      const SizedBox(height: AppTheme.spacingMd),

                      TextButton(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 15,
                          ),
                        ),
                      ).animate(delay: 900.ms).fadeIn(duration: 400.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckmark() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.successGreen,
            AppTheme.successGreen.withValues(alpha: 0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.successGreen.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 50,
        color: Colors.white,
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          duration: 600.ms,
          curve: Curves.elasticOut,
        )
        .then()
        .shimmer(
          duration: 1500.ms,
          color: Colors.white.withValues(alpha: 0.3),
        );
  }
}

// ─── Particle System ────────────────────────────────────

class _Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y - progress * p.speed) % 1.0;
      final opacity = (1 - (y - 0.5).abs() * 2).clamp(0.0, 0.6);
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(p.x * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}
