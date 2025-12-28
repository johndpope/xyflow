/// ComfyUI slot types - defines the data types that flow between nodes.
///
/// Each slot type has a specific color for visual identification
/// and rules for what it can connect to.
library;

import 'package:flutter/material.dart';

/// The type of data that flows through a slot connection.
enum SlotType {
  /// Accepts any type - universal connector
  any('*', Color(0xFF666666)),

  /// Machine learning model (UNet, etc.)
  model('MODEL', Color(0xFFB39DDB)),

  /// CLIP text encoder model
  clip('CLIP', Color(0xFFFFD54F)),

  /// VAE encoder/decoder model
  vae('VAE', Color(0xFFFF8A80)),

  /// Text conditioning (positive/negative prompts)
  conditioning('CONDITIONING', Color(0xFFFFAB40)),

  /// Latent image representation
  latent('LATENT', Color(0xFFFF80AB)),

  /// RGB image data
  image('IMAGE', Color(0xFF64B5F6)),

  /// Binary mask
  mask('MASK', Color(0xFFFFFFFF)),

  /// Integer value
  int_('INT', Color(0xFF81C784)),

  /// Floating point value
  float_('FLOAT', Color(0xFF81C784)),

  /// Text string
  string('STRING', Color(0xFF4FC3F7)),

  /// Boolean true/false
  boolean('BOOLEAN', Color(0xFFA5D6A7)),

  /// Dropdown selection from options
  combo('COMBO', Color(0xFFCE93D8)),

  /// Control net model
  controlNet('CONTROL_NET', Color(0xFF26A69A)),

  /// LoRA model
  lora('LORA', Color(0xFFFFCA28)),

  /// Upscale model
  upscaleModel('UPSCALE_MODEL', Color(0xFFEF5350)),

  /// CLIP vision model
  clipVision('CLIP_VISION', Color(0xFFAB47BC)),

  /// Style model
  styleModel('STYLE_MODEL', Color(0xFF7E57C2)),

  /// GLIGEN model
  gligen('GLIGEN', Color(0xFF29B6F6)),

  /// Sampler name
  sampler('SAMPLER', Color(0xFF66BB6A)),

  /// Scheduler name
  scheduler('SCHEDULER', Color(0xFF42A5F5)),

  /// Sigmas for sampling
  sigmas('SIGMAS', Color(0xFFEC407A)),

  /// Noise
  noise('NOISE', Color(0xFF8D6E63)),

  /// Guider
  guider('GUIDER', Color(0xFF78909C)),

  /// Audio data
  audio('AUDIO', Color(0xFF26C6DA)),

  /// Video data
  video('VIDEO', Color(0xFFD4E157));

  const SlotType(this.typeName, this.color);

  /// The string name used in ComfyUI API
  final String typeName;

  /// The color used to render this slot type
  final Color color;

  /// Parse a type name from ComfyUI API
  static SlotType fromTypeName(String name) {
    return SlotType.values.firstWhere(
      (t) => t.typeName == name,
      orElse: () => SlotType.any,
    );
  }

  /// Check if this type can connect to another type
  bool canConnectTo(SlotType other) {
    if (this == SlotType.any || other == SlotType.any) {
      return true;
    }
    return this == other;
  }
}

/// Definition of an input or output slot on a node.
class SlotDefinition {
  /// The name of the slot (e.g., "model", "positive", "image")
  final String name;

  /// The data type of the slot
  final SlotType type;

  /// Whether this input is optional (can be left unconnected)
  final bool isOptional;

  /// Default value when not connected (for inputs)
  final dynamic defaultValue;

  /// For combo type: the available options
  final List<String>? comboOptions;

  /// Minimum value (for int/float)
  final num? min;

  /// Maximum value (for int/float)
  final num? max;

  /// Step size (for int/float)
  final num? step;

  /// Whether this is a multi-line string input
  final bool multiline;

  /// Tooltip/description
  final String? tooltip;

  /// Additional configuration from API
  final Map<String, dynamic>? config;

  const SlotDefinition({
    required this.name,
    required this.type,
    this.isOptional = false,
    this.defaultValue,
    this.comboOptions,
    this.min,
    this.max,
    this.step,
    this.multiline = false,
    this.tooltip,
    this.config,
  });

  /// Create from ComfyUI API response
  factory SlotDefinition.fromApi(String name, dynamic typeData) {
    if (typeData is String) {
      // Simple type: "MODEL", "IMAGE", etc.
      return SlotDefinition(
        name: name,
        type: SlotType.fromTypeName(typeData),
      );
    }

    if (typeData is List && typeData.isNotEmpty) {
      final first = typeData[0];

      // Combo type: [["option1", "option2", ...]]
      if (first is List) {
        return SlotDefinition(
          name: name,
          type: SlotType.combo,
          comboOptions: first.cast<String>(),
          defaultValue: first.isNotEmpty ? first[0] : null,
        );
      }

      // Type with config: ["INT", {min: 0, max: 100, ...}]
      if (first is String) {
        final type = SlotType.fromTypeName(first);
        // Cast safely - API may return _Map<dynamic, dynamic>
        Map<String, dynamic>? config;
        if (typeData.length > 1 && typeData[1] is Map) {
          final rawConfig = typeData[1] as Map;
          config = rawConfig.cast<String, dynamic>();
        }

        return SlotDefinition(
          name: name,
          type: type,
          defaultValue: config?['default'],
          min: config?['min'] as num?,
          max: config?['max'] as num?,
          step: config?['step'] as num?,
          multiline: config?['multiline'] == true,
          config: config,
        );
      }
    }

    // Fallback
    return SlotDefinition(
      name: name,
      type: SlotType.any,
    );
  }

  SlotDefinition copyWith({
    String? name,
    SlotType? type,
    bool? isOptional,
    dynamic defaultValue,
    List<String>? comboOptions,
    num? min,
    num? max,
    num? step,
    bool? multiline,
    String? tooltip,
    Map<String, dynamic>? config,
  }) {
    return SlotDefinition(
      name: name ?? this.name,
      type: type ?? this.type,
      isOptional: isOptional ?? this.isOptional,
      defaultValue: defaultValue ?? this.defaultValue,
      comboOptions: comboOptions ?? this.comboOptions,
      min: min ?? this.min,
      max: max ?? this.max,
      step: step ?? this.step,
      multiline: multiline ?? this.multiline,
      tooltip: tooltip ?? this.tooltip,
      config: config ?? this.config,
    );
  }
}
