/// Topological sort for determining execution order.
///
/// Implements Kahn's algorithm for DAG topological ordering.
library;

import 'comfy_graph.dart';

/// Result of topological sort.
class TopologicalSortResult {
  /// Nodes in execution order.
  final List<ComfyNode> orderedNodes;

  /// Whether the graph has cycles.
  final bool hasCycle;

  /// Nodes involved in cycles (if any).
  final List<ComfyNode> cycleNodes;

  const TopologicalSortResult({
    required this.orderedNodes,
    this.hasCycle = false,
    this.cycleNodes = const [],
  });

  /// Whether the sort succeeded (no cycles).
  bool get isValid => !hasCycle;
}

/// Performs topological sort on a ComfyGraph.
///
/// Uses Kahn's algorithm to find a valid execution order.
/// Detects cycles and returns them if present.
TopologicalSortResult topologicalSort(ComfyGraph graph) {
  // Build adjacency list and in-degree counts
  final inDegree = <String, int>{};
  final adjacency = <String, List<String>>{};

  // Initialize
  for (final node in graph.nodes) {
    inDegree[node.id] = 0;
    adjacency[node.id] = [];
  }

  // Count in-degrees and build adjacency list
  for (final edge in graph.edges) {
    inDegree[edge.targetNodeId] = (inDegree[edge.targetNodeId] ?? 0) + 1;
    adjacency[edge.sourceNodeId]?.add(edge.targetNodeId);
  }

  // Find all nodes with no incoming edges
  final queue = <String>[];
  for (final entry in inDegree.entries) {
    if (entry.value == 0) {
      queue.add(entry.key);
    }
  }

  // Process nodes in topological order
  final result = <ComfyNode>[];
  var order = 0;

  while (queue.isNotEmpty) {
    final nodeId = queue.removeAt(0);
    final node = graph.getNode(nodeId);
    if (node != null) {
      // Assign execution order
      node.order = order++;
      result.add(node);
    }

    // Reduce in-degree of adjacent nodes
    for (final targetId in adjacency[nodeId] ?? []) {
      inDegree[targetId] = (inDegree[targetId] ?? 1) - 1;
      if (inDegree[targetId] == 0) {
        queue.add(targetId);
      }
    }
  }

  // Check for cycles
  if (result.length != graph.nodeCount) {
    // Find nodes in cycle
    final processedIds = result.map((n) => n.id).toSet();
    final cycleNodes = graph.nodes
        .where((n) => !processedIds.contains(n.id))
        .toList();

    return TopologicalSortResult(
      orderedNodes: result,
      hasCycle: true,
      cycleNodes: cycleNodes,
    );
  }

  return TopologicalSortResult(orderedNodes: result);
}

/// Get execution order for nodes leading to outputs.
///
/// Only returns nodes that are ancestors of output nodes.
TopologicalSortResult getExecutionOrder(ComfyGraph graph) {
  // First, find all output nodes
  final outputNodes = graph.getOutputNodes();
  if (outputNodes.isEmpty) {
    // If no output nodes, sort entire graph
    return topologicalSort(graph);
  }

  // Find all ancestor nodes of output nodes
  final requiredNodes = <String>{};
  final toProcess = <String>[...outputNodes.map((n) => n.id)];

  while (toProcess.isNotEmpty) {
    final nodeId = toProcess.removeLast();
    if (requiredNodes.contains(nodeId)) continue;
    requiredNodes.add(nodeId);

    // Add all source nodes
    for (final edge in graph.getIncomingEdges(nodeId)) {
      if (!requiredNodes.contains(edge.sourceNodeId)) {
        toProcess.add(edge.sourceNodeId);
      }
    }
  }

  // Create a subgraph with only required nodes
  final subgraph = ComfyGraph(registry: graph.registry);
  for (final nodeId in requiredNodes) {
    final node = graph.getNode(nodeId);
    if (node != null) {
      subgraph.addNode(node);
    }
  }
  for (final edge in graph.edges) {
    if (requiredNodes.contains(edge.sourceNodeId) &&
        requiredNodes.contains(edge.targetNodeId)) {
      subgraph.connect(
        edge.sourceNodeId,
        edge.sourceSlot,
        edge.targetNodeId,
        edge.targetSlot,
      );
    }
  }

  return topologicalSort(subgraph);
}

/// Find all paths from source to sink nodes.
List<List<ComfyNode>> findAllPaths(
  ComfyGraph graph,
  String startNodeId,
  String endNodeId,
) {
  final paths = <List<ComfyNode>>[];
  final currentPath = <ComfyNode>[];
  final visited = <String>{};

  void dfs(String nodeId) {
    if (visited.contains(nodeId)) return;

    final node = graph.getNode(nodeId);
    if (node == null) return;

    visited.add(nodeId);
    currentPath.add(node);

    if (nodeId == endNodeId) {
      paths.add(List.from(currentPath));
    } else {
      for (final edge in graph.getOutgoingEdges(nodeId)) {
        dfs(edge.targetNodeId);
      }
    }

    currentPath.removeLast();
    visited.remove(nodeId);
  }

  dfs(startNodeId);
  return paths;
}

/// Find the longest path in the graph.
List<ComfyNode> findLongestPath(ComfyGraph graph) {
  // Topological sort first
  final sortResult = topologicalSort(graph);
  if (!sortResult.isValid) return [];

  final distances = <String, int>{};
  final predecessors = <String, String?>{};

  // Initialize distances
  for (final node in graph.nodes) {
    distances[node.id] = 0;
    predecessors[node.id] = null;
  }

  // Process nodes in topological order
  for (final node in sortResult.orderedNodes) {
    for (final edge in graph.getOutgoingEdges(node.id)) {
      final newDist = distances[node.id]! + 1;
      if (newDist > (distances[edge.targetNodeId] ?? 0)) {
        distances[edge.targetNodeId] = newDist;
        predecessors[edge.targetNodeId] = node.id;
      }
    }
  }

  // Find the node with maximum distance
  String? endNodeId;
  var maxDist = 0;
  for (final entry in distances.entries) {
    if (entry.value > maxDist) {
      maxDist = entry.value;
      endNodeId = entry.key;
    }
  }

  if (endNodeId == null) return [];

  // Reconstruct path
  final path = <ComfyNode>[];
  String? current = endNodeId;
  while (current != null) {
    final node = graph.getNode(current);
    if (node != null) {
      path.insert(0, node);
    }
    current = predecessors[current];
  }

  return path;
}
