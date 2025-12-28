/// Graph validation for ComfyUI workflows.
///
/// Validates graph structure, connections, and widget values
/// before execution.
library;

import '../nodes/node_registry.dart';
import 'comfy_graph.dart';
import 'topological_sort.dart';

/// Severity level for validation issues.
enum ValidationSeverity {
  /// Error - prevents execution.
  error,

  /// Warning - allows execution but may cause issues.
  warning,

  /// Info - informational only.
  info,
}

/// A single validation issue.
class ValidationIssue {
  /// Severity of the issue.
  final ValidationSeverity severity;

  /// Human-readable message.
  final String message;

  /// Node ID related to the issue (if any).
  final String? nodeId;

  /// Slot index related to the issue (if any).
  final int? slotIndex;

  /// Widget name related to the issue (if any).
  final String? widgetName;

  const ValidationIssue({
    required this.severity,
    required this.message,
    this.nodeId,
    this.slotIndex,
    this.widgetName,
  });

  bool get isError => severity == ValidationSeverity.error;
  bool get isWarning => severity == ValidationSeverity.warning;

  @override
  String toString() {
    final location = [
      if (nodeId != null) 'node: $nodeId',
      if (slotIndex != null) 'slot: $slotIndex',
      if (widgetName != null) 'widget: $widgetName',
    ].join(', ');

    return '${severity.name.toUpperCase()}: $message${location.isNotEmpty ? ' ($location)' : ''}';
  }
}

/// Result of graph validation.
class ValidationResult {
  /// All validation issues found.
  final List<ValidationIssue> issues;

  const ValidationResult(this.issues);

  /// Create empty result (valid).
  factory ValidationResult.valid() => const ValidationResult([]);

  /// Whether the graph is valid (no errors).
  bool get isValid => !issues.any((i) => i.isError);

  /// All error issues.
  List<ValidationIssue> get errors =>
      issues.where((i) => i.isError).toList();

  /// All warning issues.
  List<ValidationIssue> get warnings =>
      issues.where((i) => i.isWarning).toList();

  /// Combine with another result.
  ValidationResult operator +(ValidationResult other) {
    return ValidationResult([...issues, ...other.issues]);
  }

  @override
  String toString() {
    if (isValid && issues.isEmpty) return 'ValidationResult: Valid';
    return 'ValidationResult: ${errors.length} errors, ${warnings.length} warnings';
  }
}

/// Validates ComfyUI graphs.
class GraphValidator {
  final NodeRegistry registry;

  GraphValidator(this.registry);

  /// Validate the entire graph.
  ValidationResult validate(ComfyGraph graph) {
    final issues = <ValidationIssue>[];

    // Check for empty graph
    if (graph.nodeCount == 0) {
      issues.add(const ValidationIssue(
        severity: ValidationSeverity.warning,
        message: 'Graph is empty',
      ));
      return ValidationResult(issues);
    }

    // Validate each node
    for (final node in graph.nodes) {
      issues.addAll(_validateNode(node, graph).issues);
    }

    // Check for cycles
    final sortResult = topologicalSort(graph);
    if (sortResult.hasCycle) {
      issues.add(ValidationIssue(
        severity: ValidationSeverity.error,
        message: 'Graph contains cycles involving ${sortResult.cycleNodes.length} nodes',
      ));
      for (final node in sortResult.cycleNodes) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          message: 'Node "${node.title}" is part of a cycle',
          nodeId: node.id,
        ));
      }
    }

    // Check for output nodes
    final outputNodes = graph.getOutputNodes();
    if (outputNodes.isEmpty) {
      issues.add(const ValidationIssue(
        severity: ValidationSeverity.warning,
        message: 'No output nodes found - nothing will be executed',
      ));
    }

    // Check for disconnected nodes
    final connectedNodes = _getConnectedNodes(graph);
    for (final node in graph.nodes) {
      if (!connectedNodes.contains(node.id)) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.info,
          message: 'Node "${node.title}" is not connected to any output',
          nodeId: node.id,
        ));
      }
    }

    return ValidationResult(issues);
  }

  /// Validate a single node.
  ValidationResult _validateNode(ComfyNode node, ComfyGraph graph) {
    final issues = <ValidationIssue>[];

    // Check if node type exists
    final def = registry.get(node.type);
    if (def == null) {
      issues.add(ValidationIssue(
        severity: ValidationSeverity.error,
        message: 'Unknown node type: ${node.type}',
        nodeId: node.id,
      ));
      return ValidationResult(issues);
    }

    // Check deprecated/experimental
    if (def.deprecated) {
      issues.add(ValidationIssue(
        severity: ValidationSeverity.warning,
        message: 'Node "${node.title}" uses deprecated type ${node.type}',
        nodeId: node.id,
      ));
    }

    if (def.experimental) {
      issues.add(ValidationIssue(
        severity: ValidationSeverity.info,
        message: 'Node "${node.title}" uses experimental type ${node.type}',
        nodeId: node.id,
      ));
    }

    // Check required inputs are connected
    final incomingEdges = graph.getIncomingEdges(node.id);
    final connectedInputs = incomingEdges.map((e) => e.targetSlot).toSet();

    for (var i = 0; i < def.inputs.length; i++) {
      final input = def.inputs[i];
      if (!input.isOptional && !connectedInputs.contains(i)) {
        issues.add(ValidationIssue(
          severity: ValidationSeverity.error,
          message: 'Required input "${input.name}" is not connected',
          nodeId: node.id,
          slotIndex: i,
        ));
      }
    }

    // Validate widget values
    for (final widget in def.widgets) {
      final value = node.widgetValues[widget.name];
      final widgetIssues = _validateWidgetValue(node.id, widget.name, value, widget);
      issues.addAll(widgetIssues);
    }

    return ValidationResult(issues);
  }

  /// Validate a widget value.
  List<ValidationIssue> _validateWidgetValue(
    String nodeId,
    String widgetName,
    dynamic value,
    dynamic widgetDef,
  ) {
    final issues = <ValidationIssue>[];

    // TODO: Add comprehensive widget validation based on widget type
    // - INT: check min/max/step
    // - FLOAT: check min/max/step
    // - STRING: check required
    // - COMBO: check value is in options

    return issues;
  }

  /// Get all nodes connected to output nodes.
  Set<String> _getConnectedNodes(ComfyGraph graph) {
    final connected = <String>{};
    final outputNodes = graph.getOutputNodes();

    for (final output in outputNodes) {
      _collectAncestors(graph, output.id, connected);
    }

    return connected;
  }

  /// Recursively collect all ancestor nodes.
  void _collectAncestors(ComfyGraph graph, String nodeId, Set<String> visited) {
    if (visited.contains(nodeId)) return;
    visited.add(nodeId);

    for (final edge in graph.getIncomingEdges(nodeId)) {
      _collectAncestors(graph, edge.sourceNodeId, visited);
    }
  }

  /// Quick check if graph can be executed.
  bool canExecute(ComfyGraph graph) {
    return validate(graph).isValid;
  }
}

/// Validate a connection before creating it.
ValidationResult validateConnection(
  ComfyGraph graph,
  NodeRegistry registry,
  String sourceNodeId,
  int sourceSlot,
  String targetNodeId,
  int targetSlot,
) {
  final issues = <ValidationIssue>[];

  // Check nodes exist
  final sourceNode = graph.getNode(sourceNodeId);
  final targetNode = graph.getNode(targetNodeId);

  if (sourceNode == null) {
    issues.add(ValidationIssue(
      severity: ValidationSeverity.error,
      message: 'Source node not found',
      nodeId: sourceNodeId,
    ));
    return ValidationResult(issues);
  }

  if (targetNode == null) {
    issues.add(ValidationIssue(
      severity: ValidationSeverity.error,
      message: 'Target node not found',
      nodeId: targetNodeId,
    ));
    return ValidationResult(issues);
  }

  // Check node types exist
  final sourceDef = registry.get(sourceNode.type);
  final targetDef = registry.get(targetNode.type);

  if (sourceDef == null) {
    issues.add(ValidationIssue(
      severity: ValidationSeverity.error,
      message: 'Unknown source node type: ${sourceNode.type}',
      nodeId: sourceNodeId,
    ));
  }

  if (targetDef == null) {
    issues.add(ValidationIssue(
      severity: ValidationSeverity.error,
      message: 'Unknown target node type: ${targetNode.type}',
      nodeId: targetNodeId,
    ));
  }

  if (sourceDef == null || targetDef == null) {
    return ValidationResult(issues);
  }

  // Check slot indices
  if (sourceSlot >= sourceDef.outputs.length) {
    issues.add(ValidationIssue(
      severity: ValidationSeverity.error,
      message: 'Invalid output slot index: $sourceSlot',
      nodeId: sourceNodeId,
      slotIndex: sourceSlot,
    ));
  }

  if (targetSlot >= targetDef.inputs.length) {
    issues.add(ValidationIssue(
      severity: ValidationSeverity.error,
      message: 'Invalid input slot index: $targetSlot',
      nodeId: targetNodeId,
      slotIndex: targetSlot,
    ));
  }

  if (issues.isNotEmpty) return ValidationResult(issues);

  // Check type compatibility
  final sourceType = sourceDef.outputs[sourceSlot].type;
  final targetType = targetDef.inputs[targetSlot].type;

  if (!sourceType.canConnectTo(targetType)) {
    issues.add(ValidationIssue(
      severity: ValidationSeverity.error,
      message: 'Type mismatch: ${sourceType.typeName} cannot connect to ${targetType.typeName}',
    ));
  }

  // Check for self-connection
  if (sourceNodeId == targetNodeId) {
    issues.add(const ValidationIssue(
      severity: ValidationSeverity.error,
      message: 'Cannot connect a node to itself',
    ));
  }

  // Check if connection would create a cycle
  // (Simple check - would need more sophisticated detection for complex graphs)

  return ValidationResult(issues);
}
