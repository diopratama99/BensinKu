import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({
    super.key,
    required this.child,
    this.assetPath,
    this.topPadding = 0,
  });

  final Widget child;
  final String? assetPath;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
                colors: [
                  cs.primaryContainer.withValues(alpha: 0.7),
                  cs.primaryContainer.withValues(alpha: 0.2),
                  cs.surface,
                ],
              ),
            ),
          ),
        ),
        if (assetPath != null)
          Positioned(
            left: -30,
            right: -30,
            top: topPadding,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.4,
                child: SvgPicture.asset(
                  assetPath!,
                  fit: BoxFit.cover,
                  height: 240,
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class BrandPanel extends StatelessWidget {
  const BrandPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class IntroHeroCard extends StatelessWidget {
  const IntroHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.assetPath,
  });

  final String title;
  final String subtitle;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.88, end: 1),
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary,
              cs.secondary,
              const Color(0xFF1A7A62),
            ],
            stops: const [0.0, 0.6, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.30),
              blurRadius: 28,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SvgPicture.asset(
                assetPath,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'BensinKu',
                style: TextStyle(
                  color: cs.onPrimary.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
