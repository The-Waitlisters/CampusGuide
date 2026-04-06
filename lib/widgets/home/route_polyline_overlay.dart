import 'dart:math' show pi, log, sin, pow, cos;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/directions/transport_mode_strategy.dart';

/// Draws route legs as a [CustomPaint] overlay sitting directly above the
/// Google Map widget.
///
/// This completely bypasses [google_maps_flutter_web]'s broken polyline
/// rendering layer.  Screen coordinates are computed synchronously using
/// a Mercator projection derived from the current [CameraPosition] — no
/// platform-channel calls, no async, no freeze.
///
/// Only used on Flutter Web; the GoogleMap `polylines:` param continues to
/// handle rendering on iOS / Android where the plugin works correctly.
class RoutePolylineOverlay extends StatelessWidget {
  const RoutePolylineOverlay({
    super.key,
    required this.legs,
    required this.cameraPosition,
  });

  final List<RouteLeg>  legs;
  final CameraPosition  cameraPosition;

  @override
  Widget build(BuildContext context) {
    if (legs.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return CustomPaint(
            size: size,
            painter: _RoutePainter(
              legs:           legs,
              cameraPosition: cameraPosition,
            ),
          );
        },
      ),
    );
  }
}

// ── painter ──────────────────────────────────────────────────────────────────

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.legs, required this.cameraPosition});

  final List<RouteLeg> legs;
  final CameraPosition cameraPosition;

  // ── Mercator projection ──────────────────────────────────────────────────

  /// Converts a [LatLng] to a logical-pixel [Offset] on the canvas.
  ///
  /// Algorithm: project both the camera target and the point onto the same
  /// Web-Mercator world plane (tile size 256 * 2^zoom), then offset from the
  /// viewport centre by the difference.  Bearing rotation is applied so the
  /// result is correct even when the map is tilted.
  Offset _project(LatLng ll, Size size) {
    const double tileSize = 256.0;
    final double scale = tileSize * pow(2.0, cameraPosition.zoom).toDouble();

    double worldX(double lng) => (lng + 180.0) / 360.0 * scale;
    double worldY(double lat) {
      final s = sin(lat * pi / 180.0);
      return (0.5 - log((1.0 + s) / (1.0 - s)) / (4.0 * pi)) * scale;
    }

    final dx = worldX(ll.longitude) - worldX(cameraPosition.target.longitude);
    final dy = worldY(ll.latitude)  - worldY(cameraPosition.target.latitude);

    final b = cameraPosition.bearing * pi / 180.0;
    return Offset(
      size.width  / 2.0 + dx * cos(-b) - dy * sin(-b),
      size.height / 2.0 + dx * sin(-b) + dy * cos(-b),
    );
  }

  // ── paint ────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    for (final leg in legs) {
      final points = leg.polylinePoints
          .map((ll) => _project(ll, size))
          .toList(growable: false);

      if (points.length < 2) continue;

      final color = _colorForLeg(leg);
      final width = leg.legMode == LegMode.walking ? 5.0 : 7.0;

      final paint = Paint()
        ..color       = color
        ..strokeWidth = width
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round
        ..style       = PaintingStyle.stroke;

      if (leg.legMode == LegMode.walking) {
        _drawDashed(canvas, points, paint);
      } else {
        final path = Path()..moveTo(points[0].dx, points[0].dy);
        for (int j = 1; j < points.length; j++) {
          path.lineTo(points[j].dx, points[j].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  /// Draws a dashed polyline (dash 8 px, gap 8 px).
  void _drawDashed(Canvas canvas, List<Offset> points, Paint paint) {
    const double dashLen = 8.0;
    const double gapLen  = 8.0;

    double carry   = 0;
    bool   dashing = true;

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final dx     = p1.dx - p0.dx;
      final dy     = p1.dy - p0.dy;
      final segLen = (p1 - p0).distance;
      if (segLen == 0) continue;

      double pos = carry;

      while (pos < segLen) {
        final segEnd = dashing ? dashLen : gapLen;
        final t0     = pos / segLen;
        final t1     = ((pos + segEnd) / segLen).clamp(0.0, 1.0);

        if (dashing) {
          canvas.drawLine(
            Offset(p0.dx + dx * t0, p0.dy + dy * t0),
            Offset(p0.dx + dx * t1, p0.dy + dy * t1),
            paint,
          );
        }

        pos     += segEnd;
        dashing  = !dashing;
      }

      carry = pos - segLen;
    }
  }

  static Color _colorForLeg(RouteLeg leg) {
    switch (leg.legMode) {
      case LegMode.walking:  return const Color(0xFF555555);
      case LegMode.cycling:  return const Color(0xFF34A853);
      case LegMode.driving:  return const Color(0xFF1A73E8);
      case LegMode.shuttle:  return const Color(0xFF912338);
      case LegMode.transit:  return leg.transitColor ?? const Color(0xFF1A73E8);
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.legs           != legs ||
      old.cameraPosition != cameraPosition;
}
