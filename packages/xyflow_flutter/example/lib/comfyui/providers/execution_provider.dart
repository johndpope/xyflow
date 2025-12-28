/// Execution Provider - Manages execution state for ComfyUI workflows.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Execution status enum.
enum ExecutionStatus {
  idle,
  queued,
  executing,
  completed,
  error,
  cancelled,
}

/// Progress information for current execution.
class ExecutionProgress {
  /// Current node being executed.
  final String? currentNodeId;

  /// Current step in the node.
  final int currentStep;

  /// Total steps for current node.
  final int totalSteps;

  /// Overall progress (0.0 to 1.0).
  final double overallProgress;

  /// Current node title (for display).
  final String? currentNodeTitle;

  const ExecutionProgress({
    this.currentNodeId,
    this.currentStep = 0,
    this.totalSteps = 0,
    this.overallProgress = 0.0,
    this.currentNodeTitle,
  });

  ExecutionProgress copyWith({
    String? currentNodeId,
    int? currentStep,
    int? totalSteps,
    double? overallProgress,
    String? currentNodeTitle,
  }) {
    return ExecutionProgress(
      currentNodeId: currentNodeId ?? this.currentNodeId,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      overallProgress: overallProgress ?? this.overallProgress,
      currentNodeTitle: currentNodeTitle ?? this.currentNodeTitle,
    );
  }

  /// Step progress as a fraction (0.0 to 1.0).
  double get stepProgress => totalSteps > 0 ? currentStep / totalSteps : 0.0;
}

/// Image preview from execution.
class ExecutionPreview {
  /// Node ID that generated this preview.
  final String nodeId;

  /// Image data (base64 or URL).
  final String imageData;

  /// Whether this is a URL or base64 data.
  final bool isUrl;

  /// Timestamp when preview was received.
  final DateTime timestamp;

  const ExecutionPreview({
    required this.nodeId,
    required this.imageData,
    this.isUrl = false,
    required this.timestamp,
  });
}

/// Queue item representing a pending execution.
class QueueItem {
  /// Unique prompt ID.
  final String promptId;

  /// Position in queue (1-based).
  final int position;

  /// Timestamp when queued.
  final DateTime queuedAt;

  const QueueItem({
    required this.promptId,
    required this.position,
    required this.queuedAt,
  });
}

/// State for execution.
class ExecutionState {
  /// Current execution status.
  final ExecutionStatus status;

  /// Current prompt ID (if executing).
  final String? promptId;

  /// Execution progress.
  final ExecutionProgress progress;

  /// Error message if execution failed.
  final String? error;

  /// Image previews generated during execution.
  final List<ExecutionPreview> previews;

  /// Queue status.
  final List<QueueItem> queue;

  /// Whether connected to ComfyUI backend.
  final bool isConnected;

  /// Last execution time in milliseconds.
  final int? lastExecutionTime;

  const ExecutionState({
    this.status = ExecutionStatus.idle,
    this.promptId,
    this.progress = const ExecutionProgress(),
    this.error,
    this.previews = const [],
    this.queue = const [],
    this.isConnected = false,
    this.lastExecutionTime,
  });

  /// Whether currently executing.
  bool get isExecuting => status == ExecutionStatus.executing;

  /// Whether in queue.
  bool get isQueued => status == ExecutionStatus.queued;

  /// Whether idle (not executing or queued).
  bool get isIdle => status == ExecutionStatus.idle;

  /// Whether has error.
  bool get hasError => status == ExecutionStatus.error && error != null;

  /// Queue position (0 if not in queue).
  int get queuePosition {
    if (promptId == null) return 0;
    final item = queue.where((q) => q.promptId == promptId).firstOrNull;
    return item?.position ?? 0;
  }

  ExecutionState copyWith({
    ExecutionStatus? status,
    String? promptId,
    ExecutionProgress? progress,
    String? error,
    List<ExecutionPreview>? previews,
    List<QueueItem>? queue,
    bool? isConnected,
    int? lastExecutionTime,
    bool clearError = false,
    bool clearPromptId = false,
  }) {
    return ExecutionState(
      status: status ?? this.status,
      promptId: clearPromptId ? null : (promptId ?? this.promptId),
      progress: progress ?? this.progress,
      error: clearError ? null : (error ?? this.error),
      previews: previews ?? this.previews,
      queue: queue ?? this.queue,
      isConnected: isConnected ?? this.isConnected,
      lastExecutionTime: lastExecutionTime ?? this.lastExecutionTime,
    );
  }
}

/// Notifier for execution state.
class ExecutionNotifier extends StateNotifier<ExecutionState> {
  ExecutionNotifier() : super(const ExecutionState());

  DateTime? _executionStartTime;

  /// Start execution with a prompt ID.
  void startExecution(String promptId) {
    _executionStartTime = DateTime.now();
    state = state.copyWith(
      status: ExecutionStatus.queued,
      promptId: promptId,
      progress: const ExecutionProgress(),
      clearError: true,
    );
  }

  /// Update to executing status (execution has started).
  void setExecuting() {
    state = state.copyWith(status: ExecutionStatus.executing);
  }

  /// Update execution progress.
  void updateProgress({
    String? nodeId,
    int? currentStep,
    int? totalSteps,
    double? overallProgress,
    String? nodeTitle,
  }) {
    state = state.copyWith(
      status: ExecutionStatus.executing,
      progress: state.progress.copyWith(
        currentNodeId: nodeId,
        currentStep: currentStep,
        totalSteps: totalSteps,
        overallProgress: overallProgress,
        currentNodeTitle: nodeTitle,
      ),
    );
  }

  /// Complete execution successfully.
  void completeExecution() {
    final executionTime = _executionStartTime != null
        ? DateTime.now().difference(_executionStartTime!).inMilliseconds
        : null;
    _executionStartTime = null;

    state = state.copyWith(
      status: ExecutionStatus.completed,
      progress: state.progress.copyWith(overallProgress: 1.0),
      lastExecutionTime: executionTime,
    );
  }

  /// Set execution error.
  void setError(String error) {
    _executionStartTime = null;
    state = state.copyWith(
      status: ExecutionStatus.error,
      error: error,
    );
  }

  /// Cancel current execution.
  void cancelExecution() {
    _executionStartTime = null;
    state = state.copyWith(
      status: ExecutionStatus.cancelled,
      clearPromptId: true,
    );
  }

  /// Reset to idle state.
  void reset() {
    _executionStartTime = null;
    state = state.copyWith(
      status: ExecutionStatus.idle,
      progress: const ExecutionProgress(),
      clearError: true,
      clearPromptId: true,
    );
  }

  /// Add image preview.
  void addPreview(String nodeId, String imageData, {bool isUrl = false}) {
    final preview = ExecutionPreview(
      nodeId: nodeId,
      imageData: imageData,
      isUrl: isUrl,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(previews: [...state.previews, preview]);
  }

  /// Clear all previews.
  void clearPreviews() {
    state = state.copyWith(previews: []);
  }

  /// Update queue status.
  void updateQueue(List<QueueItem> queue) {
    state = state.copyWith(queue: queue);
  }

  /// Set connection status.
  void setConnected(bool connected) {
    state = state.copyWith(isConnected: connected);
    if (!connected && state.isExecuting) {
      setError('Connection lost');
    }
  }

  /// Get previews for a specific node.
  List<ExecutionPreview> getPreviewsForNode(String nodeId) {
    return state.previews.where((p) => p.nodeId == nodeId).toList();
  }

  /// Get the latest preview for a node.
  ExecutionPreview? getLatestPreviewForNode(String nodeId) {
    final nodesPreviews = getPreviewsForNode(nodeId);
    return nodesPreviews.isNotEmpty ? nodesPreviews.last : null;
  }
}

/// Provider for execution state.
final executionProvider =
    StateNotifierProvider<ExecutionNotifier, ExecutionState>((ref) {
  return ExecutionNotifier();
});

/// Provider for execution status.
final executionStatusProvider = Provider<ExecutionStatus>((ref) {
  return ref.watch(executionProvider).status;
});

/// Provider for execution progress.
final executionProgressProvider = Provider<ExecutionProgress>((ref) {
  return ref.watch(executionProvider).progress;
});

/// Provider for whether currently executing.
final isExecutingProvider = Provider<bool>((ref) {
  return ref.watch(executionProvider).isExecuting;
});

/// Provider for connection status.
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(executionProvider).isConnected;
});

/// Provider for execution error.
final executionErrorProvider = Provider<String?>((ref) {
  return ref.watch(executionProvider).error;
});

/// Provider for image previews.
final previewsProvider = Provider<List<ExecutionPreview>>((ref) {
  return ref.watch(executionProvider).previews;
});

/// Provider for previews of a specific node.
final nodePreviewsProvider =
    Provider.family<List<ExecutionPreview>, String>((ref, nodeId) {
  return ref
      .watch(executionProvider)
      .previews
      .where((p) => p.nodeId == nodeId)
      .toList();
});

/// Provider for the current executing node ID.
final currentExecutingNodeProvider = Provider<String?>((ref) {
  return ref.watch(executionProvider).progress.currentNodeId;
});

/// Provider for queue items.
final queueProvider = Provider<List<QueueItem>>((ref) {
  return ref.watch(executionProvider).queue;
});

/// Provider for queue length.
final queueLengthProvider = Provider<int>((ref) {
  return ref.watch(executionProvider).queue.length;
});
