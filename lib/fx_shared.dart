import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// =============================================================
/// Mouse FX (cursor trail, ripples) + Parallax + Particles
/// =============================================================

class MouseFX extends InheritedWidget {
  final MouseFXController controller;
  const MouseFX({super.key, required this.controller, required super.child});

  static MouseFXController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MouseFX>()!.controller;

  @override
  bool updateShouldNotify(MouseFX oldWidget) =>
      oldWidget.controller != controller;
}

class MouseFXController extends ChangeNotifier {
  Offset position = Offset.zero;
  Size screen = Size.zero;
  final List<Offset> _trail = [];
  int trailMax = 22;

  double _cursorScale = 1.0;
  double _cursorScaleTarget = 1.0;

  final List<_Ripple> _ripples = [];

  double get normX => screen.width == 0 ? 0.5 : (position.dx / screen.width);
  double get normY => screen.height == 0 ? 0.5 : (position.dy / screen.height);

  List<Offset> get trail => _trail;
  List<_Ripple> get ripples => _ripples;

  double get cursorScale => _cursorScale;

  void setScreen(Size s) => screen = s;

  void updatePosition(Offset p) {
    position = p;
    _trail.add(p);
    if (_trail.length > trailMax) _trail.removeAt(0);
    notifyListeners();
  }

  void hoverLight() => _cursorScaleTarget = 1.25;
  void hoverStrong() => _cursorScaleTarget = 1.6;
  void hoverNone() => _cursorScaleTarget = 1.0;

  void bump([double to = 2.1]) {
    _cursorScale = to;
    notifyListeners();
  }

  void tick() {
    _cursorScale = lerpDouble(_cursorScale, _cursorScaleTarget, 0.18)!;
    _ripples.removeWhere((r) => r.t >= 1.0);
    for (final r in _ripples) {
      r.step();
    }
    notifyListeners();
  }

  void clickRipple(Offset p) {
    _ripples.add(_Ripple(p));
    bump(2.3);
  }
}

class _Ripple {
  final Offset pos;
  late final int _startMs;
  double t = 0; // 0..1
  static const dur = 520; // ms
  _Ripple(this.pos) : _startMs = DateTime.now().millisecondsSinceEpoch;

  void step() {
    final now = DateTime.now().millisecondsSinceEpoch;
    t = ((now - _startMs) / dur).clamp(0.0, 1.0);
  }
}

class MouseFXOverlay extends StatefulWidget {
  const MouseFXOverlay({super.key});

  @override
  State<MouseFXOverlay> createState() => _MouseFXOverlayState();
}

class _MouseFXOverlayState extends State<MouseFXOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker = AnimationController(
    vsync: this,
    duration: const Duration(days: 99),
  )..addListener(() => MouseFX.of(context).tick());

  @override
  void initState() {
    super.initState();
    _ticker.repeat(period: const Duration(milliseconds: 16));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fx = MouseFX.of(context);
    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: fx,
        builder: (context, _) {
          return CustomPaint(
            painter: _CursorPainter(
              pos: fx.position,
              trail: fx.trail,
              scale: fx.cursorScale,
              ripples: fx.ripples,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _CursorPainter extends CustomPainter {
  final Offset pos;
  final List<Offset> trail;
  final double scale;
  final List<_Ripple> ripples;
  _CursorPainter({
    required this.pos,
    required this.trail,
    required this.scale,
    required this.ripples,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // trail
    final trailLen = trail.length;
    for (int i = 0; i < trailLen; i++) {
      final p = trail[i];
      final t = i / max(1, trailLen - 1);
      final alpha = (255 * pow(t, 2) * 0.35).toInt();
      final r = 6.0 + 10.0 * t;
      final paint = Paint()
        ..color = const Color(0xFF00FF88).withAlpha(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(p, r, paint);
    }

    // ripples
    for (final r in ripples) {
      final radius = lerpDouble(0, 70, Curves.easeOut.transform(r.t))!;
      final a = (180 * (1 - r.t)).toInt();
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF00D4FF).withAlpha(a);
      canvas.drawCircle(r.pos, radius, paint);
    }

    // cursor ring + glow
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFFFFFF).withOpacity(0.85);
    final glow = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF00FF88).withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final base = 10.0;
    final radius = base * scale;
    canvas.drawCircle(pos, radius, glow);
    canvas.drawCircle(pos, radius, ring);
  }

  @override
  bool shouldRepaint(covariant _CursorPainter old) =>
      old.pos != pos ||
      old.scale != scale ||
      old.trail != trail ||
      old.ripples != ripples;
}

bool get isDesktopLike =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

/// Parallax layer that moves based on global mouse position
class ParallaxLayer extends StatelessWidget {
  const ParallaxLayer({super.key, required this.depth, required this.child});
  final double depth; // px of max translation
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fx = MouseFX.of(context);
    return AnimatedBuilder(
      animation: fx,
      builder: (context, _) {
        final dx = (fx.normX - 0.5) * depth;
        final dy = (fx.normY - 0.5) * depth;
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
    );
  }
}

/// Simple falling dots layer
class ParticlesLayer extends StatefulWidget {
  const ParticlesLayer({super.key, this.count = 50});
  final int count;

  @override
  State<ParticlesLayer> createState() => _ParticlesLayerState();
}

class _ParticlesLayerState extends State<ParticlesLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();
  late final List<_Particle> _ps = List.generate(
    widget.count,
    (_) => _Particle.random(),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) =>
          CustomPaint(painter: _ParticlesPainter(_ps, _ctrl.value)),
    );
  }
}

/// Colorful “quantum” glow dots
class QuantumParticlesLayer extends StatefulWidget {
  const QuantumParticlesLayer({super.key, this.count = 30});
  final int count;

  @override
  State<QuantumParticlesLayer> createState() => _QuantumParticlesLayerState();
}

class _QuantumParticlesLayerState extends State<QuantumParticlesLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();
  late final List<_Particle> _ps = List.generate(
    widget.count,
    (_) => _Particle.random(quantum: true),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) =>
          CustomPaint(painter: _QuantumPainter(_ps, _ctrl.value)),
    );
  }
}

class _Particle {
  double x, y, s, spd;
  Color color;
  _Particle(this.x, this.y, this.s, this.spd, this.color);

  factory _Particle.random({bool quantum = false}) {
    final rnd = Random();
    return _Particle(
      rnd.nextDouble(),
      rnd.nextDouble(),
      quantum ? rnd.nextDouble() * 3 + 1 : rnd.nextDouble() * 2 + 1,
      quantum ? rnd.nextDouble() * 0.4 + 0.3 : rnd.nextDouble() * 0.2 + 0.1,
      quantum
          ? [
              const Color(0xFF00FF88),
              const Color(0xFF00D4FF),
              const Color(0xFFFF6B9D),
            ][rnd.nextInt(3)]
          : const Color(0x6600FF88),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> ps;
  final double t; // 0..1
  _ParticlesPainter(this.ps, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(42);
    for (var p in ps) {
      final y = size.height * ((p.y + t * p.spd) % 1.0);
      final x = size.width * p.x;
      final paint = Paint()..color = const Color(0x6600FF88);
      canvas.drawCircle(Offset(x, y), p.s, paint);
      if (rnd.nextDouble() < 0.02) {
        canvas.drawCircle(
          Offset(x, y),
          p.s + 1.5,
          paint..color = const Color(0x3300FF88),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter old) => old.t != t;
}

class _QuantumPainter extends CustomPainter {
  final List<_Particle> ps;
  final double t;
  _QuantumPainter(this.ps, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in ps) {
      final y = size.height * ((p.y + t * p.spd) % 1.0);
      final x = size.width * ((p.x + t * 0.2) % 1.0);
      final paint = Paint()
        ..color = p.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, y), p.s, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _QuantumPainter old) => old.t != t;
}
