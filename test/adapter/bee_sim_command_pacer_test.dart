import 'package:flutter_test/flutter_test.dart';
import 'package:nlpa2/adapter/ble/bee_sim_command_pacer.dart';

void main() {
  test('matches BeeSIM cooldown ordinals for a long command stream', () async {
    final cooldownBeforeCommands = <int>[];
    final durations = <Duration>[];
    var command = 0;
    final pacer = BeeSimCommandPacer(
      delay: (duration) async {
        cooldownBeforeCommands.add(command);
        durations.add(duration);
      },
    );

    for (command = 1; command <= 64; command++) {
      await pacer.beforeCommand();
    }

    expect(cooldownBeforeCommands, <int>[22, 43, 64]);
    expect(durations, everyElement(BeeSimCommandPacer.cooldown));
  });

  test('reset starts a fresh 21-command burst', () async {
    var cooldowns = 0;
    final pacer = BeeSimCommandPacer(
      delay: (_) async {
        cooldowns++;
      },
    );

    for (var i = 0; i < BeeSimCommandPacer.commandsPerBurst; i++) {
      expect(await pacer.beforeCommand(), isFalse);
    }
    pacer.reset();
    expect(await pacer.beforeCommand(), isFalse);
    expect(cooldowns, 0);
  });
}
