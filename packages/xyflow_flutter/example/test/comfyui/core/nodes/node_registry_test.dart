import 'package:flutter_test/flutter_test.dart';
import '../../../../lib/comfyui/core/nodes/node_registry.dart';
import '../../../../lib/comfyui/core/nodes/node_definition.dart';
import '../../../../lib/comfyui/core/nodes/slot_types.dart';

void main() {
  group('NodeRegistry', () {
    late NodeRegistry registry;

    setUp(() {
      registry = NodeRegistry();
    });

    test('starts empty', () {
      expect(registry.length, 0);
      expect(registry.nodeNames, isEmpty);
      expect(registry.categories, isEmpty);
    });

    test('registers single node', () {
      final def = NodeDefinition(
        name: 'TestNode',
        displayName: 'Test Node',
        category: 'testing',
      );

      registry.register(def);

      expect(registry.length, 1);
      expect(registry.has('TestNode'), true);
      expect(registry.get('TestNode'), def);
    });

    test('registers multiple nodes', () {
      registry.registerAll([
        NodeDefinition(name: 'Node1', displayName: 'Node 1', category: 'cat1'),
        NodeDefinition(name: 'Node2', displayName: 'Node 2', category: 'cat2'),
        NodeDefinition(name: 'Node3', displayName: 'Node 3', category: 'cat1'),
      ]);

      expect(registry.length, 3);
      expect(registry.categories.toSet(), {'cat1', 'cat2'});
    });

    test('getByCategory returns nodes in category', () {
      registry.registerAll([
        NodeDefinition(name: 'Loader1', displayName: 'Loader 1', category: 'loaders'),
        NodeDefinition(name: 'Loader2', displayName: 'Loader 2', category: 'loaders'),
        NodeDefinition(name: 'Sampler', displayName: 'Sampler', category: 'sampling'),
      ]);

      final loaders = registry.getByCategory('loaders');
      expect(loaders.length, 2);
      expect(loaders.map((n) => n.name).toSet(), {'Loader1', 'Loader2'});

      final samplers = registry.getByCategory('sampling');
      expect(samplers.length, 1);
      expect(samplers[0].name, 'Sampler');

      final empty = registry.getByCategory('nonexistent');
      expect(empty, isEmpty);
    });

    test('getByCategoryPrefix returns nodes with category prefix', () {
      registry.registerAll([
        NodeDefinition(name: 'Node1', displayName: 'Node 1', category: 'image'),
        NodeDefinition(name: 'Node2', displayName: 'Node 2', category: 'image/upscaling'),
        NodeDefinition(name: 'Node3', displayName: 'Node 3', category: 'image/transform'),
        NodeDefinition(name: 'Node4', displayName: 'Node 4', category: 'other'),
      ]);

      final imageNodes = registry.getByCategoryPrefix('image');
      expect(imageNodes.length, 3);
    });

    group('search', () {
      setUp(() {
        registry.registerAll([
          NodeDefinition(name: 'KSampler', displayName: 'K Sampler', category: 'sampling'),
          NodeDefinition(name: 'KSamplerAdvanced', displayName: 'K Sampler (Advanced)', category: 'sampling'),
          NodeDefinition(name: 'CheckpointLoaderSimple', displayName: 'Load Checkpoint', category: 'loaders'),
          NodeDefinition(name: 'CLIPTextEncode', displayName: 'CLIP Text Encode', category: 'conditioning'),
          NodeDefinition(name: 'VAEDecode', displayName: 'VAE Decode', category: 'latent'),
          NodeDefinition(name: 'VAEEncode', displayName: 'VAE Encode', category: 'latent'),
          NodeDefinition(name: 'SaveImage', displayName: 'Save Image', category: 'image'),
        ]);
      });

      test('returns all nodes for empty query', () {
        final results = registry.search('');
        expect(results.length, 7);
      });

      test('finds exact match first', () {
        final results = registry.search('KSampler');
        expect(results[0].name, 'KSampler');
      });

      test('finds by prefix', () {
        final results = registry.search('KSamp');
        expect(results.length, 2);
        expect(results.every((n) => n.name.startsWith('KSamp')), true);
      });

      test('finds by contains', () {
        final results = registry.search('Sampler');
        expect(results.any((n) => n.name.contains('Sampler')), true);
      });

      test('finds by display name', () {
        final results = registry.search('Load Checkpoint');
        expect(results[0].name, 'CheckpointLoaderSimple');
      });

      test('case insensitive search', () {
        final results = registry.search('vae');
        // Finds VAEDecode, VAEEncode, and also SaveImage (contains 'ave' which fuzzy matches 'vae')
        expect(results.where((n) => n.name.contains('VAE')).length, 2);
      });

      test('fuzzy match finds chars in order', () {
        final results = registry.search('ks');
        expect(results.any((n) => n.name == 'KSampler'), true);
      });
    });

    group('getCategoryTree', () {
      setUp(() {
        registry.registerAll([
          NodeDefinition(name: 'Node1', displayName: 'Node 1', category: 'loaders'),
          NodeDefinition(name: 'Node2', displayName: 'Node 2', category: 'loaders'),
          NodeDefinition(name: 'Node3', displayName: 'Node 3', category: 'sampling'),
          NodeDefinition(name: 'Node4', displayName: 'Node 4', category: 'sampling/custom'),
          NodeDefinition(name: 'Node5', displayName: 'Node 5', category: 'sampling/custom'),
        ]);
      });

      test('builds tree structure', () {
        final tree = registry.getCategoryTree();

        expect(tree.name, 'root');
        expect(tree.children.length, 2); // loaders, sampling
      });

      test('counts total nodes correctly', () {
        final tree = registry.getCategoryTree();

        expect(tree.totalNodes, 5);
      });

      test('nested categories have correct structure', () {
        final tree = registry.getCategoryTree();

        final sampling = tree.children.firstWhere((c) => c.name == 'sampling');
        expect(sampling.nodes.length, 1); // Only Node3 is directly in sampling
        expect(sampling.children.length, 1); // Has custom subcategory

        final custom = sampling.children[0];
        expect(custom.name, 'custom');
        expect(custom.nodes.length, 2); // Node4 and Node5
      });

      test('allNodes flattens tree', () {
        final tree = registry.getCategoryTree();

        final sampling = tree.children.firstWhere((c) => c.name == 'sampling');
        final allSamplingNodes = sampling.allNodes;

        expect(allSamplingNodes.length, 3); // Node3, Node4, Node5
      });
    });

    group('loadFromApi', () {
      test('loads ComfyUI object_info format', () {
        final objectInfo = {
          'KSampler': {
            'input': {
              'required': {
                'model': 'MODEL',
                'seed': ['INT', {'default': 0}],
              },
            },
            'output': ['LATENT'],
            'name': 'KSampler',
            'display_name': 'K Sampler',
            'category': 'sampling',
          },
          'CheckpointLoaderSimple': {
            'input': {
              'required': {
                'ckpt_name': [['model.safetensors']],
              },
            },
            'output': ['MODEL', 'CLIP', 'VAE'],
            'name': 'CheckpointLoaderSimple',
            'display_name': 'Load Checkpoint',
            'category': 'loaders',
          },
        };

        registry.loadFromApi(objectInfo);

        expect(registry.length, 2);
        expect(registry.has('KSampler'), true);
        expect(registry.has('CheckpointLoaderSimple'), true);

        final sampler = registry.get('KSampler')!;
        expect(sampler.category, 'sampling');
        expect(sampler.inputs.any((s) => s.name == 'model'), true);
        expect(sampler.outputs.length, 1);
      });

      test('handles invalid entries gracefully', () {
        final objectInfo = {
          'ValidNode': {
            'input': {'required': {}},
            'output': ['IMAGE'],
            'name': 'ValidNode',
            'category': 'test',
          },
          'InvalidNode': 'not a map',
          'AnotherValid': {
            'input': {'required': {}},
            'output': [],
            'name': 'AnotherValid',
            'category': 'test',
          },
        };

        registry.loadFromApi(objectInfo);

        expect(registry.length, 2);
        expect(registry.has('ValidNode'), true);
        expect(registry.has('AnotherValid'), true);
        expect(registry.has('InvalidNode'), false);
      });
    });

    test('clear removes all nodes', () {
      registry.registerAll([
        NodeDefinition(name: 'Node1', displayName: 'Node 1', category: 'cat1'),
        NodeDefinition(name: 'Node2', displayName: 'Node 2', category: 'cat2'),
      ]);

      expect(registry.length, 2);

      registry.clear();

      expect(registry.length, 0);
      expect(registry.categories, isEmpty);
    });
  });
}
