import 'dart:js_interop';

@JS('eval')
external JSAny? _jsEval(JSString code);

/// Web Audio sound effects for the Robot Grid example.
abstract final class RobotGridSound {
  static bool enabled = true;

  static void playConnect() {
    if (!enabled) return;
    _eval(
      "(function(){var c=new AudioContext(),o=c.createOscillator(),g=c.createGain();"
      "o.type='sine';o.frequency.setValueAtTime(600,c.currentTime);"
      "o.frequency.exponentialRampToValueAtTime(1200,c.currentTime+0.1);"
      "g.gain.setValueAtTime(0.08,c.currentTime);"
      "g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+0.15);"
      "o.connect(g);g.connect(c.destination);o.start();o.stop(c.currentTime+0.15)})()",
    );
  }

  static void playBounce(double intensity) {
    if (!enabled) return;
    final vol = (0.03 + intensity * 0.25).clamp(0.03, 0.28);
    final freq = (100 + intensity * 80).round();
    final dur = (0.12 + intensity * 0.15).toStringAsFixed(2);
    _eval(
      "(function(){var c=new AudioContext(),o=c.createOscillator(),n=c.createOscillator(),g=c.createGain();"
      "o.type='sine';n.type='triangle';"
      "o.frequency.setValueAtTime($freq,c.currentTime);"
      "o.frequency.exponentialRampToValueAtTime(40,c.currentTime+$dur);"
      "n.frequency.setValueAtTime(${freq * 2},c.currentTime);"
      "n.frequency.exponentialRampToValueAtTime(30,c.currentTime+${(double.parse(dur) * 0.8).toStringAsFixed(2)});"
      "g.gain.setValueAtTime($vol,c.currentTime);"
      "g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+$dur);"
      "o.connect(g);n.connect(g);g.connect(c.destination);"
      "o.start();n.start();o.stop(c.currentTime+$dur);n.stop(c.currentTime+$dur)})()",
    );
  }

  static void playCut() {
    if (!enabled) return;
    _eval(
      "(function(){var c=new AudioContext(),o=c.createOscillator(),g=c.createGain();"
      "o.type='sawtooth';o.frequency.setValueAtTime(800,c.currentTime);"
      "o.frequency.exponentialRampToValueAtTime(200,c.currentTime+0.1);"
      "g.gain.setValueAtTime(0.06,c.currentTime);"
      "g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+0.12);"
      "o.connect(g);g.connect(c.destination);o.start();o.stop(c.currentTime+0.12)})()",
    );
  }

  static void playSpawn() {
    if (!enabled) return;
    _eval(
      "(function(){var c=new AudioContext(),o=c.createOscillator(),g=c.createGain();"
      "o.type='sine';o.frequency.setValueAtTime(300,c.currentTime);"
      "o.frequency.exponentialRampToValueAtTime(500,c.currentTime+0.06);"
      "o.frequency.exponentialRampToValueAtTime(250,c.currentTime+0.12);"
      "g.gain.setValueAtTime(0.06,c.currentTime);"
      "g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+0.15);"
      "o.connect(g);g.connect(c.destination);o.start();o.stop(c.currentTime+0.15)})()",
    );
  }

  static void playPickup() {
    if (!enabled) return;
    _eval(
      "(function(){var c=new AudioContext(),o=c.createOscillator(),g=c.createGain();"
      "o.type='sine';o.frequency.setValueAtTime(400,c.currentTime);"
      "o.frequency.exponentialRampToValueAtTime(600,c.currentTime+0.05);"
      "g.gain.setValueAtTime(0.04,c.currentTime);"
      "g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+0.08);"
      "o.connect(g);g.connect(c.destination);o.start();o.stop(c.currentTime+0.08)})()",
    );
  }

  static void playDrop() {
    if (!enabled) return;
    _eval(
      "(function(){var c=new AudioContext(),o=c.createOscillator(),g=c.createGain();"
      "o.type='sine';o.frequency.setValueAtTime(200,c.currentTime);"
      "o.frequency.exponentialRampToValueAtTime(100,c.currentTime+0.08);"
      "g.gain.setValueAtTime(0.05,c.currentTime);"
      "g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+0.1);"
      "o.connect(g);g.connect(c.destination);o.start();o.stop(c.currentTime+0.1)})()",
    );
  }

  static void playThrow(double intensity) {
    if (!enabled) return;
    final vol = (intensity * 0.08).clamp(0.02, 0.1);
    final freq = (300 + intensity * 400).clamp(300, 700).round();
    _eval(
      "(function(){var c=new AudioContext(),o=c.createOscillator(),n=c.createOscillator(),g=c.createGain();"
      "o.type='sine';n.type='sawtooth';"
      "o.frequency.setValueAtTime($freq,c.currentTime);"
      "o.frequency.exponentialRampToValueAtTime(100,c.currentTime+0.2);"
      "n.frequency.setValueAtTime(${freq ~/ 2},c.currentTime);"
      "n.frequency.exponentialRampToValueAtTime(50,c.currentTime+0.15);"
      "g.gain.setValueAtTime($vol,c.currentTime);"
      "g.gain.exponentialRampToValueAtTime(0.001,c.currentTime+0.2);"
      "o.connect(g);n.connect(g);g.connect(c.destination);"
      "o.start();n.start();o.stop(c.currentTime+0.2);n.stop(c.currentTime+0.15)})()",
    );
  }

  static void _eval(String code) {
    try {
      _jsEval(code.toJS);
    } catch (_) {}
  }
}
