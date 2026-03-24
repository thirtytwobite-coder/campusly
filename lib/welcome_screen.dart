import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'login_screen.dart';
import 'vibrant_background.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          const VibrantBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBadge(isDark: isDark)
                      .animate()
                      .fadeIn(duration: 800.ms)
                      .slideY(begin: -0.3, curve: Curves.easeOutQuart),
                  const SizedBox(height: 32),
                  Text(
                    'Your College Life,\nElevated.',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      letterSpacing: -1.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 800.ms)
                      .slideX(begin: -0.1),
                  const SizedBox(height: 16),
                  Text(
                    'The ultimate ecosystem for campus events, club engagement, and professional networking.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 800.ms),
                  const SizedBox(height: 40),
                  
                  // Premium Modern Highlight Card
                  GlassCard(
                    borderRadius: 32,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.flash_on_rounded, color: Colors.blueAccent, size: 28),
                            ).animate(onPlay: (c) => c.repeat(reverse: true))
                             .shimmer(duration: 2.seconds, color: Colors.white30),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'STAY EMPOWERED',
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const Text(
                                    'Real-time Engagement',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Experience a seamless connection with everything happening on campus, from technical workshops to cultural festivals.',
                          style: TextStyle(height: 1.4, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 600.ms, duration: 800.ms).slideY(begin: 0.1),
                  
                  const SizedBox(height: 24),
                  
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _HighlightChip(icon: Icons.event_available_rounded, label: 'Smart Events'),
                      _HighlightChip(icon: Icons.groups_3_rounded, label: 'Dynamic Clubs'),
                      _HighlightChip(icon: Icons.auto_graph_rounded, label: 'Live Analytics'),
                    ],
                  ).animate().fadeIn(delay: 800.ms, duration: 800.ms),
                  
                  const Spacer(),
                  
                  // Bottom Glass Navigation Card
                  GlassCard(
                    borderRadius: 32,
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ready to begin?',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Join the high-performance campus network.',
                                    style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
                                );
                              },
                              child: const Center(
                                child: Text(
                                  'LAUNCH CAMPUSLY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ).animate().scale(delay: 1.seconds, duration: 400.ms, curve: Curves.easeOutBack),
                      ],
                    ),
                  ).animate().fadeIn(delay: 900.ms, duration: 800.ms).slideY(begin: 0.2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBadge extends StatelessWidget {
  final bool isDark;

  const _TopBadge({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? Colors.white24 : const Color(0x220F172A),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.waving_hand_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .rotate(begin: -0.1, end: 0.1, duration: 1.seconds, curve: Curves.easeInOut),
          const SizedBox(width: 8),
          Text(
            'Welcome to Campusly',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HighlightChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.07)
            : Colors.white.withOpacity(0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0x220F172A),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
