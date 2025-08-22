import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fx_shared.dart';

/// =============================================================
/// Shared UI: Logo, NavLink, CTAs, SectionTitle, CountUp, images, etc.
/// =============================================================

class Logo extends StatelessWidget {
  const Logo({super.key});
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [Color(0xFF00FF88), Color(0xFF00D4FF)],
      ).createShader(rect),
      child: Text(
        'EVVE',
        style: GoogleFonts.orbitron(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class NavLink extends StatefulWidget {
  const NavLink({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<NavLink> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onHover: (v) {
        setState(() => _hover = v);
        final fx = MouseFX.of(context);
        v ? fx.hoverLight() : fx.hoverNone();
      },
      borderRadius: BorderRadius.circular(50),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: _hover ? const Color(0x1A00FF88) : Colors.transparent,
          border: Border.all(
            color: _hover ? const Color(0x3300FF88) : Colors.transparent,
          ),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: Colors.white.withOpacity(_hover ? 1 : 0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// MagneticHover: subtle cursor feedback wrapper (no layout change)
class MagneticHover extends StatelessWidget {
  const MagneticHover({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => MouseFX.of(context).hoverLight(),
      onExit: (_) => MouseFX.of(context).hoverNone(),
      child: child,
    );
  }
}

// ---- CTA buttons ------------------------------------------------

const double _kCtaWidth = 220;
const double _kCtaHeight = 48;

class PrimaryCta extends StatelessWidget {
  const PrimaryCta({super.key, required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ButtonBase(
      onTap: onTap,
      text: text,
      width: _kCtaWidth,
      height: _kCtaHeight,
      textColor: const Color(0xFF0F0F23),
      gradient: const LinearGradient(
        colors: [Color(0xFF00FF88), Color(0xFF00D4FF)],
      ),
    );
  }
}

class SecondaryCta extends StatelessWidget {
  const SecondaryCta({super.key, required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ButtonBase(
      onTap: onTap,
      text: text,
      width: _kCtaWidth,
      height: _kCtaHeight,
      textColor: Colors.white,
      outline: true,
    );
  }
}

class _ButtonBase extends StatefulWidget {
  const _ButtonBase({
    required this.onTap,
    required this.text,
    this.gradient,
    this.outline = false,
    this.textColor,
    this.width,
    this.height = _kCtaHeight,
  });

  final VoidCallback onTap;
  final String text;
  final LinearGradient? gradient;
  final bool outline;
  final Color? textColor;
  final double? width;
  final double height;

  @override
  State<_ButtonBase> createState() => _ButtonBaseState();
}

class _ButtonBaseState extends State<_ButtonBase> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.height / 2;

    final constraints = BoxConstraints(
      minWidth: widget.width ?? _kCtaWidth,
      maxWidth: widget.width ?? _kCtaWidth,
      minHeight: widget.height,
      maxHeight: widget.height,
    );

    final gradientFill = widget.gradient != null
        ? DecoratedBox(
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: const SizedBox.expand(),
          )
        : const SizedBox.shrink();

    return ConstrainedBox(
      constraints: constraints,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          onTap: widget.onTap,
          onHover: (v) {
            setState(() => _hover = v);
            final fx = MouseFX.of(context);
            v ? fx.hoverStrong() : fx.hoverNone();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: widget.gradient == null ? Colors.transparent : null,
              border: widget.outline
                  ? Border.all(
                      color: _hover ? const Color(0xFF00FF88) : Colors.white24,
                      width: 2,
                    )
                  : null,
              boxShadow: widget.gradient != null && _hover
                  ? const [
                      BoxShadow(
                        color: Color(0x3300FF88),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.gradient != null)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: gradientFill,
                    ),
                  ),
                Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.2,
                    color: widget.textColor ?? Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [Color(0xFF00FF88), Color(0xFF00D4FF)],
          ).createShader(rect),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 4,
          width: 260,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Color(0xFF00FF88),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CountUp extends StatefulWidget {
  const CountUp({super.key, required this.to});
  final int to;
  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> {
  int _val = 0;

  @override
  void initState() {
    super.initState();
    const d = Duration(milliseconds: 2000);
    final sw = Stopwatch()..start();
    Timer.periodic(const Duration(milliseconds: 16), (tm) {
      final t = (sw.elapsedMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);
      setState(() => _val = (widget.to * Curves.easeOut.transform(t)).floor());
      if (t >= 1) tm.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$_val',
      textAlign: TextAlign.center,
      style: GoogleFonts.orbitron(
        fontSize: 46,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    );
  }
}

/// Tries `<base>.jpg`, then `<base>.png`, else placeholder.
class AssetImageWithFallback extends StatelessWidget {
  const AssetImageWithFallback({super.key, required this.base});
  final String base;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '$base.jpg',
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, stack) {
        return Image.asset(
          '$base.png',
          fit: BoxFit.cover,
          errorBuilder: (ctx2, err2, stack2) {
            return Container(
              color: Colors.black26,
              alignment: Alignment.center,
              child: const Icon(Icons.image_not_supported_outlined, size: 42),
            );
          },
        );
      },
    );
  }
}

class AvatarCircle extends StatelessWidget {
  const AvatarCircle({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF00FF88), Color(0xFF00D4FF)],
        ),
      ),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          shape: BoxShape.circle,
        ),
        child: Text(
          initial,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class Stars extends StatelessWidget {
  const Stars({super.key, required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    final full = rating.floor();
    final hasHalf = (rating - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (i < full) {
          icon = Icons.star_rounded;
        } else if (i == full && hasHalf) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, size: 18, color: const Color(0xFFFFD166));
      }),
    );
  }
}
