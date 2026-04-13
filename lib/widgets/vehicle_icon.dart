import 'package:flutter/material.dart';
import '../data/models.dart';

class VehicleIcon extends StatelessWidget {
  final VehicleType type;
  final double size;

  const VehicleIcon({
    super.key,
    required this.type,
    this.size = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMotor = type == VehicleType.motor;
    final icon = isMotor ? Icons.two_wheeler_rounded : Icons.directions_car_filled_rounded;

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.35), // slightly squircle
      ),
      child: Icon(
        icon,
        color: cs.primary,
        size: size * 0.55,
      ),
    );
  }
}
