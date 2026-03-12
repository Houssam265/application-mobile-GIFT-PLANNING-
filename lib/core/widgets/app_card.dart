import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTheme.padding),
    this.backgroundColor,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.radiusLarge);

    final card = Card(
      color: backgroundColor ?? theme.colorScheme.surface,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap == null) {
      return ClipRRect(
        borderRadius: radius,
        child: card,
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: card,
      ),
    );
  }
}
