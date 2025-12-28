/// ComfyEdge Widget - Custom edge widget for ComfyUI-style connections.
///
/// Renders edges with:
/// - Type-based coloring (matching slot types)
/// - Bezier curve (default), step, smoothstep, or straight styles
/// - Animation support
/// - Selection highlighting
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:xyflow_flutter/xyflow_flutter.dart';

import '../core/nodes/slot_types.dart';
import '../core/graph/comfy_graph.dart';

/// Edge type constants for ComfyUI.
class ComfyEdgeType {
  ComfyEdgeType._();

  /// Default bezier curve.
  static const String bezier = 'default';

  /// Step edge with right angles.
  static const String step = 'step';

  /// Smooth step with rounded corners.
  static const String smoothStep = 'smoothstep';

  /// Straight line.
  static const String straight = 'straight';
}

/// Data class passed to ComfyEdgeWidget.
class ComfyEdgeData {
  /// The ComfyEdge instance.
  final ComfyEdge edge;

  /// The edge style type.
  final String edgeType;

  /// Whether the edge is animated.
  final bool animated;

  const ComfyEdgeData({
    required this.edge,
    this.edgeType = ComfyEdgeType.bezier,
    this.animated = false,
  });
}

/// Custom edge widget for ComfyUI-style connections.
class ComfyEdgeWidget extends StatelessWidget {
  /// Creates a ComfyEdge widget.
  const ComfyEdgeWidget({
    super.key,
    required this.props,
  });

  /// The edge props from xyflow.
  final EdgeProps<ComfyEdgeData> props;

  @override
  Widget build(BuildContext context) {
    final data = props.data;
    final slotType = data?.edge.type ?? SlotType.any;
    final edgeType = data?.edgeType ?? ComfyEdgeType.bezier;
    final animated = props.animated || (data?.animated ?? false);

    // Get color from slot type
    final color = props.selected
        ? Colors.white
        : slotType.color;

    // Calculate the path
    final path = _calculatePath(edgeType);

    return CustomPaint(
      painter: _ComfyEdgePainter(
        path: path.path,
        color: color,
        strokeWidth: props.selected ? 3.0 : 2.0,
        animated: animated,
        selected: props.selected,
        glowColor: slotType.color,
      ),
      size: Size.infinite,
    );
  }

  EdgePath _calculatePath(String edgeType) {
    final srcPos = _toEdgePosition(props.sourcePosition);
    final tgtPos = _toEdgePosition(props.targetPosition);

    switch (edgeType) {
      case ComfyEdgeType.straight:
        return StraightEdgePath.getStraightPath(
          sourceX: props.sourceX,
          sourceY: props.sourceY,
          targetX: props.targetX,
          targetY: props.targetY,
        );
      case ComfyEdgeType.step:
        return StepEdgePath.getStepPath(
          sourceX: props.sourceX,
          sourceY: props.sourceY,
          targetX: props.targetX,
          targetY: props.targetY,
          sourcePosition: srcPos,
          targetPosition: tgtPos,
        );
      case ComfyEdgeType.smoothStep:
        return SmoothStepEdgePath.getSmoothStepPath(
          sourceX: props.sourceX,
          sourceY: props.sourceY,
          targetX: props.targetX,
          targetY: props.targetY,
          sourcePosition: srcPos,
          targetPosition: tgtPos,
        );
      case ComfyEdgeType.bezier:
      default:
        return BezierEdgePath.getBezierPath(
          sourceX: props.sourceX,
          sourceY: props.sourceY,
          targetX: props.targetX,
          targetY: props.targetY,
          sourcePosition: srcPos,
          targetPosition: tgtPos,
        );
    }
  }

  EdgePosition _toEdgePosition(Position position) {
    switch (position) {
      case Position.left:
        return EdgePosition.left;
      case Position.right:
        return EdgePosition.right;
      case Position.top:
        return EdgePosition.top;
      case Position.bottom:
        return EdgePosition.bottom;
    }
  }
}

/// Custom painter for ComfyUI-style edges.
class _ComfyEdgePainter extends CustomPainter {
  _ComfyEdgePainter({
    required this.path,
    required this.color,
    this.strokeWidth = 2.0,
    this.animated = false,
    this.selected = false,
    this.glowColor,
  });

  final Path path;
  final Color color;
  final double strokeWidth;
  final bool animated;
  final bool selected;
  final Color? glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw glow effect when selected
    if (selected && glowColor != null) {
      final glowPaint = Paint()
        ..color = glowColor!.withValues(alpha: 0.3)
        ..strokeWidth = strokeWidth + 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, glowPaint);
    }

    // Main edge stroke
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (animated) {
      // Draw dashed animated line
      _drawDashedPath(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final pathMetrics = path.computeMetrics();
    const dashLength = 10.0;
    const gapLength = 5.0;

    for (final metric in pathMetrics) {
      double distance = 0;
      bool draw = true;

      while (distance < metric.length) {
        final length = draw ? dashLength : gapLength;
        final extractPath = metric.extractPath(
          distance,
          (distance + length).clamp(0, metric.length),
        );

        if (draw) {
          canvas.drawPath(extractPath, paint);
        }

        distance += length;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ComfyEdgePainter oldDelegate) {
    return path != oldDelegate.path ||
        color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        animated != oldDelegate.animated ||
        selected != oldDelegate.selected;
  }
}

/// Standalone edge widget for use outside of xyflow context.
class ComfyEdgeStandalone extends StatelessWidget {
  /// Creates a standalone ComfyEdge widget.
  const ComfyEdgeStandalone({
    super.key,
    required this.sourceX,
    required this.sourceY,
    required this.targetX,
    required this.targetY,
    this.slotType = SlotType.any,
    this.edgeType = ComfyEdgeType.bezier,
    this.selected = false,
    this.animated = false,
  });

  final double sourceX;
  final double sourceY;
  final double targetX;
  final double targetY;
  final SlotType slotType;
  final String edgeType;
  final bool selected;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final path = _calculatePath();
    final color = selected ? Colors.white : slotType.color;

    return CustomPaint(
      painter: _ComfyEdgePainter(
        path: path.path,
        color: color,
        strokeWidth: selected ? 3.0 : 2.0,
        animated: animated,
        selected: selected,
        glowColor: slotType.color,
      ),
      size: Size.infinite,
    );
  }

  EdgePath _calculatePath() {
    switch (edgeType) {
      case ComfyEdgeType.straight:
        return StraightEdgePath.getStraightPath(
          sourceX: sourceX,
          sourceY: sourceY,
          targetX: targetX,
          targetY: targetY,
        );
      case ComfyEdgeType.step:
        return StepEdgePath.getStepPath(
          sourceX: sourceX,
          sourceY: sourceY,
          targetX: targetX,
          targetY: targetY,
          sourcePosition: EdgePosition.right,
          targetPosition: EdgePosition.left,
        );
      case ComfyEdgeType.smoothStep:
        return SmoothStepEdgePath.getSmoothStepPath(
          sourceX: sourceX,
          sourceY: sourceY,
          targetX: targetX,
          targetY: targetY,
          sourcePosition: EdgePosition.right,
          targetPosition: EdgePosition.left,
        );
      case ComfyEdgeType.bezier:
      default:
        return BezierEdgePath.getBezierPath(
          sourceX: sourceX,
          sourceY: sourceY,
          targetX: targetX,
          targetY: targetY,
          sourcePosition: EdgePosition.right,
          targetPosition: EdgePosition.left,
        );
    }
  }
}

/// Extension to help with edge type conversion.
extension EdgeTypeExtension on String {
  /// Convert to xyflow edge type.
  String toXYFlowEdgeType() {
    switch (this) {
      case ComfyEdgeType.bezier:
        return EdgeTypes.defaultEdge;
      case ComfyEdgeType.step:
        return EdgeTypes.step;
      case ComfyEdgeType.smoothStep:
        return EdgeTypes.smoothStep;
      case ComfyEdgeType.straight:
        return EdgeTypes.straight;
      default:
        return EdgeTypes.defaultEdge;
    }
  }
}
