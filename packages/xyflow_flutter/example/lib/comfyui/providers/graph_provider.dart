/// Graph Provider - Riverpod state management for ComfyUI graph.
///
/// Manages the graph state including nodes, edges, and modifications.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/graph/comfy_graph.dart';
import '../core/nodes/node_registry.dart';

/// State for the graph.
class GraphState {
  /// The ComfyUI graph.
  final ComfyGraph graph;

  /// Whether the graph has unsaved changes.
  final bool isDirty;

  /// The current workflow file path (if loaded from file).
  final String? filePath;

  /// Error message if any operation failed.
  final String? error;

  const GraphState({
    required this.graph,
    this.isDirty = false,
    this.filePath,
    this.error,
  });

  GraphState copyWith({
    ComfyGraph? graph,
    bool? isDirty,
    String? filePath,
    String? error,
  }) {
    return GraphState(
      graph: graph ?? this.graph,
      isDirty: isDirty ?? this.isDirty,
      filePath: filePath ?? this.filePath,
      error: error,
    );
  }
}

/// Notifier for graph state.
class GraphNotifier extends StateNotifier<GraphState> {
  GraphNotifier(NodeRegistry? registry)
      : super(GraphState(graph: ComfyGraph(registry: registry)));

  /// Get the current graph.
  ComfyGraph get graph => state.graph;

  /// Add a node by type.
  ComfyNode? addNode(String type, Offset position) {
    final node = state.graph.addNodeByType(type, position);
    if (node != null) {
      state = state.copyWith(isDirty: true);
    }
    return node;
  }

  /// Add a node directly.
  ComfyNode addNodeDirect(ComfyNode node) {
    state.graph.addNode(node);
    state = state.copyWith(isDirty: true);
    return node;
  }

  /// Remove a node.
  void removeNode(String nodeId) {
    state.graph.removeNode(nodeId);
    state = state.copyWith(isDirty: true);
  }

  /// Update node position.
  void updateNodePosition(String nodeId, Offset position) {
    state.graph.updateNodePosition(nodeId, position);
    state = state.copyWith(isDirty: true);
  }

  /// Update widget value.
  void updateWidgetValue(String nodeId, String widgetName, dynamic value) {
    state.graph.updateWidgetValue(nodeId, widgetName, value);
    state = state.copyWith(isDirty: true);
  }

  /// Update node property.
  void updateNodeProperty(String nodeId, String property, dynamic value) {
    final node = state.graph.getNode(nodeId);
    if (node != null) {
      switch (property) {
        case 'title':
          node.title = value as String;
        case 'mode':
          node.mode = value as int;
        case 'collapsed':
          node.collapsed = value as bool;
        case 'pinned':
          node.pinned = value as bool;
      }
      state = state.copyWith(isDirty: true);
    }
  }

  /// Connect two nodes.
  ComfyEdge? connect(
    String sourceNodeId,
    int sourceSlot,
    String targetNodeId,
    int targetSlot,
  ) {
    final edge = state.graph.connect(
      sourceNodeId,
      sourceSlot,
      targetNodeId,
      targetSlot,
    );
    if (edge != null) {
      state = state.copyWith(isDirty: true);
    }
    return edge;
  }

  /// Remove an edge.
  void removeEdge(String edgeId) {
    state.graph.removeEdge(edgeId);
    state = state.copyWith(isDirty: true);
  }

  /// Disconnect a slot.
  void disconnectSlot(String nodeId, int slotIndex, {required bool isInput}) {
    state.graph.disconnectSlot(nodeId, slotIndex, isInput: isInput);
    state = state.copyWith(isDirty: true);
  }

  /// Add a group.
  ComfyGroup addGroup(String title, Rect bounds, {Color? color}) {
    final group = ComfyGroup(
      title: title,
      bounds: bounds,
      color: color ?? const Color(0xFF335533),
    );
    state.graph.addGroup(group);
    state = state.copyWith(isDirty: true);
    return group;
  }

  /// Remove a group.
  void removeGroup(String groupId) {
    state.graph.removeGroup(groupId);
    state = state.copyWith(isDirty: true);
  }

  /// Duplicate selected nodes.
  List<ComfyNode> duplicateNodes(Set<String> nodeIds, Offset offset) {
    final newNodes = state.graph.duplicateNodes(nodeIds, offset);
    if (newNodes.isNotEmpty) {
      state = state.copyWith(isDirty: true);
    }
    return newNodes;
  }

  /// Clear the graph.
  void clear() {
    state.graph.clear();
    state = state.copyWith(isDirty: true, filePath: null);
  }

  /// Mark as saved.
  void markSaved({String? filePath}) {
    state = state.copyWith(isDirty: false, filePath: filePath);
  }

  /// Set error.
  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  /// Create a new graph with a registry.
  void newGraph(NodeRegistry? registry) {
    state = GraphState(graph: ComfyGraph(registry: registry));
  }
}

/// Provider for the node registry.
final nodeRegistryProvider = StateProvider<NodeRegistry>((ref) {
  return NodeRegistry();
});

/// Provider for the graph notifier.
final graphProvider = StateNotifierProvider<GraphNotifier, GraphState>((ref) {
  final registry = ref.watch(nodeRegistryProvider);
  return GraphNotifier(registry);
});

/// Provider for all nodes in the graph.
final nodesProvider = Provider<Iterable<ComfyNode>>((ref) {
  return ref.watch(graphProvider).graph.nodes;
});

/// Provider for all edges in the graph.
final edgesProvider = Provider<Iterable<ComfyEdge>>((ref) {
  return ref.watch(graphProvider).graph.edges;
});

/// Provider for all groups in the graph.
final groupsProvider = Provider<Iterable<ComfyGroup>>((ref) {
  return ref.watch(graphProvider).graph.groups;
});

/// Provider for a specific node.
final nodeProvider = Provider.family<ComfyNode?, String>((ref, nodeId) {
  return ref.watch(graphProvider).graph.getNode(nodeId);
});

/// Provider for a specific edge.
final edgeProvider = Provider.family<ComfyEdge?, String>((ref, edgeId) {
  return ref.watch(graphProvider).graph.getEdge(edgeId);
});

/// Provider for incoming edges to a node.
final incomingEdgesProvider = Provider.family<List<ComfyEdge>, String>((ref, nodeId) {
  return ref.watch(graphProvider).graph.getIncomingEdges(nodeId);
});

/// Provider for outgoing edges from a node.
final outgoingEdgesProvider = Provider.family<List<ComfyEdge>, String>((ref, nodeId) {
  return ref.watch(graphProvider).graph.getOutgoingEdges(nodeId);
});

/// Provider for output nodes (nodes that trigger execution).
final outputNodesProvider = Provider<List<ComfyNode>>((ref) {
  return ref.watch(graphProvider).graph.getOutputNodes();
});

/// Provider for dirty state.
final isDirtyProvider = Provider<bool>((ref) {
  return ref.watch(graphProvider).isDirty;
});
