/// Custom scooped navigation bar widget for the Campusly app.
/// This widget provides a modern, curved navigation bar with smooth animations.
/// It supports multiple navigation items with icons and labels, and handles
/// active state styling with customizable colors. The scooped design gives
/// a distinctive look to the app's bottom navigation.

import 'package:flutter/material.dart';

class ScoopedNavItem {
  final IconData icon;
  final String label;

  const ScoopedNavItem({
    required this.icon,
    required this.label,
  });
}

class ScoopedNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color activeColor;
  final List<ScoopedNavItem> items;

  const ScoopedNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.activeColor,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 70,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.asMap().entries.map((entry) {
          int idx = entry.key;
          ScoopedNavItem item = entry.value;
          bool isSelected = currentIndex == idx;
          
          return GestureDetector(
            onTap: () => onTap(idx),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    color: isSelected ? activeColor : (isDark ? Colors.white54 : Colors.black54),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: activeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
