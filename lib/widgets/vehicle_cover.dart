import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../app/theme.dart';
import '../data/models.dart';
import '../services/vehicle_assets.dart';

/// Vehicle photo cover. Uses asset if user uploaded; else mono placeholder.
class VehicleCover extends StatelessWidget {
  const VehicleCover({
    super.key,
    required this.vehicle,
    this.height = 120,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = AppEditorial.rCard,
    this.placeholderTone,
  });

  final Vehicle vehicle;
  final double height;
  final double? width;
  final BoxFit fit;
  final double borderRadius;

  /// Background tint when no photo. Defaults to butterSoft.
  final Color? placeholderTone;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: VehicleAssets.resolve(vehicle),
      builder: (context, snap) {
        final asset = snap.data;
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox(
            height: height,
            width: width,
            child: asset != null
                ? Image.asset(
                    asset,
                    fit: fit,
                    errorBuilder: (_, __, ___) => _Placeholder(
                        vehicle: vehicle, tone: placeholderTone),
                  )
                : _Placeholder(vehicle: vehicle, tone: placeholderTone),
          ),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.vehicle, this.tone});

  final Vehicle vehicle;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final isMotor = vehicle.type == VehicleType.motor;
    final bg = tone ?? AppEditorial.butterSoft;
    return Container(
      decoration: BoxDecoration(color: bg),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -10,
            bottom: -8,
            child: Text(
              vehicle.type.dbValue.toUpperCase(),
              style: AppEditorial.mono(
                fontSize: 56,
                fontWeight: FontWeight.w700,
                color: AppEditorial.butterDeep.withValues(alpha: 0.18),
                letterSpacing: -2,
              ),
            ),
          ),
          Icon(
            isMotor
                ? PhosphorIconsRegular.motorcycle
                : PhosphorIconsRegular.car,
            size: 40,
            color: AppEditorial.butterDeep,
          ),
        ],
      ),
    );
  }
}
