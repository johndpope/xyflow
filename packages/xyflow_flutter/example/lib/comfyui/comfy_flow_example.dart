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
import 'widgets/node_search_panel.dart';
import 'widgets/properties_panel.dart';

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

  // UI state
  String? _selectedNodeId;
  bool _showSearchPanel = false;
  Offset? _searchPanelPosition;
  List<String> _recentNodes = [];
  bool _showPropertiesPanel = true;

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

  ComfyNode? get _selectedNode =>
      _selectedNodeId != null ? _graph.getNode(_selectedNodeId!) : null;

  NodeDefinition? get _selectedNodeDefinition =>
      _selectedNode != null ? _registry.get(_selectedNode!.type) : null;

  void _onNodeClick(Node<ComfyNodeData> node) {
    setState(() {
      _selectedNodeId = node.id;
    });
  }

  void _addNodeFromSearch(NodeDefinition def, Offset? position) {
    setState(() {
      final node = _graph.addNodeByType(
        def.name,
        position ?? const Offset(200, 200),
      );
      if (node != null) {
        // Track recent nodes
        _recentNodes.remove(def.name);
        _recentNodes.insert(0, def.name);
        if (_recentNodes.length > 10) {
          _recentNodes = _recentNodes.take(10).toList();
        }
        _selectedNodeId = node.id;
      }
      _showSearchPanel = false;
      _updateXYFlowState();
    });
  }

  void _onWidgetValueChanged(String nodeId, String widgetName, dynamic value) {
    setState(() {
      _graph.updateWidgetValue(nodeId, widgetName, value);
      _updateXYFlowState();
    });
  }

  void _onNodePropertyChanged(String nodeId, String property, dynamic value) {
    setState(() {
      final node = _graph.getNode(nodeId);
      if (node != null) {
        switch (property) {
          case 'title':
            node.title = value as String;
          case 'mode':
            node.mode = value as int;
          case 'collapsed':
            node.collapsed = value as bool;
        }
      }
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
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                _showSearchPanel = true;
                _searchPanelPosition = null;
              });
            },
            tooltip: 'Add Node',
          ),
          IconButton(
            icon: Icon(_showPropertiesPanel ? Icons.view_sidebar : Icons.view_sidebar_outlined),
            onPressed: () {
              setState(() {
                _showPropertiesPanel = !_showPropertiesPanel;
              });
            },
            tooltip: 'Toggle Properties Panel',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _graph.clear();
                _selectedNodeId = null;
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
                    'Double-tap canvas to add nodes.\n'
                    'Drag from handles to connect.\n'
                    'Click nodes to select and edit.',
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
      body: Row(
        children: [
          // Main canvas
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onDoubleTapDown: (details) {
                    setState(() {
                      _showSearchPanel = true;
                      _searchPanelPosition = details.localPosition;
                    });
                  },
                  child: XYFlow<ComfyNodeData, ComfyEdgeData>(
                    nodes: _nodes,
                    edges: _edges,
                    onNodesChange: _onNodesChange,
                    onConnect: _onConnect,
                    onNodeClick: _onNodeClick,
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
                ),
                // Floating search panel
                if (_showSearchPanel)
                  FloatingNodeSearchPanel(
                    registry: _registry,
                    onNodeSelected: _addNodeFromSearch,
                    position: _searchPanelPosition ?? const Offset(100, 100),
                    recentNodes: _recentNodes,
                    onClose: () {
                      setState(() {
                        _showSearchPanel = false;
                      });
                    },
                  ),
              ],
            ),
          ),
          // Properties panel
          if (_showPropertiesPanel)
            PropertiesPanel(
              registry: _registry,
              selectedNode: _selectedNode,
              nodeDefinition: _selectedNodeDefinition,
              incomingEdges: _selectedNodeId != null
                  ? _graph.getIncomingEdges(_selectedNodeId!)
                  : [],
              outgoingEdges: _selectedNodeId != null
                  ? _graph.getOutgoingEdges(_selectedNodeId!)
                  : [],
              onWidgetValueChanged: _onWidgetValueChanged,
              onNodePropertyChanged: _onNodePropertyChanged,
            ),
        ],
      ),
    );
  }
}
