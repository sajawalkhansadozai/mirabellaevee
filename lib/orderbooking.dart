// orderbooking.dart
import 'dart:ui'; // for ImageFilter blur
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' as fb;

import 'fx_shared.dart';
import 'widgets_shared.dart';
import 'bike_details_page.dart'; // NEW: details screen

class OrderPage extends StatefulWidget {
  static const route = '/order';
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  late final MouseFXController _fx;
  final ScrollController _scroll = ScrollController();

  // Firestore collections
  CollectionReference<Map<String, dynamic>> get _bikesCol =>
      FirebaseFirestore.instance.collection('bikes');
  CollectionReference<Map<String, dynamic>> get _ordersCol =>
      FirebaseFirestore.instance.collection('orders');

  bool get _firebaseReady {
    try {
      return fb.Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _fx = MouseFXController();
  }

  @override
  void dispose() {
    _scroll.dispose();
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

    final page = Stack(
      children: [
        // background + particles
        Container(decoration: const BoxDecoration(gradient: bgGrad)),
        const Positioned.fill(child: ParticlesLayer(count: 55)),
        const Positioned.fill(
          child: ParallaxLayer(
            depth: 10,
            child: QuantumParticlesLayer(count: 30),
          ),
        ),

        // content
        CustomScrollView(
          controller: _scroll,
          slivers: [
            // Glassy AppBar
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 72,
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
              title: const Logo(),
              actions: [
                if (_firebaseReady)
                  StreamBuilder<User?>(
                    stream: FirebaseAuth.instance.authStateChanges(),
                    builder: (context, snap) {
                      final user = snap.data;
                      if (user == null) {
                        return IconButton(
                          tooltip: 'Admin sign in',
                          icon: const Icon(Icons.lock_open_rounded),
                          onPressed: () => _showAdminLoginDialog(context),
                        );
                      }
                      return Row(
                        children: [
                          // Orders panel button (admin only)
                          IconButton(
                            tooltip: 'View Orders',
                            icon: const Icon(Icons.list_alt_rounded),
                            onPressed: () => _openOrdersPanel(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user.email ?? 'Admin',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Sign out',
                            icon: const Icon(Icons.logout_rounded),
                            onPressed: () => FirebaseAuth.instance.signOut(),
                          ),
                        ],
                      );
                    },
                  )
                else
                  IconButton(
                    tooltip:
                        'Admin disabled (Firebase not initialized in main.dart)',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Admin features are disabled because Firebase is not initialized.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_outline_rounded),
                  ),
                const SizedBox(width: 8),
              ],
            ),

            // Header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: Column(
                  children: [
                    SectionTitle('Order Now'),
                    SizedBox(height: 10),
                    Text(
                      'Choose your EVEE and proceed to booking.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

            // Bikes grid (live from Firestore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final cross = c.maxWidth < 720
                            ? 1
                            : c.maxWidth < 1024
                            ? 2
                            : 3;

                        if (!_firebaseReady) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              _FirebaseNotReadyBanner(),
                              SizedBox(height: 16),
                              _EmptyCatalogDisabled(),
                            ],
                          );
                        }

                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: _bikesCol
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            if (snap.hasError) {
                              return Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text('Error: ${snap.error}'),
                              );
                            }
                            final docs = snap.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return _EmptyCatalog(
                                onAdminAdd: () => _maybeOpenAddDialog(context),
                              );
                            }

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cross,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20,
                                    childAspectRatio: c.maxWidth < 380
                                        ? 0.75
                                        : 0.86,
                                  ),
                              itemCount: docs.length,
                              itemBuilder: (context, i) {
                                final b = Bike.fromDoc(docs[i]);
                                return _BikeCard(
                                  bike: b,
                                  // UPDATED: push full page instead of dialog
                                  onViewDetails: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => BikeDetailsPage(
                                          bike: b,
                                          onBook: (ctx, bike) =>
                                              _openBookingDialog(ctx, bike),
                                        ),
                                      ),
                                    );
                                  },
                                  onBook: () => _openBookingDialog(context, b),
                                  onEdit: () =>
                                      _maybeOpenEditDialog(context, b),
                                  onDelete: () => _maybeDeleteBike(context, b),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // Footer line
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20,
                ),
                child: Center(
                  child: Text(
                    '© 2025 EVEE Bikes. All rights reserved.',
                    style: TextStyle(color: Colors.white.withOpacity(0.65)),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Admin FAB (only visible when signed in and Firebase ready)
        Positioned(
          right: 20,
          bottom: 24,
          child: !_firebaseReady
              ? const SizedBox.shrink()
              : StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, snap) {
                    if (snap.data == null) return const SizedBox.shrink();
                    return FloatingActionButton.extended(
                      onPressed: () => _openAddOrEditDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Bike'),
                    );
                  },
                ),
        ),

        if (useFxCursor) const Positioned.fill(child: MouseFXOverlay()),
      ],
    );

    // pointer tracking (same as main)
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
        child: page,
      ),
    );

    return MouseFX(
      controller: _fx,
      child: Scaffold(
        resizeToAvoidBottomInset:
            true, // ✅ keeps content visible when the keyboard opens
        body: tracked,
      ),
    );
  }

  // ---------------- Admin helpers ----------------

  Future<void> _showAdminLoginDialog(BuildContext context) async {
    if (!_firebaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Firebase not initialized. Initialize Firebase in main.dart to use Admin.',
          ),
        ),
      );
      return;
    }

    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) {
        return _GlassDialog(
          title: Row(
            children: const [
              Icon(Icons.lock_rounded, size: 18),
              SizedBox(width: 8),
              Flexible(child: Text('Admin Sign In')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FxTextField(
                controller: emailCtrl,
                label: 'Email',
                hint: 'admin@yourdomain.com',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              _FxTextField(
                controller: passCtrl,
                label: 'Password',
                icon: Icons.password_rounded,
                obscureText: true,
              ),
              const SizedBox(height: 6),
              Row(
                children: const [
                  Icon(Icons.info_outline, size: 14, color: Colors.white70),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Only authorized admins can add, edit or delete bikes.',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            _GhostButton(text: 'Cancel', onTap: () => Navigator.pop(context)),
            _PrimaryButton(
              text: 'Sign in',
              onTap: () async {
                try {
                  await FirebaseAuth.instance.signInWithEmailAndPassword(
                    email: emailCtrl.text.trim(),
                    password: passCtrl.text.trim(),
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _maybeOpenAddDialog(BuildContext context) {
    if (!_firebaseReady) {
      _showAdminLoginDialog(context);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showAdminLoginDialog(context);
    } else {
      _openAddOrEditDialog(context);
    }
  }

  void _maybeOpenEditDialog(BuildContext context, Bike b) {
    if (!_firebaseReady) {
      _showAdminLoginDialog(context);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showAdminLoginDialog(context);
    } else {
      _openAddOrEditDialog(context, existing: b);
    }
  }

  Future<void> _maybeDeleteBike(BuildContext context, Bike b) async {
    if (!_firebaseReady) return _showAdminLoginDialog(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _showAdminLoginDialog(context);

    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => _GlassDialog(
        title: Row(
          children: const [
            Icon(Icons.delete_forever_rounded, size: 18),
            SizedBox(width: 8),
            Flexible(child: Text('Delete bike?')),
          ],
        ),
        content: Text(
          'This will permanently remove the bike.',
          style: TextStyle(color: Colors.white.withOpacity(0.9)),
        ),
        actions: [
          _GhostButton(
            text: 'Cancel',
            onTap: () => Navigator.pop(context, false),
          ),
          _DangerButton(
            text: 'Delete',
            onTap: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _bikesCol.doc(b.id).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted "${b.name}".')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _openAddOrEditDialog(
    BuildContext context, {
    Bike? existing,
  }) async {
    if (!_firebaseReady) {
      _showAdminLoginDialog(context);
      return;
    }

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing?.price ?? '');
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    // Optional extra images (up to 3)
    final g = existing?.gallery ?? const <String>[];
    final image2Ctrl = TextEditingController(text: g.isNotEmpty ? g[0] : '');
    final image3Ctrl = TextEditingController(text: g.length > 1 ? g[1] : '');
    final image4Ctrl = TextEditingController(text: g.length > 2 ? g[2] : '');
    // NEW: details field
    final detailsCtrl = TextEditingController(text: existing?.details ?? '');
    final isEdit = existing != null;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return _GlassDialog(
              title: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit_rounded : Icons.add_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(isEdit ? 'Edit Bike' : 'Add Bike')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FxTextField(
                    controller: nameCtrl,
                    label: 'Name',
                    icon: Icons.directions_bike_rounded,
                  ),
                  const SizedBox(height: 10),
                  _FxTextField(
                    controller: priceCtrl,
                    label: 'Price (e.g., PKR 249,000)',
                    icon: Icons.sell_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  _FxTextField(
                    controller: detailsCtrl,
                    label: 'Details',
                    icon: Icons.description_rounded,
                    minLines: 3,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 10),
                  _FxTextField(
                    controller: imageCtrl,
                    label: 'Main Image URL',
                    hint:
                        'https://res.cloudinary.com/<cloud>/image/upload/.../main.jpg',
                    icon: Icons.link_rounded,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _PreviewCard(imageUrl: imageCtrl.text.trim()),
                  const SizedBox(height: 14),
                  // Extra images (optional)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'More images (optional)',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FxTextField(
                    controller: image2Ctrl,
                    label: 'Image 2 URL',
                    icon: Icons.image_rounded,
                  ),
                  const SizedBox(height: 8),
                  _FxTextField(
                    controller: image3Ctrl,
                    label: 'Image 3 URL',
                    icon: Icons.image_rounded,
                  ),
                  const SizedBox(height: 8),
                  _FxTextField(
                    controller: image4Ctrl,
                    label: 'Image 4 URL',
                    icon: Icons.image_rounded,
                  ),
                ],
              ),
              actions: [
                _GhostButton(
                  text: 'Cancel',
                  onTap: () => Navigator.pop(context),
                ),
                _PrimaryButton(
                  text: isEdit ? 'Save' : 'Add',
                  onTap: () async {
                    final name = nameCtrl.text.trim();
                    final price = priceCtrl.text.trim();
                    final url = imageCtrl.text.trim();

                    if (name.isEmpty || price.isEmpty || !_looksLikeUrl(url)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please fill all fields with a valid https image URL.',
                          ),
                        ),
                      );
                      return;
                    }

                    // Gather gallery (filter empties)
                    final gallery = [
                      image2Ctrl.text.trim(),
                      image3Ctrl.text.trim(),
                      image4Ctrl.text.trim(),
                    ].where((s) => s.startsWith('http')).toList();

                    try {
                      if (isEdit) {
                        await _bikesCol.doc(existing!.id).update({
                          'name': name,
                          'price': price,
                          'imageUrl': url,
                          'gallery': gallery,
                          'details': detailsCtrl.text.trim(), // NEW
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                      } else {
                        await _bikesCol.add({
                          'name': name,
                          'price': price,
                          'imageUrl': url,
                          'gallery': gallery,
                          'details': detailsCtrl.text.trim(), // NEW
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      }
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Save failed: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------- Booking dialog (saves to Firestore: orders) ----------------

  Future<void> _openBookingDialog(BuildContext context, Bike bike) async {
    if (!_firebaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking disabled (no Firebase).')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    int qty = 1;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setD) {
            return _GlassDialog(
              title: Row(
                children: const [
                  Icon(Icons.shopping_bag_rounded, size: 18),
                  SizedBox(width: 8),
                  Flexible(child: Text('Complete your booking')),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SelectedBikeRow(bike: bike),
                      const SizedBox(height: 14),
                      _FxTextField(
                        controller: nameCtrl,
                        label: 'Full name',
                        icon: Icons.person_rounded,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      _FxTextField(
                        controller: emailCtrl,
                        label: 'Email address',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          if (s.isEmpty) return 'Required';
                          if (!s.contains('@') || !s.contains('.')) {
                            return 'Invalid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      _FxTextField(
                        controller: phoneCtrl,
                        label: 'Phone number',
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      _FxTextField(
                        controller: addressCtrl,
                        label: 'Address',
                        icon: Icons.home_rounded,
                        minLines: 2,
                        maxLines: 3,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      _QtyStepper(
                        qty: qty,
                        onMinus: qty > 1 ? () => setD(() => qty--) : null,
                        onPlus: () => setD(() => qty++),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                _GhostButton(
                  text: 'Cancel',
                  onTap: () => Navigator.pop(context),
                ),
                _PrimaryButton(
                  text: 'Done',
                  onTap: () async {
                    if (!formKey.currentState!.validate()) return;

                    try {
                      await _ordersCol.add({
                        // user info
                        'name': nameCtrl.text.trim(),
                        'email': emailCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                        'quantity': qty,

                        // bike snapshot
                        'bikeId': bike.id,
                        'bikeName': bike.name,
                        'bikePrice': bike.price,
                        'bikeImageUrl': bike.imageUrl,

                        'status': 'new',
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context); // close dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Order placed! Our team will contact you soon.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to place order: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------- URL validator (Cloudinary-friendly) ----------

  bool _looksLikeUrl(String s) {
    if (!s.startsWith('https://')) return false;

    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return false;

    // Cloudinary
    if (uri.host.endsWith('res.cloudinary.com')) return true;

    // Common CDNs that often serve images with query params
    if (uri.host.contains('firebasestorage.googleapis.com')) return true;
    if (uri.host.contains('images.unsplash.com')) return true;
    if (uri.host.startsWith('cdn.') || uri.host.contains('.cdn.')) return true;

    // Fallback: allow typical image extensions
    final p = uri.path.toLowerCase();
    return p.endsWith('.png') ||
        p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.webp') ||
        p.endsWith('.gif');
  }

  // ---------------- Orders panel (admin) ----------------

  Future<void> _openOrdersPanel(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (!_firebaseReady || user == null) {
      _showAdminLoginDialog(context);
      return;
    }

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final maxH = size.height * 0.88;
        final maxW = size.width < 600 ? size.width - 24 : 960.0;

        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.transparent,
          child: SafeArea(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                    boxShadow: const [
                      // bluish glow
                      BoxShadow(
                        color: Color(0x332EA8FF),
                        blurRadius: 32,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxW,
                      maxHeight: maxH,
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.list_alt_rounded, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Orders',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const Spacer(),
                              _GhostButton(
                                text: 'Close',
                                onTap: () => Navigator.pop(context),
                                dense: true,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _ordersCol
                                .orderBy('createdAt', descending: true)
                                .snapshots(),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snap.hasError) {
                                return Center(
                                  child: Text(
                                    'Error loading orders: ${snap.error}',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                );
                              }
                              final orders = snap.data?.docs ?? [];
                              if (orders.isEmpty) {
                                return const Center(
                                  child: Text('No orders yet.'),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: orders.length,
                                separatorBuilder: (_, __) => Divider(
                                  color: Colors.white.withOpacity(0.06),
                                ),
                                itemBuilder: (context, i) {
                                  final d = orders[i];
                                  final data = d.data();
                                  final name = (data['name'] ?? '').toString();
                                  final email = (data['email'] ?? '')
                                      .toString();
                                  final phone = (data['phone'] ?? '')
                                      .toString();
                                  final address = (data['address'] ?? '')
                                      .toString();
                                  final qty = data['quantity'] ?? 1;

                                  final bikeName = (data['bikeName'] ?? '')
                                      .toString();
                                  final bikePrice = (data['bikePrice'] ?? '')
                                      .toString();
                                  final bikeImg = (data['bikeImageUrl'] ?? '')
                                      .toString();

                                  final status = (data['status'] ?? 'new')
                                      .toString();

                                  return ListTile(
                                    isThreeLine: true,
                                    contentPadding: const EdgeInsets.all(8),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: SizedBox(
                                        width: 72,
                                        height: 40,
                                        child: _NetworkImageOrPlaceholder(
                                          url: bikeImg,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      '$name  •  $phone',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          address,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Bike: $bikeName  —  $bikePrice  —  Qty: $qty',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (v) async {
                                        if (v == 'delete') {
                                          await _ordersCol.doc(d.id).delete();
                                        } else {
                                          await _ordersCol.doc(d.id).update({
                                            'status': v,
                                          });
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'new',
                                          child: Text('Mark as New'),
                                        ),
                                        PopupMenuItem(
                                          value: 'processing',
                                          child: Text('Mark as Processing'),
                                        ),
                                        PopupMenuItem(
                                          value: 'done',
                                          child: Text('Mark as Done'),
                                        ),
                                        PopupMenuDivider(),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete Order'),
                                        ),
                                      ],
                                      child: Chip(label: Text(status)),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------- Models & UI ----------------

class Bike {
  final String id;
  final String name;
  final String price;
  final String imageUrl;
  final List<String> gallery; // up to 3 extra images (optional)
  final String details; // NEW

  Bike({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.gallery,
    required this.details, // NEW
  });

  factory Bike.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    final mainUrl = (data['imageUrl'] ?? '').toString();

    List<String> _urls(dynamic v) {
      if (v is List) {
        return v
            .map((e) => e?.toString() ?? '')
            .where((s) => s.startsWith('http'))
            .cast<String>()
            .toList();
      }
      return const [];
    }

    // Prefer 'gallery' array; also read common alt fields for backward compat.
    final gallery = <String>{}
      ..addAll(_urls(data['gallery']))
      ..addAll(_urls(data['images']))
      ..addAll(_urls(data['extraImages']));

    for (final k in const ['image2', 'image3', 'image4']) {
      final v = (data[k] ?? '').toString();
      if (v.startsWith('http')) gallery.add(v);
    }

    // Remove duplicates / main image
    final cleaned = gallery.where((u) => u != mainUrl).toList();

    // Keep at most 3 extras
    final top3 = cleaned.take(3).toList();

    // NEW: support multiple possible keys for details
    final details =
        (data['details'] ?? data['detail'] ?? data['description'] ?? '')
            .toString();

    return Bike(
      id: d.id,
      name: (data['name'] ?? '').toString(),
      price: (data['price'] ?? '').toString(),
      imageUrl: mainUrl,
      gallery: top3,
      details: details, // NEW
    );
  }
}

class _FirebaseNotReadyBanner extends StatelessWidget {
  const _FirebaseNotReadyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.35)),
      ),
      child: const Text(
        'Firebase is not initialized. Admin login and dynamic catalog are disabled. '
        'Initialize Firebase in main.dart to enable.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _EmptyCatalogDisabled extends StatelessWidget {
  const _EmptyCatalogDisabled();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      child: Column(
        children: const [
          Icon(Icons.inventory_2_outlined, size: 54, color: Colors.white70),
          SizedBox(height: 12),
          Text(
            'Catalog unavailable',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          SizedBox(height: 6),
          Text(
            'Initialize Firebase to load bikes from Firestore.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.onAdminAdd});
  final VoidCallback onAdminAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 54,
            color: Colors.white70,
          ),
          const SizedBox(height: 12),
          const Text(
            'No bikes yet',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Admin can add bikes using the button below.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAdminAdd,
            icon: const Icon(Icons.lock_rounded),
            label: const Text('Admin sign in to add'),
          ),
        ],
      ),
    );
  }
}

class _BikeCard extends StatelessWidget {
  const _BikeCard({
    required this.bike,
    required this.onViewDetails,
    required this.onBook,
    required this.onEdit,
    required this.onDelete,
  });

  final Bike bike;
  final VoidCallback onViewDetails;
  final VoidCallback onBook;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          // bluish glow
          BoxShadow(
            color: const Color(0xFF2EA8FF).withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clickable header (image + name + price) -> details page
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onViewDetails,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _NetworkImageOrPlaceholder(url: bike.imageUrl),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  bike.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  bike.price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.80)),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StreamBuilder<User?>(
                    stream: fb.Firebase.apps.isEmpty
                        ? const Stream<User?>.empty()
                        : FirebaseAuth.instance.authStateChanges(),
                    builder: (context, snap) {
                      if (snap.data == null) return const SizedBox.shrink();
                      return Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_rounded),
                            onPressed: onEdit,
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_rounded),
                            onPressed: onDelete,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              // UPDATED: Check Details button (navigates to details page)
              _GradientButton(text: 'Check Details', onTap: onViewDetails),
            ],
          ),
        ],
      ),
    );
  }
}

/// Simple network image with graceful fallback (+ progress)
class _NetworkImageOrPlaceholder extends StatelessWidget {
  const _NetworkImageOrPlaceholder({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || !url.startsWith('http')) {
      return _placeholder();
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, event) {
        if (event == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (c, e, s) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    color: Colors.black26,
    alignment: Alignment.center,
    child: const Icon(Icons.image_not_supported_outlined, size: 42),
  );
}

/// Gradient CTA matching your main page style (BLUISH)
class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const height = 44.0;
    const width = 160.0;
    final radius = BorderRadius.circular(height / 2);

    return ConstrainedBox(
      constraints: const BoxConstraints.tightFor(width: width, height: height),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF3B82F6),
                  Color(0xFF60A5FA),
                ], // blue → light blue
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332EA8FF), // soft blue glow
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF0F0F23),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////////
// Pretty UI building blocks (glassy dialogs, inputs, preview, qty stepper)
///////////////////////////////////////////////////////////////////////////////

class _GlassDialog extends StatelessWidget {
  const _GlassDialog({
    required this.title,
    required this.content,
    required this.actions,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = size.width < 600 ? size.width - 24 : 560.0;
    final maxH = size.height * 0.88;

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            // keeps the whole dialog above the keyboard
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x332EA8FF), // bluish glass glow
                          blurRadius: 30,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [Expanded(child: title)],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ✅ Keyboard-aware, scrollable content
                        Flexible(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final bottomInset = MediaQuery.of(
                                context,
                              ).viewInsets.bottom;
                              return SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(
                                  bottom: bottomInset + 16,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                    // avoid over-expansion; let content scroll
                                    maxHeight: constraints.maxHeight - 24,
                                  ),
                                  child: content,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Wrap actions so they don't overflow on small screens
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 10,
                            runSpacing: 8,
                            children: actions,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FxTextField extends StatelessWidget {
  const _FxTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? minLines;
  final int maxLines;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final base = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
    );
    final focused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Color(0xFF60A5FA),
        width: 1.5,
      ), // blue focus
    );

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      // ✅ better keyboard flow: next for single-line, newline for multi-line
      textInputAction: maxLines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        enabledBorder: base,
        border: base,
        focusedBorder: focused,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth == double.infinity ? 300.0 : c.maxWidth;
        return Container(
          width: w,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
            color: Colors.white.withOpacity(0.03),
          ),
          clipBehavior: Clip.antiAlias,
          child: _NetworkImageOrPlaceholder(url: imageUrl),
        );
      },
    );
  }
}

class _SelectedBikeRow extends StatelessWidget {
  const _SelectedBikeRow({required this.bike});
  final Bike bike;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 96,
            height: 54,
            child: _NetworkImageOrPlaceholder(url: bike.imageUrl),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bike.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                bike.price,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, this.onMinus, this.onPlus});

  final int qty;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.remove_rounded),
            onPressed: onMinus,
            tooltip: 'Decrease',
          ),
          const SizedBox(width: 8),
          Text(
            '$qty',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(width: 8),
          IconButton(
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.add_rounded),
            onPressed: onPlus,
            tooltip: 'Increase',
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.text,
    required this.onTap,
    this.dense = false,
  });
  final String text;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final pad = dense
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: pad,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(text),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style:
          ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ).merge(
            ButtonStyle(
              overlayColor: MaterialStateProperty.all(
                Colors.white.withOpacity(0.05),
              ),
            ),
          ),
      child: Ink(
        decoration: BoxDecoration(
          // BLUISH gradient for primary actions
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF0F0F23),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5A5A), Color(0xFFFF8A8A)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: const Text(
            'Delete',
            style: TextStyle(
              color: Color(0xFF0F0F23),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
