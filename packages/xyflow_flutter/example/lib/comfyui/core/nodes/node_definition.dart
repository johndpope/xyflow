/// ComfyUI node definition - describes what a node type looks like and does.
library;

import 'package:flutter/material.dart';

import 'slot_types.dart';

/// Definition of a node widget (input control on the node).
class WidgetDefinition {
  /// Widget name (e.g., "seed", "steps", "cfg")
  final String name;

  /// Widget type
  final WidgetType type;

  /// Default value
  final dynamic defaultValue;

  /// For combo: available options
  final List<String>? options;

  /// Min value for numeric types
  final num? min;

  /// Max value for numeric types
  final num? max;

  /// Step for numeric types
  final num? step;

  /// Whether string is multiline
  final bool multiline;

  /// Display label (if different from name)
  final String? label;

  /// Tooltip
  final String? tooltip;

  const WidgetDefinition({
    required this.name,
    required this.type,
    this.defaultValue,
    this.options,
    this.min,
    this.max,
    this.step,
    this.multiline = false,
    this.label,
    this.tooltip,
  });

  factory WidgetDefinition.fromSlot(SlotDefinition slot) {
    return WidgetDefinition(
      name: slot.name,
      type: _slotTypeToWidgetType(slot.type),
      defaultValue: slot.defaultValue,
      options: slot.comboOptions,
      min: slot.min,
      max: slot.max,
      step: slot.step,
      multiline: slot.multiline,
      tooltip: slot.tooltip,
    );
  }

  static WidgetType _slotTypeToWidgetType(SlotType slotType) {
    return switch (slotType) {
      SlotType.int_ => WidgetType.int_,
      SlotType.float_ => WidgetType.float_,
      SlotType.string => WidgetType.string,
      SlotType.boolean => WidgetType.boolean,
      SlotType.combo => WidgetType.combo,
      _ => WidgetType.string,
    };
  }
}

/// Types of input widgets that can appear on nodes.
enum WidgetType {
  int_,
  float_,
  string,
  boolean,
  combo,
  image,
  color,
  seed,
  custom,
}

/// Category colors for nodes.
class NodeCategory {
  static const Map<String, Color> colors = {
    'loaders': Color(0xFF4A6741),
    'conditioning': Color(0xFF6B4B3A),
    'sampling': Color(0xFF3A4A6B),
    'latent': Color(0xFF6B3A5A),
    'image': Color(0xFF3A6B5A),
    'mask': Color(0xFF5A5A5A),
    'advanced': Color(0xFF4A4A6B),
    'utils': Color(0xFF5A6B4A),
    '_for_testing': Color(0xFF6B6B6B),
  };

  static Color getColor(String category) {
    final base = category.split('/').first.toLowerCase();
    return colors[base] ?? const Color(0xFF4A4A4A);
  }
}

/// Complete definition of a ComfyUI node type.
class NodeDefinition {
  /// Internal name (e.g., "KSampler")
  final String name;

  /// Display name (e.g., "K Sampler")
  final String displayName;

  /// Category path (e.g., "sampling", "sampling/custom")
  final String category;

  /// Description of what the node does
  final String? description;

  /// Input slots (connections from other nodes)
  final List<SlotDefinition> inputs;

  /// Output slots (connections to other nodes)
  final List<SlotDefinition> outputs;

  /// Widget inputs (controls on the node itself)
  final List<WidgetDefinition> widgets;

  /// Hidden inputs (not shown on node)
  final List<SlotDefinition> hiddenInputs;

  /// Header color
  final Color color;

  /// Background color
  final Color bgColor;

  /// Whether this is an output node (triggers execution)
  final bool isOutputNode;

  /// Output node type (e.g., "IMAGE", "LATENT")
  final String? outputNodeType;

  /// Whether the node is deprecated
  final bool deprecated;

  /// Whether the node is experimental
  final bool experimental;

  const NodeDefinition({
    required this.name,
    required this.displayName,
    required this.category,
    this.description,
    this.inputs = const [],
    this.outputs = const [],
    this.widgets = const [],
    this.hiddenInputs = const [],
    Color? color,
    Color? bgColor,
    this.isOutputNode = false,
    this.outputNodeType,
    this.deprecated = false,
    this.experimental = false,
  })  : color = color ?? const Color(0xFF353535),
        bgColor = bgColor ?? const Color(0xFF2A2A2A);

  /// Create from ComfyUI object_info API response.
  factory NodeDefinition.fromApi(String name, Map<String, dynamic> data) {
    final inputData = data['input'] as Map<String, dynamic>? ?? {};
    final requiredInputs = inputData['required'] as Map<String, dynamic>? ?? {};
    final optionalInputs = inputData['optional'] as Map<String, dynamic>? ?? {};
    final hiddenInputs = inputData['hidden'] as Map<String, dynamic>? ?? {};

    final outputNames = (data['output'] as List?)?.cast<String>() ?? [];
    final outputIsList = (data['output_is_list'] as List?)?.cast<bool>() ?? [];
    final outputTooltips = (data['output_tooltips'] as List?)?.cast<String?>() ?? [];

    // Parse inputs - separate slots from widgets
    final slots = <SlotDefinition>[];
    final widgets = <WidgetDefinition>[];

    void processInputs(Map<String, dynamic> inputs, {bool optional = false}) {
      inputs.forEach((inputName, inputData) {
        final slot = SlotDefinition.fromApi(inputName, inputData);
        final slotWithOptional = slot.copyWith(isOptional: optional);

        // Slots are for complex types (MODEL, IMAGE, etc.)
        // Widgets are for simple types shown on node (INT, FLOAT, STRING, COMBO)
        if (_isWidgetType(slot.type)) {
          widgets.add(WidgetDefinition.fromSlot(slotWithOptional));
        } else {
          slots.add(slotWithOptional);
        }
      });
    }

    processInputs(requiredInputs, optional: false);
    processInputs(optionalInputs, optional: true);

    // Parse hidden inputs
    final hidden = hiddenInputs.entries.map((e) {
      return SlotDefinition.fromApi(e.key, e.value).copyWith(isOptional: true);
    }).toList();

    // Parse outputs
    final outputs = <SlotDefinition>[];
    for (var i = 0; i < outputNames.length; i++) {
      outputs.add(SlotDefinition(
        name: outputNames[i],
        type: SlotType.fromTypeName(outputNames[i]),
        tooltip: i < outputTooltips.length ? outputTooltips[i] : null,
      ));
    }

    final category = data['category'] as String? ?? 'uncategorized';
    final displayName = data['display_name'] as String? ?? name;
    final description = data['description'] as String?;
    final isOutputNode = data['output_node'] == true;

    return NodeDefinition(
      name: name,
      displayName: displayName,
      category: category,
      description: description,
      inputs: slots,
      outputs: outputs,
      widgets: widgets,
      hiddenInputs: hidden,
      color: NodeCategory.getColor(category),
      isOutputNode: isOutputNode,
      outputNodeType: isOutputNode ? (outputNames.isNotEmpty ? outputNames[0] : null) : null,
      deprecated: data['deprecated'] == true,
      experimental: data['experimental'] == true,
    );
  }

  /// Check if a slot type should be rendered as a widget
  static bool _isWidgetType(SlotType type) {
    return switch (type) {
      SlotType.int_ => true,
      SlotType.float_ => true,
      SlotType.string => true,
      SlotType.boolean => true,
      SlotType.combo => true,
      SlotType.sampler => true,
      SlotType.scheduler => true,
      _ => false,
    };
  }

  /// Get all input slot names
  List<String> get inputNames => inputs.map((s) => s.name).toList();

  /// Get all output slot names
  List<String> get outputNames => outputs.map((s) => s.name).toList();

  /// Get all widget names
  List<String> get widgetNames => widgets.map((w) => w.name).toList();

  /// Find input slot by name
  SlotDefinition? getInput(String name) {
    try {
      return inputs.firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Find output slot by name
  SlotDefinition? getOutput(String name) {
    try {
      return outputs.firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Find widget by name
  WidgetDefinition? getWidget(String name) {
    try {
      return widgets.firstWhere((w) => w.name == name);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'NodeDefinition($name)';
}
