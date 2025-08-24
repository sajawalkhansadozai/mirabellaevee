// lib/bike_details_page.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

// Reuse your Bike model (from orderbooking.dart)
import 'orderbooking.dart' show Bike;

// Reuse your FX layers & mouse cursor from your existing project
import 'fx_shared.dart'; // MouseFX, MouseFXController, ParticlesLayer, ParallaxLayer, QuantumParticlesLayer, MouseFXOverlay, isDesktopLike

class BikeDetailsPage extends StatefulWidget {
  const BikeDetailsPage({Key? key, required this.bike, required this.onBook})
    : super(key: key);

  final Bike bike;
  final void Function(BuildContext ctx, Bike bike) onBook;

  static const route = '/bike-details';

  @override
  State<BikeDetailsPage> createState() => _BikeDetailsPageState();
}

class _BikeDetailsPageState extends State<BikeDetailsPage> {
  final ScrollController _scroll = ScrollController();
  // Initialize at declaration to avoid LateInitializationError after hot-reload.
  final MouseFXController _fx = MouseFXController();
  final PageController _page = PageController();

  late List<String> _images; // main + up to 3 more (padded to 4)
  int _selected = 0;

  @override
  void initState() {
    super.initState();

    // Build: main + gallery; include main in thumbs and pad to exactly 4 boxes
    final main = widget.bike.imageUrl;
    final gallery = widget.bike.gallery
        .where((u) => u.startsWith('http'))
        .toList();

    final set = <String>[];
    if (main.isNotEmpty) set.add(main);
    for (final g in gallery) {
      if (!set.contains(g)) set.add(g);
    }
    _images = set.take(4).toList();
    while (_images.length < 4) {
      _images.add(main.isNotEmpty ? main : '');
    }
  }

  @override
  void didChangeDependencies() {
    // Pre-cache for smoother switching
    for (final u in _images) {
      if (u.startsWith('http')) {
        precacheImage(NetworkImage(u), context);
      }
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgGrad = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0F0F23), Color(0xFF1A1A3A), Color(0xFF2D2D5F)],
    );

    final size = MediaQuery.of(context).size;
    _fx.setScreen(size);
    final useFxCursor = isDesktopLike && size.width > 700;

    final content = Stack(
      children: [
        // Background
        Container(decoration: const BoxDecoration(gradient: bgGrad)),
        const Positioned.fill(child: ParticlesLayer(count: 55)),
        const Positioned.fill(
          child: ParallaxLayer(
            depth: 10,
            child: QuantumParticlesLayer(count: 30),
          ),
        ),

        // Content
        CustomScrollView(
          controller: _scroll,
          slivers: [
            // Glassy AppBar (stays dark, not white)
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              toolbarHeight: 64,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.22),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(widget.bike.name, overflow: TextOverflow.ellipsis),
            ),

            // Body
            SliverToBoxAdapter(
              child: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final isWide = c.maxWidth >= 960;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: isWide ? _wideLayout() : _narrowLayout(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        if (useFxCursor) const Positioned.fill(child: MouseFXOverlay()),
      ],
    );

    // Pointer tracking for fancy cursor
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
        child: content,
      ),
    );

    return MouseFX(
      controller: _fx,
      child: Scaffold(backgroundColor: Colors.transparent, body: tracked),
    );
  }

  // ============================ Layouts ============================

  Widget _wideLayout() {
    final specs = _inferSpecs(widget.bike.details);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: gallery
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroPager(
                    controller: _page,
                    images: _images,
                    onChanged: (i) => setState(() => _selected = i),
                  ),
                  const SizedBox(height: 12),
                  _ThumbStrip(
                    images: _images,
                    selected: _selected,
                    onTap: (i) {
                      setState(() => _selected = i);
                      _page.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right: info
            Expanded(
              flex: 5,
              child: _InfoPanel(
                bike: widget.bike,
                onBook: () => widget.onBook(context, widget.bike),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _SpecsSection(items: specs),
      ],
    );
  }

  Widget _narrowLayout() {
    final specs = _inferSpecs(widget.bike.details);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroPager(
          controller: _page,
          images: _images,
          onChanged: (i) => setState(() => _selected = i),
        ),
        const SizedBox(height: 12),
        _ThumbStrip(
          images: _images,
          selected: _selected,
          onTap: (i) {
            setState(() => _selected = i);
            _page.animateToPage(
              i,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
            );
          },
        ),
        const SizedBox(height: 18),
        _InfoPanel(
          bike: widget.bike,
          onBook: () => widget.onBook(context, widget.bike),
        ),
        const SizedBox(height: 22),
        _SpecsSection(items: specs),
      ],
    );
  }

  // ===================== Specs parser =====================

  List<_SpecItem> _inferSpecs(String detailsRaw) {
    final d = (detailsRaw).toLowerCase();

    String? first(RegExp r, {int group = 1}) {
      final m = r.firstMatch(d);
      return m == null ? null : m.group(group);
    }

    String lifespan = 'Extended Durability';
    final y = first(RegExp(r'(\d+)\s*(?:year|yr|yrs|years)'));
    if (y != null) lifespan = '$y Years';

    String battery = '—';
    if (d.contains('graphene')) {
      battery = 'Graphene Battery';
    } else {
      final b = first(RegExp(r'battery(?:\s*type|\s*power)?[:\s]+([^.,\n]+)'));
      if (b != null) battery = b.trim();
    }

    String charging = '—';
    final ch = first(
      RegExp(
        r'(?:charging(?:\s*time)?[:\s]+)?(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours)\b',
      ),
    );
    if (ch != null) charging = '$ch Hours';

    String durable = 'Structure';
    if (d.contains('steel') || d.contains('alloy') || d.contains('frame')) {
      durable = 'Alloy/Steel Frame';
    }

    String range = '—';
    final rg = first(RegExp(r'range[:\s]+(\d+)\s*(?:km|kms|kilometers?)'));
    if (rg != null) range = '$rg KM';

    return [
      _SpecItem(
        icon: Icons.timelapse_rounded,
        title: 'Lifespan',
        value: lifespan,
      ),
      _SpecItem(
        icon: Icons.battery_charging_full_rounded,
        title: 'Battery',
        value: battery,
      ),
      _SpecItem(
        icon: Icons.ev_station_rounded,
        title: 'Charging',
        value: charging,
      ),
      _SpecItem(
        icon: Icons.view_in_ar_rounded,
        title: 'Durable',
        value: durable,
      ),
      _SpecItem(icon: Icons.speed_rounded, title: 'Range', value: range),
    ];
  }
}

// ============================= UI =============================

class _HeroPager extends StatelessWidget {
  const _HeroPager({
    required this.controller,
    required this.images,
    required this.onChanged,
  });

  final PageController controller;
  final List<String> images;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: PageView.builder(
          controller: controller,
          itemCount: images.length,
          physics: const BouncingScrollPhysics(),
          onPageChanged: onChanged,
          itemBuilder: (_, i) => _FadingNetworkImage(url: images[i]),
        ),
      ),
    );
  }
}

class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({
    required this.images,
    required this.selected,
    required this.onTap,
  });
  final List<String> images;
  final int selected;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final url = images[i];
          final sel = i == selected;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 142,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sel
                      ? const Color(0xFF60A5FA)
                      : Colors.white.withOpacity(0.10),
                  width: sel ? 2 : 1,
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x113B82F6), Color(0x00000000)],
                ),
                color: Colors.white.withOpacity(0.03),
                boxShadow: sel
                    ? const [
                        BoxShadow(
                          color: Color(0x332EA8FF),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: _FadingNetworkImage(url: url),
            ),
          );
        },
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.bike, required this.onBook});
  final Bike bike;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332EA8FF),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bike.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            bike.price,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          if (bike.details.isNotEmpty) ...[
            Text(
              'Details',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              bike.details,
              softWrap: true,
              style: TextStyle(color: Colors.white.withOpacity(0.95)),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Book Now',
                    style: TextStyle(
                      color: Color(0xFF0F0F23),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================= Specs (responsive) =======================

class _SpecItem {
  final IconData icon;
  final String title;
  final String value;
  const _SpecItem({
    required this.icon,
    required this.title,
    required this.value,
  });
}

class _SpecsSection extends StatelessWidget {
  const _SpecsSection({required this.items});
  final List<_SpecItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TECHNICAL SPECIFICATIONS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cross = w >= 1100
                ? 5
                : w >= 880
                ? 4
                : w >= 640
                ? 3
                : w >= 420
                ? 2
                : 1;
            return GridView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cross,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 2.8,
              ),
              itemBuilder: (context, i) => _SpecCard(item: items[i]),
            );
          },
        ),
      ],
    );
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({required this.item});
  final _SpecItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        color: Colors.white.withOpacity(0.035),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x113B82F6), Color(0x00000000)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A2EA8FF),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x223B82F6),
              border: Border.all(color: const Color(0x443B82F6)),
            ),
            child: Icon(item.icon, size: 22, color: const Color(0xFF60A5FA)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF60A5FA),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(color: Colors.white.withOpacity(0.90)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Image helpers =====================

class _FadingNetworkImage extends StatelessWidget {
  const _FadingNetworkImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || !url.startsWith('http')) return _placeholder();
    return Image.network(
      url,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (_, __, ___) => _placeholder(),
      loadingBuilder: (context, child, evt) {
        if (evt == null) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black26),
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        );
      },
    );
  }

  Widget _placeholder() => Container(
    color: Colors.black26,
    alignment: Alignment.center,
    child: const Icon(Icons.image_not_supported_outlined, size: 42),
  );
}
