/// Custom background widget that provides a vibrant, animated gradient background.
/// This widget creates a visually appealing backdrop with circular gradient overlays
/// that adapt to the current theme (light/dark mode). It uses radial gradients
/// and positioning to create depth and visual interest across the app's screens.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class VibrantBackground extends StatelessWidget {
  const VibrantBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)]
                      : const [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? const [Color(0x442563EB), Color(0x002563EB)]
                      : const [Color(0x333B82F6), Color(0x003B82F6)],
                ),
              ),
            ),
          ),
          Positioned(
            left: -110,
            bottom: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? const [Color(0x1A10B981), Color(0x0010B981)]
                      : const [Color(0x1510B981), Color(0x0010B981)],
                ),
              ),
            ),
          ),
          Positioned(
            right: -50,
            bottom: 100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? const [Color(0x1A6366F1), Color(0x006366F1)]
                      : const [Color(0x156366F1), Color(0x006366F1)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 200,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDark
                      ? const [Color(0x1AEC4899), Color(0x00EC4899)]
                      : const [Color(0x15EC4899), Color(0x00EC4899)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GridPainter(
                  color: isDark
                      ? const Color(0x0F94A3B8)
                      : const Color(0x0A0F172A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? color;
  final double blur;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.color,
    this.blur = 15,
    this.border,
    this.boxShadow,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Achieving a real "glass" look: very low opacity background + blur
    final defaultColor = color ?? (isDark 
        ? Colors.white.withOpacity(0.03)
        : Colors.white.withOpacity(0.15));
    
    final defaultBorder = border ?? Border.all(
      color: isDark 
          ? Colors.white.withOpacity(0.08)
          : Colors.white.withOpacity(0.3),
      width: 1.0,
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 15),
          ),
          if (!isDark) BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: 1,
            spreadRadius: 1,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: defaultColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: defaultBorder,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(isDark ? 0.05 : 0.2),
                  Colors.white.withOpacity(isDark ? 0.01 : 0.05),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color color;

  const _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 42.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
