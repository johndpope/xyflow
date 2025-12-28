/// ComfyFlow Example - Demonstrates ComfyUI-style node graph editing.
library;

import 'package:flutter/material.dart';
import 'package:xyflow_flutter/xyflow_flutter.dart';

import 'core/graph/comfy_graph.dart';
import 'core/nodes/node_definition.dart';
import 'core/nodes/node_registry.dart';
import 'core/nodes/slot_types.dart';
import 'widgets/comfy_node_widget.dart';
import 'widgets/comfy_edge_widget.dart';

/// Example widget demonstrating ComfyUI-style node graph editing.
class ComfyFlowExample extends StatefulWidget {
  const ComfyFlowExample({super.key});

  @override
  State<ComfyFlowExample> createState() => _ComfyFlowExampleState();
}

class _ComfyFlowExampleState extends State<ComfyFlowExample> {
  late NodeRegistry _registry;
  late ComfyGraph _graph;
  List<Node<ComfyNodeData>> _nodes = [];
  List<Edge<ComfyEdgeData>> _edges = [];

  @override
  void initState() {
    super.initState();
    _initializeRegistry();
    _initializeGraph();
  }

  void _initializeRegistry() {
    _registry = NodeRegistry();

    // Register sample node definitions
    _registry.register(NodeDefinition(
      name: 'CheckpointLoaderSimple',
      displayName: 'Load Checkpoint',
      category: 'loaders',
      description: 'Loads a checkpoint model file',
      color: const Color(0xFF4E6F4E),
      outputs: [
        SlotDefinition(name: 'MODEL', type: SlotType.model),
        SlotDefinition(name: 'CLIP', type: SlotType.clip),
        SlotDefinition(name: 'VAE', type: SlotType.vae),
      ],
      widgets: [
        WidgetDefinition(
          name: 'ckpt_name',
          type: WidgetType.combo,
          options: ['v1-5-pruned.safetensors', 'sd_xl_base_1.0.safetensors'],
        ),
      ],
    ));

    _registry.register(NodeDefinition(
      name: 'CLIPTextEncode',
      displayName: 'CLIP Text Encode',
      category: 'conditioning',
      description: 'Encodes text using CLIP',
      color: const Color(0xFF8B5A8B),
      inputs: [
        SlotDefinition(name: 'clip', type: SlotType.clip),
      ],
      outputs: [
        SlotDefinition(name: 'CONDITIONING', type: SlotType.conditioning),
      ],
      widgets: [
        WidgetDefinition(
          name: 'text',
          type: WidgetType.string,
          multiline: true,
          defaultValue: 'beautiful landscape, mountains, sunset',
        ),
      ],
    ));

    _registry.register(NodeDefinition(
      name: 'KSampler',
      displayName: 'KSampler',
      category: 'sampling',
      description: 'Samples latent images using various sampling methods',
      color: const Color(0xFF7D5A3C),
      inputs: [
        SlotDefinition(name: 'model', type: SlotType.model),
        SlotDefinition(name: 'positive', type: SlotType.conditioning),
        SlotDefinition(name: 'negative', type: SlotType.conditioning),
        SlotDefinition(name: 'latent_image', type: SlotType.latent),
      ],
      outputs: [
        SlotDefinition(name: 'LATENT', type: SlotType.latent),
      ],
      widgets: [
        WidgetDefinition(
          name: 'seed',
          type: WidgetType.seed,
          defaultValue: 42,
        ),
        WidgetDefinition(
          name: 'steps',
          type: WidgetType.int_,
          defaultValue: 20,
          min: 1,
          max: 100,
        ),
        WidgetDefinition(
          name: 'cfg',
          type: WidgetType.float_,
          defaultValue: 7.0,
          min: 1.0,
          max: 30.0,
          step: 0.5,
        ),
        WidgetDefinition(
          name: 'sampler_name',
          type: WidgetType.combo,
          options: ['euler', 'euler_ancestral', 'dpmpp_2m', 'dpmpp_sde'],
        ),
        WidgetDefinition(
          name: 'scheduler',
          type: WidgetType.combo,
          options: ['normal', 'karras', 'exponential', 'sgm_uniform'],
        ),
        WidgetDefinition(
          name: 'denoise',
          type: WidgetType.float_,
          defaultValue: 1.0,
          min: 0.0,
          max: 1.0,
          step: 0.01,
        ),
      ],
    ));

    _registry.register(NodeDefinition(
      name: 'EmptyLatentImage',
      displayName: 'Empty Latent Image',
      category: 'latent',
      description: 'Creates an empty latent image',
      color: const Color(0xFF5A5A8B),
      outputs: [
        SlotDefinition(name: 'LATENT', type: SlotType.latent),
      ],
      widgets: [
        WidgetDefinition(
          name: 'width',
          type: WidgetType.int_,
          defaultValue: 512,
          min: 64,
          max: 2048,
          step: 64,
        ),
        WidgetDefinition(
          name: 'height',
          type: WidgetType.int_,
          defaultValue: 512,
          min: 64,
          max: 2048,
          step: 64,
        ),
        WidgetDefinition(
          name: 'batch_size',
          type: WidgetType.int_,
          defaultValue: 1,
          min: 1,
          max: 64,
        ),
      ],
    ));

    _registry.register(NodeDefinition(
      name: 'VAEDecode',
      displayName: 'VAE Decode',
      category: 'latent',
      description: 'Decodes latent images to pixel space',
      color: const Color(0xFF5A5A8B),
      inputs: [
        SlotDefinition(name: 'samples', type: SlotType.latent),
        SlotDefinition(name: 'vae', type: SlotType.vae),
      ],
      outputs: [
        SlotDefinition(name: 'IMAGE', type: SlotType.image),
      ],
    ));

    _registry.register(NodeDefinition(
      name: 'SaveImage',
      displayName: 'Save Image',
      category: 'image',
      description: 'Saves images to disk',
      color: const Color(0xFF5A8B8B),
      isOutputNode: true,
      inputs: [
        SlotDefinition(name: 'images', type: SlotType.image),
      ],
      widgets: [
        WidgetDefinition(
          name: 'filename_prefix',
          type: WidgetType.string,
          defaultValue: 'ComfyUI',
        ),
      ],
    ));
  }

  void _initializeGraph() {
    _graph = ComfyGraph(registry: _registry);

    // Create sample workflow
    final loader = _graph.addNodeByType(
      'CheckpointLoaderSimple',
      const Offset(50, 100),
    );
    final positivePrompt = _graph.addNodeByType(
      'CLIPTextEncode',
      const Offset(350, 50),
    );
    final negativePrompt = _graph.addNodeByType(
      'CLIPTextEncode',
      const Offset(350, 200),
    );
    final emptyLatent = _graph.addNodeByType(
      'EmptyLatentImage',
      const Offset(350, 350),
    );
    final sampler = _graph.addNodeByType(
      'KSampler',
      const Offset(650, 150),
    );
    final vaeDecode = _graph.addNodeByType(
      'VAEDecode',
      const Offset(950, 150),
    );
    final saveImage = _graph.addNodeByType(
      'SaveImage',
      const Offset(1200, 150),
    );

    // Set custom titles
    positivePrompt?.title = 'Positive Prompt';
    negativePrompt?.title = 'Negative Prompt';

    // Set prompt values
    positivePrompt?.widgetValues['text'] = 'beautiful landscape, mountains, sunset, 4k, high quality';
    negativePrompt?.widgetValues['text'] = 'ugly, blurry, low quality';

    // Create connections
    if (loader != null && positivePrompt != null) {
      _graph.connect(loader.id, 1, positivePrompt.id, 0); // CLIP -> clip
    }
    if (loader != null && negativePrompt != null) {
      _graph.connect(loader.id, 1, negativePrompt.id, 0); // CLIP -> clip
    }
    if (loader != null && sampler != null) {
      _graph.connect(loader.id, 0, sampler.id, 0); // MODEL -> model
    }
    if (positivePrompt != null && sampler != null) {
      _graph.connect(positivePrompt.id, 0, sampler.id, 1); // CONDITIONING -> positive
    }
    if (negativePrompt != null && sampler != null) {
      _graph.connect(negativePrompt.id, 0, sampler.id, 2); // CONDITIONING -> negative
    }
    if (emptyLatent != null && sampler != null) {
      _graph.connect(emptyLatent.id, 0, sampler.id, 3); // LATENT -> latent_image
    }
    if (sampler != null && vaeDecode != null) {
      _graph.connect(sampler.id, 0, vaeDecode.id, 0); // LATENT -> samples
    }
    if (loader != null && vaeDecode != null) {
      _graph.connect(loader.id, 2, vaeDecode.id, 1); // VAE -> vae
    }
    if (vaeDecode != null && saveImage != null) {
      _graph.connect(vaeDecode.id, 0, saveImage.id, 0); // IMAGE -> images
    }

    // Convert to xyflow format
    _updateXYFlowState();
  }

  void _updateXYFlowState() {
    // Convert ComfyNodes to xyflow Nodes
    _nodes = _graph.nodes.map((comfyNode) {
      return Node<ComfyNodeData>(
        id: comfyNode.id,
        position: XYPosition(
          x: comfyNode.position.dx,
          y: comfyNode.position.dy,
        ),
        data: ComfyNodeData(
          node: comfyNode,
          definition: _registry.get(comfyNode.type),
          onWidgetValueChanged: (name, value) {
            setState(() {
              comfyNode.widgetValues[name] = value;
              _updateXYFlowState();
            });
          },
        ),
        type: 'comfy',
      );
    }).toList();

    // Convert ComfyEdges to xyflow Edges
    _edges = _graph.edges.map((comfyEdge) {
      return Edge<ComfyEdgeData>(
        id: comfyEdge.id,
        source: comfyEdge.sourceNodeId,
        target: comfyEdge.targetNodeId,
        sourceHandle: comfyEdge.sourceSlot.toString(),
        targetHandle: comfyEdge.targetSlot.toString(),
        data: ComfyEdgeData(edge: comfyEdge),
        type: 'comfy',
        style: {
          'stroke': comfyEdge.type.color.value,
        },
      );
    }).toList();
  }

  void _onNodesChange(List<NodeChange> changes) {
    setState(() {
      for (final change in changes) {
        if (change is NodePositionChange && change.position != null) {
          _graph.updateNodePosition(
            change.id,
            Offset(change.position!.x, change.position!.y),
          );
        }
      }
      _updateXYFlowState();
    });
  }

  void _onConnect(Connection connection) {
    setState(() {
      final sourceSlot = int.tryParse(connection.sourceHandle ?? '0') ?? 0;
      final targetSlot = int.tryParse(connection.targetHandle ?? '0') ?? 0;
      _graph.connect(
        connection.source,
        sourceSlot,
        connection.target,
        targetSlot,
      );
      _updateXYFlowState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('ComfyFlow Example'),
        backgroundColor: const Color(0xFF2D2D2D),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _graph.clear();
                _initializeGraph();
              });
            },
            tooltip: 'Reset Graph',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Graph Info'),
                  content: Text(
                    'Nodes: ${_graph.nodeCount}\n'
                    'Edges: ${_graph.edgeCount}\n\n'
                    'Drag nodes to reposition.\n'
                    'Connect handles to create edges.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Graph Info',
          ),
        ],
      ),
      body: XYFlow<ComfyNodeData, ComfyEdgeData>(
        nodes: _nodes,
        edges: _edges,
        onNodesChange: _onNodesChange,
        onConnect: _onConnect,
        nodeTypes: {
          'comfy': (props) => ComfyNodeWidget(props: props),
        },
        edgeTypes: {
          'comfy': (props) => ComfyEdgeWidget(props: props),
        },
        fitViewOnInit: true,
        minZoom: 0.1,
        maxZoom: 4.0,
        snapToGrid: true,
        snapGrid: (20, 20),
        children: const [
          Background(
            variant: BackgroundVariant.dots,
            color: Color(0xFF2A2A2A),
            gap: 20,
            size: 1,
          ),
        ],
      ),
    );
  }
}
