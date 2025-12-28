/// Settings Provider - User preferences and application settings.
///
/// Manages persistent settings for the ComfyUI editor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Edge rendering style.
enum EdgeStyle {
  bezier,
  straight,
  step,
  smoothstep,
}

/// Grid display mode.
enum GridMode {
  none,
  dots,
  lines,
}

/// Theme mode.
enum AppThemeMode {
  system,
  light,
  dark,
}

/// Canvas settings.
class CanvasSettings {
  /// Minimum zoom level.
  final double minZoom;

  /// Maximum zoom level.
  final double maxZoom;

  /// Zoom sensitivity (scroll wheel).
  final double zoomSensitivity;

  /// Whether to snap nodes to grid.
  final bool snapToGrid;

  /// Grid size for snapping.
  final double gridSize;

  /// Grid display mode.
  final GridMode gridMode;

  /// Grid color.
  final Color gridColor;

  /// Background color.
  final Color backgroundColor;

  const CanvasSettings({
    this.minZoom = 0.1,
    this.maxZoom = 4.0,
    this.zoomSensitivity = 1.0,
    this.snapToGrid = true,
    this.gridSize = 20.0,
    this.gridMode = GridMode.dots,
    this.gridColor = const Color(0xFF333333),
    this.backgroundColor = const Color(0xFF1a1a1a),
  });

  CanvasSettings copyWith({
    double? minZoom,
    double? maxZoom,
    double? zoomSensitivity,
    bool? snapToGrid,
    double? gridSize,
    GridMode? gridMode,
    Color? gridColor,
    Color? backgroundColor,
  }) {
    return CanvasSettings(
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      zoomSensitivity: zoomSensitivity ?? this.zoomSensitivity,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      gridSize: gridSize ?? this.gridSize,
      gridMode: gridMode ?? this.gridMode,
      gridColor: gridColor ?? this.gridColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}

/// Edge settings.
class EdgeSettings {
  /// Edge rendering style.
  final EdgeStyle style;

  /// Edge stroke width.
  final double strokeWidth;

  /// Whether to animate edges during execution.
  final bool animateOnExecution;

  /// Animation speed (pixels per second).
  final double animationSpeed;

  /// Whether to show edge labels.
  final bool showLabels;

  /// Edge curvature (for bezier).
  final double curvature;

  const EdgeSettings({
    this.style = EdgeStyle.bezier,
    this.strokeWidth = 3.0,
    this.animateOnExecution = true,
    this.animationSpeed = 100.0,
    this.showLabels = false,
    this.curvature = 0.25,
  });

  EdgeSettings copyWith({
    EdgeStyle? style,
    double? strokeWidth,
    bool? animateOnExecution,
    double? animationSpeed,
    bool? showLabels,
    double? curvature,
  }) {
    return EdgeSettings(
      style: style ?? this.style,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      animateOnExecution: animateOnExecution ?? this.animateOnExecution,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      showLabels: showLabels ?? this.showLabels,
      curvature: curvature ?? this.curvature,
    );
  }
}

/// Node settings.
class NodeSettings {
  /// Default node width.
  final double defaultWidth;

  /// Minimum node width.
  final double minWidth;

  /// Whether to show node shadows.
  final bool showShadows;

  /// Node corner radius.
  final double cornerRadius;

  /// Header height.
  final double headerHeight;

  /// Slot height.
  final double slotHeight;

  /// Whether to show type badges on slots.
  final bool showTypeBadges;

  /// Whether to auto-collapse nodes without connections.
  final bool autoCollapse;

  const NodeSettings({
    this.defaultWidth = 200.0,
    this.minWidth = 140.0,
    this.showShadows = true,
    this.cornerRadius = 8.0,
    this.headerHeight = 32.0,
    this.slotHeight = 24.0,
    this.showTypeBadges = true,
    this.autoCollapse = false,
  });

  NodeSettings copyWith({
    double? defaultWidth,
    double? minWidth,
    bool? showShadows,
    double? cornerRadius,
    double? headerHeight,
    double? slotHeight,
    bool? showTypeBadges,
    bool? autoCollapse,
  }) {
    return NodeSettings(
      defaultWidth: defaultWidth ?? this.defaultWidth,
      minWidth: minWidth ?? this.minWidth,
      showShadows: showShadows ?? this.showShadows,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      headerHeight: headerHeight ?? this.headerHeight,
      slotHeight: slotHeight ?? this.slotHeight,
      showTypeBadges: showTypeBadges ?? this.showTypeBadges,
      autoCollapse: autoCollapse ?? this.autoCollapse,
    );
  }
}

/// Behavior settings.
class BehaviorSettings {
  /// Whether to confirm before deleting nodes.
  final bool confirmDelete;

  /// Whether to auto-connect compatible slots.
  final bool autoConnect;

  /// Whether to pan canvas on scroll (vs zoom).
  final bool panOnScroll;

  /// Whether middle mouse button pans.
  final bool middleMousePan;

  /// Whether to show tooltips.
  final bool showTooltips;

  /// Tooltip delay in milliseconds.
  final int tooltipDelay;

  /// Whether to highlight compatible slots while dragging.
  final bool highlightCompatibleSlots;

  /// Undo history limit.
  final int undoHistoryLimit;

  const BehaviorSettings({
    this.confirmDelete = false,
    this.autoConnect = true,
    this.panOnScroll = false,
    this.middleMousePan = true,
    this.showTooltips = true,
    this.tooltipDelay = 500,
    this.highlightCompatibleSlots = true,
    this.undoHistoryLimit = 50,
  });

  BehaviorSettings copyWith({
    bool? confirmDelete,
    bool? autoConnect,
    bool? panOnScroll,
    bool? middleMousePan,
    bool? showTooltips,
    int? tooltipDelay,
    bool? highlightCompatibleSlots,
    int? undoHistoryLimit,
  }) {
    return BehaviorSettings(
      confirmDelete: confirmDelete ?? this.confirmDelete,
      autoConnect: autoConnect ?? this.autoConnect,
      panOnScroll: panOnScroll ?? this.panOnScroll,
      middleMousePan: middleMousePan ?? this.middleMousePan,
      showTooltips: showTooltips ?? this.showTooltips,
      tooltipDelay: tooltipDelay ?? this.tooltipDelay,
      highlightCompatibleSlots:
          highlightCompatibleSlots ?? this.highlightCompatibleSlots,
      undoHistoryLimit: undoHistoryLimit ?? this.undoHistoryLimit,
    );
  }
}

/// Execution settings.
class ExecutionSettings {
  /// Whether to auto-queue on changes.
  final bool autoQueue;

  /// Auto-queue delay in milliseconds.
  final int autoQueueDelay;

  /// Whether to show execution progress overlay.
  final bool showProgress;

  /// Whether to show preview images inline.
  final bool showInlinePreviews;

  /// Preview image size.
  final double previewSize;

  /// Whether to auto-scroll to executing node.
  final bool followExecution;

  const ExecutionSettings({
    this.autoQueue = false,
    this.autoQueueDelay = 1000,
    this.showProgress = true,
    this.showInlinePreviews = true,
    this.previewSize = 128.0,
    this.followExecution = false,
  });

  ExecutionSettings copyWith({
    bool? autoQueue,
    int? autoQueueDelay,
    bool? showProgress,
    bool? showInlinePreviews,
    double? previewSize,
    bool? followExecution,
  }) {
    return ExecutionSettings(
      autoQueue: autoQueue ?? this.autoQueue,
      autoQueueDelay: autoQueueDelay ?? this.autoQueueDelay,
      showProgress: showProgress ?? this.showProgress,
      showInlinePreviews: showInlinePreviews ?? this.showInlinePreviews,
      previewSize: previewSize ?? this.previewSize,
      followExecution: followExecution ?? this.followExecution,
    );
  }
}

/// All application settings.
class AppSettings {
  /// Theme mode.
  final AppThemeMode themeMode;

  /// Canvas settings.
  final CanvasSettings canvas;

  /// Edge settings.
  final EdgeSettings edge;

  /// Node settings.
  final NodeSettings node;

  /// Behavior settings.
  final BehaviorSettings behavior;

  /// Execution settings.
  final ExecutionSettings execution;

  const AppSettings({
    this.themeMode = AppThemeMode.dark,
    this.canvas = const CanvasSettings(),
    this.edge = const EdgeSettings(),
    this.node = const NodeSettings(),
    this.behavior = const BehaviorSettings(),
    this.execution = const ExecutionSettings(),
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    CanvasSettings? canvas,
    EdgeSettings? edge,
    NodeSettings? node,
    BehaviorSettings? behavior,
    ExecutionSettings? execution,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      canvas: canvas ?? this.canvas,
      edge: edge ?? this.edge,
      node: node ?? this.node,
      behavior: behavior ?? this.behavior,
      execution: execution ?? this.execution,
    );
  }

  /// Convert to JSON for persistence.
  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.name,
      'canvas': {
        'minZoom': canvas.minZoom,
        'maxZoom': canvas.maxZoom,
        'zoomSensitivity': canvas.zoomSensitivity,
        'snapToGrid': canvas.snapToGrid,
        'gridSize': canvas.gridSize,
        'gridMode': canvas.gridMode.name,
        'gridColor': canvas.gridColor.toARGB32(),
        'backgroundColor': canvas.backgroundColor.toARGB32(),
      },
      'edge': {
        'style': edge.style.name,
        'strokeWidth': edge.strokeWidth,
        'animateOnExecution': edge.animateOnExecution,
        'animationSpeed': edge.animationSpeed,
        'showLabels': edge.showLabels,
        'curvature': edge.curvature,
      },
      'node': {
        'defaultWidth': node.defaultWidth,
        'minWidth': node.minWidth,
        'showShadows': node.showShadows,
        'cornerRadius': node.cornerRadius,
        'headerHeight': node.headerHeight,
        'slotHeight': node.slotHeight,
        'showTypeBadges': node.showTypeBadges,
        'autoCollapse': node.autoCollapse,
      },
      'behavior': {
        'confirmDelete': behavior.confirmDelete,
        'autoConnect': behavior.autoConnect,
        'panOnScroll': behavior.panOnScroll,
        'middleMousePan': behavior.middleMousePan,
        'showTooltips': behavior.showTooltips,
        'tooltipDelay': behavior.tooltipDelay,
        'highlightCompatibleSlots': behavior.highlightCompatibleSlots,
        'undoHistoryLimit': behavior.undoHistoryLimit,
      },
      'execution': {
        'autoQueue': execution.autoQueue,
        'autoQueueDelay': execution.autoQueueDelay,
        'showProgress': execution.showProgress,
        'showInlinePreviews': execution.showInlinePreviews,
        'previewSize': execution.previewSize,
        'followExecution': execution.followExecution,
      },
    };
  }

  /// Create from JSON.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final canvasJson = json['canvas'] as Map<String, dynamic>?;
    final edgeJson = json['edge'] as Map<String, dynamic>?;
    final nodeJson = json['node'] as Map<String, dynamic>?;
    final behaviorJson = json['behavior'] as Map<String, dynamic>?;
    final executionJson = json['execution'] as Map<String, dynamic>?;

    return AppSettings(
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == json['themeMode'],
        orElse: () => AppThemeMode.dark,
      ),
      canvas: canvasJson != null
          ? CanvasSettings(
              minZoom: (canvasJson['minZoom'] as num?)?.toDouble() ?? 0.1,
              maxZoom: (canvasJson['maxZoom'] as num?)?.toDouble() ?? 4.0,
              zoomSensitivity:
                  (canvasJson['zoomSensitivity'] as num?)?.toDouble() ?? 1.0,
              snapToGrid: canvasJson['snapToGrid'] as bool? ?? true,
              gridSize: (canvasJson['gridSize'] as num?)?.toDouble() ?? 20.0,
              gridMode: GridMode.values.firstWhere(
                (e) => e.name == canvasJson['gridMode'],
                orElse: () => GridMode.dots,
              ),
              gridColor: Color(canvasJson['gridColor'] as int? ?? 0xFF333333),
              backgroundColor:
                  Color(canvasJson['backgroundColor'] as int? ?? 0xFF1a1a1a),
            )
          : const CanvasSettings(),
      edge: edgeJson != null
          ? EdgeSettings(
              style: EdgeStyle.values.firstWhere(
                (e) => e.name == edgeJson['style'],
                orElse: () => EdgeStyle.bezier,
              ),
              strokeWidth:
                  (edgeJson['strokeWidth'] as num?)?.toDouble() ?? 3.0,
              animateOnExecution:
                  edgeJson['animateOnExecution'] as bool? ?? true,
              animationSpeed:
                  (edgeJson['animationSpeed'] as num?)?.toDouble() ?? 100.0,
              showLabels: edgeJson['showLabels'] as bool? ?? false,
              curvature: (edgeJson['curvature'] as num?)?.toDouble() ?? 0.25,
            )
          : const EdgeSettings(),
      node: nodeJson != null
          ? NodeSettings(
              defaultWidth:
                  (nodeJson['defaultWidth'] as num?)?.toDouble() ?? 200.0,
              minWidth: (nodeJson['minWidth'] as num?)?.toDouble() ?? 140.0,
              showShadows: nodeJson['showShadows'] as bool? ?? true,
              cornerRadius:
                  (nodeJson['cornerRadius'] as num?)?.toDouble() ?? 8.0,
              headerHeight:
                  (nodeJson['headerHeight'] as num?)?.toDouble() ?? 32.0,
              slotHeight: (nodeJson['slotHeight'] as num?)?.toDouble() ?? 24.0,
              showTypeBadges: nodeJson['showTypeBadges'] as bool? ?? true,
              autoCollapse: nodeJson['autoCollapse'] as bool? ?? false,
            )
          : const NodeSettings(),
      behavior: behaviorJson != null
          ? BehaviorSettings(
              confirmDelete: behaviorJson['confirmDelete'] as bool? ?? false,
              autoConnect: behaviorJson['autoConnect'] as bool? ?? true,
              panOnScroll: behaviorJson['panOnScroll'] as bool? ?? false,
              middleMousePan: behaviorJson['middleMousePan'] as bool? ?? true,
              showTooltips: behaviorJson['showTooltips'] as bool? ?? true,
              tooltipDelay: behaviorJson['tooltipDelay'] as int? ?? 500,
              highlightCompatibleSlots:
                  behaviorJson['highlightCompatibleSlots'] as bool? ?? true,
              undoHistoryLimit: behaviorJson['undoHistoryLimit'] as int? ?? 50,
            )
          : const BehaviorSettings(),
      execution: executionJson != null
          ? ExecutionSettings(
              autoQueue: executionJson['autoQueue'] as bool? ?? false,
              autoQueueDelay: executionJson['autoQueueDelay'] as int? ?? 1000,
              showProgress: executionJson['showProgress'] as bool? ?? true,
              showInlinePreviews:
                  executionJson['showInlinePreviews'] as bool? ?? true,
              previewSize:
                  (executionJson['previewSize'] as num?)?.toDouble() ?? 128.0,
              followExecution:
                  executionJson['followExecution'] as bool? ?? false,
            )
          : const ExecutionSettings(),
    );
  }
}

/// Notifier for application settings.
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  /// Update theme mode.
  void setThemeMode(AppThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  /// Update canvas settings.
  void updateCanvas(CanvasSettings Function(CanvasSettings) update) {
    state = state.copyWith(canvas: update(state.canvas));
  }

  /// Update edge settings.
  void updateEdge(EdgeSettings Function(EdgeSettings) update) {
    state = state.copyWith(edge: update(state.edge));
  }

  /// Update node settings.
  void updateNode(NodeSettings Function(NodeSettings) update) {
    state = state.copyWith(node: update(state.node));
  }

  /// Update behavior settings.
  void updateBehavior(BehaviorSettings Function(BehaviorSettings) update) {
    state = state.copyWith(behavior: update(state.behavior));
  }

  /// Update execution settings.
  void updateExecution(ExecutionSettings Function(ExecutionSettings) update) {
    state = state.copyWith(execution: update(state.execution));
  }

  /// Set snap to grid.
  void setSnapToGrid(bool enabled) {
    state = state.copyWith(
      canvas: state.canvas.copyWith(snapToGrid: enabled),
    );
  }

  /// Set grid size.
  void setGridSize(double size) {
    state = state.copyWith(
      canvas: state.canvas.copyWith(gridSize: size),
    );
  }

  /// Set edge style.
  void setEdgeStyle(EdgeStyle style) {
    state = state.copyWith(
      edge: state.edge.copyWith(style: style),
    );
  }

  /// Set auto queue.
  void setAutoQueue(bool enabled) {
    state = state.copyWith(
      execution: state.execution.copyWith(autoQueue: enabled),
    );
  }

  /// Reset to defaults.
  void reset() {
    state = const AppSettings();
  }

  /// Load from JSON.
  void loadFromJson(Map<String, dynamic> json) {
    state = AppSettings.fromJson(json);
  }
}

/// Provider for application settings.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

/// Provider for theme mode.
final themeModeProvider = Provider<AppThemeMode>((ref) {
  return ref.watch(settingsProvider).themeMode;
});

/// Provider for canvas settings.
final canvasSettingsProvider = Provider<CanvasSettings>((ref) {
  return ref.watch(settingsProvider).canvas;
});

/// Provider for edge settings.
final edgeSettingsProvider = Provider<EdgeSettings>((ref) {
  return ref.watch(settingsProvider).edge;
});

/// Provider for node settings.
final nodeSettingsProvider = Provider<NodeSettings>((ref) {
  return ref.watch(settingsProvider).node;
});

/// Provider for behavior settings.
final behaviorSettingsProvider = Provider<BehaviorSettings>((ref) {
  return ref.watch(settingsProvider).behavior;
});

/// Provider for execution settings.
final executionSettingsProvider = Provider<ExecutionSettings>((ref) {
  return ref.watch(settingsProvider).execution;
});

/// Provider for snap to grid.
final snapToGridProvider = Provider<bool>((ref) {
  return ref.watch(canvasSettingsProvider).snapToGrid;
});

/// Provider for grid size.
final gridSizeProvider = Provider<double>((ref) {
  return ref.watch(canvasSettingsProvider).gridSize;
});

/// Provider for edge style.
final edgeStyleProvider = Provider<EdgeStyle>((ref) {
  return ref.watch(edgeSettingsProvider).style;
});

/// Provider for auto queue.
final autoQueueProvider = Provider<bool>((ref) {
  return ref.watch(executionSettingsProvider).autoQueue;
});
