import 'dart:ui';
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
                      ? const [Color(0xFF0F172A), Color(0xFF1E293B)]
                      : const [Color(0xFFF0F4F8), Color(0xFFE2E8F0)],
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
                      ? const [Color(0x2210B981), Color(0x0010B981)]
                      : const [Color(0x2210B981), Color(0x0010B981)],
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

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.color,
    this.blur = 15,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Achieving a real "glass" look: very low opacity background + blur
    final defaultColor = color ?? (isDark 
        ? Colors.white.withOpacity(0.05)
        : Colors.white.withOpacity(0.2));
    
    final defaultBorder = border ?? Border.all(
      color: isDark 
          ? Colors.white.withOpacity(0.1)
          : Colors.white.withOpacity(0.4),
      width: 1.5,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: defaultColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: defaultBorder,
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
