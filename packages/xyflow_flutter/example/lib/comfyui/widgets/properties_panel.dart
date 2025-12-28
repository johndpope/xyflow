/// Properties Panel - Display and edit selected node properties.
///
/// Features:
/// - Display selected node info
/// - Edit widget values
/// - Show input/output connections
/// - Node settings (title, muted, bypassed)
library;

import 'package:flutter/material.dart';

import '../core/nodes/node_definition.dart';
import '../core/nodes/node_registry.dart';
import '../core/nodes/slot_types.dart';
import '../core/graph/comfy_graph.dart';

/// Callback when a widget value changes.
typedef OnWidgetValueChanged = void Function(String nodeId, String widgetName, dynamic value);

/// Callback when node property changes.
typedef OnNodePropertyChanged = void Function(String nodeId, String property, dynamic value);

/// Panel for displaying and editing node properties.
class PropertiesPanel extends StatelessWidget {
  /// Creates a properties panel.
  const PropertiesPanel({
    super.key,
    required this.registry,
    this.selectedNode,
    this.nodeDefinition,
    this.incomingEdges = const [],
    this.outgoingEdges = const [],
    this.onWidgetValueChanged,
    this.onNodePropertyChanged,
    this.width = 280,
  });

  /// The node registry.
  final NodeRegistry registry;

  /// The currently selected node.
  final ComfyNode? selectedNode;

  /// The definition of the selected node.
  final NodeDefinition? nodeDefinition;

  /// Incoming edges to the selected node.
  final List<ComfyEdge> incomingEdges;

  /// Outgoing edges from the selected node.
  final List<ComfyEdge> outgoingEdges;

  /// Callback when widget value changes.
  final OnWidgetValueChanged? onWidgetValueChanged;

  /// Callback when node property changes.
  final OnNodePropertyChanged? onNodePropertyChanged;

  /// Panel width.
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFF2D2D2D),
        border: Border(left: BorderSide(color: Colors.black54)),
      ),
      child: selectedNode == null
          ? _buildEmptyState()
          : _buildNodeProperties(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, color: Colors.grey[600], size: 48),
            const SizedBox(height: 12),
            Text(
              'Select a node to view properties',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeProperties() {
    final node = selectedNode!;
    final def = nodeDefinition;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Node header
        _buildHeader(node, def),
        const SizedBox(height: 16),

        // Node settings
        _buildSection('Settings', [
          _buildTitleField(node),
          _buildModeToggles(node),
        ]),

        // Widget values
        if (def != null && def.widgets.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSection('Widgets', [
            for (final widget in def.widgets)
              _buildWidgetEditor(node, widget),
          ]),
        ],

        // Inputs
        if (def != null && def.inputs.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSection('Inputs', [
            for (int i = 0; i < def.inputs.length; i++)
              _buildSlotInfo(def.inputs[i], i, true),
          ]),
        ],

        // Outputs
        if (def != null && def.outputs.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSection('Outputs', [
            for (int i = 0; i < def.outputs.length; i++)
              _buildSlotInfo(def.outputs[i], i, false),
          ]),
        ],

        // Node info
        const SizedBox(height: 16),
        _buildSection('Info', [
          _buildInfoRow('Type', node.type),
          _buildInfoRow('ID', node.id),
          if (def?.category != null)
            _buildInfoRow('Category', def!.category),
          if (def?.description != null && def!.description!.isNotEmpty)
            _buildInfoRow('Description', def.description!),
        ]),
      ],
    );
  }

  Widget _buildHeader(ComfyNode node, NodeDefinition? def) {
    final color = node.color ?? def?.color ?? NodeCategory.getColor(def?.category ?? 'default');

    return Row(
      children: [
        Container(
          width: 6,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                node.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                node.type,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildTitleField(ComfyNode node) {
    return _PropertyField(
      label: 'Title',
      child: TextFormField(
        initialValue: node.title,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: _inputDecoration,
        onChanged: (value) {
          onNodePropertyChanged?.call(node.id, 'title', value);
        },
      ),
    );
  }

  Widget _buildModeToggles(ComfyNode node) {
    return Column(
      children: [
        _PropertyField(
          label: 'Mode',
          child: Row(
            children: [
              _buildModeChip('Muted', node.isMuted, () {
                onNodePropertyChanged?.call(node.id, 'mode', node.isMuted ? 0 : 1);
              }),
              const SizedBox(width: 8),
              _buildModeChip('Bypassed', node.isBypassed, () {
                onNodePropertyChanged?.call(node.id, 'mode', node.isBypassed ? 0 : 2);
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _PropertyField(
          label: 'Collapsed',
          child: Switch(
            value: node.collapsed,
            onChanged: (value) {
              onNodePropertyChanged?.call(node.id, 'collapsed', value);
            },
            activeColor: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildModeChip(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.orange.withValues(alpha: 0.2) : Colors.black26,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? Colors.orange : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.orange : Colors.grey[500],
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetEditor(ComfyNode node, WidgetDefinition widget) {
    final value = node.widgetValues[widget.name] ?? widget.defaultValue;

    return _PropertyField(
      label: widget.name,
      child: _buildWidgetInput(node.id, widget, value),
    );
  }

  Widget _buildWidgetInput(String nodeId, WidgetDefinition widget, dynamic value) {
    switch (widget.type) {
      case WidgetType.int_:
        return _IntInput(
          value: value as int? ?? 0,
          min: widget.min?.toInt(),
          max: widget.max?.toInt(),
          step: widget.step?.toInt() ?? 1,
          onChanged: (v) => onWidgetValueChanged?.call(nodeId, widget.name, v),
        );
      case WidgetType.float_:
        return _FloatInput(
          value: (value as num?)?.toDouble() ?? 0.0,
          min: widget.min?.toDouble(),
          max: widget.max?.toDouble(),
          step: widget.step?.toDouble() ?? 0.01,
          onChanged: (v) => onWidgetValueChanged?.call(nodeId, widget.name, v),
        );
      case WidgetType.string:
        return _StringInput(
          value: value as String? ?? '',
          multiline: widget.multiline,
          onChanged: (v) => onWidgetValueChanged?.call(nodeId, widget.name, v),
        );
      case WidgetType.boolean:
        return Switch(
          value: value as bool? ?? false,
          onChanged: (v) => onWidgetValueChanged?.call(nodeId, widget.name, v),
          activeColor: Colors.blue,
        );
      case WidgetType.combo:
        return _ComboInput(
          value: value,
          options: widget.options ?? [],
          onChanged: (v) => onWidgetValueChanged?.call(nodeId, widget.name, v),
        );
      case WidgetType.seed:
        return _SeedInput(
          value: value as int? ?? 0,
          onChanged: (v) => onWidgetValueChanged?.call(nodeId, widget.name, v),
        );
      case WidgetType.color:
        return _ColorInput(
          value: value as String? ?? '#FFFFFF',
          onChanged: (v) => onWidgetValueChanged?.call(nodeId, widget.name, v),
        );
      default:
        return Text(
          '$value',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        );
    }
  }

  Widget _buildSlotInfo(SlotDefinition slot, int index, bool isInput) {
    final connectedEdges = isInput
        ? incomingEdges.where((e) => e.targetSlot == index)
        : outgoingEdges.where((e) => e.sourceSlot == index);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: slot.type.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                Text(
                  slot.type.typeName,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (connectedEdges.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${connectedEdges.length} connected',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration get _inputDecoration => InputDecoration(
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
      );
}

/// A property field with label.
class _PropertyField extends StatelessWidget {
  const _PropertyField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

/// Integer input widget.
class _IntInput extends StatelessWidget {
  const _IntInput({
    required this.value,
    this.min,
    this.max,
    this.step = 1,
    this.onChanged,
  });

  final int value;
  final int? min;
  final int? max;
  final int step;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            color: Colors.grey[500],
            onPressed: () {
              final newValue = value - step;
              if (min == null || newValue >= min!) {
                onChanged?.call(newValue);
              }
            },
          ),
          Expanded(
            child: Text(
              value.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            color: Colors.grey[500],
            onPressed: () {
              final newValue = value + step;
              if (max == null || newValue <= max!) {
                onChanged?.call(newValue);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Float input widget.
class _FloatInput extends StatelessWidget {
  const _FloatInput({
    required this.value,
    this.min,
    this.max,
    this.step = 0.01,
    this.onChanged,
  });

  final double value;
  final double? min;
  final double? max;
  final double step;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            color: Colors.grey[500],
            onPressed: () {
              final newValue = value - step;
              if (min == null || newValue >= min!) {
                onChanged?.call(newValue);
              }
            },
          ),
          Expanded(
            child: Text(
              value.toStringAsFixed(2),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            color: Colors.grey[500],
            onPressed: () {
              final newValue = value + step;
              if (max == null || newValue <= max!) {
                onChanged?.call(newValue);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// String input widget.
class _StringInput extends StatelessWidget {
  const _StringInput({
    required this.value,
    this.multiline = false,
    this.onChanged,
  });

  final String value;
  final bool multiline;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      maxLines: multiline ? 3 : 1,
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: onChanged,
    );
  }
}

/// Combo box input widget.
class _ComboInput extends StatelessWidget {
  const _ComboInput({
    required this.value,
    required this.options,
    this.onChanged,
  });

  final dynamic value;
  final List<String> options;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(value) ? value.toString() : options.firstOrNull,
          isExpanded: true,
          dropdownColor: const Color(0xFF2D2D2D),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          icon: Icon(Icons.arrow_drop_down, color: Colors.grey[500]),
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged?.call(v);
          },
        ),
      ),
    );
  }
}

/// Seed input widget.
class _SeedInput extends StatelessWidget {
  const _SeedInput({
    required this.value,
    this.onChanged,
  });

  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                value.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.casino, size: 16),
            color: Colors.grey[500],
            tooltip: 'Randomize',
            onPressed: () {
              final random = DateTime.now().millisecondsSinceEpoch % 0xFFFFFFFF;
              onChanged?.call(random);
            },
          ),
        ],
      ),
    );
  }
}

/// Color input widget.
class _ColorInput extends StatelessWidget {
  const _ColorInput({
    required this.value,
    this.onChanged,
  });

  final String value;
  final ValueChanged<String>? onChanged;

  Color _parseColor(String hex) {
    try {
      final hexCode = hex.replaceAll('#', '');
      return Color(int.parse('FF$hexCode', radix: 16));
    } catch (e) {
      return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _parseColor(value),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
