/// Workflow Service - Save and load ComfyUI workflows.
///
/// Handles workflow persistence in ComfyUI JSON format.
library;

import 'dart:convert';
import 'dart:ui' show Offset;

import '../core/graph/comfy_graph.dart';
import '../core/nodes/node_registry.dart';
import '../core/serialization/workflow_json.dart';

/// Result of a workflow operation.
class WorkflowResult<T> {
  /// Whether the operation succeeded.
  final bool success;

  /// Result data (if successful).
  final T? data;

  /// Error message (if failed).
  final String? error;

  const WorkflowResult({
    required this.success,
    this.data,
    this.error,
  });

  factory WorkflowResult.success(T data) => WorkflowResult(
        success: true,
        data: data,
      );

  factory WorkflowResult.failure(String error) => WorkflowResult(
        success: false,
        error: error,
      );
}

/// Workflow metadata.
class WorkflowMetadata {
  /// Workflow title.
  final String? title;

  /// Workflow description.
  final String? description;

  /// Author name.
  final String? author;

  /// Version string.
  final String? version;

  /// Tags for categorization.
  final List<String> tags;

  /// Creation timestamp.
  final DateTime? createdAt;

  /// Last modified timestamp.
  final DateTime? modifiedAt;

  /// Thumbnail image (base64).
  final String? thumbnail;

  const WorkflowMetadata({
    this.title,
    this.description,
    this.author,
    this.version,
    this.tags = const [],
    this.createdAt,
    this.modifiedAt,
    this.thumbnail,
  });

  WorkflowMetadata copyWith({
    String? title,
    String? description,
    String? author,
    String? version,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? thumbnail,
  }) {
    return WorkflowMetadata(
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      version: version ?? this.version,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      thumbnail: thumbnail ?? this.thumbnail,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (author != null) 'author': author,
      if (version != null) 'version': version,
      if (tags.isNotEmpty) 'tags': tags,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (modifiedAt != null) 'modified_at': modifiedAt!.toIso8601String(),
      if (thumbnail != null) 'thumbnail': thumbnail,
    };
  }

  factory WorkflowMetadata.fromJson(Map<String, dynamic> json) {
    return WorkflowMetadata(
      title: json['title'] as String?,
      description: json['description'] as String?,
      author: json['author'] as String?,
      version: json['version'] as String?,
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      modifiedAt: json['modified_at'] != null
          ? DateTime.tryParse(json['modified_at'] as String)
          : null,
      thumbnail: json['thumbnail'] as String?,
    );
  }
}

/// Workflow with metadata.
class Workflow {
  /// The graph data.
  final ComfyGraph graph;

  /// Workflow metadata.
  final WorkflowMetadata metadata;

  /// File path (if loaded from file).
  final String? filePath;

  const Workflow({
    required this.graph,
    this.metadata = const WorkflowMetadata(),
    this.filePath,
  });

  Workflow copyWith({
    ComfyGraph? graph,
    WorkflowMetadata? metadata,
    String? filePath,
  }) {
    return Workflow(
      graph: graph ?? this.graph,
      metadata: metadata ?? this.metadata,
      filePath: filePath ?? this.filePath,
    );
  }
}

/// Service for managing workflows.
class WorkflowService {
  /// Node registry for parsing.
  final NodeRegistry? registry;

  WorkflowService({this.registry});

  /// Parse workflow from JSON string.
  WorkflowResult<Workflow> parseWorkflow(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return parseWorkflowJson(json);
    } catch (e) {
      return WorkflowResult.failure('Invalid JSON: $e');
    }
  }

  /// Parse workflow from JSON map.
  WorkflowResult<Workflow> parseWorkflowJson(Map<String, dynamic> json) {
    try {
      final deserializer = WorkflowDeserializer(registry: registry);
      final graph = deserializer.fromJson(json);

      // Extract metadata from extra field
      final extra = json['extra'] as Map<String, dynamic>?;
      final metadata = extra != null
          ? WorkflowMetadata.fromJson(extra)
          : const WorkflowMetadata();

      return WorkflowResult.success(Workflow(
        graph: graph,
        metadata: metadata,
      ));
    } catch (e) {
      return WorkflowResult.failure('Failed to parse workflow: $e');
    }
  }

  /// Serialize workflow to JSON string.
  WorkflowResult<String> serializeWorkflow(
    Workflow workflow, {
    bool pretty = true,
  }) {
    try {
      final json = serializeWorkflowToJson(workflow);
      if (json.success && json.data != null) {
        final encoder = pretty
            ? const JsonEncoder.withIndent('  ')
            : const JsonEncoder();
        return WorkflowResult.success(encoder.convert(json.data));
      }
      return WorkflowResult.failure(json.error ?? 'Unknown error');
    } catch (e) {
      return WorkflowResult.failure('Failed to serialize workflow: $e');
    }
  }

  /// Serialize workflow to JSON map.
  WorkflowResult<Map<String, dynamic>> serializeWorkflowToJson(
    Workflow workflow,
  ) {
    try {
      final json = WorkflowSerializer.toJson(workflow.graph);

      // Add metadata to extra field
      if (workflow.metadata.title != null ||
          workflow.metadata.description != null ||
          workflow.metadata.tags.isNotEmpty) {
        final extra = json['extra'] as Map<String, dynamic>? ?? {};
        extra.addAll(workflow.metadata.toJson());
        json['extra'] = extra;
      }

      return WorkflowResult.success(json);
    } catch (e) {
      return WorkflowResult.failure('Failed to serialize workflow: $e');
    }
  }

  /// Create a new empty workflow.
  Workflow createNewWorkflow({WorkflowMetadata? metadata}) {
    return Workflow(
      graph: ComfyGraph(registry: registry),
      metadata: metadata ??
          WorkflowMetadata(
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          ),
    );
  }

  /// Duplicate a workflow.
  Workflow duplicateWorkflow(Workflow workflow, {String? newTitle}) {
    final json = WorkflowSerializer.toJson(workflow.graph);
    final deserializer = WorkflowDeserializer(registry: registry);
    final newGraph = deserializer.fromJson(json);

    return Workflow(
      graph: newGraph,
      metadata: workflow.metadata.copyWith(
        title: newTitle ?? '${workflow.metadata.title ?? "Workflow"} (Copy)',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      ),
    );
  }

  /// Merge two workflows.
  WorkflowResult<Workflow> mergeWorkflows(
    Workflow base,
    Workflow other, {
    Offset offset = const Offset(200, 200),
  }) {
    try {
      // Duplicate nodes from other workflow with offset
      final nodeIdMap = <String, String>{};

      for (final node in other.graph.nodes) {
        final newNode = ComfyNode(
          type: node.type,
          position: node.position + offset,
          title: node.title,
          widgetValues: Map.from(node.widgetValues),
          mode: node.mode,
          properties: Map.from(node.properties),
        );
        base.graph.addNode(newNode);
        nodeIdMap[node.id] = newNode.id;
      }

      // Duplicate edges with updated IDs
      for (final edge in other.graph.edges) {
        final newSourceId = nodeIdMap[edge.sourceNodeId];
        final newTargetId = nodeIdMap[edge.targetNodeId];

        if (newSourceId != null && newTargetId != null) {
          base.graph.connect(
            newSourceId,
            edge.sourceSlot,
            newTargetId,
            edge.targetSlot,
          );
        }
      }

      return WorkflowResult.success(base.copyWith(
        metadata: base.metadata.copyWith(
          modifiedAt: DateTime.now(),
        ),
      ));
    } catch (e) {
      return WorkflowResult.failure('Failed to merge workflows: $e');
    }
  }

  /// Validate a workflow.
  List<String> validateWorkflow(Workflow workflow) {
    final errors = <String>[];

    // Check for nodes with missing types
    for (final node in workflow.graph.nodes) {
      if (registry != null && registry!.get(node.type) == null) {
        errors.add('Unknown node type: ${node.type} (${node.id})');
      }
    }

    // Check for edges with invalid connections
    for (final edge in workflow.graph.edges) {
      final sourceNode = workflow.graph.getNode(edge.sourceNodeId);
      final targetNode = workflow.graph.getNode(edge.targetNodeId);

      if (sourceNode == null) {
        errors.add('Edge references missing source node: ${edge.sourceNodeId}');
      }
      if (targetNode == null) {
        errors.add('Edge references missing target node: ${edge.targetNodeId}');
      }
    }

    // Check for output nodes
    final outputNodes = workflow.graph.getOutputNodes();
    if (outputNodes.isEmpty) {
      errors.add('Workflow has no output nodes');
    }

    return errors;
  }

  /// Get workflow statistics.
  Map<String, dynamic> getWorkflowStats(Workflow workflow) {
    final nodeTypes = <String, int>{};
    for (final node in workflow.graph.nodes) {
      nodeTypes[node.type] = (nodeTypes[node.type] ?? 0) + 1;
    }

    return {
      'nodeCount': workflow.graph.nodes.length,
      'edgeCount': workflow.graph.edges.length,
      'groupCount': workflow.graph.groups.length,
      'nodeTypes': nodeTypes,
      'hasOutput': workflow.graph.getOutputNodes().isNotEmpty,
    };
  }
}

