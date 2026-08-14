import 'package:flutter_test/flutter_test.dart';
import 'package:xyflow_flutter/xyflow_flutter.dart';

void main() {
  test('observeGraph reports focus, selection, and wiring', () {
    final nodes = [
      Node<String>(id: 'a', position: const XYPosition(x: 0, y: 0), data: 'Open'),
      Node<String>(
        id: 'b',
        position: const XYPosition(x: 280, y: 0),
        data: 'Twist',
        selected: true,
      ),
    ];
    final edges = [
      Edge<void>(id: 'e-a-b', source: 'a', target: 'b', label: 'if cover blown'),
    ];
    final snap = observeGraph(
      nodes: nodes,
      edges: edges,
      nodeData: (n) => {'title': n.data},
    );
    expect(snap['node_count'], 2);
    expect(snap['edge_count'], 1);
    expect(snap['focus_node_id'], 'b');
    expect(snap['selected_ids'], ['b']);
    expect((snap['nodes'] as List).first['data']['title'], 'Open');
    expect((snap['edges'] as List).first['label'], 'if cover blown');
  });

  test('applyGraphPatch adds a branch and rewires an edge', () {
    final nodes = [
      Node<String>(id: 'a', position: const XYPosition(x: 0, y: 0), data: 'Open'),
      Node<String>(id: 'b', position: const XYPosition(x: 280, y: 0), data: 'Finale'),
    ];
    final edges = [
      Edge<void>(id: 'e-a-b', source: 'a', target: 'b'),
    ];
    final result = applyGraphPatch<String, void>(
      nodes: nodes,
      edges: edges,
      patch: GraphPatch.fromJson({
        'add_nodes': [
          {'id': 'c', 'x': 140, 'y': 180, 'title': 'Double agent'},
        ],
        'rewire': [
          {'id': 'e-a-b', 'source': 'a', 'target': 'c', 'label': 'twist'},
        ],
        'add_edges': [
          {'source': 'c', 'target': 'b', 'label': 'rejoin'},
        ],
      }),
      nodeData: (json, existing) =>
          (json['title'] as String?) ?? existing?.data ?? 'Hub',
    );
    expect(result.nodes.map((n) => n.id), ['a', 'b', 'c']);
    expect(result.edges.singleWhere((e) => e.id == 'e-a-b').target, 'c');
    expect(result.edges.any((e) => e.source == 'c' && e.target == 'b'), isTrue);
  });
}
