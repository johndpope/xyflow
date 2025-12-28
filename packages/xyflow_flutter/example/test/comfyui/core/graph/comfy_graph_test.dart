import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../../../../lib/comfyui/core/graph/comfy_graph.dart';
import '../../../../lib/comfyui/core/nodes/node_definition.dart';
import '../../../../lib/comfyui/core/nodes/node_registry.dart';
import '../../../../lib/comfyui/core/nodes/slot_types.dart';

void main() {
  group('ComfyNode', () {
    test('creates node with default values', () {
      final node = ComfyNode(type: 'TestNode');

      expect(node.type, 'TestNode');
      expect(node.title, 'TestNode');
      expect(node.position, Offset.zero);
      expect(node.mode, 0);
      expect(node.collapsed, false);
      expect(node.pinned, false);
    });

    test('creates node from definition', () {
      final def = NodeDefinition(
        name: 'KSampler',
        displayName: 'K Sampler',
        category: 'sampling',
        widgets: [
          WidgetDefinition(
            name: 'steps',
            type: WidgetType.int_,
            defaultValue: 20,
          ),
          WidgetDefinition(
            name: 'cfg',
            type: WidgetType.float_,
            defaultValue: 7.0,
          ),
        ],
      );

      final node = ComfyNode.fromDefinition(def, position: const Offset(100, 200));

      expect(node.type, 'KSampler');
      expect(node.title, 'K Sampler');
      expect(node.position, const Offset(100, 200));
      expect(node.widgetValues['steps'], 20);
      expect(node.widgetValues['cfg'], 7.0);
    });

    test('mode flags work correctly', () {
      final node = ComfyNode(type: 'TestNode');

      expect(node.isMuted, false);
      expect(node.isBypassed, false);
      expect(node.isAlwaysRun, false);

      node.isMuted = true;
      expect(node.mode, 1);
      expect(node.isMuted, true);

      node.isBypassed = true;
      expect(node.mode, 2);
      expect(node.isBypassed, true);
    });

    test('copyWith creates modified copy', () {
      final original = ComfyNode(
        type: 'TestNode',
        position: const Offset(10, 20),
      );

      final copy = original.copyWith(
        position: const Offset(100, 200),
        title: 'Modified',
      );

      expect(copy.position, const Offset(100, 200));
      expect(copy.title, 'Modified');
      expect(copy.type, 'TestNode');
      expect(original.position, const Offset(10, 20));
    });
  });

  group('ComfyEdge', () {
    test('creates edge with required fields', () {
      final edge = ComfyEdge(
        sourceNodeId: 'node1',
        sourceSlot: 0,
        targetNodeId: 'node2',
        targetSlot: 0,
      );

      expect(edge.sourceNodeId, 'node1');
      expect(edge.targetNodeId, 'node2');
      expect(edge.sourceSlot, 0);
      expect(edge.targetSlot, 0);
      expect(edge.type, SlotType.any);
    });

    test('creates edge with specific type', () {
      final edge = ComfyEdge(
        sourceNodeId: 'node1',
        sourceSlot: 0,
        targetNodeId: 'node2',
        targetSlot: 0,
        type: SlotType.image,
      );

      expect(edge.type, SlotType.image);
    });
  });

  group('ComfyGraph', () {
    late ComfyGraph graph;

    setUp(() {
      graph = ComfyGraph();
    });

    test('starts empty', () {
      expect(graph.nodeCount, 0);
      expect(graph.edgeCount, 0);
      expect(graph.nodes, isEmpty);
      expect(graph.edges, isEmpty);
    });

    test('adds and retrieves nodes', () {
      final node = ComfyNode(type: 'TestNode');
      graph.addNode(node);

      expect(graph.nodeCount, 1);
      expect(graph.getNode(node.id), node);
    });

    test('removes nodes and connected edges', () {
      final node1 = ComfyNode(id: 'node1', type: 'TestNode');
      final node2 = ComfyNode(id: 'node2', type: 'TestNode');
      graph.addNode(node1);
      graph.addNode(node2);

      graph.connect('node1', 0, 'node2', 0);
      expect(graph.edgeCount, 1);

      graph.removeNode('node1');
      expect(graph.nodeCount, 1);
      expect(graph.edgeCount, 0); // Edge should be removed too
    });

    test('connects nodes', () {
      final node1 = ComfyNode(id: 'node1', type: 'TestNode');
      final node2 = ComfyNode(id: 'node2', type: 'TestNode');
      graph.addNode(node1);
      graph.addNode(node2);

      final edge = graph.connect('node1', 0, 'node2', 0);

      expect(edge, isNotNull);
      expect(graph.edgeCount, 1);
      expect(edge!.sourceNodeId, 'node1');
      expect(edge.targetNodeId, 'node2');
    });

    test('replaces existing connection to same input', () {
      final node1 = ComfyNode(id: 'node1', type: 'TestNode');
      final node2 = ComfyNode(id: 'node2', type: 'TestNode');
      final node3 = ComfyNode(id: 'node3', type: 'TestNode');
      graph.addNode(node1);
      graph.addNode(node2);
      graph.addNode(node3);

      // Connect node1 -> node3
      graph.connect('node1', 0, 'node3', 0);
      expect(graph.edgeCount, 1);

      // Connect node2 -> node3 (same input slot)
      graph.connect('node2', 0, 'node3', 0);
      expect(graph.edgeCount, 1); // Should replace, not add

      final edges = graph.getIncomingEdges('node3');
      expect(edges.length, 1);
      expect(edges.first.sourceNodeId, 'node2');
    });

    test('getIncomingEdges returns correct edges', () {
      final node1 = ComfyNode(id: 'node1', type: 'TestNode');
      final node2 = ComfyNode(id: 'node2', type: 'TestNode');
      final node3 = ComfyNode(id: 'node3', type: 'TestNode');
      graph.addNode(node1);
      graph.addNode(node2);
      graph.addNode(node3);

      graph.connect('node1', 0, 'node3', 0);
      graph.connect('node2', 0, 'node3', 1);

      final incoming = graph.getIncomingEdges('node3');
      expect(incoming.length, 2);
    });

    test('getOutgoingEdges returns correct edges', () {
      final node1 = ComfyNode(id: 'node1', type: 'TestNode');
      final node2 = ComfyNode(id: 'node2', type: 'TestNode');
      final node3 = ComfyNode(id: 'node3', type: 'TestNode');
      graph.addNode(node1);
      graph.addNode(node2);
      graph.addNode(node3);

      graph.connect('node1', 0, 'node2', 0);
      graph.connect('node1', 1, 'node3', 0);

      final outgoing = graph.getOutgoingEdges('node1');
      expect(outgoing.length, 2);
    });

    test('duplicateNodes creates copies with new IDs', () {
      final node1 = ComfyNode(id: 'node1', type: 'TestNode', position: const Offset(0, 0));
      final node2 = ComfyNode(id: 'node2', type: 'TestNode', position: const Offset(100, 0));
      graph.addNode(node1);
      graph.addNode(node2);
      graph.connect('node1', 0, 'node2', 0);

      final newNodes = graph.duplicateNodes({'node1', 'node2'}, const Offset(50, 50));

      expect(newNodes.length, 2);
      expect(graph.nodeCount, 4);
      expect(graph.edgeCount, 2); // Original + duplicated edge

      // Check positions are offset
      for (final node in newNodes) {
        expect(node.position.dx, greaterThanOrEqualTo(50));
        expect(node.position.dy, greaterThanOrEqualTo(50));
      }
    });

    test('clear removes all nodes, edges, and groups', () {
      final node = ComfyNode(type: 'TestNode');
      graph.addNode(node);
      graph.addGroup(ComfyGroup(title: 'Test', bounds: Rect.zero));

      graph.clear();

      expect(graph.nodeCount, 0);
      expect(graph.edgeCount, 0);
      expect(graph.groups, isEmpty);
    });
  });

  group('ComfyGraph with registry', () {
    late NodeRegistry registry;
    late ComfyGraph graph;

    setUp(() {
      registry = NodeRegistry();

      // Register test node definitions
      registry.register(NodeDefinition(
        name: 'CheckpointLoader',
        displayName: 'Load Checkpoint',
        category: 'loaders',
        outputs: [
          SlotDefinition(name: 'MODEL', type: SlotType.model),
          SlotDefinition(name: 'CLIP', type: SlotType.clip),
          SlotDefinition(name: 'VAE', type: SlotType.vae),
        ],
      ));

      registry.register(NodeDefinition(
        name: 'KSampler',
        displayName: 'K Sampler',
        category: 'sampling',
        inputs: [
          SlotDefinition(name: 'model', type: SlotType.model),
          SlotDefinition(name: 'positive', type: SlotType.conditioning),
          SlotDefinition(name: 'negative', type: SlotType.conditioning),
          SlotDefinition(name: 'latent', type: SlotType.latent),
        ],
        outputs: [
          SlotDefinition(name: 'LATENT', type: SlotType.latent),
        ],
      ));

      registry.register(NodeDefinition(
        name: 'SaveImage',
        displayName: 'Save Image',
        category: 'image',
        inputs: [
          SlotDefinition(name: 'images', type: SlotType.image),
        ],
        isOutputNode: true,
      ));

      graph = ComfyGraph(registry: registry);
    });

    test('addNodeByType creates node from registry', () {
      final node = graph.addNodeByType('KSampler', const Offset(100, 100));

      expect(node, isNotNull);
      expect(node!.type, 'KSampler');
      expect(node.title, 'K Sampler');
    });

    test('addNodeByType returns null for unknown type', () {
      final node = graph.addNodeByType('UnknownNode', Offset.zero);
      expect(node, isNull);
    });

    test('canConnect validates slot types', () {
      graph.addNodeByType('CheckpointLoader', Offset.zero);
      graph.addNodeByType('KSampler', const Offset(200, 0));

      final loader = graph.nodes.firstWhere((n) => n.type == 'CheckpointLoader');
      final sampler = graph.nodes.firstWhere((n) => n.type == 'KSampler');

      // MODEL output to model input - should work
      expect(graph.canConnect(loader.id, 0, sampler.id, 0), true);

      // CLIP output to model input - should fail
      expect(graph.canConnect(loader.id, 1, sampler.id, 0), false);
    });

    test('connect validates and sets edge type', () {
      graph.addNodeByType('CheckpointLoader', Offset.zero);
      graph.addNodeByType('KSampler', const Offset(200, 0));

      final loader = graph.nodes.firstWhere((n) => n.type == 'CheckpointLoader');
      final sampler = graph.nodes.firstWhere((n) => n.type == 'KSampler');

      final edge = graph.connect(loader.id, 0, sampler.id, 0);

      expect(edge, isNotNull);
      expect(edge!.type, SlotType.model);
    });

    test('connect returns null for incompatible types', () {
      graph.addNodeByType('CheckpointLoader', Offset.zero);
      graph.addNodeByType('KSampler', const Offset(200, 0));

      final loader = graph.nodes.firstWhere((n) => n.type == 'CheckpointLoader');
      final sampler = graph.nodes.firstWhere((n) => n.type == 'KSampler');

      // Try to connect CLIP to model input
      final edge = graph.connect(loader.id, 1, sampler.id, 0);

      expect(edge, isNull);
    });

    test('getOutputNodes finds output nodes', () {
      graph.addNodeByType('KSampler', Offset.zero);
      graph.addNodeByType('SaveImage', const Offset(200, 0));

      final outputs = graph.getOutputNodes();

      expect(outputs.length, 1);
      expect(outputs.first.type, 'SaveImage');
    });
  });

  group('ComfyGroup', () {
    test('creates group with required fields', () {
      final group = ComfyGroup(
        title: 'Test Group',
        bounds: const Rect.fromLTWH(0, 0, 200, 200),
      );

      expect(group.title, 'Test Group');
      expect(group.bounds, const Rect.fromLTWH(0, 0, 200, 200));
      expect(group.locked, false);
    });

    test('graph tracks groups', () {
      final graph = ComfyGraph();
      final group = ComfyGroup(
        title: 'Test',
        bounds: const Rect.fromLTWH(10, 10, 100, 100),
      );

      graph.addGroup(group);
      expect(graph.groups.length, 1);

      graph.removeGroup(group.id);
      expect(graph.groups, isEmpty);
    });
  });
}
