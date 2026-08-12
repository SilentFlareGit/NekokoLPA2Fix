typedef BeeSimDelay = Future<void> Function(Duration duration);

/// Matches the recovery window used by BeeSIM's reference client.
///
/// The upstream counter is checked before it is incremented, so commands
/// 1 through 21 run immediately and command 22 waits before transmission.
class BeeSimCommandPacer {
  BeeSimCommandPacer({BeeSimDelay? delay})
    : _delay = delay ?? ((duration) => Future<void>.delayed(duration));

  static const int commandsPerBurst = 21;
  static const Duration cooldown = Duration(milliseconds: 1200);

  final BeeSimDelay _delay;
  int _commandsSinceCooldown = 0;

  /// Waits when the previous BeeSIM command burst exhausted its allowance.
  ///
  /// Returns true when a cooldown was applied, which lets the transport log
  /// the recovery window without putting logging concerns in this class.
  Future<bool> beforeCommand() async {
    if (_commandsSinceCooldown >= commandsPerBurst) {
      await _delay(cooldown);
      _commandsSinceCooldown = 0;
      _commandsSinceCooldown++;
      return true;
    }

    _commandsSinceCooldown++;
    return false;
  }

  void reset() {
    _commandsSinceCooldown = 0;
  }
}
