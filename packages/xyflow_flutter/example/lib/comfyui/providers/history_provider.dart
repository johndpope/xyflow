/// History Provider - Undo/redo support for ComfyUI graph operations.
///
/// Manages command history for graph modifications.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/graph/comfy_graph.dart';
import '../core/serialization/workflow_json.dart';
import 'graph_provider.dart';

/// A snapshot of the graph state for undo/redo.
class GraphSnapshot {
  /// Serialized graph data.
  final Map<String, dynamic> data;

  /// Description of the action that created this snapshot.
  final String description;

  /// Timestamp when snapshot was created.
  final DateTime timestamp;

  const GraphSnapshot({
    required this.data,
    required this.description,
    required this.timestamp,
  });
}

/// State for history management.
class HistoryState {
  /// Stack of undo snapshots.
  final List<GraphSnapshot> undoStack;

  /// Stack of redo snapshots.
  final List<GraphSnapshot> redoStack;

  /// Maximum history size.
  final int maxHistorySize;

  /// Whether currently in an undo/redo operation.
  final bool isApplying;

  const HistoryState({
    this.undoStack = const [],
    this.redoStack = const [],
    this.maxHistorySize = 50,
    this.isApplying = false,
  });

  /// Whether can undo.
  bool get canUndo => undoStack.isNotEmpty;

  /// Whether can redo.
  bool get canRedo => redoStack.isNotEmpty;

  /// Number of undo steps available.
  int get undoCount => undoStack.length;

  /// Number of redo steps available.
  int get redoCount => redoStack.length;

  /// Get description of next undo action.
  String? get nextUndoDescription =>
      undoStack.isNotEmpty ? undoStack.last.description : null;

  /// Get description of next redo action.
  String? get nextRedoDescription =>
      redoStack.isNotEmpty ? redoStack.last.description : null;

  HistoryState copyWith({
    List<GraphSnapshot>? undoStack,
    List<GraphSnapshot>? redoStack,
    int? maxHistorySize,
    bool? isApplying,
  }) {
    return HistoryState(
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      maxHistorySize: maxHistorySize ?? this.maxHistorySize,
      isApplying: isApplying ?? this.isApplying,
    );
  }
}

/// Notifier for history state.
class HistoryNotifier extends StateNotifier<HistoryState> {
  final Ref _ref;

  HistoryNotifier(this._ref) : super(const HistoryState());

  /// Record current state before making a change.
  ///
  /// Call this before modifying the graph.
  void recordState(String description) {
    if (state.isApplying) return;

    final graph = _ref.read(graphProvider).graph;
    final snapshot = _createSnapshot(graph, description);

    // Add to undo stack
    var newUndoStack = [...state.undoStack, snapshot];

    // Trim if exceeds max size
    if (newUndoStack.length > state.maxHistorySize) {
      newUndoStack = newUndoStack.sublist(
        newUndoStack.length - state.maxHistorySize,
      );
    }

    // Clear redo stack when new action is recorded
    state = state.copyWith(
      undoStack: newUndoStack,
      redoStack: [],
    );
  }

  /// Undo the last action.
  void undo() {
    if (!state.canUndo) return;

    final graph = _ref.read(graphProvider).graph;
    final graphNotifier = _ref.read(graphProvider.notifier);

    // Create snapshot of current state for redo
    final currentSnapshot = _createSnapshot(graph, 'Current state');

    // Get the state to restore
    final snapshotToRestore = state.undoStack.last;
    final newUndoStack = state.undoStack.sublist(0, state.undoStack.length - 1);

    // Mark as applying to prevent recording this change
    state = state.copyWith(isApplying: true);

    try {
      // Restore the graph state
      _applySnapshot(graphNotifier, snapshotToRestore);

      // Update stacks
      state = state.copyWith(
        undoStack: newUndoStack,
        redoStack: [...state.redoStack, currentSnapshot],
        isApplying: false,
      );
    } catch (e) {
      state = state.copyWith(isApplying: false);
      rethrow;
    }
  }

  /// Redo the last undone action.
  void redo() {
    if (!state.canRedo) return;

    final graph = _ref.read(graphProvider).graph;
    final graphNotifier = _ref.read(graphProvider.notifier);

    // Create snapshot of current state for undo
    final currentSnapshot = _createSnapshot(graph, 'Before redo');

    // Get the state to restore
    final snapshotToRestore = state.redoStack.last;
    final newRedoStack = state.redoStack.sublist(0, state.redoStack.length - 1);

    // Mark as applying to prevent recording this change
    state = state.copyWith(isApplying: true);

    try {
      // Restore the graph state
      _applySnapshot(graphNotifier, snapshotToRestore);

      // Update stacks
      state = state.copyWith(
        undoStack: [...state.undoStack, currentSnapshot],
        redoStack: newRedoStack,
        isApplying: false,
      );
    } catch (e) {
      state = state.copyWith(isApplying: false);
      rethrow;
    }
  }

  /// Clear all history.
  void clear() {
    state = state.copyWith(
      undoStack: [],
      redoStack: [],
    );
  }

  /// Set maximum history size.
  void setMaxHistorySize(int size) {
    var newUndoStack = state.undoStack;
    if (newUndoStack.length > size) {
      newUndoStack = newUndoStack.sublist(newUndoStack.length - size);
    }

    state = state.copyWith(
      maxHistorySize: size,
      undoStack: newUndoStack,
    );
  }

  GraphSnapshot _createSnapshot(ComfyGraph graph, String description) {
    return GraphSnapshot(
      data: WorkflowSerializer.toJson(graph),
      description: description,
      timestamp: DateTime.now(),
    );
  }

  void _applySnapshot(GraphNotifier notifier, GraphSnapshot snapshot) {
    final deserializer = WorkflowDeserializer();
    final restoredGraph = deserializer.fromJson(snapshot.data);

    // Replace the graph
    notifier.replaceGraph(restoredGraph);
  }
}

/// Provider for history state.
final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier(ref);
});

/// Provider for whether can undo.
final canUndoProvider = Provider<bool>((ref) {
  return ref.watch(historyProvider).canUndo;
});

/// Provider for whether can redo.
final canRedoProvider = Provider<bool>((ref) {
  return ref.watch(historyProvider).canRedo;
});

/// Provider for undo count.
final undoCountProvider = Provider<int>((ref) {
  return ref.watch(historyProvider).undoCount;
});

/// Provider for redo count.
final redoCountProvider = Provider<int>((ref) {
  return ref.watch(historyProvider).redoCount;
});

/// Provider for next undo description.
final nextUndoDescriptionProvider = Provider<String?>((ref) {
  return ref.watch(historyProvider).nextUndoDescription;
});

/// Provider for next redo description.
final nextRedoDescriptionProvider = Provider<String?>((ref) {
  return ref.watch(historyProvider).nextRedoDescription;
});

/// Extension on Ref for convenient history recording.
extension HistoryRefExtension on Ref {
  /// Record state and perform an action.
  ///
  /// Usage:
  /// ```dart
  /// ref.withHistory('Add node', () {
  ///   ref.read(graphProvider.notifier).addNode(...);
  /// });
  /// ```
  T withHistory<T>(String description, T Function() action) {
    read(historyProvider.notifier).recordState(description);
    return action();
  }
}

/// Extension on WidgetRef for convenient history recording.
extension HistoryWidgetRefExtension on WidgetRef {
  /// Record state and perform an action.
  ///
  /// Usage:
  /// ```dart
  /// ref.withHistory('Add node', () {
  ///   ref.read(graphProvider.notifier).addNode(...);
  /// });
  /// ```
  T withHistory<T>(String description, T Function() action) {
    read(historyProvider.notifier).recordState(description);
    return action();
  }
}
