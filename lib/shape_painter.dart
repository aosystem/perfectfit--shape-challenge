import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:perfectfit/shape_type.dart';

class ShapePainter extends CustomPainter {
  final List<Offset> points;
  final double radiusRatio;
  final double guideOpacity;
  final bool isShowingGuide;
  final ShapeType shapeType;
  final double? score;
  final Function(int green, int blue, int red, int total, Set<int> covered)? onResult;

  ShapePainter({
    required this.points,
    required this.radiusRatio,
    required this.guideOpacity,
    required this.isShowingGuide,
    required this.shapeType,
    this.score,
    this.onResult,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final targetRadius = (size.width / 2) * radiusRatio;

    double finalOpacity = 0.0;
    bool useDashedLine = false;

    if (score != null) {
      finalOpacity = 0.8;
      useDashedLine = false;
    } else if (guideOpacity > 0 && !isShowingGuide) {
      finalOpacity = guideOpacity * 0.7;
      useDashedLine = false;
    } else if (isShowingGuide) {
      finalOpacity = 0.4;
      useDashedLine = true;
    }

    if (finalOpacity > 0) {
      final guidePaint = Paint()
        ..color = Colors.grey.withValues(alpha: finalOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      Path path = _buildShapePath(center, targetRadius);

      if (useDashedLine) {
        _drawDashedPath(canvas, path, guidePaint, 10.0, 8.0);
      } else {
        canvas.drawPath(path, guidePaint);
      }
    }

    _drawUserPoints(canvas, center, targetRadius);

    canvas.drawCircle(center, 6, Paint()..color = Colors.red);
    canvas.drawCircle(
      Offset(center.dx, center.dy - targetRadius),
      8,
      Paint()..color = Colors.grey.withValues(alpha: 0.8),
    );
  }

  Path _buildShapePath(Offset center, double radius) {
    Path path = Path();
    if (shapeType == ShapeType.circle) {
      path.addOval(Rect.fromCircle(center: center, radius: radius));
    } else {
      int sides = _getSidesFromType(shapeType);
      for (int i = 0; i < sides; i++) {
        double angle = -pi / 2 + (2 * pi * i / sides);
        Offset p = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
    }
    return path;
  }

  void _drawUserPoints(Canvas canvas, Offset center, double targetRadius) {
    int greenCount = 0;
    int blueCount = 0;
    int redCount = 0;
    Set<int> coveredAngles = {};
    const double tolerance = 0.03;

    if (points.isNotEmpty) {
      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        final vector = p - center;
        final theta = atan2(vector.dy, vector.dx);

        final targetDist = _getTargetDistance(theta, targetRadius, shapeType);
        final error = vector.distance - targetDist;
        final errorRatio = error.abs() / targetDist;

        int angleDeg = ((theta * 180 / pi).toInt() + 180) % 360;
        coveredAngles.add(angleDeg);

        Color lineColor;
        if (errorRatio <= tolerance) {
          lineColor = Colors.greenAccent;
          greenCount++;
        } else {
          lineColor = error < 0 ? Colors.blueAccent : Colors.redAccent;
          error < 0 ? blueCount++ : redCount++;
        }

        if (i > 0) {
          final Offset p1 = points[i - 1];
          final Offset p2 = points[i];

          final glowPaint = Paint()
            ..color = lineColor.withValues(alpha: 0.5)
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 10.0
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

          canvas.drawLine(p1, p2, glowPaint);

          final linePaint = Paint()
            ..color = lineColor
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 5.0
            ..style = PaintingStyle.stroke;

          canvas.drawLine(p1, p2, linePaint);
        }
      }
    }

    if (onResult != null && points.length >= 10) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onResult!(greenCount, blueCount, redCount, points.length, coveredAngles);
      });
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dashWidth, double dashSpace) {
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double nextDistance = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, nextDistance), paint);
        distance = nextDistance + dashSpace;
      }
    }
  }

  int _getSidesFromType(ShapeType type) {
    switch (type) {
      case ShapeType.circle: return 0;
      case ShapeType.triangle: return 3;
      case ShapeType.square: return 4;
      case ShapeType.pentagon: return 5;
      case ShapeType.hexagon: return 6;
      case ShapeType.heptagon: return 7;
      case ShapeType.octagon: return 8;
      case ShapeType.nonagon: return 9;
      case ShapeType.decagon: return 10;
    }
  }

  double _getTargetDistance(double theta, double baseRadius, ShapeType type) {
    if (type == ShapeType.circle) return baseRadius;

    int sides = _getSidesFromType(type);
    double offset = pi / 2;
    double angle = (theta + offset) % (2 * pi / sides);
    if (angle < 0) angle += (2 * pi / sides);

    double phi = angle - (pi / sides);
    double apothem = baseRadius * cos(pi / sides);
    return apothem / cos(phi);
  }

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) => true;
}
