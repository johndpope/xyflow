/// ComfyUI workflow JSON serialization.
///
/// Handles serialization and deserialization of ComfyUI workflow
/// format for compatibility with the ComfyUI backend.
library;

import 'dart:convert';
import 'dart:ui';

import '../graph/comfy_graph.dart';
import '../nodes/node_registry.dart';
import '../nodes/slot_types.dart';

/// Serializes a ComfyGraph to ComfyUI JSON format.
class WorkflowSerializer {
  /// Serialize graph to ComfyUI workflow JSON.
  static Map<String, dynamic> toJson(ComfyGraph graph) {
    return {
      'last_node_id': _getMaxNodeId(graph),
      'last_link_id': _getMaxLinkId(graph),
      'nodes': graph.nodes.map((n) => _nodeToJson(n, graph)).toList(),
      'links': graph.edges.map((e) => _edgeToLinkArray(e, graph)).toList(),
      'groups': graph.groups.map(_groupToJson).toList(),
      'config': {},
      'extra': graph.extra,
      'version': 0.4,
    };
  }

  /// Serialize graph to JSON string.
  static String toJsonString(ComfyGraph graph, {bool pretty = false}) {
    final json = toJson(graph);
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(json);
    }
    return jsonEncode(json);
  }

  static int _getMaxNodeId(ComfyGraph graph) {
    var maxId = 0;
    for (final node in graph.nodes) {
      final id = int.tryParse(node.id) ?? 0;
      if (id > maxId) maxId = id;
    }
    return maxId;
  }

  static int _getMaxLinkId(ComfyGraph graph) {
    var maxId = 0;
    for (final edge in graph.edges) {
      final id = int.tryParse(edge.id) ?? 0;
      if (id > maxId) maxId = id;
    }
    return maxId;
  }

  static Map<String, dynamic> _nodeToJson(ComfyNode node, ComfyGraph graph) {
    // Find connected inputs
    final inputs = <Map<String, dynamic>>[];
    final incomingEdges = graph.getIncomingEdges(node.id);

    // Group edges by target slot
    final edgesBySlot = <int, ComfyEdge>{};
    for (final edge in incomingEdges) {
      edgesBySlot[edge.targetSlot] = edge;
    }

    // Build inputs array (includes slot info and link ID)
    for (var i = 0; i < edgesBySlot.length || i < 10; i++) {
      if (!edgesBySlot.containsKey(i)) break;
      final edge = edgesBySlot[i];
      if (edge != null) {
        inputs.add({
          'name': 'input_$i', // Will be filled from definition
          'type': edge.type.typeName,
          'link': int.tryParse(edge.id) ?? edge.id.hashCode,
        });
      }
    }

    // Build outputs array
    final outputs = <Map<String, dynamic>>[];
    final outgoingEdges = graph.getOutgoingEdges(node.id);
    final edgesBySourceSlot = <int, List<ComfyEdge>>{};
    for (final edge in outgoingEdges) {
      edgesBySourceSlot.putIfAbsent(edge.sourceSlot, () => []).add(edge);
    }

    for (var i = 0; i < (edgesBySourceSlot.keys.isEmpty ? 0 : edgesBySourceSlot.keys.reduce((a, b) => a > b ? a : b) + 1); i++) {
      final edges = edgesBySourceSlot[i] ?? [];
      outputs.add({
        'name': 'output_$i',
        'type': edges.isNotEmpty ? edges.first.type.typeName : '*',
        'links': edges.map((e) => int.tryParse(e.id) ?? e.id.hashCode).toList(),
        'slot_index': i,
      });
    }

    return {
      'id': int.tryParse(node.id) ?? node.id.hashCode,
      'type': node.type,
      'pos': [node.position.dx, node.position.dy],
      'size': {'0': node.size.width, '1': node.size.height},
      'flags': {
        if (node.collapsed) 'collapsed': true,
        if (node.pinned) 'pinned': true,
      },
      'order': node.order,
      'mode': node.mode,
      if (node.title != node.type) 'title': node.title,
      'inputs': inputs,
      'outputs': outputs,
      'properties': node.properties,
      'widgets_values': node.widgetValues.values.toList(),
      if (node.color != null) 'color': _colorToHex(node.color!),
      if (node.bgColor != null) 'bgcolor': _colorToHex(node.bgColor!),
    };
  }

  static List<dynamic> _edgeToLinkArray(ComfyEdge edge, ComfyGraph graph) {
    // ComfyUI link format: [linkId, sourceNodeId, sourceSlot, targetNodeId, targetSlot, type]
    return [
      int.tryParse(edge.id) ?? edge.id.hashCode,
      int.tryParse(edge.sourceNodeId) ?? edge.sourceNodeId.hashCode,
      edge.sourceSlot,
      int.tryParse(edge.targetNodeId) ?? edge.targetNodeId.hashCode,
      edge.targetSlot,
      edge.type.typeName,
    ];
  }

  static Map<String, dynamic> _groupToJson(ComfyGroup group) {
    return {
      'title': group.title,
      'bounding': [
        group.bounds.left,
        group.bounds.top,
        group.bounds.width,
        group.bounds.height,
      ],
      'color': _colorToHex(group.color),
      'font_size': group.fontSize,
      'locked': group.locked,
    };
  }

  static String _colorToHex(dynamic color) {
    if (color is int) {
      return '#${color.toRadixString(16).padLeft(6, '0')}';
    }
    // Assume it's a Color object
    final c = color;
    final r = ((c.r * 255).round()).toRadixString(16).padLeft(2, '0');
    final g = ((c.g * 255).round()).toRadixString(16).padLeft(2, '0');
    final b = ((c.b * 255).round()).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }
}

/// Deserializes ComfyUI JSON format to a ComfyGraph.
class WorkflowDeserializer {
  final NodeRegistry? registry;

  WorkflowDeserializer({this.registry});

  /// Parse JSON string to graph.
  ComfyGraph fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return fromJson(json);
  }

  /// Parse JSON map to graph.
  ComfyGraph fromJson(Map<String, dynamic> json) {
    final graph = ComfyGraph(registry: registry);

    // Parse nodes
    final nodesJson = json['nodes'] as List? ?? [];
    final nodeIdMap = <int, String>{}; // Map ComfyUI int IDs to our string IDs

    for (final nodeJson in nodesJson) {
      final node = _parseNode(nodeJson as Map<String, dynamic>);
      graph.addNode(node);

      final comfyId = nodeJson['id'] as int?;
      if (comfyId != null) {
        nodeIdMap[comfyId] = node.id;
      }
    }

    // Parse links
    final linksJson = json['links'] as List? ?? [];
    for (final linkJson in linksJson) {
      if (linkJson is List && linkJson.length >= 6) {
        final sourceNodeId = nodeIdMap[linkJson[1] as int];
        final targetNodeId = nodeIdMap[linkJson[3] as int];

        if (sourceNodeId != null && targetNodeId != null) {
          graph.connect(
            sourceNodeId,
            linkJson[2] as int,
            targetNodeId,
            linkJson[4] as int,
          );
        }
      }
    }

    // Parse groups
    final groupsJson = json['groups'] as List? ?? [];
    for (final groupJson in groupsJson) {
      final group = _parseGroup(groupJson as Map<String, dynamic>);
      graph.addGroup(group);
    }

    // Extra data
    if (json['extra'] is Map) {
      graph.extra.addAll((json['extra'] as Map).cast<String, dynamic>());
    }

    return graph;
  }

  ComfyNode _parseNode(Map<String, dynamic> json) {
    // Parse position
    final posJson = json['pos'];
    final position = posJson is List && posJson.length >= 2
        ? Offset((posJson[0] as num).toDouble(), (posJson[1] as num).toDouble())
        : Offset.zero;

    // Parse size
    final sizeJson = json['size'];
    Size size;
    if (sizeJson is Map) {
      size = Size(
        (sizeJson['0'] as num?)?.toDouble() ?? 200,
        (sizeJson['1'] as num?)?.toDouble() ?? 100,
      );
    } else if (sizeJson is List && sizeJson.length >= 2) {
      size = Size(
        (sizeJson[0] as num).toDouble(),
        (sizeJson[1] as num).toDouble(),
      );
    } else {
      size = const Size(200, 100);
    }

    // Parse flags
    final flags = json['flags'] as Map<String, dynamic>? ?? {};

    // Parse widget values
    final widgetValues = <String, dynamic>{};
    final widgetValuesJson = json['widgets_values'] as List?;
    if (widgetValuesJson != null) {
      // Widget values are ordered - we'd need the definition to map them
      // For now, store as indexed values
      for (var i = 0; i < widgetValuesJson.length; i++) {
        widgetValues['widget_$i'] = widgetValuesJson[i];
      }
    }

    // Map widget values properly if we have the registry
    if (registry != null) {
      final def = registry!.get(json['type'] as String? ?? '');
      if (def != null && widgetValuesJson != null) {
        widgetValues.clear();
        for (var i = 0; i < def.widgets.length && i < widgetValuesJson.length; i++) {
          widgetValues[def.widgets[i].name] = widgetValuesJson[i];
        }
      }
    }

    return ComfyNode(
      id: (json['id'] as int?)?.toString() ?? '',
      type: json['type'] as String? ?? 'Unknown',
      title: json['title'] as String?,
      position: position,
      size: size,
      order: json['order'] as int? ?? 0,
      mode: json['mode'] as int? ?? 0,
      widgetValues: widgetValues,
      properties: (json['properties'] as Map?)?.cast<String, dynamic>() ?? {},
      collapsed: flags['collapsed'] == true,
      pinned: flags['pinned'] == true,
      color: _parseColor(json['color']),
      bgColor: _parseColor(json['bgcolor']),
    );
  }

  ComfyGroup _parseGroup(Map<String, dynamic> json) {
    final bounding = json['bounding'] as List? ?? [0, 0, 100, 100];

    return ComfyGroup(
      title: json['title'] as String? ?? 'Group',
      bounds: Rect.fromLTWH(
        (bounding[0] as num).toDouble(),
        (bounding[1] as num).toDouble(),
        (bounding[2] as num).toDouble(),
        (bounding[3] as num).toDouble(),
      ),
      color: _parseColor(json['color']) ?? const Color(0xFF335533),
      fontSize: (json['font_size'] as num?)?.toDouble() ?? 24,
      locked: json['locked'] == true,
    );
  }

  Color? _parseColor(dynamic value) {
    if (value == null) return null;
    if (value is String && value.startsWith('#')) {
      final hex = value.substring(1);
      final intValue = int.tryParse(hex, radix: 16);
      if (intValue != null) {
        return Color(0xFF000000 | intValue);
      }
    }
    return null;
  }
}
