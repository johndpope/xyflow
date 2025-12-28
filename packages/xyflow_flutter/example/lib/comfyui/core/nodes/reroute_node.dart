/// Reroute Node - Special node for routing connections.
///
/// Reroute nodes act as pass-through points for edges, allowing
/// better visual organization of complex workflows.
library;

import 'package:flutter/material.dart';

import '../graph/comfy_graph.dart';
import 'node_definition.dart';
import 'slot_types.dart';

/// Reroute node type identifier.
const String rerouteNodeType = 'Reroute';

/// Create a reroute node definition.
NodeDefinition createRerouteNodeDefinition() {
  return NodeDefinition(
    name: rerouteNodeType,
    displayName: 'Reroute',
    category: 'utils',
    description: 'Routes connections through a point',
    inputs: [
      SlotDefinition(
        name: '',
        type: SlotType.any,
        isOptional: false,
      ),
    ],
    outputs: [
      SlotDefinition(
        name: '',
        type: SlotType.any,
        isOptional: false,
      ),
    ],
    widgets: [],
  );
}

/// Create a reroute node at the given position.
ComfyNode createRerouteNode(Offset position, {SlotType? slotType}) {
  return ComfyNode(
    type: rerouteNodeType,
    position: position,
    title: '',
    widgetValues: {
      if (slotType != null) '_slotType': slotType.name,
    },
  );
}

/// Check if a node is a reroute node.
bool isRerouteNode(ComfyNode node) {
  return node.type == rerouteNodeType;
}

/// Get the slot type of a reroute node.
///
/// Reroute nodes inherit their type from the first connected edge.
SlotType getRerouteSlotType(ComfyNode node, ComfyGraph graph) {
  if (!isRerouteNode(node)) {
    return SlotType.any;
  }

  // Check if type is stored in widgetValues
  final storedType = node.widgetValues['_slotType'] as String?;
  if (storedType != null) {
    try {
      return SlotType.values.firstWhere((e) => e.name == storedType);
    } catch (_) {
      // Fall through to check connections
    }
  }

  // Check incoming edges
  final incoming = graph.getIncomingEdges(node.id);
  if (incoming.isNotEmpty) {
    final sourceNode = graph.getNode(incoming.first.sourceNodeId);
    if (sourceNode != null) {
      // If source is also a reroute, follow the chain
      if (isRerouteNode(sourceNode)) {
        return getRerouteSlotType(sourceNode, graph);
      }
      // Otherwise get the output slot type
      return incoming.first.type;
    }
  }

  // Check outgoing edges
  final outgoing = graph.getOutgoingEdges(node.id);
  if (outgoing.isNotEmpty) {
    final targetNode = graph.getNode(outgoing.first.targetNodeId);
    if (targetNode != null) {
      // If target is also a reroute, follow the chain
      if (isRerouteNode(targetNode)) {
        return getRerouteSlotType(targetNode, graph);
      }
      // Otherwise get the input slot type
      return outgoing.first.type;
    }
  }

  return SlotType.any;
}

/// Update the slot type of a reroute node.
void updateRerouteSlotType(ComfyNode node, SlotType type) {
  if (isRerouteNode(node)) {
    node.widgetValues['_slotType'] = type.name;
  }
}

/// Find all reroute nodes in a chain starting from the given node.
///
/// Follows both incoming and outgoing reroute connections.
List<ComfyNode> getRerouteChain(ComfyNode node, ComfyGraph graph) {
  if (!isRerouteNode(node)) {
    return [];
  }

  final chain = <ComfyNode>[node];
  final visited = <String>{node.id};

  void followChain(ComfyNode current) {
    // Follow incoming
    for (final edge in graph.getIncomingEdges(current.id)) {
      final source = graph.getNode(edge.sourceNodeId);
      if (source != null && isRerouteNode(source) && !visited.contains(source.id)) {
        visited.add(source.id);
        chain.add(source);
        followChain(source);
      }
    }

    // Follow outgoing
    for (final edge in graph.getOutgoingEdges(current.id)) {
      final target = graph.getNode(edge.targetNodeId);
      if (target != null && isRerouteNode(target) && !visited.contains(target.id)) {
        visited.add(target.id);
        chain.add(target);
        followChain(target);
      }
    }
  }

  followChain(node);
  return chain;
}

/// Get the source node of a reroute chain (the non-reroute node providing input).
ComfyNode? getRerouteChainSource(ComfyNode node, ComfyGraph graph) {
  if (!isRerouteNode(node)) {
    return node;
  }

  final visited = <String>{node.id};
  ComfyNode current = node;

  while (true) {
    final incoming = graph.getIncomingEdges(current.id);
    if (incoming.isEmpty) {
      return null; // No source
    }

    final source = graph.getNode(incoming.first.sourceNodeId);
    if (source == null) {
      return null;
    }

    if (!isRerouteNode(source)) {
      return source; // Found non-reroute source
    }

    if (visited.contains(source.id)) {
      return null; // Cycle detected
    }

    visited.add(source.id);
    current = source;
  }
}

/// Get all target nodes of a reroute chain (non-reroute nodes receiving output).
List<ComfyNode> getRerouteChainTargets(ComfyNode node, ComfyGraph graph) {
  if (!isRerouteNode(node)) {
    return [node];
  }

  final targets = <ComfyNode>[];
  final visited = <String>{};

  void findTargets(ComfyNode current) {
    if (visited.contains(current.id)) {
      return;
    }
    visited.add(current.id);

    for (final edge in graph.getOutgoingEdges(current.id)) {
      final target = graph.getNode(edge.targetNodeId);
      if (target == null) continue;

      if (isRerouteNode(target)) {
        findTargets(target);
      } else {
        targets.add(target);
      }
    }
  }

  findTargets(node);
  return targets;
}

/// Insert a reroute node on an existing edge.
ComfyNode? insertRerouteOnEdge(
  ComfyGraph graph,
  String edgeId,
  Offset position,
) {
  final edge = graph.getEdge(edgeId);
  if (edge == null) return null;

  // Create reroute node with the edge's type
  final reroute = createRerouteNode(position, slotType: edge.type);
  graph.addNode(reroute);

  // Store original connection info
  final sourceNodeId = edge.sourceNodeId;
  final sourceSlot = edge.sourceSlot;
  final targetNodeId = edge.targetNodeId;
  final targetSlot = edge.targetSlot;

  // Remove original edge
  graph.removeEdge(edgeId);

  // Connect source -> reroute
  graph.connect(sourceNodeId, sourceSlot, reroute.id, 0);

  // Connect reroute -> target
  graph.connect(reroute.id, 0, targetNodeId, targetSlot);

  return reroute;
}

/// Remove a reroute node and reconnect edges.
void removeRerouteNode(ComfyGraph graph, String rerouteId) {
  final node = graph.getNode(rerouteId);
  if (node == null || !isRerouteNode(node)) return;

  final incoming = graph.getIncomingEdges(rerouteId);
  final outgoing = graph.getOutgoingEdges(rerouteId);

  // Get source info
  String? sourceNodeId;
  int? sourceSlot;

  if (incoming.isNotEmpty) {
    sourceNodeId = incoming.first.sourceNodeId;
    sourceSlot = incoming.first.sourceSlot;
  }

  // Collect target info
  final targets = outgoing
      .map((e) => (nodeId: e.targetNodeId, slot: e.targetSlot))
      .toList();

  // Remove the reroute node (this also removes connected edges)
  graph.removeNode(rerouteId);

  // Reconnect source to all targets
  if (sourceNodeId != null && sourceSlot != null) {
    for (final target in targets) {
      graph.connect(sourceNodeId, sourceSlot, target.nodeId, target.slot);
    }
  }
}

/// Collapse a chain of reroute nodes into a single reroute.
ComfyNode? collapseRerouteChain(ComfyGraph graph, ComfyNode startNode) {
  if (!isRerouteNode(startNode)) return null;

  final chain = getRerouteChain(startNode, graph);
  if (chain.length <= 1) return startNode;

  // Find the first and last in chain by connection
  ComfyNode? first;
  ComfyNode? last;

  for (final node in chain) {
    final incoming = graph.getIncomingEdges(node.id);
    final hasNonRerouteSource = incoming.any((e) {
      final source = graph.getNode(e.sourceNodeId);
      return source != null && !isRerouteNode(source);
    });
    if (hasNonRerouteSource || incoming.isEmpty) {
      first = node;
    }

    final outgoing = graph.getOutgoingEdges(node.id);
    final hasNonRerouteTarget = outgoing.any((e) {
      final target = graph.getNode(e.targetNodeId);
      return target != null && !isRerouteNode(target);
    });
    if (hasNonRerouteTarget || outgoing.isEmpty) {
      last = node;
    }
  }

  if (first == null || last == null || first.id == last.id) {
    return startNode;
  }

  // Calculate midpoint position
  final positions = chain.map((n) => n.position).toList();
  final midX = positions.map((p) => p.dx).reduce((a, b) => a + b) / positions.length;
  final midY = positions.map((p) => p.dy).reduce((a, b) => a + b) / positions.length;

  // Get connections to preserve
  final incoming = graph.getIncomingEdges(first.id).where((e) {
    final source = graph.getNode(e.sourceNodeId);
    return source != null && !isRerouteNode(source);
  }).toList();

  final outgoing = graph.getOutgoingEdges(last.id).where((e) {
    final target = graph.getNode(e.targetNodeId);
    return target != null && !isRerouteNode(target);
  }).toList();

  // Remove all reroutes in chain
  for (final node in chain) {
    graph.removeNode(node.id);
  }

  // Create single reroute at midpoint
  final slotType = incoming.isNotEmpty ? incoming.first.type : SlotType.any;
  final newReroute = createRerouteNode(Offset(midX, midY), slotType: slotType);
  graph.addNode(newReroute);

  // Reconnect
  for (final edge in incoming) {
    graph.connect(edge.sourceNodeId, edge.sourceSlot, newReroute.id, 0);
  }

  for (final edge in outgoing) {
    graph.connect(newReroute.id, 0, edge.targetNodeId, edge.targetSlot);
  }

  return newReroute;
}
