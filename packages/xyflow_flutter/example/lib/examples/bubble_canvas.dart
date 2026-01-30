import 'dart:math';
import 'dart:js_interop';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// JS interop for Web Audio sound effects (cherry-picked from robot_grid.dart)
// ═══════════════════════════════════════════════════════════════════════════════

@JS('eval')
external JSAny? _jsEval(JSString code);

abstract final class _Sound {
  static bool _enabled = true;

  static void playSpawn() {
    if (!kIsWeb || !_enabled) return;
    try {
      _jsEval(
        "(function(){var c=new AudioContext(),o=c.createOscillator(),g=c.createGain();"
        "o.type='sine';o.frequency.setValueAtTime(300,c.currentTime);"
        "o.frequency.exponentialRampToValueAtTime(500,c.currentTime+0.06);"
        "o.frequency.exponentialRampToValueAtTime(250,c.currentTime+0.12);"
        "g.gain.setValueAtTime(0.06,c.currentTime);"
        "g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+0.15);"
        "o.connect(g);g.connect(c.destination);o.start();o.stop(c.currentTime+0.15)})()"
            .toJS,
      );
    } catch (_) {}
  }

  static void playBounce(double intensity) {
    if (!kIsWeb || !_enabled) return;
    try {
      final vol = (0.03 + intensity * 0.25).clamp(0.03, 0.28);
      final freq = (100 + intensity * 80).round();
      final dur = (0.12 + intensity * 0.15).toStringAsFixed(2);
      _jsEval(
        "(function(){var c=new AudioContext(),o=c.createOscillator(),n=c.createOscillator(),g=c.createGain();"
        "o.type='sine';n.type='triangle';"
        "o.frequency.setValueAtTime($freq,c.currentTime);"
        "o.frequency.exponentialRampToValueAtTime(40,c.currentTime+$dur);"
        "n.frequency.setValueAtTime(${freq * 2},c.currentTime);"
        "n.frequency.exponentialRampToValueAtTime(30,c.currentTime+${(double.parse(dur) * 0.8).toStringAsFixed(2)});"
        "g.gain.setValueAtTime($vol,c.currentTime);"
        "g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+$dur);"
        "o.connect(g);n.connect(g);g.connect(c.destination);"
        "o.start();n.start();o.stop(c.currentTime+$dur);n.stop(c.currentTime+$dur)})()"
            .toJS,
      );
    } catch (_) {}
  }

  static void playPickup() {
    if (!kIsWeb || !_enabled) return;
    try {
      _jsEval(
        "(function(){var c=new AudioContext(),o=c.createOscillator(),g=c.createGain();"
        "o.type='sine';o.frequency.setValueAtTime(400,c.currentTime);"
        "o.frequency.exponentialRampToValueAtTime(600,c.currentTime+0.05);"
        "g.gain.setValueAtTime(0.04,c.currentTime);"
        "g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+0.08);"
        "o.connect(g);g.connect(c.destination);o.start();o.stop(c.currentTime+0.08)})()"
            .toJS,
      );
    } catch (_) {}
  }

  static void playDrop() {
    if (!kIsWeb || !_enabled) return;
    try {
      _jsEval(
        "(function(){var c=new AudioContext(),o=c.createOscillator(),g=c.createGain();"
        "o.type='sine';o.frequency.setValueAtTime(200,c.currentTime);"
        "o.frequency.exponentialRampToValueAtTime(100,c.currentTime+0.08);"
        "g.gain.setValueAtTime(0.05,c.currentTime);"
        "g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+0.1);"
        "o.connect(g);g.connect(c.destination);o.start();o.stop(c.currentTime+0.1)})()"
            .toJS,
      );
    } catch (_) {}
  }

  static void playThrow(double intensity) {
    if (!kIsWeb || !_enabled) return;
    try {
      final vol = (intensity * 0.08).clamp(0.02, 0.1);
      final freq = (300 + intensity * 400).clamp(300, 700).round();
      _jsEval(
        "(function(){var c=new AudioContext(),o=c.createOscillator(),n=c.createOscillator(),g=c.createGain();"
        "o.type='sine';n.type='sawtooth';"
        "o.frequency.setValueAtTime($freq,c.currentTime);"
        "o.frequency.exponentialRampToValueAtTime(100,c.currentTime+0.2);"
        "n.frequency.setValueAtTime(${freq ~/ 2},c.currentTime);"
        "n.frequency.exponentialRampToValueAtTime(50,c.currentTime+0.15);"
        "g.gain.setValueAtTime($vol,c.currentTime);"
        "g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+0.2);"
        "o.connect(g);n.connect(g);g.connect(c.destination);"
        "o.start();n.start();o.stop(c.currentTime+0.2);n.stop(c.currentTime+0.15)})()"
            .toJS,
      );
    } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Style constants
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class _S {
  static const Color canvasBg = Color(0xFF171717);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceLight = Color(0xFF2A2A2A);
  static const Color border = Color(0xFF333333);
  static const Color textPrimary = Color(0xFFE5E5E5);
  static const Color textSecondary = Color(0xFF8B949E);
  static const double borderRadius = 12.0;
  static const List<Color> accents = [
    Color(0xFF58A6FF), Color(0xFF3FB950), Color(0xFFD2A8FF),
    Color(0xFFF78166), Color(0xFFFF7B72), Color(0xFF79C0FF),
    Color(0xFFF0883E), Color(0xFF56D364),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// Simulation config
// ═══════════════════════════════════════════════════════════════════════════════

class _BubbleSimConfig {
  double maxVelocity = 40;
  double baseFriction = 0.975;
  double highSpeedFriction = 0.94;
  double bounceDamping = 0.45;
  double bounceFriction = 0.85;
  double minVelocity = 0.15;
  double momentumThreshold = 1.5;
  int velocitySamples = 9;
  int sampleWindowMs = 80;
  double boundaryMargin = 18;

  // Particles
  bool particlesEnabled = true;
  int particleCount = 12;
  double particleLifespan = 2.0;
  double particleGravity = 120;
  double pulseDuration = 1.5;
  double pulseSpeed = 300;

  // Grid (spring displacement)
  double gridSize = 40;
  double gridMaxDist = 300;
  double gridPushStrength = 20;
  double gridSpringStiffness = 0.08;
  double gridDamping = 0.75;
  double gridHoverRadius = 160;
  double gridBaseOpacity = 0.15;
  double gridBrightnessRadius = 110;

  double get maxVelPxS => maxVelocity * 1000;
  double get minVelPxS => minVelocity * 1000;
  double get thresholdPxS => momentumThreshold * 1000;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Data classes
// ═══════════════════════════════════════════════════════════════════════════════

enum BubbleLayoutMode { grid, list }

class BubbleItem {
  const BubbleItem({
    required this.id,
    this.imageUrl,
    this.title,
    this.subtitle,
    this.accentColor,
  });
  final String id;
  final String? imageUrl;
  final String? title;
  final String? subtitle;
  final Color? accentColor;
}

typedef BubbleItemBuilder = Widget Function(BubbleItem item, bool isDragging);

class BubbleCanvasDelegate {
  const BubbleCanvasDelegate({
    required this.items,
    this.builder,
    this.bubbleWidth = 200,
    this.bubbleHeight = 240,
    this.listItemHeight = 80,
    this.rowSpacing = 260,
    this.listSpacing = 12,
    this.layoutMode = BubbleLayoutMode.grid,
    this.onLoadMore,
    this.onItemDisclosure,
  });
  final List<BubbleItem> items;
  final BubbleItemBuilder? builder;
  final double bubbleWidth;
  final double bubbleHeight;
  final double listItemHeight;
  final double rowSpacing;
  final double listSpacing;
  final BubbleLayoutMode layoutMode;
  final VoidCallback? onLoadMore;
  final void Function(BubbleItem item)? onItemDisclosure;
}

class _VelocitySample {
  const _VelocitySample(this.position, this.timestamp);
  final Offset position;
  final int timestamp;
}

class _MomentumState {
  _MomentumState({required this.velocity, required this.position});
  Offset velocity;
  Offset position;
}

class _PulseEvent {
  _PulseEvent({required this.center, required this.startTime, required this.color});
  final Offset center;
  final double startTime;
  final Color color;
}

class _Particle {
  _Particle({
    required this.position, required this.velocity, required this.size,
    required this.color, required this.createdAt, required this.lifespan,
    this.shape = 0,
  });
  Offset position;
  Offset velocity;
  final double size;
  final Color color;
  final double createdAt;
  final double lifespan;
  final int shape;
}

class _GridDot {
  _GridDot({required this.ix, required this.iy, required double gridSize})
      : baseX = ix * gridSize,
        baseY = iy * gridSize,
        x = ix * gridSize,
        y = iy * gridSize;
  final int ix, iy;
  final double baseX, baseY;
  double x, y;
  double vx = 0, vy = 0;
  double size = 1;
  double targetSize = 1;
  double brightness = 0;
}

/// Per-bubble physics state tracked by the canvas
class _BubblePhysics {
  _BubblePhysics({
    required this.canvasX,
    required this.canvasY,
    this.accentColor = const Color(0xFF58A6FF),
    this.staggerDelay = 0.0,
  });
  double canvasX;
  double canvasY;
  Color accentColor;
  double staggerDelay;
  bool hasEnteredViewport = false;
  double spawnTime = -1;
  double bounceScale = 1.0;
  double opacity = 0.0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BubbleCanvas widget
// ═══════════════════════════════════════════════════════════════════════════════

class BubbleCanvas extends StatefulWidget {
  const BubbleCanvas({
    super.key,
    required this.delegate,
    this.height = 600,
    this.soundEnabled = true,
    this.showGrid = true,
  });
  final BubbleCanvasDelegate delegate;
  final double height;
  final bool soundEnabled;
  final bool showGrid;

  @override
  State<BubbleCanvas> createState() => _BubbleCanvasState();
}

class _BubbleCanvasState extends State<BubbleCanvas>
    with TickerProviderStateMixin {
  final _BubbleSimConfig _cfg = _BubbleSimConfig();
  final GlobalKey _canvasKey = GlobalKey();

  // Scroll
  double _scrollOffset = 0;
  double _scrollVelocity = 0;
  bool _isScrolling = false;

  // Item drag
  String? _draggingItemId;
  Offset? _dragStartCanvasPos;
  final Map<String, List<_VelocitySample>> _velocitySamples = {};
  final Map<String, _MomentumState> _activeMomentum = {};

  // Per-bubble physics
  final Map<String, _BubblePhysics> _bubblePhysics = {};

  // Physics ticker
  Ticker? _physicsTicker;
  Duration _lastTickerElapsed = Duration.zero;
  double _tickerSeconds = 0;

  // Visual effects
  final List<_PulseEvent> _activePulses = [];
  final List<_Particle> _particles = [];

  // Dynamic grid
  List<_GridDot> _gridDots = [];
  Map<String, _GridDot> _gridMap = {};
  Size? _gridViewportSize;
  Offset? _mousePos;

  // Repaint notifier
  final ValueNotifier<int> _effectsRepaint = ValueNotifier<int>(0);

  // Layout: how many columns fit
  int _columns = 3;
  double _gutterX = 16;

  // Load-more guard
  bool _loadMoreFired = false;

  // ── Expand/collapse state ──
  String? _expandedItemId;        // which item is currently expanding/expanded
  double _expandT = 0;            // 0 = collapsed, 1 = fully expanded
  bool _expanding = true;         // true = opening, false = closing
  List<BubbleItem> _childItems = [];
  final Map<String, _BubblePhysics> _childPhysics = {};
  bool get _isExpanded => _expandedItemId != null;

  /// Home Y of the expanded parent (used for displacement comparison)
  double _expandedParentHomeY = 0;

  /// Total vertical space children occupy (used for displacement + virtual height)
  double get _childDisplacementAmount {
    if (_childItems.isEmpty) return 0;
    return _childItems.length * (_itemHeight + widget.delegate.listSpacing) + 8;
  }

  @override
  void initState() {
    super.initState();
    _Sound._enabled = widget.soundEnabled;
    _physicsTicker = createTicker(_onPhysicsTick)..start();
    _initBubblePositions();
  }

  @override
  void didUpdateWidget(covariant BubbleCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _Sound._enabled = widget.soundEnabled;
    final modeChanged = widget.delegate.layoutMode != oldWidget.delegate.layoutMode;
    if (modeChanged) {
      _bubblePhysics.clear();
      _activeMomentum.clear();
      _scrollOffset = 0;
      _scrollVelocity = 0;
      // Clear expand state on mode change
      _expandedItemId = null;
      _expandT = 0;
      _childItems = [];
      _childPhysics.clear();
    }
    if (widget.delegate.items.length != oldWidget.delegate.items.length || modeChanged) {
      _initBubblePositions();
      _loadMoreFired = false;
    }
  }

  @override
  void dispose() {
    _physicsTicker?.dispose();
    _effectsRepaint.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Layout helpers
  // ══════════════════════════════════════════════════════════════════════════════

  bool get _isList => widget.delegate.layoutMode == BubbleLayoutMode.list;

  void _computeLayout(double viewportWidth) {
    if (_isList) {
      _columns = 1;
      _gutterX = 16;
      return;
    }
    final bw = widget.delegate.bubbleWidth;
    final minGutter = 16.0;
    _columns = max(1, ((viewportWidth - minGutter) / (bw + minGutter)).floor());
    final totalBubblesWidth = _columns * bw;
    _gutterX = (viewportWidth - totalBubblesWidth) / (_columns + 1);
  }

  double get _itemHeight => _isList ? widget.delegate.listItemHeight : widget.delegate.bubbleHeight;
  double get _itemSpacing => _isList ? widget.delegate.listSpacing : widget.delegate.rowSpacing;

  double get _virtualCanvasHeight {
    final items = widget.delegate.items;
    if (items.isEmpty) return widget.height;
    double base;
    if (_isList) {
      base = 20.0 + items.length * (_itemHeight + _itemSpacing);
    } else {
      final rows = (items.length / _columns).ceil();
      base = rows * widget.delegate.rowSpacing + widget.delegate.bubbleHeight;
    }
    // Add child space when expanded
    if (_isExpanded) {
      final eased = Curves.easeInOutCubic.transform(_expandT);
      base += _childDisplacementAmount * eased;
    }
    return base;
  }

  double get _maxScroll => max(0, _virtualCanvasHeight - widget.height);

  Offset _positionForIndex(int index) {
    if (_isList) {
      final x = _gutterX;
      final y = 20.0 + index * (_itemHeight + _itemSpacing);
      return Offset(x, y);
    }
    final col = index % _columns;
    final row = index ~/ _columns;
    final bw = widget.delegate.bubbleWidth;
    final x = _gutterX + col * (bw + _gutterX);
    final y = 20.0 + row * widget.delegate.rowSpacing;
    return Offset(x, y);
  }

  void _initBubblePositions() {
    final items = widget.delegate.items;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (_bubblePhysics.containsKey(item.id)) continue;
      final pos = _positionForIndex(i);
      _bubblePhysics[item.id] = _BubblePhysics(
        canvasX: pos.dx,
        canvasY: pos.dy,
        accentColor: item.accentColor ?? _S.accents[i % _S.accents.length],
        staggerDelay: _isList ? i * 0.06 : 0.0,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Grid management (adapted from robot_grid, no connections)
  // ══════════════════════════════════════════════════════════════════════════════

  void _initGrid(Size viewportSize) {
    _gridDots.clear();
    _gridMap.clear();
    final gs = _cfg.gridSize;
    final cols = (viewportSize.width / gs).ceil() + 4;
    final rows = (viewportSize.height / gs).ceil() + 4;
    for (var ix = -2; ix <= cols; ix++) {
      for (var iy = -2; iy <= rows; iy++) {
        final dot = _GridDot(ix: ix, iy: iy, gridSize: gs);
        _gridDots.add(dot);
        _gridMap['$ix,$iy'] = dot;
      }
    }
    _gridViewportSize = viewportSize;
  }

  void _stepGrid() {
    if (_gridDots.isEmpty) return;

    // Collect screen-space rects of visible bubbles as displacement sources
    final bubbleBounds = <Rect>[];
    final rb = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final viewW = rb?.size.width ?? 400;
    final bw = _isList ? (viewW - _gutterX - 60) : widget.delegate.bubbleWidth;
    final bh = _itemHeight;
    for (final entry in _bubblePhysics.entries) {
      final bp = entry.value;
      final screenY = bp.canvasY - _scrollOffset;
      if (screenY + bh < -100 || screenY > widget.height + 100) continue;
      bubbleBounds.add(Rect.fromLTWH(bp.canvasX, screenY, bw, bh));
    }
    // Include child physics in grid displacement
    for (final entry in _childPhysics.entries) {
      final bp = entry.value;
      if (bp.opacity <= 0) continue;
      final screenY = bp.canvasY - _scrollOffset;
      if (screenY + bh < -100 || screenY > widget.height + 100) continue;
      bubbleBounds.add(Rect.fromLTWH(bp.canvasX, screenY, bw, bh));
    }

    final maxDist = _cfg.gridMaxDist;
    final pushStr = _cfg.gridPushStrength;
    final stiffness = _cfg.gridSpringStiffness;
    final damping = _cfg.gridDamping;
    final brightR = _cfg.gridBrightnessRadius;

    for (final dot in _gridDots) {
      var totalPushX = 0.0;
      var totalPushY = 0.0;
      var minDist = double.infinity;

      for (final bounds in bubbleBounds) {
        final closestX = dot.baseX.clamp(bounds.left, bounds.right);
        final closestY = dot.baseY.clamp(bounds.top, bounds.bottom);
        final dx = dot.baseX - closestX;
        final dy = dot.baseY - closestY;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist > 0 && dist < maxDist) {
          final norm = dist / maxDist;
          final push = pow(1 - norm, 2) * pushStr;
          totalPushX += (dx / dist) * push;
          totalPushY += (dy / dist) * push;
        }
        minDist = min(minDist, dist);
      }

      final targetX = dot.baseX + totalPushX;
      final targetY = dot.baseY + totalPushY;

      final forceX = (targetX - dot.x) * stiffness;
      final forceY = (targetY - dot.y) * stiffness;
      dot.vx = (dot.vx + forceX) * damping;
      dot.vy = (dot.vy + forceY) * damping;
      dot.x += dot.vx;
      dot.y += dot.vy;

      final normDist = (minDist / maxDist).clamp(0.0, 1.0);
      final ripple = sin(normDist * pi);
      dot.targetSize = 0.8 + ripple * 2;
      dot.size += (dot.targetSize - dot.size) * 0.15;

      final bDist = (minDist / brightR).clamp(0.0, 1.0);
      dot.brightness = pow(1 - bDist, 2).toDouble();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Scroll vs drag disambiguation
  // ══════════════════════════════════════════════════════════════════════════════

  String? _hitTestBubble(Offset localPos) {
    final rb = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final viewW = rb?.size.width ?? 400;
    final bw = _isList ? (viewW - _gutterX - 60) : widget.delegate.bubbleWidth;
    final bh = _itemHeight;
    // Check child physics first (they render on top)
    for (final child in _childItems.reversed) {
      final bp = _childPhysics[child.id];
      if (bp == null || bp.opacity <= 0) continue;
      final screenY = bp.canvasY - _scrollOffset;
      final rect = Rect.fromLTWH(bp.canvasX, screenY, bw, bh);
      if (rect.contains(localPos)) return child.id;
    }
    // Then check main items (reverse order so topmost is hit first)
    for (final item in widget.delegate.items.reversed) {
      final bp = _bubblePhysics[item.id];
      if (bp == null) continue;
      final screenY = bp.canvasY - _scrollOffset;
      final rect = Rect.fromLTWH(bp.canvasX, screenY, bw, bh);
      if (rect.contains(localPos)) return item.id;
    }
    return null;
  }

  // Scroll velocity sampling
  final List<_VelocitySample> _scrollSamples = [];

  void _onPanStart(DragStartDetails details) {
    // Block interactions during expand/collapse animation (mid-transition)
    if (_isExpanded && _expandT > 0 && _expandT < 1) return;

    final hitId = _hitTestBubble(details.localPosition);
    if (hitId != null) {
      // Check if it's a child item (not draggable, just ignore)
      if (_childPhysics.containsKey(hitId)) {
        // Start scroll instead
        _isScrolling = true;
        _scrollVelocity = 0;
        _scrollSamples.clear();
        _scrollSamples.add(_VelocitySample(details.localPosition, DateTime.now().millisecondsSinceEpoch));
        return;
      }

      // Check disclosure zone (rightmost 44px in list mode)
      if (_isList) {
        final bp = _bubblePhysics[hitId]!;
        final rb = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
        final viewW = rb?.size.width ?? 400;
        final bw = viewW - _gutterX - 60;
        final rightEdge = bp.canvasX + bw;
        if (details.localPosition.dx > rightEdge - 44) {
          if (_expandedItemId == hitId) {
            // Tapping disclosure on expanded parent → collapse
            _collapseExpanded();
          } else {
            // Tapping disclosure on a different item
            if (_isExpanded) {
              // Collapse current first, then expand new after animation
              _collapseExpanded();
              // We'll let the collapse complete, and user can tap again
            } else {
              final item = widget.delegate.items.firstWhere((i) => i.id == hitId);
              _expandItem(item, bp, bw);
            }
          }
          return;
        }
      }
      // Start item drag (but not if this item is the expanded parent)
      _draggingItemId = hitId;
      final bp = _bubblePhysics[hitId]!;
      _dragStartCanvasPos = Offset(bp.canvasX, bp.canvasY);
      _activeMomentum.remove(hitId);
      _velocitySamples[hitId] = [];
      _Sound.playPickup();
      setState(() {});
    } else {
      // Start scroll
      _isScrolling = true;
      _scrollVelocity = 0;
      _scrollSamples.clear();
      _scrollSamples.add(_VelocitySample(details.localPosition, DateTime.now().millisecondsSinceEpoch));
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_draggingItemId != null) {
      _onItemDragUpdate(details);
    } else if (_isScrolling) {
      _onScrollUpdate(details);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_draggingItemId != null) {
      _onItemDragEnd(details);
    } else if (_isScrolling) {
      _onScrollEnd(details);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Item drag
  // ══════════════════════════════════════════════════════════════════════════════

  void _onItemDragUpdate(DragUpdateDetails details) {
    final id = _draggingItemId;
    if (id == null) return;
    final bp = _bubblePhysics[id];
    if (bp == null) return;

    bp.canvasX += details.delta.dx;
    bp.canvasY += details.delta.dy;

    final now = DateTime.now().millisecondsSinceEpoch;
    final samples = _velocitySamples[id] ??= [];
    samples.add(_VelocitySample(Offset(bp.canvasX, bp.canvasY), now));
    final cutoff = now - _cfg.sampleWindowMs;
    samples.removeWhere((s) => s.timestamp < cutoff);
    while (samples.length > _cfg.velocitySamples) {
      samples.removeAt(0);
    }

    setState(() {});
  }

  void _onItemDragEnd(DragEndDetails details) {
    final id = _draggingItemId;
    _draggingItemId = null;
    _dragStartCanvasPos = null;
    if (id == null) return;

    final samples = _velocitySamples.remove(id);
    if (samples == null || samples.length < 2) {
      _Sound.playDrop();
      setState(() {});
      return;
    }

    double vx = 0, vy = 0, totalWeight = 0;
    for (var i = 1; i < samples.length; i++) {
      final dtMs = (samples[i].timestamp - samples[i - 1].timestamp).toDouble();
      if (dtMs < 8 || dtMs > 100) continue;
      final dt = dtMs / 1000.0;
      final weight = i / samples.length;
      vx += ((samples[i].position.dx - samples[i - 1].position.dx) / dt) * weight;
      vy += ((samples[i].position.dy - samples[i - 1].position.dy) / dt) * weight;
      totalWeight += weight;
    }
    if (totalWeight == 0) { _Sound.playDrop(); setState(() {}); return; }
    vx /= totalWeight;
    vy /= totalWeight;

    final speed = sqrt(vx * vx + vy * vy);
    if (speed > _cfg.maxVelPxS) {
      final scale = _cfg.maxVelPxS / speed;
      vx *= scale;
      vy *= scale;
    }
    if (speed < _cfg.thresholdPxS) {
      _Sound.playDrop();
      setState(() {});
      return;
    }

    final bp = _bubblePhysics[id]!;
    _Sound.playThrow((speed / _cfg.maxVelPxS).clamp(0.0, 1.0));
    _activeMomentum[id] = _MomentumState(
      velocity: Offset(vx, vy),
      position: Offset(bp.canvasX, bp.canvasY),
    );
    setState(() {});
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Scroll
  // ══════════════════════════════════════════════════════════════════════════════

  void _onScrollUpdate(DragUpdateDetails details) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _scrollSamples.add(_VelocitySample(details.localPosition, now));
    final cutoff = now - 80;
    _scrollSamples.removeWhere((s) => s.timestamp < cutoff);
    while (_scrollSamples.length > 9) _scrollSamples.removeAt(0);

    setState(() {
      _scrollOffset = (_scrollOffset - details.delta.dy).clamp(0, _maxScroll);
    });
  }

  void _onScrollEnd(DragEndDetails details) {
    _isScrolling = false;

    // Compute scroll velocity from samples
    if (_scrollSamples.length >= 2) {
      double vy = 0, totalWeight = 0;
      for (var i = 1; i < _scrollSamples.length; i++) {
        final dtMs = (_scrollSamples[i].timestamp - _scrollSamples[i - 1].timestamp).toDouble();
        if (dtMs < 8 || dtMs > 100) continue;
        final dt = dtMs / 1000.0;
        final weight = i / _scrollSamples.length;
        vy += ((_scrollSamples[i].position.dy - _scrollSamples[i - 1].position.dy) / dt) * weight;
        totalWeight += weight;
      }
      if (totalWeight > 0) {
        vy /= totalWeight;
        if (vy.abs() > 150) {
          _scrollVelocity = -vy; // negative because drag-up = scroll-down
        }
      }
    }
    _scrollSamples.clear();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        _scrollOffset = (_scrollOffset + event.scrollDelta.dy).clamp(0, _maxScroll);
      });
      _scrollVelocity = event.scrollDelta.dy * 2;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Expand / collapse
  // ══════════════════════════════════════════════════════════════════════════════

  void _expandItem(BubbleItem item, _BubblePhysics bp, double itemWidth) {
    _expandedItemId = item.id;
    _expandedParentHomeY = bp.canvasY;
    _expandT = 0;
    _expanding = true;
    _childItems = [];
    _childPhysics.clear();

    // Generate child items
    final rng = Random(item.id.hashCode);
    final count = 4 + rng.nextInt(5);
    final childLabels = ['Overview', 'Details', 'Gallery', 'Map View', 'Reviews', 'Related', 'History', 'Stats'];
    _childItems = List.generate(count, (i) {
      return BubbleItem(
        id: '${item.id}-child-$i',
        imageUrl: item.imageUrl,
        title: childLabels[i % childLabels.length],
        subtitle: '${item.title ?? "Item"} \u2023 ${childLabels[i % childLabels.length]}',
        accentColor: item.accentColor,
      );
    });

    // Create child physics entries on the canvas below the parent
    final childStartY = bp.canvasY + _itemHeight + widget.delegate.listSpacing;
    for (var i = 0; i < _childItems.length; i++) {
      final child = _childItems[i];
      _childPhysics[child.id] = _BubblePhysics(
        canvasX: bp.canvasX,
        canvasY: childStartY + i * (_itemHeight + widget.delegate.listSpacing),
        accentColor: child.accentColor ?? bp.accentColor,
        staggerDelay: i * 0.06,
      );
    }

    _Sound.playSpawn();
    setState(() {});
  }

  void _collapseExpanded() {
    _expanding = false;
    _Sound.playDrop();
    setState(() {});
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Physics ticker
  // ══════════════════════════════════════════════════════════════════════════════

  void _onPhysicsTick(Duration elapsed) {
    final dt = (elapsed - _lastTickerElapsed).inMicroseconds / 1e6;
    _lastTickerElapsed = elapsed;
    _tickerSeconds = elapsed.inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.1) return;

    // Init/resize grid
    final rb = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb != null && rb.hasSize) {
      final s = rb.size;
      _computeLayout(s.width);
      // Re-init positions if layout changed
      _initBubblePositions();
      if (widget.showGrid) {
        if (_gridViewportSize == null ||
            (_gridViewportSize!.width - s.width).abs() > 10 ||
            (_gridViewportSize!.height - s.height).abs() > 10) {
          _initGrid(s);
        }
      }
    }

    // Clean up expired effects
    _activePulses.removeWhere((p) => (_tickerSeconds - p.startTime) > _cfg.pulseDuration);

    // Decay bounce scales
    for (final bp in _bubblePhysics.values) {
      bp.bounceScale = 1.0 + (bp.bounceScale - 1.0) * 0.85;
    }

    // Step particles
    _stepParticles(dt);

    // Step grid
    if (widget.showGrid) _stepGrid();

    // Scroll momentum
    bool needsRebuild = false;
    if (_scrollVelocity.abs() > 1) {
      _scrollOffset = (_scrollOffset + _scrollVelocity * dt).clamp(0, _maxScroll);
      _scrollVelocity *= _cfg.baseFriction;

      // Boundary bounce
      if (_scrollOffset <= 0 && _scrollVelocity < 0) {
        _scrollVelocity = -_scrollVelocity * _cfg.bounceDamping;
        _Sound.playBounce((_scrollVelocity.abs() / 2000).clamp(0.0, 1.0));
      } else if (_scrollOffset >= _maxScroll && _scrollVelocity > 0) {
        _scrollVelocity = -_scrollVelocity * _cfg.bounceDamping;
        _Sound.playBounce((_scrollVelocity.abs() / 2000).clamp(0.0, 1.0));
      }

      if (_scrollVelocity.abs() < 1) _scrollVelocity = 0;
      needsRebuild = true;
    }

    // ── Expand/collapse animation ──
    if (_isExpanded) {
      if (_expanding) {
        _expandT = min(1.0, _expandT + dt * 3.3); // ~300ms
      } else {
        _expandT = max(0.0, _expandT - dt * 4.0); // ~250ms collapse
        if (_expandT <= 0) {
          _expandedItemId = null;
          _childItems = [];
          _childPhysics.clear();
        }
      }
      // Step displacement physics for siblings
      _stepDisplacement();
      // Step child entry/fadeout
      _stepChildPhysics(dt);
      needsRebuild = true;
    }

    // Check viewport entry for bubbles
    _checkViewportEntry();

    // Animate spawn opacity/scale
    for (final bp in _bubblePhysics.values) {
      if (bp.hasEnteredViewport && bp.opacity < 1.0) {
        bp.opacity = min(1.0, bp.opacity + dt * 4); // ~250ms fade
        needsRebuild = true;
      }
    }

    // Item momentum
    if (_activeMomentum.isNotEmpty) {
      _stepItemMomentum(dt);
      needsRebuild = true;
    }

    // Load more trigger
    if (!_loadMoreFired && _maxScroll > 0 && _scrollOffset > _maxScroll - 200) {
      _loadMoreFired = true;
      widget.delegate.onLoadMore?.call();
    }

    if (needsRebuild) setState(() {});

    // Always repaint effects layer
    _effectsRepaint.value++;
  }

  void _checkViewportEntry() {
    final bh = _itemHeight;
    for (final item in widget.delegate.items) {
      final bp = _bubblePhysics[item.id];
      if (bp == null || bp.hasEnteredViewport) continue;
      final screenY = bp.canvasY - _scrollOffset;
      if (screenY + bh > 0 && screenY < widget.height) {
        // In list mode, stagger the entry: don't mark as entered until delay has passed
        if (_isList && bp.staggerDelay > 0) {
          bp.staggerDelay -= 1 / 60; // decrement roughly per frame
          continue;
        }
        bp.hasEnteredViewport = true;
        bp.spawnTime = _tickerSeconds;
        bp.opacity = 0.0;
        _Sound.playSpawn();
      }
    }
  }

  /// Spring-displace siblings below the expanded parent
  void _stepDisplacement() {
    if (!_isExpanded) return;
    final eased = Curves.easeInOutCubic.transform(_expandT);
    final displacement = _childDisplacementAmount * eased;
    final items = widget.delegate.items;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.id == _expandedItemId) continue;
      final bp = _bubblePhysics[item.id];
      if (bp == null) continue;
      // Skip items being dragged or in momentum
      if (_draggingItemId == item.id || _activeMomentum.containsKey(item.id)) continue;

      final homePos = _positionForIndex(i);
      // Displace items whose home Y is below the parent
      if (homePos.dy > _expandedParentHomeY) {
        final targetY = homePos.dy + displacement;
        // Spring toward target (critically damped feel)
        bp.canvasY += (targetY - bp.canvasY) * 0.12;
      } else {
        // Spring back to home for items above
        bp.canvasY += (homePos.dy - bp.canvasY) * 0.12;
      }
      // Always spring X back to home
      bp.canvasX += (homePos.dx - bp.canvasX) * 0.12;
    }
  }

  /// Manage child bubble viewport entry and collapse fadeout
  void _stepChildPhysics(double dt) {
    if (_childPhysics.isEmpty) return;
    final bh = _itemHeight;

    if (_expanding) {
      // Children: check viewport entry with stagger delay
      for (final child in _childItems) {
        final bp = _childPhysics[child.id];
        if (bp == null || bp.hasEnteredViewport) continue;
        final screenY = bp.canvasY - _scrollOffset;
        if (screenY + bh > 0 && screenY < widget.height) {
          if (bp.staggerDelay > 0) {
            bp.staggerDelay -= 1.0 / 60.0;
            continue;
          }
          bp.hasEnteredViewport = true;
          bp.spawnTime = _tickerSeconds;
          bp.opacity = 0.0;
        }
      }
      // Fade in children that have entered viewport
      for (final bp in _childPhysics.values) {
        if (bp.hasEnteredViewport && bp.opacity < 1.0) {
          bp.opacity = min(1.0, bp.opacity + dt * 4); // ~250ms fade
        }
      }
    } else {
      // Collapsing: fade out children (~200ms)
      for (final bp in _childPhysics.values) {
        bp.opacity = max(0.0, bp.opacity - dt * 5);
      }
    }
  }

  void _stepParticles(double dt) {
    final toRemove = <int>[];
    for (var i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      if (_tickerSeconds - p.createdAt > p.lifespan) { toRemove.add(i); continue; }
      p.velocity = Offset(p.velocity.dx, p.velocity.dy + _cfg.particleGravity * dt);
      p.velocity = p.velocity * 0.99;
      p.position = p.position + p.velocity * dt;
    }
    for (var i = toRemove.length - 1; i >= 0; i--) _particles.removeAt(toRemove[i]);
  }

  void _stepItemMomentum(double dt) {
    final rb = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final viewW = rb.size.width;
    final bw = _isList ? (viewW - _gutterX - 60) : widget.delegate.bubbleWidth;
    final bh = _itemHeight;
    final margin = _cfg.boundaryMargin;

    final toRemove = <String>[];

    for (final entry in _activeMomentum.entries) {
      final id = entry.key;
      final state = entry.value;
      final bp = _bubblePhysics[id];
      if (bp == null) { toRemove.add(id); continue; }

      final speed = state.velocity.distance;
      final speedRatio = min(speed / _cfg.maxVelPxS, 1.0);
      final friction = _cfg.baseFriction - (speedRatio * (_cfg.baseFriction - _cfg.highSpeedFriction));
      state.velocity = state.velocity * friction;

      var newX = state.position.dx + state.velocity.dx * dt;
      var newY = state.position.dy + state.velocity.dy * dt;
      var vx = state.velocity.dx, vy = state.velocity.dy;
      bool bounced = false;

      // Horizontal bounds (screen space)
      if (newX < margin) {
        newX = margin;
        vx = -vx * _cfg.bounceDamping;
        bounced = true;
        _emitBounce(id, Offset(newX, newY - _scrollOffset + bh / 2));
      } else if (newX > viewW - bw - margin) {
        newX = viewW - bw - margin;
        vx = -vx * _cfg.bounceDamping;
        bounced = true;
        _emitBounce(id, Offset(newX + bw, newY - _scrollOffset + bh / 2));
      }
      // Vertical bounds (canvas space, visible region)
      final minY = _scrollOffset + margin;
      final maxY = _scrollOffset + widget.height - bh - margin;
      if (newY < minY) {
        newY = minY;
        vy = -vy * _cfg.bounceDamping;
        bounced = true;
        _emitBounce(id, Offset(newX + bw / 2, 0));
      } else if (newY > maxY) {
        newY = maxY;
        vy = -vy * _cfg.bounceDamping;
        bounced = true;
        _emitBounce(id, Offset(newX + bw / 2, widget.height));
      }

      if (bounced) {
        vx *= _cfg.bounceFriction;
        vy *= _cfg.bounceFriction;
        bp.bounceScale = 1.015;
      }
      state.velocity = Offset(vx, vy);
      state.position = Offset(newX, newY);
      bp.canvasX = newX;
      bp.canvasY = newY;

      if (state.velocity.distance < _cfg.minVelPxS) toRemove.add(id);
    }
    for (final id in toRemove) _activeMomentum.remove(id);

    // Collision detection O(n²) — fine for <100 visible items
    // Disable during expand to prevent fighting with displacement spring
    if (!_isExpanded) _resolveCollisions();
  }

  void _resolveCollisions() {
    final rb = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final viewW = rb?.size.width ?? 400;
    final bw = _isList ? (viewW - _gutterX - 60) : widget.delegate.bubbleWidth;
    final bh = _itemHeight;
    final items = widget.delegate.items;

    for (var i = 0; i < items.length; i++) {
      final a = _bubblePhysics[items[i].id];
      if (a == null) continue;
      for (var j = i + 1; j < items.length; j++) {
        final b = _bubblePhysics[items[j].id];
        if (b == null) continue;

        final aRect = Rect.fromLTWH(a.canvasX, a.canvasY, bw, bh);
        final bRect = Rect.fromLTWH(b.canvasX, b.canvasY, bw, bh);

        if (!aRect.overlaps(bRect)) continue;

        // Push apart on shortest axis
        final overlapX = min(aRect.right - bRect.left, bRect.right - aRect.left);
        final overlapY = min(aRect.bottom - bRect.top, bRect.bottom - aRect.top);

        final aDragged = _draggingItemId == items[i].id;
        final bDragged = _draggingItemId == items[j].id;

        if (overlapX < overlapY) {
          final push = overlapX / 2 + 1;
          if (a.canvasX < b.canvasX) {
            if (!aDragged) a.canvasX -= push;
            if (!bDragged) b.canvasX += push;
          } else {
            if (!aDragged) a.canvasX += push;
            if (!bDragged) b.canvasX -= push;
          }
        } else {
          final push = overlapY / 2 + 1;
          if (a.canvasY < b.canvasY) {
            if (!aDragged) a.canvasY -= push;
            if (!bDragged) b.canvasY += push;
          } else {
            if (!aDragged) a.canvasY += push;
            if (!bDragged) b.canvasY -= push;
          }
        }
      }
    }
  }

  void _emitBounce(String itemId, Offset screenPos) {
    final bp = _bubblePhysics[itemId];
    final color = bp?.accentColor ?? _S.accents[0];
    final speed = _activeMomentum[itemId]?.velocity.distance ?? 0;

    _activePulses.add(_PulseEvent(center: screenPos, startTime: _tickerSeconds, color: color));
    _Sound.playBounce((speed / _cfg.maxVelPxS).clamp(0.0, 1.0));

    if (_cfg.particlesEnabled) {
      final rng = Random();
      for (var i = 0; i < _cfg.particleCount; i++) {
        final angle = rng.nextDouble() * 2 * pi;
        final spd = 60 + rng.nextDouble() * 200;
        _particles.add(_Particle(
          position: screenPos,
          velocity: Offset(cos(angle) * spd, sin(angle) * spd - 60),
          size: 2 + rng.nextDouble() * 4,
          color: rng.nextDouble() < 0.4 ? const Color(0xFF60A5FA) : color,
          createdAt: _tickerSeconds,
          lifespan: _cfg.particleLifespan * (0.5 + rng.nextDouble() * 0.5),
          shape: rng.nextInt(2),
        ));
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRect(
        child: MouseRegion(
          onHover: (e) => _mousePos = e.localPosition,
          onExit: (_) => _mousePos = null,
          child: Listener(
          onPointerMove: (e) => _mousePos = e.localPosition,
          onPointerSignal: _onPointerSignal,
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Container(
              key: _canvasKey,
              color: _S.canvasBg,
              child: Stack(
                children: [
                  // Layer 1: Warp grid
                  if (widget.showGrid)
                    Positioned.fill(
                      child: ListenableBuilder(
                        listenable: _effectsRepaint,
                        builder: (context, _) => CustomPaint(
                          painter: _WarpGridPainter(
                            dots: _gridDots,
                            dotMap: _gridMap,
                            gridSize: _cfg.gridSize,
                            mousePos: _mousePos,
                            cfg: _cfg,
                          ),
                        ),
                      ),
                    ),

                  // Layer 2: Bubble widgets (only visible items)
                  ..._buildVisibleBubbles(),

                  // Layer 3: Effects overlay
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ListenableBuilder(
                        listenable: _effectsRepaint,
                        builder: (context, _) => CustomPaint(
                          painter: _BubbleEffectsPainter(
                            pulses: _activePulses,
                            currentTime: _tickerSeconds,
                            particles: _particles,
                            cfg: _cfg,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Layer 4: Scrollbar track (inset ~1cm from right edge)
                  if (_maxScroll > 0)
                    Positioned(
                      right: 38, // ~1cm indent from right edge
                      top: 12,
                      bottom: 12,
                      width: 6,
                      child: IgnorePointer(
                        child: _ScrollbarIndicator(
                          scrollOffset: _scrollOffset,
                          maxScroll: _maxScroll,
                          viewportHeight: widget.height,
                          contentHeight: _virtualCanvasHeight,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }

  List<Widget> _buildVisibleBubbles() {
    final items = widget.delegate.items;
    final rb = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    final viewW = rb?.size.width ?? 400;
    final bw = _isList ? (viewW - _gutterX - 60) : widget.delegate.bubbleWidth;
    final bh = _itemHeight;

    final result = <Widget>[];

    // Render all main items (including the expanded parent)
    for (final item in items) {
      final bp = _bubblePhysics[item.id];
      if (bp == null) continue;

      final screenY = bp.canvasY - _scrollOffset;
      // Cull off-screen
      if (screenY + bh < -50 || screenY > widget.height + 50) continue;
      if (!bp.hasEnteredViewport) continue;

      final isDragging = _draggingItemId == item.id;
      final isExpandedParent = item.id == _expandedItemId;
      final spawnT = bp.spawnTime > 0
          ? min(1.0, (_tickerSeconds - bp.spawnTime) / 0.3)
          : 1.0;
      // List mode: slide in from left; Grid mode: scale in
      final entryScale = _isList ? 1.0 : (0.8 + 0.2 * Curves.easeOutBack.transform(spawnT));
      final slideX = _isList ? (1.0 - Curves.easeOutCubic.transform(spawnT)) * -60 : 0.0;
      final totalScale = entryScale * bp.bounceScale * (isDragging ? 1.02 : 1.0);

      Widget child;
      if (widget.delegate.builder != null) {
        child = widget.delegate.builder!(item, isDragging);
      } else if (_isList) {
        child = _DefaultListBubbleWidget(
          item: item,
          isDragging: isDragging,
          accentColor: bp.accentColor,
          isExpandedParent: isExpandedParent,
        );
      } else {
        child = _DefaultBubbleWidget(
          item: item,
          isDragging: isDragging,
          accentColor: bp.accentColor,
        );
      }

      result.add(
        Positioned(
          left: bp.canvasX + slideX,
          top: screenY,
          width: bw,
          height: bh,
          child: Opacity(
            opacity: bp.opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: totalScale,
              child: child,
            ),
          ),
        ),
      );

      // Inject children right after the expanded parent
      if (isExpandedParent && _childPhysics.isNotEmpty) {
        for (final childItem in _childItems) {
          final cbp = _childPhysics[childItem.id];
          if (cbp == null || cbp.opacity <= 0) continue;
          final childScreenY = cbp.canvasY - _scrollOffset;
          if (childScreenY + bh < -50 || childScreenY > widget.height + 50) continue;
          if (!cbp.hasEnteredViewport) continue;

          final childSpawnT = cbp.spawnTime > 0
              ? min(1.0, (_tickerSeconds - cbp.spawnTime) / 0.3)
              : 1.0;
          final childSlideX = (1.0 - Curves.easeOutCubic.transform(childSpawnT)) * -60;

          result.add(
            Positioned(
              left: cbp.canvasX + childSlideX,
              top: childScreenY,
              width: bw,
              height: bh,
              child: Opacity(
                opacity: cbp.opacity.clamp(0.0, 1.0),
                child: _DefaultListBubbleWidget(
                  item: childItem,
                  isDragging: false,
                  accentColor: cbp.accentColor,
                ),
              ),
            ),
          );
        }
      }
    }

    // Back button (floating near expanded parent)
    if (_isExpanded && _expandT > 0.3) {
      final parentBp = _bubblePhysics[_expandedItemId];
      if (parentBp != null) {
        final parentScreenY = parentBp.canvasY - _scrollOffset;
        final backX = max(4.0, parentBp.canvasX - 36);
        final backOpacity = ((_expandT - 0.3) / 0.2).clamp(0.0, 1.0);

        result.add(
          Positioned(
            left: backX,
            top: parentScreenY + (_itemHeight / 2) - 16,
            width: 32,
            height: 32,
            child: Opacity(
              opacity: backOpacity,
              child: GestureDetector(
                onTap: _collapseExpanded,
                child: Container(
                  decoration: BoxDecoration(
                    color: _S.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (parentBp.accentColor).withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: parentBp.accentColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back, color: _S.textPrimary, size: 16),
                ),
              ),
            ),
          ),
        );
      }
    }

    return result;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Warp grid painter (adapted from robot_grid, no connections)
// ═══════════════════════════════════════════════════════════════════════════════

class _WarpGridPainter extends CustomPainter {
  _WarpGridPainter({
    required this.dots,
    required this.dotMap,
    required this.gridSize,
    required this.mousePos,
    required this.cfg,
  });
  final List<_GridDot> dots;
  final Map<String, _GridDot> dotMap;
  final double gridSize;
  final Offset? mousePos;
  final _BubbleSimConfig cfg;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    _drawGridLines(canvas);
    _drawGridDots(canvas);
  }

  double _hoverGlow(double x, double y) {
    if (mousePos == null) return 0;
    final dx = x - mousePos!.dx, dy = y - mousePos!.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist > cfg.gridHoverRadius) return 0;
    return pow(1 - dist / cfg.gridHoverRadius, 2).toDouble() * 0.6;
  }

  void _drawGridLines(Canvas canvas) {
    for (final dot in dots) {
      final right = dotMap['${dot.ix + 1},${dot.iy}'];
      if (right != null) _drawLine(canvas, dot, right);
      final bottom = dotMap['${dot.ix},${dot.iy + 1}'];
      if (bottom != null) _drawLine(canvas, dot, bottom);
    }
  }

  void _drawLine(Canvas canvas, _GridDot a, _GridDot b) {
    final avgBright = (a.brightness + b.brightness) / 2;
    final hg = max(_hoverGlow(a.x, a.y), _hoverGlow(b.x, b.y));
    final totalEffect = max(avgBright * 0.4, hg);
    final opacity = (cfg.gridBaseOpacity + totalEffect * 0.6).clamp(0.0, 1.0);
    // Gray base (150,150,150). Hover blends toward blue (88,166,255).
    final r = (150 + hg * (88 - 150)).round().clamp(88, 150);
    final g = (150 + hg * (166 - 150)).round().clamp(150, 166);
    final bv = (150 + hg * (255 - 150)).round().clamp(150, 255);
    canvas.drawLine(
      Offset(a.x, a.y),
      Offset(b.x, b.y),
      Paint()
        ..color = Color.fromRGBO(r, g, bv, opacity)
        ..strokeWidth = 0.5 + totalEffect * 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawGridDots(Canvas canvas) {
    for (final dot in dots) {
      final hg = _hoverGlow(dot.x, dot.y);
      final bright = dot.brightness;
      final totalEffect = max(bright, hg);
      const baseOp = 0.2;
      final boost = totalEffect * 0.7;
      final opacity = (baseOp + boost).clamp(0.0, 1.0);
      // White/gray dot (200,200,200). Hover blends toward blue (88,166,255).
      final r = (200 + hg * (88 - 200)).round().clamp(88, 200);
      final g = (200 + hg * (166 - 200)).round().clamp(166, 200);
      final bv = (200 + hg * (255 - 200)).round().clamp(200, 255);
      canvas.drawCircle(
        Offset(dot.x, dot.y),
        dot.size,
        Paint()..color = Color.fromRGBO(r, g, bv, opacity),
      );
      // Blue glow halo on strong hover
      if (hg > 0.25) {
        canvas.drawCircle(
          Offset(dot.x, dot.y),
          dot.size + 3,
          Paint()..color = Color.fromRGBO(88, 166, 255, (hg - 0.25) * 0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WarpGridPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Effects painter – particles and pulses
// ═══════════════════════════════════════════════════════════════════════════════

class _BubbleEffectsPainter extends CustomPainter {
  _BubbleEffectsPainter({
    required this.pulses,
    required this.currentTime,
    required this.particles,
    required this.cfg,
  });
  final List<_PulseEvent> pulses;
  final double currentTime;
  final List<_Particle> particles;
  final _BubbleSimConfig cfg;

  @override
  void paint(Canvas canvas, Size size) {
    _drawPulses(canvas);
    _drawParticles(canvas);
  }

  void _drawPulses(Canvas canvas) {
    for (final pulse in pulses) {
      final elapsed = currentTime - pulse.startTime;
      if (elapsed < 0 || elapsed > cfg.pulseDuration) continue;
      final t = elapsed / cfg.pulseDuration;
      final radius = elapsed * cfg.pulseSpeed;
      final opacity = (1.0 - t) * 0.4;
      if (opacity <= 0) continue;
      canvas.drawCircle(
        pulse.center,
        radius,
        Paint()
          ..color = pulse.color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * (1.0 - t * 0.5),
      );
      if (elapsed > 0.1) {
        final r2 = (elapsed - 0.1) * cfg.pulseSpeed;
        final o2 = (1.0 - t) * 0.2;
        if (o2 > 0) {
          canvas.drawCircle(
            pulse.center,
            r2,
            Paint()
              ..color = pulse.color.withValues(alpha: o2)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5 * (1.0 - t * 0.5),
          );
        }
      }
    }
  }

  void _drawParticles(Canvas canvas) {
    for (final p in particles) {
      final age = currentTime - p.createdAt;
      if (age > p.lifespan) continue;
      final t = age / p.lifespan;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      if (opacity <= 0) continue;
      final paint = Paint()..color = p.color.withValues(alpha: opacity * 0.8);
      if (p.shape == 0) {
        canvas.drawCircle(p.position, p.size * (1.0 - t * 0.3), paint);
      } else {
        final s = p.size * (1.0 - t * 0.3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: p.position, width: s * 1.6, height: s * 1.6),
            Radius.circular(s * 0.2),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BubbleEffectsPainter old) =>
      pulses.isNotEmpty ||
      old.pulses.isNotEmpty ||
      particles.isNotEmpty ||
      old.particles.isNotEmpty;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Scrollbar indicator (custom, non-interactive)
// ═══════════════════════════════════════════════════════════════════════════════

class _ScrollbarIndicator extends StatelessWidget {
  const _ScrollbarIndicator({
    required this.scrollOffset,
    required this.maxScroll,
    required this.viewportHeight,
    required this.contentHeight,
  });
  final double scrollOffset;
  final double maxScroll;
  final double viewportHeight;
  final double contentHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight;
        // Thumb size proportional to viewport/content ratio, min 30px
        final thumbRatio = (viewportHeight / contentHeight).clamp(0.05, 1.0);
        final thumbHeight = max(30.0, trackHeight * thumbRatio);
        final scrollableTrack = trackHeight - thumbHeight;
        final scrollFraction = maxScroll > 0 ? (scrollOffset / maxScroll).clamp(0.0, 1.0) : 0.0;
        final thumbTop = scrollFraction * scrollableTrack;

        return Stack(
          children: [
            // Track
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: _S.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // Thumb
            Positioned(
              top: thumbTop,
              left: 0,
              right: 0,
              height: thumbHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: _S.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Default bubble widget
// ═══════════════════════════════════════════════════════════════════════════════

class _DefaultBubbleWidget extends StatelessWidget {
  const _DefaultBubbleWidget({
    required this.item,
    required this.isDragging,
    required this.accentColor,
  });
  final BubbleItem item;
  final bool isDragging;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _S.surface,
        borderRadius: BorderRadius.circular(_S.borderRadius),
        border: Border.all(
          color: isDragging ? accentColor : _S.border,
          width: isDragging ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDragging ? accentColor : Colors.black).withValues(alpha: isDragging ? 0.55 : 0.25),
            offset: Offset(0, isDragging ? 32 : 24),
            blurRadius: isDragging ? 40 : 24,
            spreadRadius: isDragging ? -8 : -12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Accent header bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(_S.borderRadius - 1),
                topRight: Radius.circular(_S.borderRadius - 1),
              ),
            ),
          ),
          // Image area
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(_S.borderRadius - 1),
                bottomRight: Radius.circular(_S.borderRadius - 1),
              ),
              child: item.imageUrl != null
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        final progress = loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null;
                        return Container(
                          color: _S.surfaceLight,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 2,
                                color: accentColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: _S.surfaceLight,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: _S.textSecondary.withValues(alpha: 0.5),
                            size: 32,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: _S.surfaceLight,
                      child: Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: accentColor.withValues(alpha: 0.3),
                          size: 40,
                        ),
                      ),
                    ),
            ),
          ),
          // Title + subtitle
          if (item.title != null || item.subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.title != null)
                    Text(
                      item.title!,
                      style: const TextStyle(
                        color: _S.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle!,
                      style: const TextStyle(
                        color: _S.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Default list-mode bubble widget (horizontal card)
// ═══════════════════════════════════════════════════════════════════════════════

class _DefaultListBubbleWidget extends StatelessWidget {
  const _DefaultListBubbleWidget({
    required this.item,
    required this.isDragging,
    required this.accentColor,
    this.isExpandedParent = false,
  });
  final BubbleItem item;
  final bool isDragging;
  final Color accentColor;
  final bool isExpandedParent;

  @override
  Widget build(BuildContext context) {
    final highlighted = isDragging || isExpandedParent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _S.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? accentColor : _S.border,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (highlighted ? accentColor : Colors.black).withValues(alpha: highlighted ? 0.55 : 0.25),
            offset: Offset(0, highlighted ? 32 : 24),
            blurRadius: highlighted ? 40 : 24,
            spreadRadius: highlighted ? -8 : -12,
          ),
          if (isExpandedParent)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Row(
        children: [
          // Accent side stripe
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9),
                bottomLeft: Radius.circular(9),
              ),
            ),
          ),
          // Thumbnail
          if (item.imageUrl != null)
            SizedBox(
              width: 72,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(0),
                  bottomLeft: Radius.circular(0),
                ),
                child: Image.network(
                  item.imageUrl!,
                  fit: BoxFit.cover,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: _S.surfaceLight,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accentColor.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: _S.surfaceLight,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: _S.textSecondary.withValues(alpha: 0.4),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          // Text content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (item.title != null)
                    Text(
                      item.title!,
                      style: const TextStyle(
                        color: _S.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle!,
                      style: const TextStyle(
                        color: _S.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Disclosure chevron
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(
              isExpandedParent ? Icons.expand_less : Icons.chevron_right,
              color: isExpandedParent
                  ? accentColor.withValues(alpha: 0.8)
                  : _S.textSecondary.withValues(alpha: 0.6),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Demo page
// ═══════════════════════════════════════════════════════════════════════════════

class BubbleCanvasDemo extends StatefulWidget {
  const BubbleCanvasDemo({super.key});
  @override
  State<BubbleCanvasDemo> createState() => _BubbleCanvasDemoState();
}

class _NavLevel {
  _NavLevel({required this.title, required this.items, this.parentAccent});
  final String title;
  final List<BubbleItem> items;
  final Color? parentAccent;
}

class _BubbleCanvasDemoState extends State<BubbleCanvasDemo> {
  int _page = 0;
  BubbleLayoutMode _layoutMode = BubbleLayoutMode.grid;
  final List<_NavLevel> _navStack = [];

  static const _sampleImages = [
    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1433086966358-54859d0ed716?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1472214103451-9374bd1c798e?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1518173946687-a4c932e3f0e4?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1475924156734-496f6cac6ec1?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1465056836900-8f1e940b3925?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1490730141103-6cac27aaab94?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1505144808419-1957a94ca61e?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?w=400&h=300&fit=crop',
  ];

  static const _titles = [
    'Mountain Vista', 'Forest Path', 'Ancient Trees', 'Hidden Waterfall',
    'Rolling Hills', 'Morning Mist', 'Wild Meadow', 'Deep Forest',
    'Ocean Sunset', 'Tropical Beach', 'Golden Valley', 'Desert Dawn',
    'Sky Reflection', 'Coral Waters', 'Harvest Field',
  ];

  static const _subtitles = [
    'Nature Collection', 'Landscape Series', 'Wilderness', 'Water & Light',
    'Countryside', 'Atmospheric', 'Botanical', 'Woodland',
    'Seascape', 'Coastal', 'Panoramic', 'Arid Lands',
    'Mirrored', 'Underwater', 'Rural Life',
  ];

  static const _childLabels = [
    'Overview', 'Details', 'Gallery', 'Map View', 'Reviews',
    'Related', 'History', 'Stats',
  ];

  @override
  void initState() {
    super.initState();
    _navStack.add(_NavLevel(
      title: 'Bubble Canvas',
      items: _generateItems(0, 30),
    ));
  }

  _NavLevel get _current => _navStack.last;
  bool get _canGoBack => _navStack.length > 1;

  List<BubbleItem> _generateItems(int startIndex, int count) {
    return List.generate(count, (i) {
      final idx = startIndex + i;
      final imgIdx = idx % _sampleImages.length;
      return BubbleItem(
        id: 'bubble-$idx',
        imageUrl: _sampleImages[imgIdx],
        title: _titles[imgIdx],
        subtitle: _subtitles[imgIdx],
        accentColor: _S.accents[idx % _S.accents.length],
      );
    });
  }

  List<BubbleItem> _generateChildItems(BubbleItem parent) {
    final rng = Random(parent.id.hashCode);
    final count = 4 + rng.nextInt(5); // 4-8 children
    return List.generate(count, (i) {
      final imgIdx = (parent.id.hashCode + i) % _sampleImages.length;
      return BubbleItem(
        id: '${parent.id}-child-$i',
        imageUrl: _sampleImages[imgIdx],
        title: _childLabels[i % _childLabels.length],
        subtitle: '${parent.title ?? "Item"} \u2023 ${_childLabels[i % _childLabels.length]}',
        accentColor: parent.accentColor ?? _S.accents[i % _S.accents.length],
      );
    });
  }

  void _onDisclosure(BubbleItem item) {
    _Sound.playSpawn();
    setState(() {
      _navStack.add(_NavLevel(
        title: item.title ?? item.id,
        items: _generateChildItems(item),
        parentAccent: item.accentColor,
      ));
    });
  }

  void _goBack() {
    if (!_canGoBack) return;
    _Sound.playDrop();
    setState(() {
      _navStack.removeLast();
    });
  }

  void _loadMore() {
    _page++;
    setState(() {
      final current = _navStack.last;
      _navStack.last = _NavLevel(
        title: current.title,
        items: [...current.items, ..._generateItems(current.items.length, 15)],
        parentAccent: current.parentAccent,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _current.parentAccent ?? _S.accents[0];
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _S.canvasBg,
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _S.surface,
          foregroundColor: _S.textPrimary,
          leading: _canGoBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBack,
                )
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
          title: Row(
            children: [
              // Breadcrumb trail
              if (_canGoBack) ...[
                GestureDetector(
                  onTap: () {
                    setState(() {
                      while (_navStack.length > 1) _navStack.removeLast();
                    });
                  },
                  child: Text(
                    'All',
                    style: TextStyle(
                      fontSize: 14,
                      color: _S.textSecondary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.chevron_right, size: 16, color: _S.textSecondary),
                ),
              ],
              Flexible(
                child: Text(
                  _current.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_current.items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _S.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _S.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<BubbleLayoutMode>(
                  value: _layoutMode,
                  dropdownColor: _S.surface,
                  style: const TextStyle(color: _S.textPrimary, fontSize: 13),
                  icon: const Icon(Icons.arrow_drop_down, color: _S.textSecondary, size: 20),
                  items: const [
                    DropdownMenuItem(
                      value: BubbleLayoutMode.grid,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.grid_view, size: 16, color: _S.textSecondary),
                          SizedBox(width: 6),
                          Text('Grid'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: BubbleLayoutMode.list,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.view_list, size: 16, color: _S.textSecondary),
                          SizedBox(width: 6),
                          Text('List'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) setState(() => _layoutMode = mode);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return BubbleCanvas(
              height: constraints.maxHeight,
              delegate: BubbleCanvasDelegate(
                items: _current.items,
                layoutMode: _layoutMode,
                onLoadMore: _canGoBack ? null : _loadMore,
                onItemDisclosure: _onDisclosure,
              ),
            );
          },
        ),
      ),
    );
  }
}
