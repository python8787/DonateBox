import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A frosted glass card widget — the core of the DonateBox UI.
///
/// Uses BackdropFilter for real blur effect over gradient backgrounds.
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.borderRadius = AppTheme.radiusMedium,
    this.blur = 20.0,
    this.opacity = 0.1,
    this.padding = const EdgeInsets.all(AppTheme.spacingLg),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: opacity),
                  Colors.white.withValues(alpha: opacity * 0.5),
                ],
              ),
              border: Border.all(
                color: AppTheme.glassBorder,
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
