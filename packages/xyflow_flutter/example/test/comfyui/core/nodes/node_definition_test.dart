import 'package:flutter_test/flutter_test.dart';
import '../../../../lib/comfyui/core/nodes/node_definition.dart';
import '../../../../lib/comfyui/core/nodes/slot_types.dart';

void main() {
  group('NodeDefinition', () {
    test('creates basic node definition', () {
      final def = NodeDefinition(
        name: 'TestNode',
        displayName: 'Test Node',
        category: 'testing',
        inputs: [
          SlotDefinition(name: 'input1', type: SlotType.image),
        ],
        outputs: [
          SlotDefinition(name: 'output1', type: SlotType.image),
        ],
      );

      expect(def.name, 'TestNode');
      expect(def.displayName, 'Test Node');
      expect(def.category, 'testing');
      expect(def.inputs.length, 1);
      expect(def.outputs.length, 1);
    });

    test('inputNames returns all input slot names', () {
      final def = NodeDefinition(
        name: 'TestNode',
        displayName: 'Test Node',
        category: 'testing',
        inputs: [
          SlotDefinition(name: 'model', type: SlotType.model),
          SlotDefinition(name: 'positive', type: SlotType.conditioning),
          SlotDefinition(name: 'negative', type: SlotType.conditioning),
        ],
        outputs: [],
      );

      expect(def.inputNames, ['model', 'positive', 'negative']);
    });

    test('outputNames returns all output slot names', () {
      final def = NodeDefinition(
        name: 'TestNode',
        displayName: 'Test Node',
        category: 'testing',
        inputs: [],
        outputs: [
          SlotDefinition(name: 'MODEL', type: SlotType.model),
          SlotDefinition(name: 'CLIP', type: SlotType.clip),
          SlotDefinition(name: 'VAE', type: SlotType.vae),
        ],
      );

      expect(def.outputNames, ['MODEL', 'CLIP', 'VAE']);
    });

    test('getInput finds slot by name', () {
      final def = NodeDefinition(
        name: 'TestNode',
        displayName: 'Test Node',
        category: 'testing',
        inputs: [
          SlotDefinition(name: 'model', type: SlotType.model),
          SlotDefinition(name: 'image', type: SlotType.image),
        ],
        outputs: [],
      );

      final slot = def.getInput('model');
      expect(slot, isNotNull);
      expect(slot!.type, SlotType.model);

      final missing = def.getInput('nonexistent');
      expect(missing, isNull);
    });

    test('getOutput finds slot by name', () {
      final def = NodeDefinition(
        name: 'TestNode',
        displayName: 'Test Node',
        category: 'testing',
        inputs: [],
        outputs: [
          SlotDefinition(name: 'IMAGE', type: SlotType.image),
        ],
      );

      final slot = def.getOutput('IMAGE');
      expect(slot, isNotNull);
      expect(slot!.type, SlotType.image);
    });

    test('getWidget finds widget by name', () {
      final def = NodeDefinition(
        name: 'TestNode',
        displayName: 'Test Node',
        category: 'testing',
        widgets: [
          WidgetDefinition(
            name: 'seed',
            type: WidgetType.int_,
            defaultValue: 0,
          ),
          WidgetDefinition(
            name: 'steps',
            type: WidgetType.int_,
            defaultValue: 20,
          ),
        ],
      );

      final widget = def.getWidget('steps');
      expect(widget, isNotNull);
      expect(widget!.defaultValue, 20);
    });

    group('fromApi', () {
      test('parses KSampler-like node', () {
        final apiData = {
          'input': {
            'required': {
              'model': 'MODEL',
              'positive': 'CONDITIONING',
              'negative': 'CONDITIONING',
              'latent_image': 'LATENT',
              'seed': ['INT', {'default': 0, 'min': 0, 'max': 0xffffffffffffffff}],
              'steps': ['INT', {'default': 20, 'min': 1, 'max': 10000}],
              'cfg': ['FLOAT', {'default': 8.0, 'min': 0.0, 'max': 100.0, 'step': 0.1}],
              'sampler_name': [['euler', 'euler_ancestral', 'heun', 'dpm_2']],
              'scheduler': [['normal', 'karras', 'exponential', 'sgm_uniform']],
              'denoise': ['FLOAT', {'default': 1.0, 'min': 0.0, 'max': 1.0, 'step': 0.01}],
            },
          },
          'output': ['LATENT'],
          'output_is_list': [false],
          'output_name': ['LATENT'],
          'name': 'KSampler',
          'display_name': 'K Sampler',
          'category': 'sampling',
        };

        final def = NodeDefinition.fromApi('KSampler', apiData);

        expect(def.name, 'KSampler');
        expect(def.displayName, 'K Sampler');
        expect(def.category, 'sampling');

        // Check inputs (complex types become slots)
        expect(def.inputs.length, 4); // model, positive, negative, latent_image
        expect(def.inputs.any((s) => s.name == 'model' && s.type == SlotType.model), true);
        expect(def.inputs.any((s) => s.name == 'positive' && s.type == SlotType.conditioning), true);

        // Check widgets (simple types become widgets)
        expect(def.widgets.length, 6); // seed, steps, cfg, sampler_name, scheduler, denoise
        expect(def.widgets.any((w) => w.name == 'seed'), true);
        expect(def.widgets.any((w) => w.name == 'steps'), true);
        expect(def.widgets.any((w) => w.name == 'sampler_name' && w.type == WidgetType.combo), true);

        // Check outputs
        expect(def.outputs.length, 1);
        expect(def.outputs[0].type, SlotType.latent);
      });

      test('parses CheckpointLoaderSimple-like node', () {
        final apiData = {
          'input': {
            'required': {
              'ckpt_name': [['model1.safetensors', 'model2.safetensors']],
            },
          },
          'output': ['MODEL', 'CLIP', 'VAE'],
          'output_is_list': [false, false, false],
          'name': 'CheckpointLoaderSimple',
          'display_name': 'Load Checkpoint',
          'category': 'loaders',
        };

        final def = NodeDefinition.fromApi('CheckpointLoaderSimple', apiData);

        expect(def.name, 'CheckpointLoaderSimple');
        expect(def.displayName, 'Load Checkpoint');
        expect(def.category, 'loaders');

        // Only has a combo widget, no slots
        expect(def.inputs.length, 0);
        expect(def.widgets.length, 1);
        expect(def.widgets[0].name, 'ckpt_name');
        expect(def.widgets[0].type, WidgetType.combo);
        expect(def.widgets[0].options, ['model1.safetensors', 'model2.safetensors']);

        // Has 3 outputs
        expect(def.outputs.length, 3);
        expect(def.outputs[0].type, SlotType.model);
        expect(def.outputs[1].type, SlotType.clip);
        expect(def.outputs[2].type, SlotType.vae);
      });

      test('parses CLIPTextEncode-like node', () {
        final apiData = {
          'input': {
            'required': {
              'text': ['STRING', {'multiline': true}],
              'clip': 'CLIP',
            },
          },
          'output': ['CONDITIONING'],
          'output_is_list': [false],
          'name': 'CLIPTextEncode',
          'display_name': 'CLIP Text Encode (Prompt)',
          'category': 'conditioning',
        };

        final def = NodeDefinition.fromApi('CLIPTextEncode', apiData);

        // clip is a slot, text is a widget
        expect(def.inputs.length, 1);
        expect(def.inputs[0].name, 'clip');
        expect(def.inputs[0].type, SlotType.clip);

        expect(def.widgets.length, 1);
        expect(def.widgets[0].name, 'text');
        expect(def.widgets[0].type, WidgetType.string);
        expect(def.widgets[0].multiline, true);

        expect(def.outputs.length, 1);
        expect(def.outputs[0].type, SlotType.conditioning);
      });

      test('parses output node', () {
        final apiData = {
          'input': {
            'required': {
              'images': 'IMAGE',
            },
            'optional': {
              'filename_prefix': ['STRING', {'default': 'ComfyUI'}],
            },
          },
          'output': [],
          'output_node': true,
          'name': 'SaveImage',
          'display_name': 'Save Image',
          'category': 'image',
        };

        final def = NodeDefinition.fromApi('SaveImage', apiData);

        expect(def.isOutputNode, true);
        expect(def.inputs.length, 1);
        expect(def.inputs[0].name, 'images');
        expect(def.widgets.length, 1);
        expect(def.widgets[0].name, 'filename_prefix');
      });

      test('parses optional inputs', () {
        final apiData = {
          'input': {
            'required': {
              'image': 'IMAGE',
            },
            'optional': {
              'mask': 'MASK',
            },
          },
          'output': ['IMAGE'],
          'name': 'TestNode',
          'display_name': 'Test',
          'category': 'testing',
        };

        final def = NodeDefinition.fromApi('TestNode', apiData);

        expect(def.inputs.length, 2);

        final imageInput = def.getInput('image');
        expect(imageInput!.isOptional, false);

        final maskInput = def.getInput('mask');
        expect(maskInput!.isOptional, true);
      });
    });
  });

  group('WidgetDefinition', () {
    test('creates int widget', () {
      final widget = WidgetDefinition(
        name: 'steps',
        type: WidgetType.int_,
        defaultValue: 20,
        min: 1,
        max: 100,
        step: 1,
      );

      expect(widget.name, 'steps');
      expect(widget.type, WidgetType.int_);
      expect(widget.defaultValue, 20);
      expect(widget.min, 1);
      expect(widget.max, 100);
    });

    test('creates combo widget', () {
      final widget = WidgetDefinition(
        name: 'sampler',
        type: WidgetType.combo,
        options: ['euler', 'heun', 'dpm_2'],
        defaultValue: 'euler',
      );

      expect(widget.type, WidgetType.combo);
      expect(widget.options, ['euler', 'heun', 'dpm_2']);
    });

    test('creates from slot definition', () {
      final slot = SlotDefinition(
        name: 'cfg',
        type: SlotType.float_,
        defaultValue: 8.0,
        min: 0.0,
        max: 100.0,
        step: 0.1,
      );

      final widget = WidgetDefinition.fromSlot(slot);

      expect(widget.name, 'cfg');
      expect(widget.type, WidgetType.float_);
      expect(widget.defaultValue, 8.0);
      expect(widget.min, 0.0);
      expect(widget.max, 100.0);
    });
  });

  group('NodeCategory', () {
    test('returns correct colors for known categories', () {
      expect(NodeCategory.getColor('loaders'), NodeCategory.colors['loaders']);
      expect(NodeCategory.getColor('sampling'), NodeCategory.colors['sampling']);
      expect(NodeCategory.getColor('image'), NodeCategory.colors['image']);
    });

    test('extracts base category from path', () {
      expect(NodeCategory.getColor('sampling/custom'), NodeCategory.colors['sampling']);
      expect(NodeCategory.getColor('image/upscaling'), NodeCategory.colors['image']);
    });

    test('returns default for unknown categories', () {
      final color = NodeCategory.getColor('unknown_category');
      expect(color, isNotNull);
    });
  });
}
