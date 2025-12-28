# ComfyUI Flutter Port - Implementation Plan

## Overview

This document outlines the comprehensive plan to port ComfyUI's frontend to Flutter using the xyflow_flutter library. The goal is to achieve 100% feature parity with the original Vue/TypeScript implementation.

---

## 1. Architecture Comparison

### Original ComfyUI (Vue 3 + LiteGraph)
```
┌─────────────────────────────────────────────────────────────┐
│                    Vue 3 Application                        │
├─────────────────────────────────────────────────────────────┤
│  Components         │  Stores (Pinia)    │  Services        │
│  ├─ GraphCanvas     │  ├─ workspace      │  ├─ API          │
│  ├─ LGraphNode      │  ├─ canvas         │  ├─ WebSocket    │
│  ├─ Widgets         │  ├─ nodeDef        │  └─ Extensions   │
│  └─ Menus           │  └─ execution      │                  │
├─────────────────────────────────────────────────────────────┤
│                    LiteGraph Engine                         │
│  ├─ Graph traversal & execution                             │
│  ├─ Node/Link management                                    │
│  └─ Serialization                                           │
└─────────────────────────────────────────────────────────────┘
```

### Flutter Port (xyflow_flutter)
```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Application                      │
├─────────────────────────────────────────────────────────────┤
│  Widgets            │  State (Riverpod)  │  Services        │
│  ├─ ComfyCanvas     │  ├─ workspace      │  ├─ ComfyAPI     │
│  ├─ ComfyNode       │  ├─ graph          │  ├─ WebSocket    │
│  ├─ NodeWidgets     │  ├─ nodeDefs       │  └─ Extensions   │
│  └─ Menus           │  └─ execution      │                  │
├─────────────────────────────────────────────────────────────┤
│                    xyflow_flutter + ComfyEngine             │
│  ├─ XYFlow (canvas, pan/zoom, selection)                    │
│  ├─ ComfyGraph (execution, validation)                      │
│  └─ Serialization (ComfyUI JSON format)                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Project Structure

```
lib/comfyui/
├── main.dart                     # App entry point
├── app.dart                      # ComfyUI app widget
│
├── core/                         # Core engine
│   ├── graph/
│   │   ├── comfy_graph.dart      # Graph container
│   │   ├── graph_executor.dart   # Execution engine
│   │   ├── graph_validator.dart  # Validation logic
│   │   └── topological_sort.dart # Execution order
│   │
│   ├── nodes/
│   │   ├── node_definition.dart  # Node type definitions
│   │   ├── node_registry.dart    # Available node types
│   │   ├── slot.dart             # Input/output slots
│   │   └── slot_types.dart       # Data type definitions
│   │
│   ├── widgets/                  # Node input widgets
│   │   ├── widget_registry.dart
│   │   ├── int_widget.dart
│   │   ├── float_widget.dart
│   │   ├── string_widget.dart
│   │   ├── combo_widget.dart
│   │   ├── image_widget.dart
│   │   └── custom_widget.dart
│   │
│   └── serialization/
│       ├── workflow_json.dart    # ComfyUI JSON format
│       ├── api_format.dart       # API prompt format
│       └── import_export.dart    # File I/O
│
├── state/                        # State management (Riverpod)
│   ├── providers.dart            # All providers
│   ├── workspace_state.dart      # Workspace/tabs
│   ├── graph_state.dart          # Current graph
│   ├── node_defs_state.dart      # Node definitions
│   ├── execution_state.dart      # Execution status
│   ├── settings_state.dart       # User preferences
│   └── history_state.dart        # Undo/redo
│
├── ui/                           # UI components
│   ├── canvas/
│   │   ├── comfy_canvas.dart     # Main canvas widget
│   │   ├── canvas_background.dart
│   │   └── canvas_overlay.dart
│   │
│   ├── nodes/
│   │   ├── comfy_node.dart       # Node widget
│   │   ├── node_header.dart      # Title bar
│   │   ├── node_slots.dart       # Input/output slots
│   │   ├── node_body.dart        # Widget area
│   │   ├── node_preview.dart     # Image/video preview
│   │   └── node_status.dart      # Execution status
│   │
│   ├── edges/
│   │   ├── comfy_edge.dart       # Edge widget
│   │   └── edge_styles.dart      # Type-based styling
│   │
│   ├── menus/
│   │   ├── canvas_menu.dart      # Right-click canvas
│   │   ├── node_menu.dart        # Right-click node
│   │   ├── slot_menu.dart        # Right-click slot
│   │   └── menu_items.dart       # Menu item definitions
│   │
│   ├── panels/
│   │   ├── top_menu.dart         # Top menu bar
│   │   ├── side_toolbar.dart     # Left sidebar
│   │   ├── node_browser.dart     # Node search/add
│   │   ├── properties_panel.dart # Node properties
│   │   ├── queue_panel.dart      # Execution queue
│   │   └── settings_panel.dart   # Settings UI
│   │
│   ├── dialogs/
│   │   ├── save_dialog.dart
│   │   ├── load_dialog.dart
│   │   ├── settings_dialog.dart
│   │   └── about_dialog.dart
│   │
│   └── common/
│       ├── comfy_theme.dart      # Theme definitions
│       ├── comfy_colors.dart     # Color palette
│       ├── comfy_icons.dart      # Icon set
│       └── tooltip.dart          # Custom tooltips
│
├── services/
│   ├── comfy_api.dart            # REST API client
│   ├── websocket_service.dart    # WebSocket connection
│   ├── extension_service.dart    # Extension loading
│   └── storage_service.dart      # Local storage
│
└── utils/
    ├── keyboard_shortcuts.dart   # Hotkey handling
    ├── drag_drop.dart            # File drag-drop
    └── platform_utils.dart       # Platform detection
```

---

## 3. Implementation Phases

### Phase 1: Core Infrastructure (Week 1-2)

#### 1.1 Data Types & Slot System
```dart
// lib/comfyui/core/nodes/slot_types.dart

enum SlotType {
  any,           // Accepts any type
  model,         // ML model
  clip,          // CLIP model
  vae,           // VAE model
  conditioning,  // Conditioning data
  latent,        // Latent image
  image,         // RGB image
  mask,          // Binary mask
  int_,          // Integer
  float_,        // Float
  string,        // String
  boolean,       // Boolean
  combo,         // Dropdown selection
}

class SlotDefinition {
  final String name;
  final SlotType type;
  final bool isOptional;
  final dynamic defaultValue;
  final List<String>? comboOptions;  // For combo type
  final Map<String, dynamic>? config;
}
```

#### 1.2 Node Definition System
```dart
// lib/comfyui/core/nodes/node_definition.dart

class NodeDefinition {
  final String name;           // "KSampler"
  final String displayName;    // "K Sampler"
  final String category;       // "sampling"
  final String description;

  final List<SlotDefinition> inputs;
  final List<SlotDefinition> outputs;
  final List<WidgetDefinition> widgets;

  final Color color;
  final Color bgColor;

  // Execution behavior
  final bool isOutputNode;
  final String? outputNodeType;
}
```

#### 1.3 Node Registry
```dart
// lib/comfyui/core/nodes/node_registry.dart

class NodeRegistry {
  final Map<String, NodeDefinition> _definitions = {};

  void register(NodeDefinition def);
  NodeDefinition? get(String name);
  List<NodeDefinition> getByCategory(String category);
  List<String> get categories;

  // Load from ComfyUI backend
  Future<void> loadFromApi(ComfyApi api);
}
```

#### 1.4 Graph Executor
```dart
// lib/comfyui/core/graph/graph_executor.dart

class GraphExecutor {
  final ComfyApi api;

  // Validate graph before execution
  ValidationResult validate(ComfyGraph graph);

  // Convert to API prompt format
  Map<String, dynamic> toPrompt(ComfyGraph graph);

  // Queue execution
  Future<String> queue(ComfyGraph graph, {int? number});

  // Cancel execution
  Future<void> cancel(String promptId);

  // Get execution status
  Stream<ExecutionStatus> statusStream(String promptId);
}
```

### Phase 2: State Management (Week 2-3)

#### 2.1 Riverpod Providers
```dart
// lib/comfyui/state/providers.dart

// Node definitions from backend
final nodeDefsProvider = FutureProvider<NodeRegistry>((ref) async {
  final api = ref.read(comfyApiProvider);
  final registry = NodeRegistry();
  await registry.loadFromApi(api);
  return registry;
});

// Current graph state
final graphProvider = StateNotifierProvider<GraphNotifier, ComfyGraph>((ref) {
  return GraphNotifier();
});

// Execution state
final executionProvider = StateNotifierProvider<ExecutionNotifier, ExecutionState>((ref) {
  return ExecutionNotifier(ref.read(comfyApiProvider));
});

// Selected nodes
final selectedNodesProvider = StateProvider<Set<String>>((ref) => {});

// Undo/redo history
final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier(maxSize: 50);
});
```

#### 2.2 Graph Notifier
```dart
class GraphNotifier extends StateNotifier<ComfyGraph> {
  GraphNotifier() : super(ComfyGraph.empty());

  // Node operations
  void addNode(NodeDefinition def, Offset position);
  void removeNode(String id);
  void updateNodePosition(String id, Offset position);
  void updateNodeWidget(String nodeId, String widgetName, dynamic value);

  // Edge operations
  void addEdge(String sourceNode, int sourceSlot, String targetNode, int targetSlot);
  void removeEdge(String id);

  // Serialization
  void loadFromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();

  // Clipboard
  void copySelected(Set<String> nodeIds);
  void paste(Offset position);
}
```

### Phase 3: UI Components (Week 3-5)

#### 3.1 ComfyNode Widget
```dart
// lib/comfyui/ui/nodes/comfy_node.dart

class ComfyNode extends StatelessWidget {
  final NodeProps<ComfyNodeData> props;
  final NodeDefinition definition;
  final ExecutionStatus? status;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _buildDecoration(),
      child: Column(
        children: [
          _NodeHeader(
            title: props.data.title,
            color: definition.color,
            status: status,
          ),
          _NodeInputSlots(
            slots: definition.inputs,
            values: props.data.inputValues,
          ),
          _NodeWidgets(
            widgets: definition.widgets,
            values: props.data.widgetValues,
            onChanged: (name, value) => /* update */,
          ),
          if (props.data.preview != null)
            _NodePreview(data: props.data.preview),
          _NodeOutputSlots(
            slots: definition.outputs,
          ),
        ],
      ),
    );
  }
}
```

#### 3.2 Slot Widgets with Type Colors
```dart
// lib/comfyui/ui/nodes/node_slots.dart

class SlotWidget extends StatelessWidget {
  final SlotDefinition slot;
  final bool isInput;
  final bool isConnected;

  static const Map<SlotType, Color> slotColors = {
    SlotType.model: Color(0xFFB39DDB),      // Purple
    SlotType.clip: Color(0xFFFFD54F),        // Yellow
    SlotType.vae: Color(0xFFFF8A80),         // Red
    SlotType.conditioning: Color(0xFFFFAB40), // Orange
    SlotType.latent: Color(0xFFFF80AB),      // Pink
    SlotType.image: Color(0xFF64B5F6),       // Blue
    SlotType.mask: Color(0xFFFFFFFF),        // White
    SlotType.int_: Color(0xFF81C784),        // Green
    SlotType.float_: Color(0xFF81C784),      // Green
    SlotType.string: Color(0xFF4FC3F7),      // Cyan
  };
}
```

#### 3.3 Node Browser (Search/Add)
```dart
// lib/comfyui/ui/panels/node_browser.dart

class NodeBrowser extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(nodeDefsProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Column(
      children: [
        _SearchField(
          onChanged: (q) => ref.read(searchQueryProvider.notifier).state = q,
        ),
        Expanded(
          child: _CategoryTree(
            categories: registry.categories,
            nodes: registry.search(searchQuery),
            onNodeSelected: (def) => _addNode(context, ref, def),
          ),
        ),
        _RecentNodes(),
        _FavoriteNodes(),
      ],
    );
  }
}
```

#### 3.4 Context Menus
```dart
// lib/comfyui/ui/menus/canvas_menu.dart

class CanvasContextMenu extends StatelessWidget {
  final Offset position;
  final VoidCallback onDismiss;

  List<MenuItem> get items => [
    MenuItem(
      icon: Icons.add,
      label: 'Add Node',
      onTap: () => _showNodeBrowser(),
    ),
    MenuItem.divider(),
    MenuItem(
      icon: Icons.paste,
      label: 'Paste',
      shortcut: 'Ctrl+V',
      enabled: hasClipboard,
      onTap: () => _paste(),
    ),
    MenuItem.divider(),
    MenuItem(
      icon: Icons.undo,
      label: 'Undo',
      shortcut: 'Ctrl+Z',
      onTap: () => _undo(),
    ),
    MenuItem(
      icon: Icons.redo,
      label: 'Redo',
      shortcut: 'Ctrl+Y',
      onTap: () => _redo(),
    ),
  ];
}
```

### Phase 4: Execution & Preview (Week 5-6)

#### 4.1 WebSocket Integration
```dart
// lib/comfyui/services/websocket_service.dart

class ComfyWebSocket {
  final String url;
  WebSocketChannel? _channel;

  Stream<ComfyMessage> get messages => _controller.stream;

  Future<void> connect();
  void disconnect();

  // Message types
  // - status: Queue status updates
  // - progress: Execution progress
  // - executing: Current node being executed
  // - executed: Node execution complete with outputs
  // - execution_error: Error occurred
  // - execution_cached: Node was cached
}
```

#### 4.2 Preview System
```dart
// lib/comfyui/ui/nodes/node_preview.dart

class NodePreview extends StatelessWidget {
  final PreviewData data;

  @override
  Widget build(BuildContext context) {
    return switch (data) {
      ImagePreview(:final bytes) => Image.memory(bytes),
      VideoPreview(:final url) => VideoPreviewWidget(url: url),
      LatentPreview(:final tensor) => LatentVisualization(tensor: tensor),
      TextPreview(:final text) => SelectableText(text),
      _ => const SizedBox.shrink(),
    };
  }
}
```

### Phase 5: Advanced Features (Week 6-8)

#### 5.1 Group Nodes (Subgraphs)
- Collapse multiple nodes into a single group
- Edit group contents in-place
- Convert group to reusable node type

#### 5.2 Reroute Nodes
- Visual connection routing
- Organize complex graphs

#### 5.3 Mask Editor
- Integrated mask painting
- Brush tools and layers

#### 5.4 Extension System
```dart
// lib/comfyui/services/extension_service.dart

abstract class ComfyExtension {
  String get name;
  String get version;

  // Register custom nodes
  void registerNodes(NodeRegistry registry);

  // Add menu items
  List<MenuItem> getCanvasMenuItems(BuildContext context);
  List<MenuItem> getNodeMenuItems(BuildContext context, String nodeId);

  // Custom widgets
  Map<String, WidgetBuilder> get customWidgets;
}
```

---

## 4. Test Strategy for 100% Parity

### 4.1 Test Categories

```
tests/
├── unit/                         # Pure Dart logic tests
│   ├── core/
│   │   ├── graph_test.dart
│   │   ├── executor_test.dart
│   │   ├── validator_test.dart
│   │   └── serialization_test.dart
│   │
│   ├── state/
│   │   ├── graph_notifier_test.dart
│   │   ├── history_test.dart
│   │   └── execution_test.dart
│   │
│   └── utils/
│       └── topological_sort_test.dart
│
├── widget/                       # Widget tests
│   ├── nodes/
│   │   ├── comfy_node_test.dart
│   │   ├── slot_widget_test.dart
│   │   └── node_widgets_test.dart
│   │
│   ├── menus/
│   │   ├── canvas_menu_test.dart
│   │   └── node_menu_test.dart
│   │
│   └── panels/
│       ├── node_browser_test.dart
│       └── properties_panel_test.dart
│
├── integration/                  # Integration tests
│   ├── graph_operations_test.dart
│   ├── execution_flow_test.dart
│   ├── save_load_test.dart
│   └── undo_redo_test.dart
│
└── parity/                       # Feature parity tests
    ├── node_types_parity_test.dart
    ├── serialization_parity_test.dart
    ├── execution_parity_test.dart
    └── ui_behavior_parity_test.dart
```

### 4.2 Parity Test Approach

```dart
// tests/parity/serialization_parity_test.dart

void main() {
  group('Serialization Parity', () {
    // Load workflows from ComfyUI examples
    final testWorkflows = [
      'workflows/basic_txt2img.json',
      'workflows/img2img.json',
      'workflows/inpainting.json',
      'workflows/controlnet.json',
      // ... more
    ];

    for (final path in testWorkflows) {
      test('loads and saves $path identically', () async {
        // Load original
        final original = await File(path).readAsString();
        final originalJson = jsonDecode(original);

        // Parse into Flutter graph
        final graph = ComfyGraph.fromJson(originalJson);

        // Serialize back
        final exported = graph.toJson();

        // Compare
        expect(exported, equals(originalJson));
      });
    }
  });
}
```

### 4.3 Visual Regression Tests

```dart
// tests/widget/visual_regression_test.dart

void main() {
  testWidgets('KSampler node matches reference', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ComfyNode(
          definition: kSamplerDef,
          data: ComfyNodeData.defaultFor(kSamplerDef),
        ),
      ),
    );

    await expectLater(
      find.byType(ComfyNode),
      matchesGoldenFile('goldens/ksampler_node.png'),
    );
  });
}
```

### 4.4 Behavior Tests

```dart
// tests/integration/graph_operations_test.dart

void main() {
  group('Graph Operations', () {
    test('connecting incompatible slots fails', () {
      final graph = ComfyGraph();

      // Add two nodes
      final loader = graph.addNode('CheckpointLoaderSimple', Offset.zero);
      final sampler = graph.addNode('KSampler', Offset(300, 0));

      // Try to connect MODEL output to CONDITIONING input (should fail)
      expect(
        () => graph.connect(
          loader.id, 0,  // MODEL output
          sampler.id, 1, // positive conditioning input
        ),
        throwsA(isA<IncompatibleSlotException>()),
      );
    });

    test('connecting compatible slots succeeds', () {
      final graph = ComfyGraph();

      final loader = graph.addNode('CheckpointLoaderSimple', Offset.zero);
      final sampler = graph.addNode('KSampler', Offset(300, 0));

      // Connect MODEL output to MODEL input (should succeed)
      final edge = graph.connect(
        loader.id, 0,  // MODEL output
        sampler.id, 0, // model input
      );

      expect(edge, isNotNull);
      expect(graph.edges.length, equals(1));
    });
  });
}
```

---

## 5. Feature Parity Checklist

### Core Features
- [ ] Node types from ComfyUI backend
- [ ] All slot types with correct colors
- [ ] Widget types (INT, FLOAT, STRING, COMBO, etc.)
- [ ] Graph serialization (ComfyUI JSON format)
- [ ] API prompt format generation
- [ ] Execution queue integration
- [ ] WebSocket status updates
- [ ] Node execution progress
- [ ] Image/latent previews

### UI Features
- [ ] Pan and zoom
- [ ] Node selection (single/multi)
- [ ] Node dragging
- [ ] Edge creation via drag
- [ ] Edge deletion
- [ ] Context menus (canvas, node, slot)
- [ ] Node browser/search
- [ ] Properties panel
- [ ] Minimap
- [ ] Zoom controls

### Advanced Features
- [ ] Undo/redo
- [ ] Copy/paste
- [ ] Group nodes
- [ ] Reroute nodes
- [ ] Node bypass
- [ ] Node mute
- [ ] Keyboard shortcuts
- [ ] Workflow tabs
- [ ] Save/load dialogs
- [ ] Settings persistence

### ComfyUI Specific
- [ ] Queue management
- [ ] Execution history
- [ ] Model/VAE/LoRA management
- [ ] Image upload
- [ ] Mask editor
- [ ] Batch processing
- [ ] Interrupt execution
- [ ] Clear queue

---

## 6. Dependencies

```yaml
# pubspec.yaml additions

dependencies:
  # State management
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0

  # Networking
  dio: ^5.4.0
  web_socket_channel: ^2.4.0

  # Storage
  shared_preferences: ^2.2.0
  path_provider: ^2.1.0

  # UI
  flutter_colorpicker: ^1.0.3
  file_picker: ^6.1.0

  # Utilities
  uuid: ^4.2.0
  collection: ^1.18.0

dev_dependencies:
  # Testing
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
  golden_toolkit: ^0.15.0

  # Code generation
  riverpod_generator: ^2.3.0
  build_runner: ^2.4.0
```

---

## 7. Timeline

| Week | Phase | Deliverables |
|------|-------|--------------|
| 1-2 | Core Infrastructure | Slot types, node definitions, registry, graph executor |
| 2-3 | State Management | Riverpod providers, graph notifier, history |
| 3-4 | Basic UI | ComfyNode widget, slots, edges, canvas |
| 4-5 | Menus & Panels | Context menus, node browser, properties |
| 5-6 | Execution | WebSocket, queue, previews, progress |
| 6-7 | Advanced UI | Group nodes, reroute, mask editor |
| 7-8 | Polish & Testing | Full test coverage, visual regression |

---

## 8. Getting Started

### Step 1: Clone and setup
```bash
cd /Users/johndpope/Documents/GitHub/xyflow/packages/xyflow_flutter/example
mkdir -p lib/comfyui
```

### Step 2: Create base files
Start with the slot types and node definition system since everything depends on them.

### Step 3: Test with real ComfyUI backend
Run a local ComfyUI instance and test API integration early.

---

## Next Steps

1. Review this plan and approve/modify architecture
2. Begin Phase 1 implementation with slot types
3. Set up test infrastructure
4. Create first working node (CheckpointLoaderSimple)
5. Iterate from there
