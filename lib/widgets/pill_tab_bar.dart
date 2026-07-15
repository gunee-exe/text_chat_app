import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The 3-pill tab bar (inbox / unread / requests).
class PillTabBar extends StatelessWidget {
  final int selectedIndex;
  final List<String> labels;
  final List<int?> counts; // nullable — only inbox shows a count badge
  final ValueChanged<int> onTabSelected;

  const PillTabBar({
    super.key,
    required this.selectedIndex,
    required this.labels,
    required this.counts,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(labels.length, (i) {
        final isActive = i == selectedIndex;
        final label = labels[i];
        final count = counts[i];

        return Padding(
          padding: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
          child: GestureDetector(
            onTap: () => onTabSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.accentSolid
                    : (isDark
                        ? AppColors.darkCardFill
                        : AppColors.lightCardFill.withAlpha(200)),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count != null ? '$label $count' : label,
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : AppColors.textSecondary(theme.brightness),
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
