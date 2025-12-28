/// ComfyUI Reroute Node Widget - Visual representation of reroute nodes.
///
/// Reroute nodes are small circular connectors that allow routing
/// edges through intermediate points for cleaner layouts.
library;

import 'package:flutter/material.dart';

import '../core/graph/comfy_graph.dart';
import '../core/nodes/reroute_node.dart';
import '../core/nodes/slot_types.dart';

/// Size of the reroute node.
const double kRerouteNodeSize = 24.0;

/// Size of the connection dot.
const double kRerouteDotSize = 12.0;

/// Widget for rendering a reroute node.
class ComfyRerouteWidget extends StatelessWidget {
  /// The reroute node to render.
  final ComfyNode node;

  /// The graph containing this node.
  final ComfyGraph graph;

  /// Whether this node is selected.
  final bool isSelected;

  /// Whether this node is being hovered.
  final bool isHovered;

  /// Whether this node is currently executing.
  final bool isExecuting;

  /// Callback when node is tapped.
  final VoidCallback? onTap;

  /// Callback when node dragging starts.
  final VoidCallback? onDragStart;

  /// Callback when node is being dragged.
  final void Function(Offset delta)? onDragUpdate;

  /// Callback when node dragging ends.
  final VoidCallback? onDragEnd;

  /// Callback when connection starts from this node.
  final void Function(bool isOutput)? onConnectionStart;

  const ComfyRerouteWidget({
    super.key,
    required this.node,
    required this.graph,
    this.isSelected = false,
    this.isHovered = false,
    this.isExecuting = false,
    this.onTap,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onConnectionStart,
  });

  @override
  Widget build(BuildContext context) {
    // Get slot type for coloring
    final slotType = getRerouteSlotType(node, graph);
    final color = slotType.color;

    return GestureDetector(
      onTap: onTap,
      onPanStart: onDragStart != null ? (_) => onDragStart!() : null,
      onPanUpdate: onDragUpdate != null
          ? (details) => onDragUpdate!(details.delta)
          : null,
      onPanEnd: onDragEnd != null ? (_) => onDragEnd!() : null,
      child: SizedBox(
        width: kRerouteNodeSize,
        height: kRerouteNodeSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            _RerouteBackground(
              color: color,
              isSelected: isSelected,
              isHovered: isHovered,
              isExecuting: isExecuting,
            ),
            // Center dot
            _RerouteDot(
              color: color,
              isSelected: isSelected,
            ),
            // Input connection area (left side)
            Positioned(
              left: 0,
              child: _ConnectionArea(
                isOutput: false,
                onConnectionStart: onConnectionStart,
              ),
            ),
            // Output connection area (right side)
            Positioned(
              right: 0,
              child: _ConnectionArea(
                isOutput: true,
                onConnectionStart: onConnectionStart,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Background circle of the reroute node.
class _RerouteBackground extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final bool isHovered;
  final bool isExecuting;

  const _RerouteBackground({
    required this.color,
    required this.isSelected,
    required this.isHovered,
    required this.isExecuting,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: kRerouteNodeSize,
      height: kRerouteNodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getBackgroundColor(),
        border: Border.all(
          color: _getBorderColor(),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (isSelected || isHovered)
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          if (isExecuting)
            BoxShadow(
              color: Colors.green.withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 4,
            ),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    if (isExecuting) {
      return const Color(0xFF2a2a2a);
    }
    if (isHovered) {
      return const Color(0xFF3a3a3a);
    }
    return const Color(0xFF2d2d2d);
  }

  Color _getBorderColor() {
    if (isSelected) {
      return Colors.white;
    }
    if (isHovered) {
      return color.withOpacity(0.8);
    }
    return color.withOpacity(0.5);
  }
}

/// Center dot of the reroute node.
class _RerouteDot extends StatelessWidget {
  final Color color;
  final bool isSelected;

  const _RerouteDot({
    required this.color,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kRerouteDotSize,
      height: kRerouteDotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: isSelected ? Colors.white : color.withOpacity(0.8),
          width: 1.5,
        ),
      ),
    );
  }
}

/// Invisible connection area for starting connections.
class _ConnectionArea extends StatelessWidget {
  final bool isOutput;
  final void Function(bool isOutput)? onConnectionStart;

  const _ConnectionArea({
    required this.isOutput,
    this.onConnectionStart,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: onConnectionStart != null
          ? (_) => onConnectionStart!(isOutput)
          : null,
      child: Container(
        width: kRerouteNodeSize / 2,
        height: kRerouteNodeSize,
        color: Colors.transparent,
      ),
    );
  }
}

/// Compact reroute widget for inline display.
class ComfyRerouteCompact extends StatelessWidget {
  /// Slot type for coloring.
  final SlotType slotType;

  /// Whether selected.
  final bool isSelected;

  /// Size of the widget.
  final double size;

  const ComfyRerouteCompact({
    super.key,
    this.slotType = SlotType.any,
    this.isSelected = false,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final color = slotType.color;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2d2d2d),
        border: Border.all(
          color: isSelected ? Colors.white : color.withOpacity(0.6),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.5,
          height: size * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Painter for drawing reroute connection points.
class RerouteConnectionPainter extends CustomPainter {
  /// Slot type for coloring.
  final SlotType slotType;

  /// Whether input side is connected.
  final bool inputConnected;

  /// Whether output side is connected.
  final bool outputConnected;

  RerouteConnectionPainter({
    required this.slotType,
    required this.inputConnected,
    required this.outputConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = slotType.color;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw main circle
    final bgPaint = Paint()
      ..color = const Color(0xFF2d2d2d)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, bgPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius - 0.75, borderPaint);

    // Draw center dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.4, dotPaint);

    // Draw connection indicators
    if (inputConnected) {
      _drawConnectionIndicator(canvas, center, radius, true, color);
    }
    if (outputConnected) {
      _drawConnectionIndicator(canvas, center, radius, false, color);
    }
  }

  void _drawConnectionIndicator(
    Canvas canvas,
    Offset center,
    double radius,
    bool isInput,
    Color color,
  ) {
    final indicatorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final x = isInput ? center.dx - radius : center.dx + radius;
    canvas.drawCircle(
      Offset(x, center.dy),
      3,
      indicatorPaint,
    );
  }

  @override
  bool shouldRepaint(RerouteConnectionPainter oldDelegate) {
    return slotType != oldDelegate.slotType ||
        inputConnected != oldDelegate.inputConnected ||
        outputConnected != oldDelegate.outputConnected;
  }
}

/// Icon for reroute nodes in menus/toolbars.
class RerouteNodeIcon extends StatelessWidget {
  /// Size of the icon.
  final double size;

  /// Color of the icon.
  final Color? color;

  const RerouteNodeIcon({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).iconTheme.color ?? Colors.white;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RerouteIconPainter(color: iconColor),
      ),
    );
  }
}

class _RerouteIconPainter extends CustomPainter {
  final Color color;

  _RerouteIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    // Draw outer circle
    final outerPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius, outerPaint);

    // Draw inner dot
    final innerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.4, innerPaint);

    // Draw connection lines
    final linePaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Left line
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(center.dx - radius, center.dy),
      linePaint,
    );

    // Right line
    canvas.drawLine(
      Offset(center.dx + radius, center.dy),
      Offset(size.width, center.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_RerouteIconPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
