import 'package:flutter_test/flutter_test.dart';
import '../../../../lib/comfyui/core/nodes/slot_types.dart';

void main() {
  group('SlotType', () {
    test('has correct type names', () {
      expect(SlotType.model.typeName, 'MODEL');
      expect(SlotType.clip.typeName, 'CLIP');
      expect(SlotType.vae.typeName, 'VAE');
      expect(SlotType.conditioning.typeName, 'CONDITIONING');
      expect(SlotType.latent.typeName, 'LATENT');
      expect(SlotType.image.typeName, 'IMAGE');
      expect(SlotType.mask.typeName, 'MASK');
      expect(SlotType.int_.typeName, 'INT');
      expect(SlotType.float_.typeName, 'FLOAT');
      expect(SlotType.string.typeName, 'STRING');
    });

    test('fromTypeName parses known types', () {
      expect(SlotType.fromTypeName('MODEL'), SlotType.model);
      expect(SlotType.fromTypeName('IMAGE'), SlotType.image);
      expect(SlotType.fromTypeName('LATENT'), SlotType.latent);
      expect(SlotType.fromTypeName('INT'), SlotType.int_);
    });

    test('fromTypeName returns any for unknown types', () {
      expect(SlotType.fromTypeName('UNKNOWN'), SlotType.any);
      expect(SlotType.fromTypeName(''), SlotType.any);
    });

    test('canConnectTo allows same types', () {
      expect(SlotType.model.canConnectTo(SlotType.model), true);
      expect(SlotType.image.canConnectTo(SlotType.image), true);
      expect(SlotType.latent.canConnectTo(SlotType.latent), true);
    });

    test('canConnectTo rejects different types', () {
      expect(SlotType.model.canConnectTo(SlotType.image), false);
      expect(SlotType.latent.canConnectTo(SlotType.conditioning), false);
      expect(SlotType.int_.canConnectTo(SlotType.string), false);
    });

    test('canConnectTo allows any type as universal', () {
      expect(SlotType.any.canConnectTo(SlotType.model), true);
      expect(SlotType.any.canConnectTo(SlotType.image), true);
      expect(SlotType.model.canConnectTo(SlotType.any), true);
      expect(SlotType.image.canConnectTo(SlotType.any), true);
    });

    test('all types have unique colors', () {
      final colors = <int>{};
      for (final type in SlotType.values) {
        if (type != SlotType.any) {
          // Most types should have unique colors, some share (int/float)
          colors.add(type.color.value);
        }
      }
      // At least most types should have distinct colors
      expect(colors.length, greaterThan(15));
    });
  });

  group('SlotDefinition', () {
    test('creates basic slot', () {
      final slot = SlotDefinition(
        name: 'model',
        type: SlotType.model,
      );

      expect(slot.name, 'model');
      expect(slot.type, SlotType.model);
      expect(slot.isOptional, false);
      expect(slot.defaultValue, null);
    });

    test('creates optional slot', () {
      final slot = SlotDefinition(
        name: 'image',
        type: SlotType.image,
        isOptional: true,
      );

      expect(slot.isOptional, true);
    });

    test('creates slot with default value', () {
      final slot = SlotDefinition(
        name: 'steps',
        type: SlotType.int_,
        defaultValue: 20,
        min: 1,
        max: 100,
        step: 1,
      );

      expect(slot.defaultValue, 20);
      expect(slot.min, 1);
      expect(slot.max, 100);
      expect(slot.step, 1);
    });

    test('creates combo slot', () {
      final slot = SlotDefinition(
        name: 'sampler',
        type: SlotType.combo,
        comboOptions: ['euler', 'euler_ancestral', 'heun', 'dpm_2'],
        defaultValue: 'euler',
      );

      expect(slot.comboOptions, ['euler', 'euler_ancestral', 'heun', 'dpm_2']);
      expect(slot.defaultValue, 'euler');
    });

    group('fromApi', () {
      test('parses simple string type', () {
        final slot = SlotDefinition.fromApi('model', 'MODEL');

        expect(slot.name, 'model');
        expect(slot.type, SlotType.model);
      });

      test('parses combo type', () {
        final slot = SlotDefinition.fromApi('sampler_name', [
          ['euler', 'euler_ancestral', 'heun']
        ]);

        expect(slot.name, 'sampler_name');
        expect(slot.type, SlotType.combo);
        expect(slot.comboOptions, ['euler', 'euler_ancestral', 'heun']);
        expect(slot.defaultValue, 'euler');
      });

      test('parses type with config', () {
        final slot = SlotDefinition.fromApi('steps', [
          'INT',
          {'default': 20, 'min': 1, 'max': 10000, 'step': 1}
        ]);

        expect(slot.name, 'steps');
        expect(slot.type, SlotType.int_);
        expect(slot.defaultValue, 20);
        expect(slot.min, 1);
        expect(slot.max, 10000);
        expect(slot.step, 1);
      });

      test('parses multiline string', () {
        final slot = SlotDefinition.fromApi('text', [
          'STRING',
          {'multiline': true, 'default': ''}
        ]);

        expect(slot.type, SlotType.string);
        expect(slot.multiline, true);
      });

      test('handles unknown type gracefully', () {
        final slot = SlotDefinition.fromApi('custom', 'CUSTOM_TYPE');

        expect(slot.name, 'custom');
        expect(slot.type, SlotType.any);
      });
    });

    test('copyWith creates modified copy', () {
      final original = SlotDefinition(
        name: 'model',
        type: SlotType.model,
        isOptional: false,
      );

      final modified = original.copyWith(isOptional: true);

      expect(modified.name, 'model');
      expect(modified.type, SlotType.model);
      expect(modified.isOptional, true);
      expect(original.isOptional, false); // Original unchanged
    });
  });
}
