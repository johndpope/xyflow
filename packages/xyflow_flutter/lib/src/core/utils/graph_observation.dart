import '../types/edge.dart';
import '../types/node.dart';
import '../types/position.dart';
import '../types/viewport.dart';

/// Compact snapshot of a live [XYFlow] graph for an LLM / agent.
///
/// This is the Flutter-package equivalent of a scene "what's on screen"
/// observation: node ids, types, positions, selection, the focused node
/// (like a play-head / character), edges, and the viewport.
Map<String, dynamic> observeGraph<N, E>({
  required List<Node<N>> nodes,
  required List<Edge<E>> edges,
  Set<String>? selectedIds,
  String? focusNodeId,
  Viewport? viewport,
  Map<String, dynamic> Function(Node<N> node)? nodeData,
  Map<String, dynamic> Function(Edge<E> edge)? edgeData,
}) {
  final selected = selectedIds ??
      {for (final n in nodes) if (n.selected) n.id};
  return {
    'node_count': nodes.length,
    'edge_count': edges.length,
    'selected_ids': selected.toList(),
    'focus_node_id': focusNodeId ??
        (selected.isNotEmpty ? selected.first : (nodes.isEmpty ? null : nodes.first.id)),
    if (viewport != null)
      'viewport': {'x': viewport.x, 'y': viewport.y, 'zoom': viewport.zoom},
    'nodes': [
      for (final n in nodes)
        {
          'id': n.id,
          'type': n.type,
          'x': n.position.x,
          'y': n.position.y,
          'selected': n.selected || selected.contains(n.id),
          if (nodeData != null) 'data': nodeData(n),
        },
    ],
    'edges': [
      for (final e in edges)
        {
          'id': e.id,
          'source': e.source,
          'target': e.target,
          if (e.label != null) 'label': e.label,
          if (edgeData != null) 'data': edgeData(e),
        },
    ],
  };
}

/// Structural edit an agent can apply to a graph.
///
/// [rewire] changes an existing edge's source/target (or inserts a new
/// edge when [id] is unknown). Callers supply [nodeData] / [edgeData]
/// factories so this stays payload-agnostic.
class GraphPatch {
  const GraphPatch({
    this.addNodes = const [],
    this.updateNodes = const [],
    this.removeNodeIds = const [],
    this.addEdges = const [],
    this.removeEdgeIds = const [],
    this.rewire = const [],
  });

  final List<Map<String, dynamic>> addNodes;
  final List<Map<String, dynamic>> updateNodes;
  final List<String> removeNodeIds;
  final List<Map<String, dynamic>> addEdges;
  final List<String> removeEdgeIds;

  /// Each item: `{id?, source, target, label?}`.
  final List<Map<String, dynamic>> rewire;

  factory GraphPatch.fromJson(Map<String, dynamic> json) => GraphPatch(
        addNodes: _maps(json['add_nodes'] ?? json['addNodes']),
        updateNodes: _maps(json['update_nodes'] ?? json['updateNodes']),
        removeNodeIds: [
          for (final id in (json['remove_node_ids'] ?? json['removeNodeIds'] ?? const []))
            id.toString(),
        ],
        addEdges: _maps(json['add_edges'] ?? json['addEdges']),
        removeEdgeIds: [
          for (final id in (json['remove_edge_ids'] ?? json['removeEdgeIds'] ?? const []))
            id.toString(),
        ],
        rewire: _maps(json['rewire']),
      );
}

List<Map<String, dynamic>> _maps(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

/// Result of [applyGraphPatch].
class GraphPatchResult<N, E> {
  const GraphPatchResult({required this.nodes, required this.edges});
  final List<Node<N>> nodes;
  final List<Edge<E>> edges;
}

/// Apply a [GraphPatch] to in-memory xyflow nodes/edges.
GraphPatchResult<N, E> applyGraphPatch<N, E>({
  required List<Node<N>> nodes,
  required List<Edge<E>> edges,
  required GraphPatch patch,
  required N Function(Map<String, dynamic> json, Node<N>? existing) nodeData,
  E? Function(Map<String, dynamic> json)? edgeData,
}) {
  final removeNodes = patch.removeNodeIds.toSet();
  var nextNodes = [
    for (final n in nodes)
      if (!removeNodes.contains(n.id)) n,
  ];
  final byId = {for (final n in nextNodes) n.id: n};

  for (final raw in patch.updateNodes) {
    final id = raw['id']?.toString();
    if (id == null || !byId.containsKey(id)) continue;
    final existing = byId[id]!;
    final x = (raw['x'] as num?)?.toDouble();
    final y = (raw['y'] as num?)?.toDouble();
    byId[id] = existing.copyWith(
      type: raw['type'] as String? ?? existing.type,
      position: (x != null || y != null)
          ? XYPosition(x: x ?? existing.position.x, y: y ?? existing.position.y)
          : existing.position,
      data: nodeData(raw, existing),
    );
  }
  nextNodes = [for (final n in nextNodes) byId[n.id] ?? n];

  for (final raw in patch.addNodes) {
    final id = (raw['id'] ?? 'n-${nextNodes.length}').toString();
    if (byId.containsKey(id)) continue;
    final node = Node<N>(
      id: id,
      type: raw['type'] as String?,
      position: XYPosition(
        x: (raw['x'] as num?)?.toDouble() ?? (80.0 + nextNodes.length * 280),
        y: (raw['y'] as num?)?.toDouble() ?? 120,
      ),
      data: nodeData(raw, null),
    );
    nextNodes = [...nextNodes, node];
    byId[id] = node;
  }

  final removeEdges = patch.removeEdgeIds.toSet();
  var nextEdges = [
    for (final e in edges)
      if (!removeEdges.contains(e.id) &&
          !removeNodes.contains(e.source) &&
          !removeNodes.contains(e.target))
        e,
  ];
  final edgeById = {for (final e in nextEdges) e.id: e};

  for (final raw in patch.addEdges) {
    final source = (raw['source'] ?? raw['source_id'])?.toString();
    final target = (raw['target'] ?? raw['target_id'])?.toString();
    if (source == null || target == null || source == target) continue;
    if (!byId.containsKey(source) || !byId.containsKey(target)) continue;
    final id = (raw['id'] ?? 'e-$source-$target').toString();
    if (edgeById.containsKey(id)) continue;
    final edge = Edge<E>(
      id: id,
      source: source,
      target: target,
      label: raw['label'] as String?,
      data: edgeData?.call(raw),
    );
    nextEdges = [...nextEdges, edge];
    edgeById[id] = edge;
  }

  for (final raw in patch.rewire) {
    final source = (raw['source'] ?? raw['source_id'])?.toString();
    final target = (raw['target'] ?? raw['target_id'])?.toString();
    if (source == null || target == null || source == target) continue;
    if (!byId.containsKey(source) || !byId.containsKey(target)) continue;
    final id = raw['id']?.toString();
    if (id != null && edgeById.containsKey(id)) {
      final updated = edgeById[id]!.copyWith(
        source: source,
        target: target,
        label: raw['label'] as String? ?? edgeById[id]!.label,
      );
      edgeById[id] = updated;
      nextEdges = [for (final e in nextEdges) e.id == id ? updated : e];
    } else {
      final newId = id ?? 'e-$source-$target';
      if (edgeById.containsKey(newId)) continue;
      final edge = Edge<E>(
        id: newId,
        source: source,
        target: target,
        label: raw['label'] as String?,
        data: edgeData?.call(raw),
      );
      nextEdges = [...nextEdges, edge];
      edgeById[newId] = edge;
    }
  }

  return GraphPatchResult(nodes: nextNodes, edges: nextEdges);
}
