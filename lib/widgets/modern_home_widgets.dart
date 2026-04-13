import 'package:flutter/material.dart';

class TopIdentityHeader extends StatelessWidget {
  const TopIdentityHeader({
    super.key,
    required this.title,
    this.leadingIcon = Icons.person,
    this.trailing,
  });

  final String title;
  final IconData leadingIcon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.2),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(leadingIcon, color: cs.onPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
          ),
        ),
        trailing ??
            Icon(
              Icons.notifications_none_rounded,
              color: cs.onSurfaceVariant,
              size: 30,
            ),
      ],
    );
  }
}

class SoftPanel extends StatelessWidget {
  const SoftPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}

class BlendBar extends StatelessWidget {
  const BlendBar({super.key, required this.widthFactor, this.height = 12});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: widthFactor.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF8A3A00),
                  Color(0xFFF6B27A),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class MicroStatCard extends StatelessWidget {
  const MicroStatCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SoftPanel(
      padding: const EdgeInsets.all(16),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: cs.onPrimaryContainer, size: 18),
                ),
              if (icon != null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 8),
            Text(
              caption!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
