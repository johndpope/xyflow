/// ComfyUI API prompt format.
///
/// Converts a ComfyGraph to the API prompt format used for
/// sending execution requests to the ComfyUI backend.
library;

import 'dart:convert';

import '../graph/comfy_graph.dart';
import '../graph/topological_sort.dart';
import '../nodes/node_registry.dart';

/// Converts a ComfyGraph to ComfyUI API prompt format.
///
/// The API format is a flat map where:
/// - Keys are node IDs (as strings)
/// - Values are node definitions with inputs and class_type
class ApiPromptSerializer {
  final NodeRegistry? registry;

  ApiPromptSerializer({this.registry});

  /// Convert graph to API prompt format.
  ///
  /// Returns a map suitable for sending to ComfyUI's /prompt endpoint.
  Map<String, dynamic> toPrompt(ComfyGraph graph) {
    final prompt = <String, dynamic>{};

    // Get execution order
    final sortResult = getExecutionOrder(graph);
    if (!sortResult.isValid) {
      throw StateError('Graph contains cycles and cannot be executed');
    }

    for (final node in sortResult.orderedNodes) {
      prompt[node.id] = _nodeToPromptEntry(node, graph);
    }

    return prompt;
  }

  /// Convert graph to full API request format.
  ///
  /// Includes prompt, client_id, and optional extra info.
  Map<String, dynamic> toApiRequest(
    ComfyGraph graph, {
    String? clientId,
    Map<String, dynamic>? extraData,
  }) {
    return {
      'prompt': toPrompt(graph),
      if (clientId != null) 'client_id': clientId,
      if (extraData != null) 'extra_data': extraData,
    };
  }

  /// Convert to JSON string.
  String toJsonString(ComfyGraph graph, {bool pretty = false}) {
    final json = toApiRequest(graph);
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(json);
    }
    return jsonEncode(json);
  }

  Map<String, dynamic> _nodeToPromptEntry(ComfyNode node, ComfyGraph graph) {
    final inputs = <String, dynamic>{};

    // Get node definition for input names
    final def = registry?.get(node.type);

    // Add connected inputs
    final incomingEdges = graph.getIncomingEdges(node.id);
    for (final edge in incomingEdges) {
      String inputName;
      if (def != null && edge.targetSlot < def.inputs.length) {
        inputName = def.inputs[edge.targetSlot].name;
      } else {
        inputName = 'input_${edge.targetSlot}';
      }

      // API format: [source_node_id, source_slot_index]
      inputs[inputName] = [edge.sourceNodeId, edge.sourceSlot];
    }

    // Add widget values
    if (def != null) {
      for (final widget in def.widgets) {
        if (node.widgetValues.containsKey(widget.name)) {
          inputs[widget.name] = node.widgetValues[widget.name];
        } else if (widget.defaultValue != null) {
          inputs[widget.name] = widget.defaultValue;
        }
      }
    } else {
      // No definition, just add all widget values
      inputs.addAll(node.widgetValues);
    }

    return {
      'class_type': node.type,
      'inputs': inputs,
      if (node.isBypassed) '_meta': {'bypass': true},
    };
  }
}

/// Parses API execution results.
class ApiResultParser {
  /// Parse execution output from WebSocket message.
  static ExecutionOutput? parseOutput(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'executing':
        return ExecutingNode(
          nodeId: data['data']?['node'] as String?,
          promptId: data['data']?['prompt_id'] as String?,
        );

      case 'execution_cached':
        return ExecutionCached(
          nodes: (data['data']?['nodes'] as List?)?.cast<String>() ?? [],
          promptId: data['data']?['prompt_id'] as String?,
        );

      case 'executed':
        return NodeExecuted(
          nodeId: data['data']?['node'] as String?,
          promptId: data['data']?['prompt_id'] as String?,
          output: data['data']?['output'] as Map<String, dynamic>?,
        );

      case 'progress':
        return ExecutionProgress(
          value: data['data']?['value'] as int? ?? 0,
          max: data['data']?['max'] as int? ?? 100,
          nodeId: data['data']?['node'] as String?,
          promptId: data['data']?['prompt_id'] as String?,
        );

      case 'execution_start':
        return ExecutionStart(
          promptId: data['data']?['prompt_id'] as String?,
        );

      case 'execution_error':
        return ExecutionError(
          nodeId: data['data']?['node_id'] as String?,
          nodeType: data['data']?['node_type'] as String?,
          message: data['data']?['exception_message'] as String?,
          traceback: (data['data']?['traceback'] as List?)?.cast<String>(),
          promptId: data['data']?['prompt_id'] as String?,
        );

      case 'execution_interrupted':
        return ExecutionInterrupted(
          promptId: data['data']?['prompt_id'] as String?,
        );

      case 'status':
        return QueueStatus(
          queueRemaining: data['data']?['status']?['exec_info']?['queue_remaining'] as int? ?? 0,
        );

      default:
        return null;
    }
  }
}

/// Base class for execution outputs.
abstract class ExecutionOutput {
  final String? promptId;
  const ExecutionOutput({this.promptId});
}

/// Indicates which node is currently executing.
class ExecutingNode extends ExecutionOutput {
  final String? nodeId;

  const ExecutingNode({
    this.nodeId,
    super.promptId,
  });

  /// Whether execution is complete (nodeId is null).
  bool get isComplete => nodeId == null;
}

/// Indicates nodes were cached and skipped.
class ExecutionCached extends ExecutionOutput {
  final List<String> nodes;

  const ExecutionCached({
    required this.nodes,
    super.promptId,
  });
}

/// A node has finished executing with output.
class NodeExecuted extends ExecutionOutput {
  final String? nodeId;
  final Map<String, dynamic>? output;

  const NodeExecuted({
    this.nodeId,
    this.output,
    super.promptId,
  });

  /// Get image outputs.
  List<Map<String, dynamic>> get images {
    final imgs = output?['images'] as List?;
    return imgs?.cast<Map<String, dynamic>>() ?? [];
  }
}

/// Progress update for a node.
class ExecutionProgress extends ExecutionOutput {
  final int value;
  final int max;
  final String? nodeId;

  const ExecutionProgress({
    required this.value,
    required this.max,
    this.nodeId,
    super.promptId,
  });

  /// Progress as percentage (0-100).
  double get percentage => (value / max) * 100;
}

/// Execution has started.
class ExecutionStart extends ExecutionOutput {
  const ExecutionStart({super.promptId});
}

/// An error occurred during execution.
class ExecutionError extends ExecutionOutput {
  final String? nodeId;
  final String? nodeType;
  final String? message;
  final List<String>? traceback;

  const ExecutionError({
    this.nodeId,
    this.nodeType,
    this.message,
    this.traceback,
    super.promptId,
  });

  @override
  String toString() {
    return 'ExecutionError: $message (node: $nodeId, type: $nodeType)';
  }
}

/// Execution was interrupted.
class ExecutionInterrupted extends ExecutionOutput {
  const ExecutionInterrupted({super.promptId});
}

/// Queue status update.
class QueueStatus extends ExecutionOutput {
  final int queueRemaining;

  const QueueStatus({required this.queueRemaining});
}
