/// ComfyNode Widget - Custom node widget for ComfyUI-style nodes.
///
/// Renders nodes with:
/// - Header with category color and title
/// - Input slots with labels and connection handles
/// - Output slots with labels and connection handles
/// - Widget inputs (INT, FLOAT, STRING, COMBO)
/// - Collapsed/muted/bypassed visual states
library;

import 'package:flutter/material.dart';
import 'package:xyflow_flutter/xyflow_flutter.dart';

import '../core/nodes/node_definition.dart';
import '../core/nodes/node_registry.dart';
import '../core/nodes/slot_types.dart';
import '../core/graph/comfy_graph.dart';

/// Data class passed to ComfyNodeWidget.
class ComfyNodeData {
  /// The ComfyNode instance.
  final ComfyNode node;

  /// The node definition from registry.
  final NodeDefinition? definition;

  /// Callback when widget value changes.
  final void Function(String widgetName, dynamic value)? onWidgetValueChanged;

  const ComfyNodeData({
    required this.node,
    this.definition,
    this.onWidgetValueChanged,
  });
}

/// Widget for rendering a ComfyUI-style node.
class ComfyNodeWidget extends StatelessWidget {
  /// Creates a ComfyNode widget.
  const ComfyNodeWidget({
    super.key,
    required this.props,
  });

  /// The node props from xyflow.
  final NodeProps<ComfyNodeData> props;

  @override
  Widget build(BuildContext context) {
    final data = props.data;
    final node = data.node;
    final def = data.definition;

    // Get category color from definition or use default
    final headerColor = node.color ?? def?.color ?? _getCategoryColor(def?.category);
    final bgColor = node.bgColor ?? def?.bgColor ?? const Color(0xFF353535);

    // Check visual states
    final isMuted = node.isMuted;
    final isBypassed = node.isBypassed;
    final isCollapsed = node.collapsed;

    return Opacity(
      opacity: isMuted ? 0.5 : 1.0,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 140,
          maxWidth: 320,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: props.selected
                ? Colors.white
                : (isBypassed ? Colors.orange : Colors.black54),
            width: props.selected ? 2 : 1,
          ),
          boxShadow: props.selected
              ? [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(node, def, headerColor, isBypassed),
            // Body (inputs, outputs, widgets) - hidden when collapsed
            if (!isCollapsed) _buildBody(node, def, data.onWidgetValueChanged),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    ComfyNode node,
    NodeDefinition? def,
    Color headerColor,
    bool isBypassed,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(7),
          topRight: Radius.circular(7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapse indicator
          if (node.collapsed)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.chevron_right, size: 16, color: Colors.white70),
            ),
          // Title
          Flexible(
            child: Text(
              node.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: isBypassed ? TextDecoration.lineThrough : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Badges
          if (isBypassed)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.block, size: 12, color: Colors.orange),
            ),
          if (node.isMuted)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.volume_off, size: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(
    ComfyNode node,
    NodeDefinition? def,
    void Function(String, dynamic)? onWidgetValueChanged,
  ) {
    final inputs = def?.inputs ?? [];
    final outputs = def?.outputs ?? [];
    final widgets = def?.widgets ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inputs and outputs in a row
          if (inputs.isNotEmpty || outputs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input slots
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < inputs.length; i++)
                          _SlotWidget(
                            slot: inputs[i],
                            slotIndex: i,
                            isInput: true,
                          ),
                      ],
                    ),
                  ),
                  // Output slots
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (int i = 0; i < outputs.length; i++)
                          _SlotWidget(
                            slot: outputs[i],
                            slotIndex: i,
                            isInput: false,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Widget inputs
          if (widgets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Column(
                children: [
                  for (final widget in widgets)
                    _WidgetInputWidget(
                      widget: widget,
                      value: node.widgetValues[widget.name],
                      onChanged: onWidgetValueChanged != null
                          ? (value) => onWidgetValueChanged(widget.name, value)
                          : null,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Get color for category.
  Color _getCategoryColor(String? category) {
    if (category == null) return const Color(0xFF666666);

    final lowerCategory = category.toLowerCase();
    if (lowerCategory.contains('loader')) return const Color(0xFF4E6F4E);
    if (lowerCategory.contains('sampl')) return const Color(0xFF7D5A3C);
    if (lowerCategory.contains('conditioning')) return const Color(0xFF8B5A8B);
    if (lowerCategory.contains('latent')) return const Color(0xFF5A5A8B);
    if (lowerCategory.contains('image')) return const Color(0xFF5A8B8B);
    if (lowerCategory.contains('mask')) return const Color(0xFF8B8B5A);
    if (lowerCategory.contains('advanced')) return const Color(0xFF8B5A5A);

    return const Color(0xFF666666);
  }
}

/// Widget for a single slot (input or output).
class _SlotWidget extends StatelessWidget {
  const _SlotWidget({
    required this.slot,
    required this.slotIndex,
    required this.isInput,
  });

  final SlotDefinition slot;
  final int slotIndex;
  final bool isInput;

  @override
  Widget build(BuildContext context) {
    final slotColor = slot.type.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Label
          Padding(
            padding: EdgeInsets.only(
              left: isInput ? 14 : 4,
              right: isInput ? 4 : 14,
            ),
            child: Text(
              slot.name,
              style: TextStyle(
                color: slotColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: isInput ? TextAlign.left : TextAlign.right,
            ),
          ),
          // Connection handle
          Positioned(
            left: isInput ? -8 : null,
            right: isInput ? null : -8,
            top: 0,
            bottom: 0,
            child: Center(
              child: HandleWidget(
                type: isInput ? HandleType.target : HandleType.source,
                position: isInput ? Position.left : Position.right,
                id: '$slotIndex',
                style: HandleStyle(
                  size: 10,
                  color: slotColor,
                  borderColor: Colors.black,
                  borderWidth: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget for rendering a widget input.
class _WidgetInputWidget extends StatelessWidget {
  const _WidgetInputWidget({
    required this.widget,
    required this.value,
    this.onChanged,
  });

  final WidgetDefinition widget;
  final dynamic value;
  final void Function(dynamic)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Label
          SizedBox(
            width: 60,
            child: Text(
              widget.name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          // Input widget
          Expanded(
            child: _buildInputWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputWidget() {
    switch (widget.type) {
      case WidgetType.int_:
        return _IntInputWidget(
          value: value as int? ?? widget.defaultValue as int? ?? 0,
          min: widget.min?.toInt(),
          max: widget.max?.toInt(),
          step: widget.step?.toInt() ?? 1,
          onChanged: onChanged,
        );
      case WidgetType.float_:
        return _FloatInputWidget(
          value: (value as num?)?.toDouble() ??
              (widget.defaultValue as num?)?.toDouble() ??
              0.0,
          min: widget.min?.toDouble(),
          max: widget.max?.toDouble(),
          step: widget.step?.toDouble() ?? 0.01,
          onChanged: onChanged,
        );
      case WidgetType.string:
        return _StringInputWidget(
          value: value as String? ?? widget.defaultValue as String? ?? '',
          multiline: widget.multiline,
          onChanged: onChanged,
        );
      case WidgetType.combo:
        return _ComboInputWidget(
          value: value ?? widget.defaultValue ?? widget.options?.firstOrNull,
          options: widget.options ?? [],
          onChanged: onChanged,
        );
      case WidgetType.boolean:
        return _ToggleInputWidget(
          value: value as bool? ?? widget.defaultValue as bool? ?? false,
          onChanged: onChanged,
        );
      case WidgetType.seed:
        return _SeedInputWidget(
          value: value as int? ?? widget.defaultValue as int? ?? 0,
          onChanged: onChanged,
        );
      case WidgetType.image:
        return _FileUploadWidget(
          value: value as String?,
          type: widget.type,
          onChanged: onChanged,
        );
      case WidgetType.color:
        return _ColorInputWidget(
          value: value as String? ?? widget.defaultValue as String? ?? '#FFFFFF',
          onChanged: onChanged,
        );
      case WidgetType.custom:
        return Text(
          '${value ?? "?"}',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        );
    }
  }
}

/// Integer input widget.
class _IntInputWidget extends StatelessWidget {
  const _IntInputWidget({
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
  final void Function(dynamic)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          // Increment/decrement buttons
          InkWell(
            onTap: onChanged != null
                ? () {
                    final newValue = value - step;
                    if (min == null || newValue >= min!) {
                      onChanged!(newValue);
                    }
                  }
                : null,
            child: const Icon(Icons.remove, size: 12, color: Colors.white54),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onChanged != null
                ? () {
                    final newValue = value + step;
                    if (max == null || newValue <= max!) {
                      onChanged!(newValue);
                    }
                  }
                : null,
            child: const Icon(Icons.add, size: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

/// Float input widget.
class _FloatInputWidget extends StatelessWidget {
  const _FloatInputWidget({
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
  final void Function(dynamic)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value.toStringAsFixed(2),
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          InkWell(
            onTap: onChanged != null
                ? () {
                    final newValue = value - step;
                    if (min == null || newValue >= min!) {
                      onChanged!(newValue);
                    }
                  }
                : null,
            child: const Icon(Icons.remove, size: 12, color: Colors.white54),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onChanged != null
                ? () {
                    final newValue = value + step;
                    if (max == null || newValue <= max!) {
                      onChanged!(newValue);
                    }
                  }
                : null,
            child: const Icon(Icons.add, size: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

/// String input widget.
class _StringInputWidget extends StatelessWidget {
  const _StringInputWidget({
    required this.value,
    this.multiline = false,
    this.onChanged,
  });

  final String value;
  final bool multiline;
  final void Function(dynamic)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: multiline ? 44 : 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          value.isEmpty ? '...' : value,
          style: TextStyle(
            color: value.isEmpty ? Colors.white38 : Colors.white,
            fontSize: 11,
          ),
          maxLines: multiline ? 2 : 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Combo box input widget.
class _ComboInputWidget extends StatelessWidget {
  const _ComboInputWidget({
    required this.value,
    required this.options,
    this.onChanged,
  });

  final dynamic value;
  final List<String> options;
  final void Function(dynamic)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value?.toString() ?? options.firstOrNull ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white54),
        ],
      ),
    );
  }
}

/// Toggle/boolean input widget.
class _ToggleInputWidget extends StatelessWidget {
  const _ToggleInputWidget({
    required this.value,
    this.onChanged,
  });

  final bool value;
  final void Function(dynamic)? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: value ? Colors.green.withValues(alpha: 0.3) : Colors.black38,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: value ? Colors.green : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              size: 14,
              color: value ? Colors.green : Colors.white54,
            ),
            const SizedBox(width: 4),
            Text(
              value ? 'True' : 'False',
              style: TextStyle(
                color: value ? Colors.green : Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seed input widget with randomize button.
class _SeedInputWidget extends StatelessWidget {
  const _SeedInputWidget({
    required this.value,
    this.onChanged,
  });

  final int value;
  final void Function(dynamic)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          InkWell(
            onTap: onChanged != null
                ? () {
                    // Generate random seed
                    final random = DateTime.now().millisecondsSinceEpoch %
                        0xFFFFFFFFFFFFFFFF;
                    onChanged!(random);
                  }
                : null,
            child: const Icon(Icons.casino, size: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

/// File upload widget placeholder.
class _FileUploadWidget extends StatelessWidget {
  const _FileUploadWidget({
    required this.value,
    required this.type,
    this.onChanged,
  });

  final String? value;
  final WidgetType type;
  final void Function(dynamic)? onChanged;

  @override
  Widget build(BuildContext context) {
    // Image type is the only upload type in the current enum
    const IconData icon = Icons.image;

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          const Icon(icon, size: 12, color: Colors.white54),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value ?? 'Upload...',
              style: TextStyle(
                color: value != null ? Colors.white : Colors.white38,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Color input widget.
class _ColorInputWidget extends StatelessWidget {
  const _ColorInputWidget({
    required this.value,
    this.onChanged,
  });

  final String value;
  final void Function(dynamic)? onChanged;

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
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _parseColor(value),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Colors.white30, width: 1),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
