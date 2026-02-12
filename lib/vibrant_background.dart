import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VibrantBackground extends StatelessWidget {
  const VibrantBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        // Top right circle
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  theme.primaryColor.withOpacity(0.3),
                  theme.primaryColor.withOpacity(0.0),
                ],
              ),
            ),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 3.seconds, curve: Curves.easeInOut)
          .move(begin: const Offset(0, 0), end: const Offset(-20, 20), duration: 3.seconds, curve: Curves.easeInOut),
        ),
        
        // Bottom left circle
        Positioned(
          bottom: -50,
          left: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  theme.colorScheme.secondary.withOpacity(0.3),
                  theme.colorScheme.secondary.withOpacity(0.0),
                ],
              ),
            ),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(begin: const Offset(1, 1), end: const Offset(1.3, 1.3), duration: 4.seconds, curve: Curves.easeInOut)
          .move(begin: const Offset(0, 0), end: const Offset(30, -30), duration: 4.seconds, curve: Curves.easeInOut),
        ),
        
        // Middle right circle
        Positioned(
          top: 200,
          right: -50,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.orange.withOpacity(0.2),
                  Colors.orange.withOpacity(0.0),
                ],
              ),
            ),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(begin: const Offset(1, 1), end: const Offset(1.5, 1.5), duration: 5.seconds, curve: Curves.easeInOut)
          .move(begin: const Offset(0, 0), end: const Offset(-40, -40), duration: 5.seconds, curve: Curves.easeInOut),
        ),
      ],
    );
  }
}
