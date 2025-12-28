/// Selection Provider - Manages selection state for nodes and edges.
library;

import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/graph/comfy_graph.dart';
import '../core/nodes/node_definition.dart';
import 'graph_provider.dart';

/// State for selection.
class SelectionState {
  /// Selected node IDs.
  final Set<String> selectedNodeIds;

  /// Selected edge IDs.
  final Set<String> selectedEdgeIds;

  /// Primary selected node ID (for properties panel).
  final String? primaryNodeId;

  /// Whether multi-select mode is active.
  final bool multiSelectMode;

  const SelectionState({
    this.selectedNodeIds = const {},
    this.selectedEdgeIds = const {},
    this.primaryNodeId,
    this.multiSelectMode = false,
  });

  /// Whether any nodes are selected.
  bool get hasSelectedNodes => selectedNodeIds.isNotEmpty;

  /// Whether any edges are selected.
  bool get hasSelectedEdges => selectedEdgeIds.isNotEmpty;

  /// Whether anything is selected.
  bool get hasSelection => hasSelectedNodes || hasSelectedEdges;

  /// Number of selected nodes.
  int get selectedNodeCount => selectedNodeIds.length;

  /// Number of selected edges.
  int get selectedEdgeCount => selectedEdgeIds.length;

  SelectionState copyWith({
    Set<String>? selectedNodeIds,
    Set<String>? selectedEdgeIds,
    String? primaryNodeId,
    bool? multiSelectMode,
    bool clearPrimary = false,
  }) {
    return SelectionState(
      selectedNodeIds: selectedNodeIds ?? this.selectedNodeIds,
      selectedEdgeIds: selectedEdgeIds ?? this.selectedEdgeIds,
      primaryNodeId: clearPrimary ? null : (primaryNodeId ?? this.primaryNodeId),
      multiSelectMode: multiSelectMode ?? this.multiSelectMode,
    );
  }
}

/// Notifier for selection state.
class SelectionNotifier extends StateNotifier<SelectionState> {
  SelectionNotifier() : super(const SelectionState());

  /// Select a single node (replaces current selection).
  void selectNode(String nodeId) {
    state = SelectionState(
      selectedNodeIds: {nodeId},
      primaryNodeId: nodeId,
    );
  }

  /// Select a single edge (replaces current selection).
  void selectEdge(String edgeId) {
    state = SelectionState(
      selectedEdgeIds: {edgeId},
    );
  }

  /// Add a node to selection.
  void addNodeToSelection(String nodeId) {
    state = state.copyWith(
      selectedNodeIds: {...state.selectedNodeIds, nodeId},
      primaryNodeId: nodeId,
    );
  }

  /// Remove a node from selection.
  void removeNodeFromSelection(String nodeId) {
    final newIds = {...state.selectedNodeIds}..remove(nodeId);
    state = state.copyWith(
      selectedNodeIds: newIds,
      primaryNodeId: newIds.isEmpty ? null : (state.primaryNodeId == nodeId ? newIds.first : state.primaryNodeId),
    );
  }

  /// Toggle node selection.
  void toggleNodeSelection(String nodeId) {
    if (state.selectedNodeIds.contains(nodeId)) {
      removeNodeFromSelection(nodeId);
    } else {
      addNodeToSelection(nodeId);
    }
  }

  /// Add an edge to selection.
  void addEdgeToSelection(String edgeId) {
    state = state.copyWith(
      selectedEdgeIds: {...state.selectedEdgeIds, edgeId},
    );
  }

  /// Remove an edge from selection.
  void removeEdgeFromSelection(String edgeId) {
    final newIds = {...state.selectedEdgeIds}..remove(edgeId);
    state = state.copyWith(selectedEdgeIds: newIds);
  }

  /// Toggle edge selection.
  void toggleEdgeSelection(String edgeId) {
    if (state.selectedEdgeIds.contains(edgeId)) {
      removeEdgeFromSelection(edgeId);
    } else {
      addEdgeToSelection(edgeId);
    }
  }

  /// Select multiple nodes.
  void selectNodes(Set<String> nodeIds) {
    state = SelectionState(
      selectedNodeIds: nodeIds,
      primaryNodeId: nodeIds.isNotEmpty ? nodeIds.first : null,
    );
  }

  /// Select multiple edges.
  void selectEdges(Set<String> edgeIds) {
    state = SelectionState(
      selectedEdgeIds: edgeIds,
    );
  }

  /// Select nodes within a rectangle.
  void selectNodesInRect(Rect rect, Iterable<ComfyNode> nodes) {
    final selectedIds = nodes
        .where((node) => rect.contains(node.position))
        .map((node) => node.id)
        .toSet();

    state = SelectionState(
      selectedNodeIds: selectedIds,
      primaryNodeId: selectedIds.isNotEmpty ? selectedIds.first : null,
    );
  }

  /// Clear all selection.
  void clearSelection() {
    state = const SelectionState();
  }

  /// Clear node selection only.
  void clearNodeSelection() {
    state = state.copyWith(
      selectedNodeIds: {},
      clearPrimary: true,
    );
  }

  /// Clear edge selection only.
  void clearEdgeSelection() {
    state = state.copyWith(selectedEdgeIds: {});
  }

  /// Set multi-select mode.
  void setMultiSelectMode(bool enabled) {
    state = state.copyWith(multiSelectMode: enabled);
  }

  /// Set primary selected node.
  void setPrimaryNode(String? nodeId) {
    state = state.copyWith(
      primaryNodeId: nodeId,
      clearPrimary: nodeId == null,
    );
  }

  /// Check if a node is selected.
  bool isNodeSelected(String nodeId) {
    return state.selectedNodeIds.contains(nodeId);
  }

  /// Check if an edge is selected.
  bool isEdgeSelected(String edgeId) {
    return state.selectedEdgeIds.contains(edgeId);
  }
}

/// Provider for selection state.
final selectionProvider = StateNotifierProvider<SelectionNotifier, SelectionState>((ref) {
  return SelectionNotifier();
});

/// Provider for selected node IDs.
final selectedNodeIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(selectionProvider).selectedNodeIds;
});

/// Provider for selected edge IDs.
final selectedEdgeIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(selectionProvider).selectedEdgeIds;
});

/// Provider for primary selected node.
final primarySelectedNodeProvider = Provider<ComfyNode?>((ref) {
  final primaryId = ref.watch(selectionProvider).primaryNodeId;
  if (primaryId == null) return null;
  return ref.watch(nodeProvider(primaryId));
});

/// Provider for primary selected node definition.
final primarySelectedNodeDefinitionProvider = Provider<NodeDefinition?>((ref) {
  final node = ref.watch(primarySelectedNodeProvider);
  if (node == null) return null;
  final registry = ref.watch(nodeRegistryProvider);
  return registry.get(node.type);
});

/// Provider for checking if a specific node is selected.
final isNodeSelectedProvider = Provider.family<bool, String>((ref, nodeId) {
  return ref.watch(selectionProvider).selectedNodeIds.contains(nodeId);
});

/// Provider for checking if a specific edge is selected.
final isEdgeSelectedProvider = Provider.family<bool, String>((ref, edgeId) {
  return ref.watch(selectionProvider).selectedEdgeIds.contains(edgeId);
});

/// Provider for multi-select mode state.
final multiSelectModeProvider = Provider<bool>((ref) {
  return ref.watch(selectionProvider).multiSelectMode;
});
