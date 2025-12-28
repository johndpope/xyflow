/// ComfyAPI Service - REST API client for ComfyUI backend.
///
/// Handles all HTTP communication with ComfyUI server.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/graph/comfy_graph.dart';
import '../core/nodes/node_definition.dart';
import '../core/serialization/api_format.dart';

/// Result of an API call.
class ApiResult<T> {
  /// Whether the call succeeded.
  final bool success;

  /// Result data (if successful).
  final T? data;

  /// Error message (if failed).
  final String? error;

  /// HTTP status code.
  final int? statusCode;

  const ApiResult({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });

  factory ApiResult.success(T data) => ApiResult(
        success: true,
        data: data,
      );

  factory ApiResult.failure(String error, {int? statusCode}) => ApiResult(
        success: false,
        error: error,
        statusCode: statusCode,
      );
}

/// Queue item information.
class QueueInfo {
  /// Running prompts.
  final List<Map<String, dynamic>> running;

  /// Pending prompts.
  final List<Map<String, dynamic>> pending;

  const QueueInfo({
    required this.running,
    required this.pending,
  });

  /// Total items in queue.
  int get total => running.length + pending.length;

  /// Whether queue is empty.
  bool get isEmpty => total == 0;

  factory QueueInfo.fromJson(Map<String, dynamic> json) {
    final queueRunning = json['queue_running'] as List?;
    final queuePending = json['queue_pending'] as List?;

    return QueueInfo(
      running: queueRunning?.cast<Map<String, dynamic>>() ?? [],
      pending: queuePending?.cast<Map<String, dynamic>>() ?? [],
    );
  }
}

/// History entry for executed prompt.
class HistoryEntry {
  /// Prompt ID.
  final String promptId;

  /// Prompt data.
  final Map<String, dynamic> prompt;

  /// Output data by node ID.
  final Map<String, dynamic> outputs;

  /// Status information.
  final Map<String, dynamic>? status;

  const HistoryEntry({
    required this.promptId,
    required this.prompt,
    required this.outputs,
    this.status,
  });

  factory HistoryEntry.fromJson(String promptId, Map<String, dynamic> json) {
    return HistoryEntry(
      promptId: promptId,
      prompt: json['prompt'] as Map<String, dynamic>? ?? {},
      outputs: json['outputs'] as Map<String, dynamic>? ?? {},
      status: json['status'] as Map<String, dynamic>?,
    );
  }

  /// Get images from outputs.
  List<Map<String, dynamic>> getImages(String nodeId) {
    final nodeOutput = outputs[nodeId] as Map<String, dynamic>?;
    final images = nodeOutput?['images'] as List?;
    return images?.cast<Map<String, dynamic>>() ?? [];
  }
}

/// System stats from ComfyUI.
class SystemStats {
  /// System information.
  final Map<String, dynamic> system;

  /// Device information.
  final List<Map<String, dynamic>> devices;

  const SystemStats({
    required this.system,
    required this.devices,
  });

  factory SystemStats.fromJson(Map<String, dynamic> json) {
    final devices = json['devices'] as List?;
    return SystemStats(
      system: json['system'] as Map<String, dynamic>? ?? {},
      devices: devices?.cast<Map<String, dynamic>>() ?? [],
    );
  }

  /// Get VRAM usage for first device.
  double? get vramUsage {
    if (devices.isEmpty) return null;
    final device = devices.first;
    final vramTotal = device['vram_total'] as int?;
    final vramFree = device['vram_free'] as int?;
    if (vramTotal == null || vramFree == null || vramTotal == 0) return null;
    return (vramTotal - vramFree) / vramTotal;
  }
}

/// ComfyUI REST API service.
class ComfyApiService {
  /// Base URL for API requests.
  final String baseUrl;

  /// HTTP client.
  final http.Client _client;

  ComfyApiService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Get node definitions from /object_info.
  Future<ApiResult<Map<String, NodeDefinition>>> getObjectInfo() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/object_info'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final definitions = <String, NodeDefinition>{};

        for (final entry in json.entries) {
          try {
            final def = NodeDefinition.fromApi(
              entry.key,
              entry.value as Map<String, dynamic>,
            );
            definitions[entry.key] = def;
          } catch (e) {
            // Skip invalid definitions
          }
        }

        return ApiResult.success(definitions);
      } else {
        return ApiResult.failure(
          'Failed to get object info: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  /// Queue a prompt for execution.
  Future<ApiResult<String>> queuePrompt(
    Map<String, dynamic> workflow, {
    String? clientId,
    int? number,
    bool front = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'prompt': workflow,
      };

      if (clientId != null) {
        body['client_id'] = clientId;
      }

      if (number != null) {
        body['number'] = number;
      }

      if (front) {
        body['front'] = true;
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/prompt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final promptId = json['prompt_id'] as String?;

        if (promptId != null) {
          return ApiResult.success(promptId);
        } else {
          return ApiResult.failure('No prompt ID returned');
        }
      } else {
        // Try to parse error message
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final error = json['error'] as String?;
          final nodeErrors = json['node_errors'] as Map<String, dynamic>?;

          if (nodeErrors != null && nodeErrors.isNotEmpty) {
            final errorMessages = nodeErrors.entries
                .map((e) => '${e.key}: ${e.value}')
                .join(', ');
            return ApiResult.failure(
              'Node errors: $errorMessages',
              statusCode: response.statusCode,
            );
          }

          return ApiResult.failure(
            error ?? 'Failed to queue prompt',
            statusCode: response.statusCode,
          );
        } catch (_) {
          return ApiResult.failure(
            'Failed to queue prompt: ${response.statusCode}',
            statusCode: response.statusCode,
          );
        }
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  /// Queue a workflow from ComfyGraph.
  Future<ApiResult<String>> queueWorkflow(
    ComfyGraph graph, {
    String? clientId,
    bool front = false,
  }) async {
    final serializer = ApiPromptSerializer();
    final request = serializer.toApiRequest(graph, clientId: clientId);
    final workflow = request['prompt'] as Map<String, dynamic>;
    return queuePrompt(workflow, clientId: clientId, front: front);
  }

  /// Get queue status.
  Future<ApiResult<QueueInfo>> getQueue() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/queue'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResult.success(QueueInfo.fromJson(json));
      } else {
        return ApiResult.failure(
          'Failed to get queue: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  /// Delete items from queue.
  Future<ApiResult<void>> deleteQueueItems({
    bool all = false,
    List<String>? promptIds,
  }) async {
    try {
      final body = <String, dynamic>{};

      if (all) {
        body['clear'] = true;
      } else if (promptIds != null && promptIds.isNotEmpty) {
        body['delete'] = promptIds;
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/queue'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return ApiResult.success(null);
      } else {
        return ApiResult.failure(
          'Failed to delete queue items: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  /// Interrupt current execution.
  Future<ApiResult<void>> interrupt() async {
    try {
      final response = await _client.post(Uri.parse('$baseUrl/interrupt'));

      if (response.statusCode == 200) {
        return ApiResult.success(null);
      } else {
        return ApiResult.failure(
          'Failed to interrupt: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  /// Get execution history.
  Future<ApiResult<Map<String, HistoryEntry>>> getHistory({
    int? maxItems,
    String? promptId,
  }) async {
    try {
      var url = '$baseUrl/history';
      if (promptId != null) {
        url += '/$promptId';
      } else if (maxItems != null) {
        url += '?max_items=$maxItems';
      }

      final response = await _client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final history = <String, HistoryEntry>{};

        for (final entry in json.entries) {
          history[entry.key] = HistoryEntry.fromJson(
            entry.key,
            entry.value as Map<String, dynamic>,
          );
        }

        return ApiResult.success(history);
      } else {
        return ApiResult.failure(
          'Failed to get history: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  /// Get image from server.
  Future<ApiResult<Uint8List>> getImage(
    String filename, {
    String subfolder = '',
    String type = 'output',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/view').replace(
        queryParameters: {
          'filename': filename,
          'subfolder': subfolder,
          'type': type,
        },
      );

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        return ApiResult.success(response.bodyBytes);
      } else {
        return ApiResult.failure(
          'Failed to get image: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  /// Build image URL.
  String getImageUrl(
    String filename, {
    String subfolder = '',
    String type = 'output',
  }) {
    return '$baseUrl/view?filename=$filename&subfolder=$subfolder&type=$type';
  }

  /// Upload an image.
  Future<ApiResult<Map<String, dynamic>>> uploadImage(
    Uint8List imageData,
    String filename, {
    String subfolder = '',
    String type = 'input',
    bool overwrite = false,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/image'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageData,
          filename: filename,
        ),
      );

      if (subfolder.isNotEmpty) {
        request.fields['subfolder'] = subfolder;
      }
      request.fields['type'] = type;
      request.fields['overwrite'] = overwrite.toString();

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResult.success(json);
      } else {
        return ApiResult.failure(
          'Failed to upload image: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  /// Upload a mask.
  Future<ApiResult<Map<String, dynamic>>> uploadMask(
    Uint8List maskData,
    String filename,
    String originalRef, {
    String subfolder = '',
    String type = 'input',
    bool overwrite = false,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/mask'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          maskData,
          filename: filename,
        ),
      );

      request.fields['original_ref'] = originalRef;
      if (subfolder.isNotEmpty) {
        request.fields['subfolder'] = subfolder;
      }
      request.fields['type'] = type;
      request.fields['overwrite'] = overwrite.toString();

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResult.success(json);
      } else {
        return ApiResult.failure(
          'Failed to upload mask: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  /// Get system stats.
  Future<ApiResult<SystemStats>> getSystemStats() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/system_stats'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResult.success(SystemStats.fromJson(json));
      } else {
        return ApiResult.failure(
          'Failed to get system stats: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  /// Get embeddings list.
  Future<ApiResult<List<String>>> getEmbeddings() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/embeddings'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List;
        return ApiResult.success(json.cast<String>());
      } else {
        return ApiResult.failure(
          'Failed to get embeddings: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  /// Get extensions list.
  Future<ApiResult<List<String>>> getExtensions() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/extensions'));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List;
        return ApiResult.success(json.cast<String>());
      } else {
        return ApiResult.failure(
          'Failed to get extensions: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  /// Free VRAM/memory.
  Future<ApiResult<void>> freeMemory({
    bool unloadModels = false,
    bool freeMemory = false,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/free'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'unload_models': unloadModels,
          'free_memory': freeMemory,
        }),
      );

      if (response.statusCode == 200) {
        return ApiResult.success(null);
      } else {
        return ApiResult.failure(
          'Failed to free memory: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResult.failure('Network error: $e');
    }
  }

  /// Dispose of resources.
  void dispose() {
    _client.close();
  }
}
