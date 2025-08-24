import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'fx_shared.dart';
import 'widgets_shared.dart';
import 'orderbooking.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();
  final GlobalKey _reviewsKey = GlobalKey();

  late final AnimationController _splashCtrl;
  bool _hideSplash = false;

  double _appBarT = 0.0; // 0..1

  late final MouseFXController _fx;

  @override
  void initState() {
    super.initState();
    _fx = MouseFXController();

    _splashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    Future.delayed(const Duration(milliseconds: 3500), () async {
      if (!mounted) return;
      await _splashCtrl.forward();
      if (!mounted) return;
      setState(() => _hideSplash = true);
    });

    _scroll.addListener(() {
      final t = (_scroll.hasClients ? _scroll.offset : 0.0) / 140.0;
      final clamped = t.clamp(0.0, 1.0);
      if (clamped != _appBarT) {
        setState(() => _appBarT = clamped);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _splashCtrl.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgGrad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0F0F23), Color(0xFF1A1A3A), Color(0xFF2D2D5F)],
    );

    final glassOpacity = lerpDouble(0.18, 0.32, _appBarT)!;
    final blurSigma = lerpDouble(18, 30, _appBarT)!;
    final dividerOpacity = lerpDouble(0.03, 0.08, _appBarT)!;

    final size = MediaQuery.of(context).size;
    _fx.setScreen(size);

    final useFxCursor = isDesktopLike && size.width > 700;

    final body = Stack(
      children: [
        // Background gradient + parallax particles
        Container(decoration: const BoxDecoration(gradient: bgGrad)),
        const Positioned.fill(child: ParticlesLayer(count: 55)),
        const Positioned.fill(
          child: ParallaxLayer(
            depth: 10,
            child: QuantumParticlesLayer(count: 30),
          ),
        ),

        // Main scroll content
        CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              elevation: 0,
              toolbarHeight: 74,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(glassOpacity),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(dividerOpacity),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              titleSpacing: 12,
              title: LayoutBuilder(
                builder: (context, cons) {
                  final isNarrow = cons.maxWidth < 900;
                  return Row(
                    children: [
                      const Logo(),
                      const Spacer(),
                      if (!isNarrow) ...[
                        NavLink(
                          label: 'Home',
                          onTap: () => _scrollTo(_homeKey),
                        ),
                        const SizedBox(width: 18),
                        NavLink(
                          label: 'Features',
                          onTap: () => _scrollTo(_featuresKey),
                        ),
                        const SizedBox(width: 18),
                        NavLink(
                          label: 'Reviews',
                          onTap: () => _scrollTo(_reviewsKey),
                        ),
                        const SizedBox(width: 18),
                        NavLink(
                          label: 'About',
                          onTap: () => _scroll.animateTo(
                            0,
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.ease,
                          ),
                        ),
                        const SizedBox(width: 18),
                        NavLink(
                          label: 'Contact',
                          onTap: () => _scrollTo(_contactKey),
                        ),
                        const SizedBox(width: 24),
                      ],
                      // CTA now goes to Order page
                      PrimaryCta(
                        text: 'Get Started',
                        onTap: () =>
                            Navigator.pushNamed(context, OrderPage.route),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Hero
            SliverToBoxAdapter(
              child: _HeroSection(
                key: _homeKey,
                onExplore: () => Navigator.pushNamed(context, OrderPage.route),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
            SliverToBoxAdapter(child: _FeaturesSection(key: _featuresKey)),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
            const SliverToBoxAdapter(child: _StatsSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),

            // Reviews section (enabled)
            SliverToBoxAdapter(child: _ReviewsSection(key: _reviewsKey)),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),

            // Contact buttons now go to Order page
            SliverToBoxAdapter(child: _ContactSection(key: _contactKey)),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
            const SliverToBoxAdapter(child: _Footer()),
          ],
        ),

        // Splash overlay
        if (!_hideSplash)
          Positioned.fill(
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0).animate(
                CurvedAnimation(parent: _splashCtrl, curve: Curves.easeInOut),
              ),
              child: const SplashOverlay(),
            ),
          ),

        // Custom Cursor & FX overlay (painted on top)
        if (useFxCursor) const Positioned.fill(child: MouseFXOverlay()),
      ],
    );

    final tracked = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: (e) => _fx.updatePosition(e.position),
      onPointerMove: (e) => _fx.updatePosition(e.position),
      onPointerDown: (e) => _fx.clickRipple(e.position),
      child: MouseRegion(
        cursor: useFxCursor
            ? SystemMouseCursors.none
            : SystemMouseCursors.basic,
        onHover: (e) => _fx.updatePosition(e.position),
        child: body,
      ),
    );

    return MouseFX(
      controller: _fx,
      child: Scaffold(body: tracked),
    );
  }
}

/// ===== Splash =====
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _ringsCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _ringsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F0F23), Color(0xFF1A1A3A), Color(0xFF2D2D5F)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [
                  Color(0xFF00FF88),
                  Color(0xFF00D4FF),
                  Color(0xFFFF6B9D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(rect),
              child: Text(
                'EVEE',
                style: GoogleFonts.orbitron(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Electric Bikes Redefined',
              style: GoogleFonts.inter(
                fontSize: 20,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 140,
              height: 140,
              child: AnimatedBuilder(
                animation: _ringsCtrl,
                builder: (context, _) => CustomPaint(
                  painter: _RingsPainter(progress: _ringsCtrl.value),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 220,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              clipBehavior: Clip.antiAlias,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 3000),
                curve: Curves.easeOut,
                tween: Tween(begin: 0, end: 1),
                builder: (context, v, __) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF00FF88), Color(0xFF00D4FF)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double progress; // 0..1
  _RingsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paints = [
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = const LinearGradient(
          colors: [Color(0xFF00FF88), Color(0xFF00FF88)],
        ).createShader(Offset.zero & size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF00D4FF)],
        ).createShader(Offset.zero & size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF6B9D), Color(0xFFFF6B9D)],
        ).createShader(Offset.zero & size),
    ];

    final radii = [60.0, 45.0, 30.0];
    for (int i = 0; i < 3; i++) {
      final angle = (progress * (i.isEven ? 2 * pi : -2 * pi)) + (i * 0.4);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final rect = Rect.fromCircle(center: Offset.zero, radius: radii[i]);
      final sweep = pi * 1.2;
      canvas.drawArc(rect, -pi / 3, sweep, false, paints[i]);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// ===== Hero =====
class _HeroSection extends StatelessWidget {
  const _HeroSection({super.key, required this.onExplore});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      height: max(540, MediaQuery.of(context).size.height * 0.92),
      alignment: Alignment.center,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [
                          Color(0xFF00FF88),
                          Color(0xFF00D4FF),
                          Color(0xFFFF6B9D),
                        ],
                      ).createShader(rect),
                      child: Text(
                        'Ride The Future\nWith Mirabella EVEE',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.orbitron(
                          fontSize: w < 780 ? 48 : 82,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Experience the next generation of electric mobility with EVEE bikes.\nSustainable, powerful, and designed for the modern world.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        MagneticHover(
                          child: PrimaryCta(
                            text: 'Explore Bikes',
                            onTap: onExplore,
                          ),
                        ),
                        MagneticHover(
                          child: SecondaryCta(
                            text: 'Learn More',
                            onTap: onExplore,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (w > 900)
            const Positioned(
              right: -40,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: SizedBox(
                  width: 640,
                  child: ParallaxLayer(depth: 26, child: _BikeGlow()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BikeGlow extends StatefulWidget {
  const _BikeGlow();

  @override
  State<_BikeGlow> createState() => _BikeGlowState();
}

class _BikeGlowState extends State<_BikeGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 6000),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = sin(_ctrl.value * 2 * pi) * 0.5 + 0.5; // 0..1
        return Transform.translate(
          offset: Offset(0, -10 * t),
          child: Opacity(
            opacity: 0.12 + 0.08 * t,
            child: CustomPaint(painter: _BikePainter(t)),
          ),
        );
      },
    );
  }
}

class _BikePainter extends CustomPainter {
  final double t;
  _BikePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..shader = const LinearGradient(
        colors: [Color(0xFF00FF88), Color(0xFF00D4FF), Color(0xFFFF6B9D)],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(50, size.height * 0.55)
      ..lineTo(size.width * 0.75, size.height * 0.55)
      ..moveTo(size.width * 0.33, size.height * 0.35)
      ..lineTo(size.width * 0.5, size.height * 0.35)
      ..moveTo(size.width * 0.2, size.height * 0.55)
      ..lineTo(size.width * 0.33, size.height * 0.35)
      ..moveTo(size.width * 0.5, size.height * 0.35)
      ..lineTo(size.width * 0.75, size.height * 0.55);
    canvas.drawPath(path, p);

    final wheel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..shader = const LinearGradient(
        colors: [Color(0xFF00FF88), Color(0xFF00D4FF), Color(0xFFFF6B9D)],
      ).createShader(Offset.zero & size);

    void drawWheel(Offset c, double r) {
      final segs = 32;
      for (int i = 0; i < segs; i++) {
        final ang = (i / segs) * 2 * pi + t * 2 * pi;
        final ang2 = ang + (pi / segs);
        final a1 = Offset(c.dx + cos(ang) * r, c.dy + sin(ang) * r);
        final a2 = Offset(c.dx + cos(ang2) * r, c.dy + sin(ang2) * r);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          ang,
          0.05,
          false,
          wheel,
        );
        canvas.drawLine(a1, a2, wheel..strokeWidth = 1.5);
      }
    }

    drawWheel(Offset(size.width * 0.3, size.height * 0.55), 55);
    drawWheel(Offset(size.width * 0.75, size.height * 0.55), 55);

    final energy = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF00D4FF).withOpacity(0.8);
    final path2 = Path()
      ..moveTo(size.width * 0.28, size.height * 0.4)
      ..cubicTo(
        size.width * 0.38,
        size.height * (0.32 - 0.04 * sin(t * 2 * pi)),
        size.width * 0.48,
        size.height * (0.4 - 0.06 * sin(t * 2 * pi)),
        size.width * 0.58,
        size.height * 0.4,
      )
      ..cubicTo(
        size.width * 0.68,
        size.height * (0.32 - 0.04 * sin(t * 2 * pi)),
        size.width * 0.78,
        size.height * (0.4 - 0.06 * sin(t * 2 * pi)),
        size.width * 0.88,
        size.height * 0.4,
      );
    canvas.drawPath(path2, energy);
  }

  @override
  bool shouldRepaint(covariant _BikePainter oldDelegate) => oldDelegate.t != t;
}

/// ===== Features =====
class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
      child: Column(
        children: [
          const SectionTitle('Why Choose EVVE?'),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, c) {
              final cross = c.maxWidth < 720
                  ? 1
                  : c.maxWidth < 1024
                  ? 2
                  : 3;
              final cards = const [
                _Feature(
                  icon: Icons.bolt_rounded,
                  title: 'Lightning Fast',
                  desc:
                      'Reach speeds up to 45 km/h with our advanced motor technology and intelligent power management system.',
                ),
                _Feature(
                  icon: Icons.battery_charging_full_rounded,
                  title: 'Long Range',
                  desc:
                      'Go up to 100km on a single charge with our high-capacity lithium batteries and energy-efficient design.',
                ),
                _Feature(
                  icon: Icons.eco_rounded,
                  title: 'Eco-Friendly',
                  desc:
                      'Zero emissions, sustainable materials, and recyclable components. Ride clean, ride green with EVVE.',
                ),
                _Feature(
                  icon: Icons.smartphone_rounded,
                  title: 'Smart Connected',
                  desc:
                      'Integrated GPS tracking, smartphone app connectivity, and intelligent theft protection for peace of mind.',
                ),
                _Feature(
                  icon: Icons.build_rounded,
                  title: 'Low Maintenance',
                  desc:
                      'Minimal moving parts, self-diagnostic systems, and durable construction for years of reliable performance.',
                ),
                _Feature(
                  icon: Icons.palette_rounded,
                  title: 'Premium Design',
                  desc:
                      'Sleek, modern aesthetics combined with ergonomic comfort and premium materials for the ultimate ride.',
                ),
              ];
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: cards.length,
                    itemBuilder: (context, i) => MagneticHover(child: cards[i]),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatefulWidget {
  const _Feature({required this.icon, required this.title, required this.desc});
  final IconData icon;
  final String title;
  final String desc;
  @override
  State<_Feature> createState() => _FeatureState();
}

class _FeatureState extends State<_Feature> {
  double _rx = 0, _ry = 0;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (e) {
        final r = context.findRenderObject() as RenderBox?;
        if (r == null) return;
        final local = r.globalToLocal(e.position);
        final dx = (local.dx / r.size.width) - 0.5;
        final dy = (local.dy / r.size.height) - 0.5;
        setState(() {
          _rx = dy * -8;
          _ry = dx * 8;
        });
        MouseFX.of(context).hoverLight();
      },
      onExit: (_) {
        setState(() {
          _rx = 0;
          _ry = 0;
        });
        MouseFX.of(context).hoverNone();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF88).withOpacity(0.12),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(_rx * pi / 180)
          ..rotateY(_ry * pi / 180)
          ..translate(0.0, -4.0, 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with gradient halo
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x3300FF88), Colors.transparent],
                    ),
                  ),
                ),
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Color(0xFF00FF88), Color(0xFF00D4FF)],
                  ).createShader(rect),
                  child: Icon(widget.icon, size: 46, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              widget.desc,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.75)),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== Stats =====
class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: const Color(0x1A00FF88),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 20,
            children: const [
              _StatBox(label: 'Happy Riders', target: 10000),
              _StatBox(label: 'Max Range KM', target: 100),
              _StatBox(label: 'Top Speed KM/H', target: 45),
              _StatBox(label: 'Hours Fast Charge', target: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.target});
  final String label;
  final int target;
  @override
  Widget build(BuildContext context) {
    return MagneticHover(
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x4D00FF88)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [Color(0xFF00FF88), Color(0xFF00D4FF)],
              ).createShader(rect),
              child: CountUp(to: target),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                letterSpacing: 1,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===== Contact + Footer =====
class _ContactSection extends StatelessWidget {
  const _ContactSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 54),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  colors: [Color(0xFF00FF88), Color(0xFF00D4FF)],
                ).createShader(rect),
                child: Text(
                  'Ready to Ride?',
                  style: GoogleFonts.orbitron(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Join thousands of riders who have already made the switch to sustainable, intelligent transportation.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  MagneticHover(
                    child: PrimaryCta(
                      text: 'Order Now',
                      onTap: () =>
                          Navigator.pushNamed(context, OrderPage.route),
                    ),
                  ),
                  MagneticHover(
                    child: SecondaryCta(
                      text: 'Book Test Ride',
                      onTap: () =>
                          Navigator.pushNamed(context, OrderPage.route),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      alignment: Alignment.center,
      child: const Text(
        '© 2025 EVVE Bikes. All rights reserved. | Ride the Future, Today.',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}

/// ===== Reviews =====
class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final reviews = <_Review>[
      const _Review(
        name: 'Alishba Khan',
        tag: 'Islamabad G-13',
        rating: 5,
        quote:
            'The torque is wild and the ride quality is buttery smooth. I am riding daily now.',
      ),
      const _Review(
        name: 'Arslan Malik',
        tag: 'Lahore Model Town',
        rating: 4.5,
        quote:
            'Range anxiety? Gone. The app lock + GPS tracker is super reassuring.',
      ),
      const _Review(
        name: 'Sajjad Hussain',
        tag: 'Rawalpindi Bahria Town',
        rating: 5,
        quote:
            'Looks premium, feels premium. People stop me to ask what bike this is.',
      ),
      const _Review(
        name: 'Mia Aslam',
        tag: 'Karachi DHA',
        rating: 4.5,
        quote:
            'Fast charge really is fast. 30 minutes while I grab coffee and I am back.',
      ),
      const _Review(
        name: 'Irum Fraz',
        tag: 'Karachi Clifton',
        rating: 5,
        quote:
            'Whisper quiet motor, zero maintenance so far. Absolute joy to commute on.',
      ),
      const _Review(
        name: 'Frahan Ali',
        tag: 'Islamabad F-11',
        rating: 5,
        quote:
            'Design is gorgeous. The magnetic throttle + assist feels super natural.',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40),
      child: Column(
        children: [
          const SectionTitle('What Riders Say'),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, c) {
              final cross = c.maxWidth < 720
                  ? 1
                  : c.maxWidth < 1024
                  ? 2
                  : 3;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cross,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: reviews.length,
                    itemBuilder: (context, i) {
                      final data = reviews[i];
                      final base = _imageBaseForReview(i, data);
                      return _ReviewCard(data, imageBase: base);
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _imageBaseForReview(int index, _Review r) {
  if (r.name.trim().toLowerCase() == 'irum fraz') {
    return 'assets/evee1';
  }
  final n = index + 2; // index 0 -> evee2, 1 -> evee3...
  return 'assets/evee$n';
}

class _Review {
  final String name;
  final String tag; // city / model
  final double rating; // 0..5
  final String quote;
  const _Review({
    required this.name,
    required this.tag,
    required this.rating,
    required this.quote,
  });
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard(this.data, {super.key, required this.imageBase});
  final _Review data;
  final String imageBase;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  double _rx = 0, _ry = 0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (e) {
        final r = context.findRenderObject() as RenderBox?;
        if (r == null) return;
        final local = r.globalToLocal(e.position);
        final dx = (local.dx / r.size.width) - 0.5;
        final dy = (local.dy / r.size.height) - 0.5;
        setState(() {
          _rx = dy * -6;
          _ry = dx * 6;
        });
        MouseFX.of(context).hoverLight();
      },
      onExit: (_) {
        setState(() {
          _rx = 0;
          _ry = 0;
        });
        MouseFX.of(context).hoverNone();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF88).withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(_rx * pi / 180)
          ..rotateY(_ry * pi / 180)
          ..translate(0.0, -2.0, 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: AssetImageWithFallback(base: widget.imageBase),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Text(
                '"${widget.data.quote}"',
                style: TextStyle(
                  height: 1.35,
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.90),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                AvatarCircle(name: widget.data.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.data.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.data.tag,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Stars(rating: widget.data.rating),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
