/// ComfyGraph - Container for ComfyUI workflow graphs.
///
/// This class manages nodes, edges, and provides methods for
/// graph manipulation, validation, and serialization.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../nodes/node_definition.dart';
import '../nodes/node_registry.dart';
import '../nodes/slot_types.dart';

/// Simple unique ID generator.
String _generateId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = Random().nextInt(999999);
  return '$timestamp-$random';
}

/// Represents a node instance in the graph.
class ComfyNode {
  /// Unique identifier for this node instance.
  final String id;

  /// The node type name (e.g., "KSampler").
  final String type;

  /// Display title (can be customized).
  String title;

  /// Position on canvas.
  Offset position;

  /// Size of the node.
  Size size;

  /// Execution order.
  int order;

  /// Node mode (0=normal, 1=muted, 2=bypassed, 4=always).
  int mode;

  /// Widget values keyed by widget name.
  final Map<String, dynamic> widgetValues;

  /// Node properties.
  final Map<String, dynamic> properties;

  /// Whether node is collapsed.
  bool collapsed;

  /// Whether node is pinned.
  bool pinned;

  /// Custom header color.
  Color? color;

  /// Custom background color.
  Color? bgColor;

  ComfyNode({
    String? id,
    required this.type,
    String? title,
    this.position = Offset.zero,
    this.size = const Size(200, 100),
    this.order = 0,
    this.mode = 0,
    Map<String, dynamic>? widgetValues,
    Map<String, dynamic>? properties,
    this.collapsed = false,
    this.pinned = false,
    this.color,
    this.bgColor,
  })  : id = id ?? _generateId(),
        title = title ?? type,
        widgetValues = widgetValues ?? {},
        properties = properties ?? {};

  /// Create node with default values from definition.
  factory ComfyNode.fromDefinition(
    NodeDefinition def, {
    Offset position = Offset.zero,
  }) {
    final widgetValues = <String, dynamic>{};

    // Initialize widget values with defaults
    for (final widget in def.widgets) {
      if (widget.defaultValue != null) {
        widgetValues[widget.name] = widget.defaultValue;
      } else if (widget.type == WidgetType.combo && widget.options?.isNotEmpty == true) {
        widgetValues[widget.name] = widget.options!.first;
      }
    }

    return ComfyNode(
      type: def.name,
      title: def.displayName,
      position: position,
      widgetValues: widgetValues,
      color: def.color,
      bgColor: def.bgColor,
    );
  }

  /// Whether the node is muted (outputs are cached).
  bool get isMuted => mode == 1;

  /// Whether the node is bypassed (skipped in execution).
  bool get isBypassed => mode == 2;

  /// Whether the node always runs (never cached).
  bool get isAlwaysRun => mode == 4;

  /// Set muted state.
  set isMuted(bool value) => mode = value ? 1 : 0;

  /// Set bypassed state.
  set isBypassed(bool value) => mode = value ? 2 : 0;

  ComfyNode copyWith({
    String? id,
    String? type,
    String? title,
    Offset? position,
    Size? size,
    int? order,
    int? mode,
    Map<String, dynamic>? widgetValues,
    Map<String, dynamic>? properties,
    bool? collapsed,
    bool? pinned,
    Color? color,
    Color? bgColor,
  }) {
    return ComfyNode(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      position: position ?? this.position,
      size: size ?? this.size,
      order: order ?? this.order,
      mode: mode ?? this.mode,
      widgetValues: widgetValues ?? Map.from(this.widgetValues),
      properties: properties ?? Map.from(this.properties),
      collapsed: collapsed ?? this.collapsed,
      pinned: pinned ?? this.pinned,
      color: color ?? this.color,
      bgColor: bgColor ?? this.bgColor,
    );
  }

  @override
  String toString() => 'ComfyNode($id, type: $type)';
}

/// Represents a connection (edge) between nodes.
class ComfyEdge {
  /// Unique identifier for this edge.
  final String id;

  /// Source node ID.
  final String sourceNodeId;

  /// Source slot index.
  final int sourceSlot;

  /// Target node ID.
  final String targetNodeId;

  /// Target slot index.
  final int targetSlot;

  /// The data type flowing through this connection.
  final SlotType type;

  ComfyEdge({
    String? id,
    required this.sourceNodeId,
    required this.sourceSlot,
    required this.targetNodeId,
    required this.targetSlot,
    this.type = SlotType.any,
  }) : id = id ?? _generateId();

  ComfyEdge copyWith({
    String? id,
    String? sourceNodeId,
    int? sourceSlot,
    String? targetNodeId,
    int? targetSlot,
    SlotType? type,
  }) {
    return ComfyEdge(
      id: id ?? this.id,
      sourceNodeId: sourceNodeId ?? this.sourceNodeId,
      sourceSlot: sourceSlot ?? this.sourceSlot,
      targetNodeId: targetNodeId ?? this.targetNodeId,
      targetSlot: targetSlot ?? this.targetSlot,
      type: type ?? this.type,
    );
  }

  @override
  String toString() => 'ComfyEdge($sourceNodeId:$sourceSlot -> $targetNodeId:$targetSlot)';
}

/// A group of nodes for organization.
class ComfyGroup {
  /// Unique identifier.
  final String id;

  /// Group title.
  String title;

  /// Bounding rectangle.
  Rect bounds;

  /// Group color.
  Color color;

  /// Font size for title.
  double fontSize;

  /// Whether group is locked.
  bool locked;

  ComfyGroup({
    String? id,
    required this.title,
    required this.bounds,
    this.color = const Color(0xFF335533),
    this.fontSize = 24,
    this.locked = false,
  }) : id = id ?? _generateId();
}

/// Exception thrown when connection is invalid.
class InvalidConnectionException implements Exception {
  final String message;
  InvalidConnectionException(this.message);

  @override
  String toString() => 'InvalidConnectionException: $message';
}

/// The main graph container for ComfyUI workflows.
class ComfyGraph {
  /// Graph version for compatibility.
  final int version;

  /// Unique graph ID.
  final String id;

  /// All nodes in the graph.
  final Map<String, ComfyNode> _nodes = {};

  /// All edges in the graph.
  final Map<String, ComfyEdge> _edges = {};

  /// All groups in the graph.
  final Map<String, ComfyGroup> _groups = {};

  /// Node registry for type lookups.
  final NodeRegistry? registry;

  /// Counter for generating node IDs.
  int _lastNodeId = 0;

  /// Counter for generating edge IDs.
  int _lastEdgeId = 0;

  /// Extra metadata.
  final Map<String, dynamic> extra = {};

  ComfyGraph({
    this.version = 1,
    String? id,
    this.registry,
  }) : id = id ?? _generateId();

  /// Create an empty graph.
  factory ComfyGraph.empty({NodeRegistry? registry}) {
    return ComfyGraph(registry: registry);
  }

  /// All nodes.
  Iterable<ComfyNode> get nodes => _nodes.values;

  /// All edges.
  Iterable<ComfyEdge> get edges => _edges.values;

  /// All groups.
  Iterable<ComfyGroup> get groups => _groups.values;

  /// Number of nodes.
  int get nodeCount => _nodes.length;

  /// Number of edges.
  int get edgeCount => _edges.length;

  /// Get node by ID.
  ComfyNode? getNode(String id) => _nodes[id];

  /// Get edge by ID.
  ComfyEdge? getEdge(String id) => _edges[id];

  /// Get group by ID.
  ComfyGroup? getGroup(String id) => _groups[id];

  /// Add a node to the graph.
  ComfyNode addNode(ComfyNode node) {
    _nodes[node.id] = node;
    return node;
  }

  /// Add a node by type name.
  ComfyNode? addNodeByType(String type, Offset position) {
    final def = registry?.get(type);
    if (def == null) return null;

    final node = ComfyNode.fromDefinition(def, position: position);
    return addNode(node);
  }

  /// Remove a node and all connected edges.
  void removeNode(String id) {
    _nodes.remove(id);

    // Remove all edges connected to this node
    _edges.removeWhere((_, edge) =>
        edge.sourceNodeId == id || edge.targetNodeId == id);
  }

  /// Update a node's position.
  void updateNodePosition(String id, Offset position) {
    final node = _nodes[id];
    if (node != null) {
      node.position = position;
    }
  }

  /// Update a node's widget value.
  void updateWidgetValue(String nodeId, String widgetName, dynamic value) {
    final node = _nodes[nodeId];
    if (node != null) {
      node.widgetValues[widgetName] = value;
    }
  }

  /// Check if a connection is valid.
  bool canConnect(
    String sourceNodeId,
    int sourceSlot,
    String targetNodeId,
    int targetSlot,
  ) {
    if (registry == null) return true; // Allow all if no registry

    final sourceNode = _nodes[sourceNodeId];
    final targetNode = _nodes[targetNodeId];
    if (sourceNode == null || targetNode == null) return false;

    final sourceDef = registry!.get(sourceNode.type);
    final targetDef = registry!.get(targetNode.type);
    if (sourceDef == null || targetDef == null) return false;

    if (sourceSlot >= sourceDef.outputs.length) return false;
    if (targetSlot >= targetDef.inputs.length) return false;

    final sourceType = sourceDef.outputs[sourceSlot].type;
    final targetType = targetDef.inputs[targetSlot].type;

    return sourceType.canConnectTo(targetType);
  }

  /// Add an edge between nodes.
  ///
  /// Returns the edge if successful, null if invalid.
  ComfyEdge? connect(
    String sourceNodeId,
    int sourceSlot,
    String targetNodeId,
    int targetSlot,
  ) {
    if (!canConnect(sourceNodeId, sourceSlot, targetNodeId, targetSlot)) {
      return null;
    }

    // Remove any existing connection to target input
    _edges.removeWhere((_, edge) =>
        edge.targetNodeId == targetNodeId && edge.targetSlot == targetSlot);

    // Determine edge type
    SlotType type = SlotType.any;
    if (registry != null) {
      final sourceNode = _nodes[sourceNodeId];
      if (sourceNode != null) {
        final sourceDef = registry!.get(sourceNode.type);
        if (sourceDef != null && sourceSlot < sourceDef.outputs.length) {
          type = sourceDef.outputs[sourceSlot].type;
        }
      }
    }

    final edge = ComfyEdge(
      sourceNodeId: sourceNodeId,
      sourceSlot: sourceSlot,
      targetNodeId: targetNodeId,
      targetSlot: targetSlot,
      type: type,
    );

    _edges[edge.id] = edge;
    return edge;
  }

  /// Remove an edge by ID.
  void removeEdge(String id) {
    _edges.remove(id);
  }

  /// Remove edges connected to a specific slot.
  void disconnectSlot(String nodeId, int slotIndex, {required bool isInput}) {
    _edges.removeWhere((_, edge) {
      if (isInput) {
        return edge.targetNodeId == nodeId && edge.targetSlot == slotIndex;
      } else {
        return edge.sourceNodeId == nodeId && edge.sourceSlot == slotIndex;
      }
    });
  }

  /// Get all edges connected to a node.
  List<ComfyEdge> getNodeEdges(String nodeId) {
    return _edges.values.where((edge) =>
        edge.sourceNodeId == nodeId || edge.targetNodeId == nodeId).toList();
  }

  /// Get edges going into a node.
  List<ComfyEdge> getIncomingEdges(String nodeId) {
    return _edges.values.where((edge) => edge.targetNodeId == nodeId).toList();
  }

  /// Get edges coming out of a node.
  List<ComfyEdge> getOutgoingEdges(String nodeId) {
    return _edges.values.where((edge) => edge.sourceNodeId == nodeId).toList();
  }

  /// Add a group.
  ComfyGroup addGroup(ComfyGroup group) {
    _groups[group.id] = group;
    return group;
  }

  /// Remove a group.
  void removeGroup(String id) {
    _groups.remove(id);
  }

  /// Get nodes within a group's bounds.
  List<ComfyNode> getNodesInGroup(String groupId) {
    final group = _groups[groupId];
    if (group == null) return [];

    return _nodes.values.where((node) {
      return group.bounds.contains(node.position);
    }).toList();
  }

  /// Find output nodes (nodes that trigger execution).
  List<ComfyNode> getOutputNodes() {
    if (registry == null) return [];

    return _nodes.values.where((node) {
      final def = registry!.get(node.type);
      return def?.isOutputNode == true;
    }).toList();
  }

  /// Clear the entire graph.
  void clear() {
    _nodes.clear();
    _edges.clear();
    _groups.clear();
    extra.clear();
    _lastNodeId = 0;
    _lastEdgeId = 0;
  }

  /// Duplicate selected nodes.
  List<ComfyNode> duplicateNodes(Set<String> nodeIds, Offset offset) {
    final newNodes = <ComfyNode>[];
    final idMap = <String, String>{};

    // Clone nodes
    for (final id in nodeIds) {
      final node = _nodes[id];
      if (node == null) continue;

      final newNode = node.copyWith(
        id: _generateId(),
        position: node.position + offset,
      );
      addNode(newNode);
      newNodes.add(newNode);
      idMap[id] = newNode.id;
    }

    // Clone internal edges (use toList() to avoid concurrent modification)
    for (final edge in _edges.values.toList()) {
      if (nodeIds.contains(edge.sourceNodeId) &&
          nodeIds.contains(edge.targetNodeId)) {
        final newSourceId = idMap[edge.sourceNodeId];
        final newTargetId = idMap[edge.targetNodeId];
        if (newSourceId != null && newTargetId != null) {
          connect(
            newSourceId,
            edge.sourceSlot,
            newTargetId,
            edge.targetSlot,
          );
        }
      }
    }

    return newNodes;
  }

  @override
  String toString() => 'ComfyGraph($id, nodes: $nodeCount, edges: $edgeCount)';
}
