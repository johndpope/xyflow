/// WebSocket Service - Manages WebSocket connection to ComfyUI backend.
///
/// Handles connection lifecycle, automatic reconnection, and message parsing.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Connection state for WebSocket.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Types of messages from ComfyUI WebSocket.
enum ComfyMessageType {
  status,
  executionStart,
  executionCached,
  executing,
  progress,
  executed,
  executionError,
  executionInterrupted,
  crystools, // Progress from crystools extension
  unknown,
}

/// Parsed message from ComfyUI WebSocket.
class ComfyMessage {
  /// Message type.
  final ComfyMessageType type;

  /// Raw message data.
  final Map<String, dynamic> data;

  /// Prompt ID if applicable.
  final String? promptId;

  /// Node ID if applicable.
  final String? nodeId;

  const ComfyMessage({
    required this.type,
    required this.data,
    this.promptId,
    this.nodeId,
  });

  @override
  String toString() => 'ComfyMessage($type, promptId: $promptId, nodeId: $nodeId)';
}

/// Status message data.
class StatusData {
  /// Queue remaining count.
  final int queueRemaining;

  /// Execution info if available.
  final Map<String, dynamic>? execInfo;

  const StatusData({
    required this.queueRemaining,
    this.execInfo,
  });

  factory StatusData.fromJson(Map<String, dynamic> json) {
    final status = json['status'] as Map<String, dynamic>?;
    return StatusData(
      queueRemaining: (status?['exec_info']?['queue_remaining'] as int?) ?? 0,
      execInfo: status?['exec_info'] as Map<String, dynamic>?,
    );
  }
}

/// Progress message data.
class ProgressData {
  /// Current step.
  final int value;

  /// Maximum steps.
  final int max;

  /// Prompt ID.
  final String? promptId;

  /// Node ID being executed.
  final String? nodeId;

  const ProgressData({
    required this.value,
    required this.max,
    this.promptId,
    this.nodeId,
  });

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return ProgressData(
      value: (data?['value'] as int?) ?? 0,
      max: (data?['max'] as int?) ?? 1,
      promptId: data?['prompt_id'] as String?,
      nodeId: data?['node'] as String?,
    );
  }

  /// Progress as fraction (0.0 to 1.0).
  double get progress => max > 0 ? value / max : 0.0;
}

/// Execution output data (images, etc).
class ExecutedData {
  /// Node ID that produced output.
  final String nodeId;

  /// Output data by type.
  final Map<String, dynamic> output;

  /// Prompt ID.
  final String? promptId;

  const ExecutedData({
    required this.nodeId,
    required this.output,
    this.promptId,
  });

  factory ExecutedData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return ExecutedData(
      nodeId: (data?['node'] as String?) ?? '',
      output: (data?['output'] as Map<String, dynamic>?) ?? {},
      promptId: data?['prompt_id'] as String?,
    );
  }

  /// Get images from output if present.
  List<Map<String, dynamic>> get images {
    final imgs = output['images'];
    if (imgs is List) {
      return imgs.cast<Map<String, dynamic>>();
    }
    return [];
  }
}

/// Error data from execution.
class ExecutionErrorData {
  /// Error message.
  final String message;

  /// Error details.
  final Map<String, dynamic>? details;

  /// Node ID that caused error.
  final String? nodeId;

  /// Node type that caused error.
  final String? nodeType;

  /// Exception message.
  final String? exceptionMessage;

  /// Exception type.
  final String? exceptionType;

  /// Traceback.
  final List<String>? traceback;

  const ExecutionErrorData({
    required this.message,
    this.details,
    this.nodeId,
    this.nodeType,
    this.exceptionMessage,
    this.exceptionType,
    this.traceback,
  });

  factory ExecutionErrorData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final exceptionMessage = data?['exception_message'] as String?;
    final nodeId = data?['node_id'] as String?;
    final nodeType = data?['node_type'] as String?;

    return ExecutionErrorData(
      message: exceptionMessage ?? 'Unknown error',
      details: data,
      nodeId: nodeId,
      nodeType: nodeType,
      exceptionMessage: exceptionMessage,
      exceptionType: data?['exception_type'] as String?,
      traceback: (data?['traceback'] as List?)?.cast<String>(),
    );
  }

  @override
  String toString() {
    if (nodeType != null && nodeId != null) {
      return 'Error in $nodeType ($nodeId): $message';
    }
    return message;
  }
}

/// WebSocket service for ComfyUI communication.
class ComfyWebSocketService {
  /// Base URL for WebSocket connection.
  final String baseUrl;

  /// Client ID for this session.
  final String clientId;

  /// Maximum reconnection attempts.
  final int maxReconnectAttempts;

  /// Base delay between reconnection attempts (doubles each attempt).
  final Duration reconnectDelay;

  WebSocket? _socket;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;

  /// Current connection state.
  ConnectionState _state = ConnectionState.disconnected;
  ConnectionState get state => _state;

  /// Stream controller for connection state changes.
  final _stateController = StreamController<ConnectionState>.broadcast();
  Stream<ConnectionState> get stateStream => _stateController.stream;

  /// Stream controller for parsed messages.
  final _messageController = StreamController<ComfyMessage>.broadcast();
  Stream<ComfyMessage> get messageStream => _messageController.stream;

  /// Stream controller for binary data (image previews).
  final _binaryController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get binaryStream => _binaryController.stream;

  /// Stream controller for raw messages (for debugging).
  final _rawMessageController = StreamController<String>.broadcast();
  Stream<String> get rawMessageStream => _rawMessageController.stream;

  /// Stream controller for errors.
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  /// Whether currently connected.
  bool get isConnected => _state == ConnectionState.connected;

  ComfyWebSocketService({
    required this.baseUrl,
    required this.clientId,
    this.maxReconnectAttempts = 10,
    this.reconnectDelay = const Duration(seconds: 1),
  });

  /// Build WebSocket URL.
  String get _wsUrl {
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$wsScheme://${uri.host}:${uri.port}/ws?clientId=$clientId';
  }

  /// Connect to WebSocket.
  Future<void> connect() async {
    if (_state == ConnectionState.connected ||
        _state == ConnectionState.connecting) {
      return;
    }

    _setState(ConnectionState.connecting);
    _reconnectAttempts = 0;

    try {
      await _doConnect();
    } catch (e) {
      _handleError('Connection failed: $e');
      _scheduleReconnect();
    }
  }

  Future<void> _doConnect() async {
    _socket = await WebSocket.connect(_wsUrl);
    _setState(ConnectionState.connected);
    _reconnectAttempts = 0;

    _subscription = _socket!.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );

    // Start ping timer to keep connection alive
    _startPingTimer();
  }

  /// Disconnect from WebSocket.
  Future<void> disconnect() async {
    _stopPingTimer();
    _cancelReconnect();

    await _subscription?.cancel();
    _subscription = null;

    await _socket?.close();
    _socket = null;

    _setState(ConnectionState.disconnected);
  }

  /// Send a message to the server.
  void send(Map<String, dynamic> message) {
    if (_socket != null && _state == ConnectionState.connected) {
      _socket!.add(jsonEncode(message));
    }
  }

  /// Send raw string message.
  void sendRaw(String message) {
    if (_socket != null && _state == ConnectionState.connected) {
      _socket!.add(message);
    }
  }

  void _onMessage(dynamic message) {
    if (message is String) {
      _rawMessageController.add(message);
      _parseMessage(message);
    } else if (message is List<int>) {
      // Binary message (image preview)
      _binaryController.add(Uint8List.fromList(message));
    }
  }

  void _parseMessage(String message) {
    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final data = json['data'] as Map<String, dynamic>? ?? {};

      final msgType = _parseMessageType(type);
      final promptId = data['prompt_id'] as String?;
      final nodeId = data['node'] as String?;

      final comfyMessage = ComfyMessage(
        type: msgType,
        data: json,
        promptId: promptId,
        nodeId: nodeId,
      );

      _messageController.add(comfyMessage);
    } catch (e) {
      _errorController.add('Failed to parse message: $e');
    }
  }

  ComfyMessageType _parseMessageType(String? type) {
    switch (type) {
      case 'status':
        return ComfyMessageType.status;
      case 'execution_start':
        return ComfyMessageType.executionStart;
      case 'execution_cached':
        return ComfyMessageType.executionCached;
      case 'executing':
        return ComfyMessageType.executing;
      case 'progress':
        return ComfyMessageType.progress;
      case 'executed':
        return ComfyMessageType.executed;
      case 'execution_error':
        return ComfyMessageType.executionError;
      case 'execution_interrupted':
        return ComfyMessageType.executionInterrupted;
      case 'crystools.monitor':
        return ComfyMessageType.crystools;
      default:
        return ComfyMessageType.unknown;
    }
  }

  void _onError(dynamic error) {
    _handleError('WebSocket error: $error');
    _scheduleReconnect();
  }

  void _onDone() {
    _stopPingTimer();
    if (_state != ConnectionState.disconnected) {
      _handleError('Connection closed');
      _scheduleReconnect();
    }
  }

  void _handleError(String error) {
    _errorController.add(error);
    _setState(ConnectionState.error);
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      _errorController.add('Max reconnection attempts reached');
      _setState(ConnectionState.disconnected);
      return;
    }

    _cancelReconnect();
    _setState(ConnectionState.reconnecting);

    // Exponential backoff
    final delay = reconnectDelay * (1 << _reconnectAttempts);
    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, () async {
      try {
        await _doConnect();
      } catch (e) {
        _handleError('Reconnection failed: $e');
        _scheduleReconnect();
      }
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _startPingTimer() {
    _stopPingTimer();
    // Send ping every 30 seconds to keep connection alive
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_socket != null && _state == ConnectionState.connected) {
        try {
          _socket!.add('{"type": "ping"}');
        } catch (_) {
          // Ignore ping errors
        }
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _setState(ConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  /// Dispose of resources.
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _messageController.close();
    await _binaryController.close();
    await _rawMessageController.close();
    await _errorController.close();
  }
}

/// Extension methods for ComfyMessage.
extension ComfyMessageExtensions on ComfyMessage {
  /// Parse as status data.
  StatusData? get statusData {
    if (type == ComfyMessageType.status) {
      return StatusData.fromJson(data);
    }
    return null;
  }

  /// Parse as progress data.
  ProgressData? get progressData {
    if (type == ComfyMessageType.progress) {
      return ProgressData.fromJson(data);
    }
    return null;
  }

  /// Parse as executed data.
  ExecutedData? get executedData {
    if (type == ComfyMessageType.executed) {
      return ExecutedData.fromJson(data);
    }
    return null;
  }

  /// Parse as error data.
  ExecutionErrorData? get errorData {
    if (type == ComfyMessageType.executionError) {
      return ExecutionErrorData.fromJson(data);
    }
    return null;
  }

  /// Check if this is the start of execution for a prompt.
  bool get isExecutionStart => type == ComfyMessageType.executionStart;

  /// Check if execution completed.
  bool get isExecutionComplete {
    // Execution is complete when we get an 'executing' message with null node
    if (type == ComfyMessageType.executing) {
      final nodeData = data['data'] as Map<String, dynamic>?;
      return nodeData?['node'] == null;
    }
    return false;
  }

  /// Check if this indicates an error.
  bool get isError => type == ComfyMessageType.executionError;

  /// Check if execution was interrupted.
  bool get isInterrupted => type == ComfyMessageType.executionInterrupted;
}
