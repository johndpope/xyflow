/// Connection Provider - Manages WebSocket connection state with Riverpod.
///
/// Integrates WebSocket service with execution state management.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/websocket_service.dart';
import 'execution_provider.dart';

/// Configuration for ComfyUI connection.
class ConnectionConfig {
  /// Server host (e.g., 'localhost' or '192.168.1.100').
  final String host;

  /// Server port (default 8188).
  final int port;

  /// Whether to use HTTPS/WSS.
  final bool useSSL;

  /// Client ID for this session.
  final String clientId;

  const ConnectionConfig({
    this.host = 'localhost',
    this.port = 8188,
    this.useSSL = false,
    required this.clientId,
  });

  /// Build base URL for HTTP requests.
  String get baseUrl {
    final scheme = useSSL ? 'https' : 'http';
    return '$scheme://$host:$port';
  }

  ConnectionConfig copyWith({
    String? host,
    int? port,
    bool? useSSL,
    String? clientId,
  }) {
    return ConnectionConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      useSSL: useSSL ?? this.useSSL,
      clientId: clientId ?? this.clientId,
    );
  }
}

/// State for connection management.
class ConnectionNotifierState {
  /// Current connection state.
  final ConnectionState state;

  /// Connection configuration.
  final ConnectionConfig config;

  /// Last error message.
  final String? error;

  /// Reconnection attempt count.
  final int reconnectAttempts;

  const ConnectionNotifierState({
    this.state = ConnectionState.disconnected,
    required this.config,
    this.error,
    this.reconnectAttempts = 0,
  });

  /// Whether connected.
  bool get isConnected => state == ConnectionState.connected;

  /// Whether currently connecting or reconnecting.
  bool get isConnecting =>
      state == ConnectionState.connecting ||
      state == ConnectionState.reconnecting;

  /// Whether has error.
  bool get hasError => error != null;

  ConnectionNotifierState copyWith({
    ConnectionState? state,
    ConnectionConfig? config,
    String? error,
    int? reconnectAttempts,
    bool clearError = false,
  }) {
    return ConnectionNotifierState(
      state: state ?? this.state,
      config: config ?? this.config,
      error: clearError ? null : (error ?? this.error),
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
    );
  }
}

/// Notifier for connection state.
class ConnectionNotifier extends StateNotifier<ConnectionNotifierState> {
  final Ref _ref;
  ComfyWebSocketService? _wsService;
  StreamSubscription? _stateSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _errorSubscription;

  ConnectionNotifier(this._ref, ConnectionConfig config)
      : super(ConnectionNotifierState(config: config));

  /// Get WebSocket service.
  ComfyWebSocketService? get wsService => _wsService;

  /// Connect to ComfyUI server.
  Future<void> connect() async {
    if (_wsService != null) {
      await disconnect();
    }

    _wsService = ComfyWebSocketService(
      baseUrl: state.config.baseUrl,
      clientId: state.config.clientId,
    );

    _setupSubscriptions();

    await _wsService!.connect();
  }

  /// Disconnect from server.
  Future<void> disconnect() async {
    await _stateSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _errorSubscription?.cancel();
    _stateSubscription = null;
    _messageSubscription = null;
    _errorSubscription = null;

    await _wsService?.dispose();
    _wsService = null;

    state = state.copyWith(
      state: ConnectionState.disconnected,
      clearError: true,
    );
  }

  /// Update connection configuration.
  void updateConfig(ConnectionConfig config) {
    state = state.copyWith(config: config);
  }

  void _setupSubscriptions() {
    if (_wsService == null) return;

    // Listen to connection state changes
    _stateSubscription = _wsService!.stateStream.listen((wsState) {
      state = state.copyWith(state: wsState);

      // Update execution provider connection status
      _ref.read(executionProvider.notifier).setConnected(
            wsState == ConnectionState.connected,
          );
    });

    // Listen to messages and route to execution provider
    _messageSubscription = _wsService!.messageStream.listen(_handleMessage);

    // Listen to errors
    _errorSubscription = _wsService!.errorStream.listen((error) {
      state = state.copyWith(error: error);
    });
  }

  void _handleMessage(ComfyMessage message) {
    final executionNotifier = _ref.read(executionProvider.notifier);

    switch (message.type) {
      case ComfyMessageType.status:
        // Update queue status
        final statusData = message.statusData;
        if (statusData != null) {
          // Queue status update could be handled here
        }

      case ComfyMessageType.executionStart:
        // Execution starting
        if (message.promptId != null) {
          executionNotifier.startExecution(message.promptId!);
        }
        executionNotifier.setExecuting();

      case ComfyMessageType.executing:
        // Node is being executed
        if (message.isExecutionComplete) {
          // Execution completed (node is null)
          executionNotifier.completeExecution();
        } else if (message.nodeId != null) {
          // Update current executing node
          executionNotifier.updateProgress(
            nodeId: message.nodeId,
          );
        }

      case ComfyMessageType.progress:
        // Step progress update
        final progressData = message.progressData;
        if (progressData != null) {
          executionNotifier.updateProgress(
            nodeId: progressData.nodeId,
            currentStep: progressData.value,
            totalSteps: progressData.max,
          );
        }

      case ComfyMessageType.executed:
        // Node produced output
        final executedData = message.executedData;
        if (executedData != null) {
          // Handle output images
          for (final image in executedData.images) {
            final filename = image['filename'] as String?;
            final subfolder = image['subfolder'] as String? ?? '';
            final type = image['type'] as String? ?? 'output';

            if (filename != null) {
              // Build image URL
              final imageUrl =
                  '${state.config.baseUrl}/view?filename=$filename&subfolder=$subfolder&type=$type';
              executionNotifier.addPreview(
                executedData.nodeId,
                imageUrl,
                isUrl: true,
              );
            }
          }
        }

      case ComfyMessageType.executionError:
        // Execution error
        final errorData = message.errorData;
        executionNotifier.setError(errorData?.toString() ?? 'Unknown error');

      case ComfyMessageType.executionInterrupted:
        // Execution was interrupted/cancelled
        executionNotifier.cancelExecution();

      case ComfyMessageType.executionCached:
        // Cached nodes - no need to re-execute
        break;

      case ComfyMessageType.crystools:
        // Progress from crystools extension - could show system stats
        break;

      case ComfyMessageType.unknown:
        // Unknown message type - ignore
        break;
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

/// Provider for connection configuration.
final connectionConfigProvider = StateProvider<ConnectionConfig>((ref) {
  // Generate a unique client ID
  final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
  return ConnectionConfig(clientId: clientId);
});

/// Provider for connection notifier.
final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionNotifierState>((ref) {
  final config = ref.watch(connectionConfigProvider);
  return ConnectionNotifier(ref, config);
});

/// Provider for connection state.
final connectionStateProvider = Provider<ConnectionState>((ref) {
  return ref.watch(connectionProvider).state;
});

/// Provider for whether connected.
final isConnectedToServerProvider = Provider<bool>((ref) {
  return ref.watch(connectionProvider).isConnected;
});

/// Provider for connection error.
final connectionErrorProvider = Provider<String?>((ref) {
  return ref.watch(connectionProvider).error;
});

/// Provider for server base URL.
final serverBaseUrlProvider = Provider<String>((ref) {
  return ref.watch(connectionProvider).config.baseUrl;
});
