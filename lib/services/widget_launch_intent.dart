import 'package:flutter/services.dart';

/// Bridge to the Android side which knows whether MainActivity was
/// launched (or resumed) from the BensinKu home widget's "MULAI
/// PERJALANAN" button.
///
/// Native side consumes its own boolean flag exactly once per intent
/// delivery (cold launch or `onNewIntent`). We mirror that into a
/// per-cycle Dart cache so multiple Dart consumers (HomeShell switches
/// tab, TripMapScreen auto-starts trip) can each see the flag exactly
/// once before the cycle resets.
class WidgetLaunchIntent {
  WidgetLaunchIntent._();

  static const _channel = MethodChannel('bensinku/widget_intent');

  /// Number of consumers expected to ack each pending cycle:
  ///   1. HomeShell — switches active tab to Rute
  ///   2. TripMapScreen — auto-starts the trip
  static const int _consumerCount = 2;

  static bool _cycleActive = false;
  static int _cycleConsumed = 0;

  /// Polls the native flag. If the flag is true (intent delivered),
  /// starts a new "cycle" where up to [_consumerCount] consumers can
  /// observe `true` once each. Subsequent polls within the same cycle
  /// return true without re-asking native.
  ///
  /// Once [_consumerCount] consumers have called, the cycle ends —
  /// the next call hits native again, ready for the next intent.
  static Future<bool> consumePending() async {
    if (_cycleActive) {
      _cycleConsumed++;
      if (_cycleConsumed >= _consumerCount) {
        _cycleActive = false;
        _cycleConsumed = 0;
      }
      return true;
    }
    try {
      final native = await _channel.invokeMethod<bool>(
        'consumePendingTripStart',
      );
      if (native == true) {
        _cycleActive = true;
        _cycleConsumed = 1;
        if (_cycleConsumed >= _consumerCount) {
          _cycleActive = false;
          _cycleConsumed = 0;
        }
        return true;
      }
    } catch (_) {
      // Channel unavailable on non-Android; treat as no pending intent.
    }
    return false;
  }
}
