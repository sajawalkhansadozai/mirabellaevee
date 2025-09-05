// orderbooking.dart
// ignore_for_file: unused_element, unused_element_parameter

import 'dart:typed_data';
import 'dart:ui'; // for ImageFilter blur
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' as fb;
// NOTE: storage upload removed (text-only storage now)
// import 'package:firebase_storage/firebase_storage.dart' as fbs;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'fx_shared.dart';
import 'widgets_shared.dart';
import 'bike_details_page.dart'; // details screen

// Use central Bike model and re-export for backward compatibility
import 'models/bike.dart';
export 'models/bike.dart' show Bike;

/// ===============================
/// Reusable PDF builders (bytes)
/// (used for printing only; not stored)
/// ===============================

Future<Uint8List> buildInvoicePdfBytes({
  required Map<String, dynamic> orderData,
  required String invoiceNumber,
  required String date,
  required String chassis,
  required String engine,
  required String color,
}) async {
  final pdf = pw.Document();
  final black = PdfColor.fromInt(0xFF000000);

  // Load logos (2× size)
  final mirabellaLogo = pw.MemoryImage(
    (await rootBundle.load('assets/logo/mirabella.png')).buffer.asUint8List(),
  );
  final eveeLogo = pw.MemoryImage(
    (await rootBundle.load('assets/logo/evee.png')).buffer.asUint8List(),
  );

  // Keep only digits for Amount
  String _digitsOnly(dynamic v) =>
      (v ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');

  pw.TableRow row(String a, String b) => pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(a, style: const pw.TextStyle(fontSize: 10)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(b, style: const pw.TextStyle(fontSize: 10)),
      ),
    ],
  );

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 36, 24, 24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Logos + centered title block
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: 168,
                height: 84,
                child: pw.Image(mirabellaLogo, fit: pw.BoxFit.contain),
              ),
              pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    'EVEE MIRABELLA',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Mirabella Complex, E-18 Gulshan-e-Sehat, Islamabad',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Contact: 03350928668',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'INVOICE',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(
                width: 168,
                height: 84,
                child: pw.Image(eveeLogo, fit: pw.BoxFit.contain),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // Centered meta
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Invoice #: $invoiceNumber',
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Customer Name: ${orderData['name']}',
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Father Name: ${orderData['fatherName'] ?? '-'}',
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'CNIC #: ${orderData['cnic'] ?? '-'}',
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Address: ${orderData['address']}',
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Text('Date: $date', textAlign: pw.TextAlign.center),
              pw.Text(
                'Cell: ${orderData['phone']}',
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // Centered compact table (50/50 columns)
          pw.Center(
            child: pw.ConstrainedBox(
              constraints: const pw.BoxConstraints.tightFor(width: 460),
              child: pw.Table(
                border: pw.TableBorder.all(color: black, width: 0.8),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.black),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'DESCRIPTION',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'DETAIL',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  row('Model', (orderData['bikeName'] ?? '').toString()),
                  row('Year', '2025'),
                  row('Chassis #', chassis),
                  row('Engine #', engine),
                  row('Color', color),
                  // Amount: digits only (no Rs, commas, spaces)
                  row('Amount Rs.', _digitsOnly(orderData['bikePrice'])),
                  // Keep payment mode
                  row('Payment Mode (Cash/Credit card/Online)', 'Cash'),
                ],
              ),
            ),
          ),

          // Half-width signature lines (centered layout)
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              pw.Column(
                children: [
                  pw.SizedBox(height: 24),
                  pw.Container(width: 140, height: 1, color: black),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Customer Signature',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Column(
                children: [
                  pw.SizedBox(height: 24),
                  pw.Container(width: 140, height: 1, color: black),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Dealer Signature',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          // Terms (centered)
          pw.Text(
            'Terms & Conditions',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '1. Dealership will not be re-buying any product',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            '2. For after sales services call Evee Customer Support on +92 3280408254 and Helpline +92 304111257',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    ),
  );

  return pdf.save();
}

Future<Uint8List> buildChalanPdfBytes({
  required Map<String, dynamic> orderData,
  required String chalanNumber,
  required String date,
  required String chassis,
  required String engine,
  required String color,
}) async {
  final pdf = pw.Document();
  final black = PdfColor.fromInt(0xFF000000);

  // 2× logos
  final mirabellaLogo = pw.MemoryImage(
    (await rootBundle.load('assets/logo/mirabella.png')).buffer.asUint8List(),
  );
  final eveeLogo = pw.MemoryImage(
    (await rootBundle.load('assets/logo/evee.png')).buffer.asUint8List(),
  );

  pw.TableRow row(String a, String b) => pw.TableRow(
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(a, style: const pw.TextStyle(fontSize: 10)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(b, style: const pw.TextStyle(fontSize: 10)),
      ),
    ],
  );

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(24, 36, 24, 24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Logos + centered title block
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: 168,
                height: 84,
                child: pw.Image(mirabellaLogo, fit: pw.BoxFit.contain),
              ),
              pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    'EVEE MIRABELLA',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Mirabella Complex, E-18 Gulshan-e-Sehat, Islamabad',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    'Contact: 03350928668',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'DELIVERY CHALAN',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(
                width: 168,
                height: 84,
                child: pw.Image(eveeLogo, fit: pw.BoxFit.contain),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // Centered meta (CHALAN only)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'CHALAN #: $chalanNumber',
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Customer Name: ${orderData['name']}',
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Father Name: ${orderData['fatherName'] ?? '-'}',
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'CNIC #: ${orderData['cnic'] ?? '-'}',
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Address: ${orderData['address']}',
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 6),
              pw.Text('Date: $date', textAlign: pw.TextAlign.center),
              pw.Text(
                'Cell: ${orderData['phone']}',
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // Centered compact table (50/50 columns)
          pw.Center(
            child: pw.ConstrainedBox(
              constraints: const pw.BoxConstraints.tightFor(width: 460),
              child: pw.Table(
                border: pw.TableBorder.all(color: black, width: 0.8),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1),
                  1: pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.black),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'DESCRIPTION',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'DETAIL',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  row('Model', (orderData['bikeName'] ?? '').toString()),
                  row('Year', '2025'),
                  row('Chassis #', chassis),
                  row('Engine #', engine),
                  row('Color', color),
                ],
              ),
            ),
          ),

          // Half-width signature lines (centered layout)
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              pw.Column(
                children: [
                  pw.SizedBox(height: 24),
                  pw.Container(width: 140, height: 1, color: black),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Customer Signature',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Column(
                children: [
                  pw.SizedBox(height: 24),
                  pw.Container(width: 140, height: 1, color: black),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Dealer Signature',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          // T&C (centered)
          pw.Text(
            'Terms & Conditions',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '1. Dealership will not be responsible for any damages claimed after accepting the delivery',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            '2. For after sales services call Evee Customer Support on (+92 325 2292 290)',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    ),
  );

  return pdf.save();
}

/// Simple holder for one variant row inside the admin dialog
class _VariantRowData {
  final TextEditingController chassisCtrl;
  final TextEditingController engineCtrl;
  final TextEditingController colorCtrl;
  _VariantRowData({String chassis = '', String engine = '', String color = ''})
    : chassisCtrl = TextEditingController(text: chassis),
      engineCtrl = TextEditingController(text: engine),
      colorCtrl = TextEditingController(text: color);
}

class OrderPage extends StatefulWidget {
  static const route = '/order';
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  late final MouseFXController _fx;
  final ScrollController _scroll = ScrollController();

  // 🔐 Hidden admin login via 5 taps on logo (within 4 seconds)
  int _logoTapCount = 0;
  DateTime? _firstLogoTapAt;
  void _onLogoTap(BuildContext context) {
    final now = DateTime.now();
    if (_firstLogoTapAt == null ||
        now.difference(_firstLogoTapAt!) > const Duration(seconds: 4)) {
      _firstLogoTapAt = now;
      _logoTapCount = 1;
    } else {
      _logoTapCount++;
    }
    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      _firstLogoTapAt = null;
      _showAdminLoginDialog(context);
    }
  }

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

  /// ---------------- Numbering + TEXT helpers ----------------

  /// Atomically fetch next sequence value for a field and increment it.
  /// Uses document: meta/counters  (fields: invoice, chalan)
  Future<int> _nextSeq(String field) async {
    final ref = FirebaseFirestore.instance.collection('meta').doc('counters');
    return FirebaseFirestore.instance.runTransaction<int>((tx) async {
      final snap = await tx.get(ref);
      final data = (snap.data() ?? <String, dynamic>{});
      final current = (data[field] is num) ? (data[field] as num).toInt() : 1;
      final next = current + 1;
      tx.set(ref, {...data, field: next}, SetOptions(merge: true));
      return current; // assign current, then bump
    });
  }

  String _fmtInvoice(int n) => 'INV ${n.toString().padLeft(2, '0')}';
  String _fmtChalan(int n) => 'Mirabella/E-18/${n.toString().padLeft(3, '0')}';

  String _composeInvoiceText({
    required Map<String, dynamic> order,
    required String invoiceNumber,
    required String date,
    required String chassis,
    required String engine,
    required String color,
  }) {
    return '''
EVEE MIRABELLA
Mirabella Complex, E-18 Gulshan-e-Sehat, Islamabad
Contact: 03350928668

INVOICE
Invoice #: $invoiceNumber
Date: $date
Customer Name: ${order['name']}
Father Name: ${order['fatherName'] ?? '-'}
CNIC #: ${order['cnic'] ?? '-'}
Cell: ${order['phone']}
Address: ${order['address']}

DESCRIPTION               DETAIL
------------------------------------------------
Model                     ${(order['bikeName'] ?? '').toString()}
Year                      2025
Chassis #                 $chassis
Engine #                  $engine
Color                     $color
Amount Rs.                ${(order['bikePrice'] ?? '').toString()}
Payment Mode              Cash

Customer Signature                     Dealer Signature

Terms & Conditions
1. Dealership will not be re-buying any product
2. For after sales services call Evee Customer Support on +92 3280408254 and Helpline +92 304111257
''';
  }

  String _composeChalanText({
    required Map<String, dynamic> order,
    required String chalanNumber,
    required String date,
    required String chassis,
    required String engine,
    required String color,
  }) {
    return '''
EVEE MIRABELLA
Mirabella Complex, E-18 Gulshan-e-Sehat, Islamabad
Contact: 03350928668

DELIVERY CHALAN
CHALAN #: $chalanNumber
Date: $date
Customer Name: ${order['name']}
Father Name: ${order['fatherName'] ?? '-'}
CNIC #: ${order['cnic'] ?? '-'}
Cell: ${order['phone']}
Address: ${order['address']}

DESCRIPTION               DETAIL
------------------------------------------------
Model                     ${(order['bikeName'] ?? '').toString()}
Year                      2025
Chassis #                 $chassis
Engine #                  $engine
Color                     $color

Customer Signature                     Dealer Signature

Terms & Conditions
1. Dealership will not be responsible for any damages claimed after accepting the delivery
2. For after sales services call Evee Customer Support on (+92 325 2292 290)
''';
  }

  /// ---------------- Helpers ----------------

  String _safeFile(String s) => s.replaceAll(
    RegExp(r'[^\w\-.]+'),
    '_',
  ); // was used for storage; kept safe

  @override
  void initState() {
    super.initState();
    _fx = MouseFXController();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _fx.dispose(); // avoid leak
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
              // 🔽 Logo tappable: 5 taps -> admin login dialog
              title: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onLogoTap(context),
                child: const Logo(),
              ),
              // 🔼
              actions: [
                if (_firebaseReady)
                  StreamBuilder<User?>(
                    stream: FirebaseAuth.instance.authStateChanges(),
                    builder: (context, snap) {
                      final user = snap.data;

                      // Logged-out: no lock/open-lock button
                      if (user == null) {
                        return const SizedBox.shrink();
                      }

                      // Logged-in: show admin actions
                      return Row(
                        children: [
                          // Orders panel (admin only)
                          IconButton(
                            tooltip: 'View Orders',
                            icon: const Icon(Icons.list_alt_rounded),
                            onPressed: () => _openOrdersPanel(context),
                          ),
                          // NEW: Docs panel (invoice/chalan text)
                          IconButton(
                            tooltip: 'View Docs (Invoice & Chalan Text)',
                            icon: const Icon(Icons.description_rounded),
                            onPressed: () => _openDocsPanel(context),
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
                  // Firebase not initialized: don't show any lock button
                  const SizedBox.shrink(),
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
                                  // push full page instead of dialog
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
        // ⛔️ Do NOT resize page when keyboard appears
        resizeToAvoidBottomInset: false,
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
    // details field
    final detailsCtrl = TextEditingController(text: existing?.details ?? '');

    // ---------- load existing variants ----------
    final List<_VariantRowData> variantRows = [];
    if (existing != null) {
      try {
        final snap = await _bikesCol.doc(existing.id).get();
        final data = snap.data();
        final raw = (data?['variants'] as List?) ?? const [];
        for (final v in raw) {
          final m = Map<String, dynamic>.from(v as Map);
          variantRows.add(
            _VariantRowData(
              chassis: (m['chassis'] ?? '').toString(),
              engine: (m['engine'] ?? '').toString(),
              color: (m['color'] ?? '').toString(),
            ),
          );
        }
      } catch (_) {
        // ignore; start empty
      }
    }
    if (variantRows.isEmpty) {
      variantRows.add(_VariantRowData());
    }
    final isEdit = existing != null;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void addVariant() =>
                setDialogState(() => variantRows.add(_VariantRowData()));
            void removeVariant(int i) =>
                setDialogState(() => variantRows.removeAt(i));

            // ---------- Stacked layout for variants ----------
            Widget variantsSection() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  Row(
                    children: const [
                      Icon(Icons.build_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Variants (admin-only)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add any number of entries. Each row = one variant (Chassis, Engine, Color). These are hidden from customers.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),

                  Column(
                    children: List.generate(variantRows.length, (i) {
                      final row = variantRows[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.035),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            _FxTextField(
                              controller: row.chassisCtrl,
                              label: 'Chassis No',
                              icon: Icons.confirmation_number_rounded,
                            ),
                            const SizedBox(height: 8),
                            _FxTextField(
                              controller: row.engineCtrl,
                              label: 'Engine No',
                              icon: Icons.settings_rounded,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _FxTextField(
                                    controller: row.colorCtrl,
                                    label: 'Color',
                                    icon: Icons.color_lens_rounded,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed: variantRows.length > 1
                                      ? () => removeVariant(i)
                                      : null,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: addVariant,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Variant'),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              );
            }

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

                  // Variants editor
                  variantsSection(),
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

                    // Gather variants (skip fully empty rows)
                    final variants = variantRows
                        .map(
                          (r) => {
                            'chassis': r.chassisCtrl.text.trim(),
                            'engine': r.engineCtrl.text.trim(),
                            'color': r.colorCtrl.text.trim(),
                          },
                        )
                        .where(
                          (m) =>
                              (m['chassis'] as String).isNotEmpty ||
                              (m['engine'] as String).isNotEmpty ||
                              (m['color'] as String).isNotEmpty,
                        )
                        .toList();

                    try {
                      if (isEdit) {
                        await _bikesCol.doc(existing!.id).update({
                          'name': name,
                          'price': price,
                          'imageUrl': url,
                          'gallery': gallery,
                          'details': detailsCtrl.text.trim(),
                          'variants': variants,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                      } else {
                        await _bikesCol.add({
                          'name': name,
                          'price': price,
                          'imageUrl': url,
                          'gallery': gallery,
                          'details': detailsCtrl.text.trim(),
                          'variants': variants,
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

  // ---------------- Booking dialog (saves order; no auth needed) ----------------
  Future<void> _openBookingDialog(BuildContext context, Bike bike) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final fatherCtrl = TextEditingController(); // NEW
    final cnicCtrl = TextEditingController(); // NEW
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    int qty = 1;

    String? _validateCnic(String? v) {
      final s = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      if (s.isEmpty) return 'Required';
      // accept 13 digits (basic)
      if (s.length != 13) return 'Enter 13-digit CNIC';
      return null;
    }

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
                        controller: fatherCtrl,
                        label: 'Father name',
                        icon: Icons.family_restroom_rounded,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      _FxTextField(
                        controller: cnicCtrl,
                        label: 'ID Card (CNIC) – 13 digits',
                        icon: Icons.badge_rounded,
                        keyboardType: TextInputType.number,
                        validator: _validateCnic,
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
                  text: 'Place Order',
                  onTap: () async {
                    if (!formKey.currentState!.validate()) return;

                    try {
                      await _createOrderPublic(
                        bike: bike,
                        name: nameCtrl.text.trim(),
                        fatherName: fatherCtrl.text.trim(), // NEW
                        cnic: cnicCtrl.text.trim(), // NEW
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        quantity: qty,
                      );

                      if (context.mounted) {
                        Navigator.pop(context); // close form
                        _showBookingReceivedDialog(context); // success bubble
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Order failed: $e')),
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

  /// Writes the order to Firestore WITHOUT requiring auth
  Future<String> _createOrderPublic({
    required Bike bike,
    required String name,
    required String fatherName, // NEW
    required String cnic, // NEW
    required String email,
    required String phone,
    required String address,
    required int quantity,
  }) async {
    final doc = await _ordersCol.add({
      'name': name,
      'fatherName': fatherName, // NEW
      'cnic': cnic, // NEW
      'email': email,
      'phone': phone,
      'address': address,
      'quantity': quantity,
      'bikeId': bike.id,
      'bikeName': bike.name,
      'bikePrice': bike.price,
      'bikeImageUrl': bike.imageUrl,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'web',
    });
    return doc.id;
  }

  // ---------------- Centered circular confirmation popup ----------------
  void _showBookingReceivedDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'Booking received',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, __, ___) {
        final scale = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(
          opacity: fade,
          child: Center(
            child: ScaleTransition(scale: scale, child: const _CircleSuccess()),
          ),
        );
      },
    );
  }

  // ---------- URL validator ----------
  bool _looksLikeUrl(String s) {
    if (!s.startsWith('https://')) return false;

    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return false;

    if (uri.host.endsWith('res.cloudinary.com')) return true;
    if (uri.host.contains('images.unsplash.com')) return true;
    if (uri.host.contains('firebasestorage.googleapis.com')) return true;
    if (uri.host.startsWith('cdn.') || uri.host.contains('.cdn.')) return true;

    final p = uri.path.toLowerCase();
    return p.endsWith('.png') ||
        p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.webp') ||
        p.endsWith('.gif');
  }

  // ---------------- Inquiry Dialog (auto-sync variant + exclude already-used)
  //                 -> TEXT storage + auto numbers
  // -------------------------------------------------------
  Future<void> _openInquiryDialog(
    BuildContext context,
    Map<String, dynamic> orderData,
    String orderId,
  ) async {
    // Get bike variants
    final bikeId = orderData['bikeId'] as String;
    final bikeSnap = await _bikesCol.doc(bikeId).get();
    final bikeData = bikeSnap.data();
    final rawVariants = (bikeData?['variants'] as List?) ?? [];

    if (rawVariants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No variants available for this bike')),
      );
      return;
    }

    // Load "already taken" variants by other orders for this bike
    final takenChassis = <String>{};
    final ordersForBike = await _ordersCol
        .where('bikeId', isEqualTo: bikeId)
        .get();

    for (final od in ordersForBike.docs) {
      if (od.id == orderId) continue; // allow re-open for same order
      final m = od.data();
      final c = (m['selectedChassis'] ?? m['chassis'] ?? '').toString();
      if (c.isNotEmpty) takenChassis.add(c);
    }

    // Normalize and filter out taken variants
    List<Map<String, String>> variants = rawVariants
        .map((v) {
          final m = Map<String, dynamic>.from(v as Map);
          return {
            'chassis': (m['chassis'] ?? '').toString(),
            'engine': (m['engine'] ?? '').toString(),
            'color': (m['color'] ?? '').toString(),
          };
        })
        .where(
          (v) =>
              v['chassis']!.isNotEmpty && !takenChassis.contains(v['chassis']!),
        )
        .toList();

    // Ensure order's previous selection remains available
    final ownSelectedChassis = (orderData['selectedChassis'] ?? '').toString();
    final ownSelectedEngine = (orderData['selectedEngine'] ?? '').toString();
    final ownSelectedColor = (orderData['selectedColor'] ?? '').toString();
    if (ownSelectedChassis.isNotEmpty &&
        !variants.any((v) => v['chassis'] == ownSelectedChassis)) {
      variants = [
        {
          'chassis': ownSelectedChassis,
          'engine': ownSelectedEngine,
          'color': ownSelectedColor,
        },
        ...variants,
      ];
    }

    if (variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All variants for this bike are already assigned.'),
        ),
      );
      return;
    }

    String? selectedChassis = ownSelectedChassis.isNotEmpty
        ? ownSelectedChassis
        : null;
    String? selectedEngine = ownSelectedEngine.isNotEmpty
        ? ownSelectedEngine
        : null;
    String? selectedColor = ownSelectedColor.isNotEmpty
        ? ownSelectedColor
        : null;

    Map<String, String>? _findBy(String key, String? value) {
      if (value == null) return null;
      for (final v in variants) {
        if ((v[key] ?? '') == value) return v;
      }
      return null;
    }

    void _syncFromVariant(
      Map<String, String>? v,
      void Function(void Function()) setState,
    ) {
      if (v == null) return;
      setState(() {
        selectedChassis = v['chassis'];
        selectedEngine = v['engine'];
        selectedColor = v['color'];
      });
    }

    // Dropdown options (unique)
    final chassisOptions = variants.map((v) => v['chassis']!).toSet().toList();
    final engineOptions = variants.map((v) => v['engine']!).toSet().toList();
    final colorOptions = variants.map((v) => v['color']!).toSet().toList();

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return _GlassDialog(
              title: Row(
                children: const [
                  Icon(Icons.assignment_rounded, size: 18),
                  SizedBox(width: 8),
                  Flexible(child: Text('Order Inquiry')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Customer: ${orderData['name']}\nBike: ${orderData['bikeName']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Chassis Dropdown
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      color: Colors.white.withOpacity(0.04),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value:
                            selectedChassis != null &&
                                chassisOptions.contains(selectedChassis)
                            ? selectedChassis
                            : null,
                        hint: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Select Chassis Number'),
                        ),
                        isExpanded: true,
                        items: chassisOptions.map((chassis) {
                          return DropdownMenuItem<String>(
                            value: chassis,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(chassis),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          selectedChassis = value;
                          _syncFromVariant(_findBy('chassis', value), setState);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Engine Dropdown
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      color: Colors.white.withOpacity(0.04),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value:
                            selectedEngine != null &&
                                engineOptions.contains(selectedEngine)
                            ? selectedEngine
                            : null,
                        hint: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Select Engine Number'),
                        ),
                        isExpanded: true,
                        items: engineOptions.map((engine) {
                          return DropdownMenuItem<String>(
                            value: engine,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(engine),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          selectedEngine = value;
                          _syncFromVariant(_findBy('engine', value), setState);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Color Dropdown
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      color: Colors.white.withOpacity(0.04),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value:
                            selectedColor != null &&
                                colorOptions.contains(selectedColor)
                            ? selectedColor
                            : null,
                        hint: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Select Color'),
                        ),
                        isExpanded: true,
                        items: colorOptions.map((color) {
                          return DropdownMenuItem<String>(
                            value: color,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(color),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          selectedColor = value;
                          _syncFromVariant(_findBy('color', value), setState);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              (selectedChassis != null &&
                                  selectedEngine != null &&
                                  selectedColor != null)
                              ? () async {
                                  // Persist the chosen variant on the order so it is "taken"
                                  await _ordersCol.doc(orderId).update({
                                    'selectedChassis': selectedChassis,
                                    'selectedEngine': selectedEngine,
                                    'selectedColor': selectedColor,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                                  // Create + save Invoice TEXT & meta
                                  final now = DateTime.now();
                                  final dateStr =
                                      '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${(now.year % 100).toString().padLeft(2, '0')}';

                                  final seq = await _nextSeq('invoice');
                                  final invoiceNumber = _fmtInvoice(seq);

                                  final text = _composeInvoiceText(
                                    order: orderData
                                      ..addAll({
                                        'selectedChassis': selectedChassis,
                                        'selectedEngine': selectedEngine,
                                        'selectedColor': selectedColor,
                                      }),
                                    invoiceNumber: invoiceNumber,
                                    date: dateStr,
                                    chassis: selectedChassis!,
                                    engine: selectedEngine!,
                                    color: selectedColor!,
                                  );

                                  await _ordersCol.doc(orderId).update({
                                    'invoice': {
                                      'number': invoiceNumber,
                                      'dateStr': dateStr,
                                      'text': text,
                                    },
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Invoice saved as text in Firestore.',
                                        ),
                                      ),
                                    );
                                  }

                                  Navigator.pop(context);
                                  _generateInvoice(
                                    context,
                                    orderData,
                                    orderId,
                                    selectedChassis!,
                                    selectedEngine!,
                                    selectedColor!,
                                    invoiceNumber: invoiceNumber,
                                    dateStr: dateStr,
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.receipt_rounded),
                          label: const Text('Generate Invoice'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              (selectedChassis != null &&
                                  selectedEngine != null &&
                                  selectedColor != null)
                              ? () async {
                                  // Persist the chosen variant on the order so it is "taken"
                                  await _ordersCol.doc(orderId).update({
                                    'selectedChassis': selectedChassis,
                                    'selectedEngine': selectedEngine,
                                    'selectedColor': selectedColor,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                                  // Create + save Chalan TEXT & meta
                                  final now = DateTime.now();
                                  final dateStr =
                                      '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${(now.year % 100).toString().padLeft(2, '0')}';

                                  final seq = await _nextSeq('chalan');
                                  final chalanNumber = _fmtChalan(seq);

                                  final text = _composeChalanText(
                                    order: orderData
                                      ..addAll({
                                        'selectedChassis': selectedChassis,
                                        'selectedEngine': selectedEngine,
                                        'selectedColor': selectedColor,
                                      }),
                                    chalanNumber: chalanNumber,
                                    date: dateStr,
                                    chassis: selectedChassis!,
                                    engine: selectedEngine!,
                                    color: selectedColor!,
                                  );

                                  await _ordersCol.doc(orderId).update({
                                    'chalan': {
                                      'number': chalanNumber,
                                      'dateStr': dateStr,
                                      'text': text,
                                    },
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Delivery Chalan saved as text in Firestore.',
                                        ),
                                      ),
                                    );
                                  }

                                  Navigator.pop(context);
                                  _generateDeliveryChalan(
                                    context,
                                    orderData,
                                    orderId,
                                    selectedChassis!,
                                    selectedEngine!,
                                    selectedColor!,
                                    chalanNumber: chalanNumber,
                                    dateStr: dateStr,
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.local_shipping_rounded),
                          label: const Text('Generate Chalan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                _GhostButton(
                  text: 'Close',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------- Generate Invoice (uses provided number/date) ----------------
  Future<void> _generateInvoice(
    BuildContext context,
    Map<String, dynamic> orderData,
    String orderId,
    String chassis,
    String engine,
    String color, {
    required String invoiceNumber,
    required String dateStr,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => _InvoiceDialog(
        orderData: orderData,
        invoiceNumber: invoiceNumber,
        date: dateStr,
        chassis: chassis,
        engine: engine,
        color: color,
      ),
    );
  }

  // ---------------- Generate Delivery Chalan (uses provided number/date) ----------------
  Future<void> _generateDeliveryChalan(
    BuildContext context,
    Map<String, dynamic> orderData,
    String orderId,
    String chassis,
    String engine,
    String color, {
    required String chalanNumber,
    required String dateStr,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => _DeliveryChalanDialog(
        orderData: orderData,
        chalanNumber: chalanNumber,
        date: dateStr,
        chassis: chassis,
        engine: engine,
        color: color,
      ),
    );
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
                                        const SizedBox(height: 8),
                                        // Actions
                                        Row(
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: () =>
                                                  _openInquiryDialog(
                                                    context,
                                                    data,
                                                    d.id,
                                                  ),
                                              icon: const Icon(
                                                Icons.assignment_rounded,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'Inquiry',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF3B82F6,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                minimumSize: Size.zero,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            PopupMenuButton<String>(
                                              onSelected: (v) async {
                                                if (v == 'delete') {
                                                  await _ordersCol
                                                      .doc(d.id)
                                                      .delete();
                                                } else {
                                                  await _ordersCol
                                                      .doc(d.id)
                                                      .update({'status': v});
                                                }
                                              },
                                              itemBuilder: (context) => const [
                                                PopupMenuItem(
                                                  value: 'new',
                                                  child: Text('Mark as New'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'processing',
                                                  child: Text(
                                                    'Mark as Processing',
                                                  ),
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
                                              child: Chip(
                                                label: Text(status),
                                                labelStyle: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                                backgroundColor: status == 'new'
                                                    ? Colors.orange
                                                    : status == 'processing'
                                                    ? Colors.blue
                                                    : Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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

  // ---------------- NEW: Docs panel (Invoices & Chalans text) ----------------
  Future<void> _openDocsPanel(BuildContext context) async {
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
                              const Icon(Icons.description_rounded, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Docs (Invoices & Delivery Chalans)',
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
                                  child: Text('Error: ${snap.error}'),
                                );
                              }
                              final all = (snap.data?.docs ?? [])
                                  .map((d) => {'id': d.id, ...d.data()})
                                  .toList();

                              // Keep only those with invoice/chalan text
                              final docs = all
                                  .where(
                                    (m) =>
                                        (m['invoice']?['text'] ?? '')
                                            .toString()
                                            .trim()
                                            .isNotEmpty ||
                                        (m['chalan']?['text'] ?? '')
                                            .toString()
                                            .trim()
                                            .isNotEmpty,
                                  )
                                  .toList();

                              if (docs.isEmpty) {
                                return const Center(
                                  child: Text('No invoices or chalans yet.'),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.all(12),
                                separatorBuilder: (_, __) => Divider(
                                  color: Colors.white.withOpacity(0.06),
                                ),
                                itemCount: docs.length,
                                itemBuilder: (context, i) {
                                  final m = docs[i];
                                  final name = (m['name'] ?? '').toString();
                                  final phone = (m['phone'] ?? '').toString();
                                  final bike = (m['bikeName'] ?? '').toString();

                                  final inv =
                                      m['invoice'] as Map<String, dynamic>?;
                                  final ch =
                                      m['chalan'] as Map<String, dynamic>?;

                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.035),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.08),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.person, size: 16),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '$name  •  $phone  •  $bike',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            if ((inv?['text'] ?? '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty)
                                              OutlinedButton.icon(
                                                icon: const Icon(
                                                  Icons.receipt_long_rounded,
                                                ),
                                                label: Text(
                                                  'Invoice: ${inv?['number'] ?? '-'}',
                                                ),
                                                onPressed: () => _showTextDocDialog(
                                                  context,
                                                  title:
                                                      'Invoice — ${(inv?['number'] ?? '').toString()}',
                                                  text: (inv?['text'] ?? '')
                                                      .toString(),
                                                ),
                                              ),
                                            if ((ch?['text'] ?? '')
                                                .toString()
                                                .trim()
                                                .isNotEmpty)
                                              OutlinedButton.icon(
                                                icon: const Icon(
                                                  Icons.local_shipping_outlined,
                                                ),
                                                label: Text(
                                                  'Chalan: ${ch?['number'] ?? '-'}',
                                                ),
                                                onPressed: () => _showTextDocDialog(
                                                  context,
                                                  title:
                                                      'Delivery Chalan — ${(ch?['number'] ?? '').toString()}',
                                                  text: (ch?['text'] ?? '')
                                                      .toString(),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
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

  Future<void> _showTextDocDialog(
    BuildContext context, {
    required String title,
    required String text,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Invoice Dialog (A4 PDF printing) ----------------
class _InvoiceDialog extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final String invoiceNumber;
  final String date;
  final String chassis;
  final String engine;
  final String color;

  const _InvoiceDialog({
    required this.orderData,
    required this.invoiceNumber,
    required this.date,
    required this.chassis,
    required this.engine,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = size.width < 860 ? size.width - 24 : 800.0;
    final maxH = size.height * 0.88;

    // amount detail: numbers only (e.g., 99000)
    final amountOnly = (orderData['bikePrice'] ?? '').toString().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Invoice',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.black),
                  ),
                ],
              ),
            ),

            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.center, // center everything
                  children: [
                    // Logos + centered heading (2x logos)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset('assets/logo/mirabella.png', height: 100),
                        const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'EVEE MIRABELLA',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Mirabella Complex, E-18 Gulshan-e-Sehat, Islamabad',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Contact: 03350928668',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'INVOICE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        Image.asset('assets/logo/evee.png', height: 100),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Meta (centered block)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Invoice #: $invoiceNumber',
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Customer Name: ${orderData['name']}',
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Father Name: ${orderData['fatherName'] ?? '-'}',
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'CNIC #: ${orderData['cnic'] ?? '-'}',
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Address: ${orderData['address']}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text('Date: $date', textAlign: TextAlign.center),
                        Text(
                          'Cell: ${orderData['phone']}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Centered, narrower table with black header
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 520,
                          maxWidth: 560,
                        ),
                        child: Table(
                          border: TableBorder.all(color: Colors.black),
                          columnWidths: const {
                            0: FlexColumnWidth(1), // 50/50
                            1: FlexColumnWidth(1),
                          },
                          children: [
                            const TableRow(
                              decoration: BoxDecoration(color: Colors.black),
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'DESCRIPTION',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'DETAIL',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            _row(
                              'Model',
                              (orderData['bikeName'] ?? '').toString(),
                            ),
                            _row('Year', '2025'),
                            _row('Chassis #', chassis),
                            _row('Engine #', engine),
                            _row('Color', color),
                            _row('Amount Rs.', amountOnly), // numbers only
                            _row(
                              'Payment Mode (Cash/Credit card/Online)',
                              'Cash',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Signature area (centered, half-width lines)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: const [
                        _SigBlock(label: 'Customer Signature'),
                        _SigBlock(label: 'Dealer Signature'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Terms
                    const Text(
                      'Terms & Conditions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const Text(
                      '1. Dealership will not be re-buying any product',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.black),
                    ),
                    const Text(
                      '2. For after sales services call Evee Customer Support on +92 3280408254 and Helpline +92 304111257',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _printInvoicePdf,
                    icon: const Icon(Icons.print),
                    label: const Text('Print Invoice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TableRow _row(String a, String b) => TableRow(
    children: [
      const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
          '', // will be replaced below via LayoutBuilder trick if needed
        ),
      ),
      const Padding(padding: EdgeInsets.all(8.0), child: Text('')),
    ],
  );

  Future<void> _printInvoicePdf() async {
    final bytes = await buildInvoicePdfBytes(
      orderData: orderData,
      invoiceNumber: invoiceNumber,
      date: date,
      chassis: chassis,
      engine: engine,
      color: color,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'invoice_$invoiceNumber.pdf',
    );
  }
}

// Small helper to render the centered signature line + label
class _SigBlock extends StatelessWidget {
  final String label;
  const _SigBlock({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SizedBox(height: 24),
        SizedBox(width: 140, height: 1, child: ColoredBox(color: Colors.black)),
        SizedBox(height: 4),
        // Use label via parent Text
      ],
    );
  }
}

// ---------------- Delivery Chalan Dialog (A4 PDF printing) ----------------
class _DeliveryChalanDialog extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final String chalanNumber;
  final String date;
  final String chassis;
  final String engine;
  final String color;

  const _DeliveryChalanDialog({
    required this.orderData,
    required this.chalanNumber,
    required this.date,
    required this.chassis,
    required this.engine,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxW = size.width < 860 ? size.width - 24 : 800.0;
    final maxH = size.height * 0.88;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Delivery Chalan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.black),
                  ),
                ],
              ),
            ),

            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.center, // ⬅ center everything
                  children: [
                    // ── Logos left/right + centered headings (2x logos) ────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/logo/mirabella.png',
                          height: 100, // 2x bigger
                        ),
                        const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'EVEE MIRABELLA',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Mirabella Complex, E-18 Gulshan-e-Sehat, Islamabad',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Contact: 03350928668',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'DELIVERY CHALAN',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        Image.asset(
                          'assets/logo/evee.png',
                          height: 100, // 2x bigger
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Meta block centered ─────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'CHALAN #: $chalanNumber',
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Customer Name: ${orderData['name']}',
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Father Name: ${orderData['fatherName'] ?? '-'}',
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'CNIC #: ${orderData['cnic'] ?? '-'}',
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Address: ${orderData['address']}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text('Date: $date', textAlign: TextAlign.center),
                        Text(
                          'Cell: ${orderData['phone']}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Table centered (narrower width) ────────────────────
                    Center(
                      child: SizedBox(
                        width: 460, // smaller table, centered with text
                        child: Table(
                          border: TableBorder.all(color: Colors.black),
                          columnWidths: const {
                            0: FlexColumnWidth(1), // 50/50 columns
                            1: FlexColumnWidth(1),
                          },
                          children: [
                            const TableRow(
                              decoration: BoxDecoration(color: Colors.black),
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Text(
                                    'DESCRIPTION',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Text(
                                    'DETAIL',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            _row(
                              'Model',
                              (orderData['bikeName'] ?? '').toString(),
                            ),
                            _row('Year', '2025'),
                            _row('Chassis #', chassis),
                            _row('Engine #', engine),
                            _row('Color', color),
                          ],
                        ),
                      ),
                    ),

                    // ── Signature area centered (half-width lines) ─────────
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment
                          .spaceEvenly, // center the two blocks
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: const [
                            SizedBox(height: 24),
                            SizedBox(
                              width: 140,
                              height: 1,
                              child: ColoredBox(color: Colors.black),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Customer Signature',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: const [
                            SizedBox(height: 24),
                            SizedBox(
                              width: 140,
                              height: 1,
                              child: ColoredBox(color: Colors.black),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Dealer Signature',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Terms & Conditions (centered) ──────────────────────
                    const Text(
                      'Terms & Conditions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const Text(
                      '1. Dealership will not be responsible for any damages claimed after accepting the delivery',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.black),
                    ),
                    const Text(
                      '2. For after sales services call Evee Customer Support on (+92 325 2292 290)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),

            // Footer actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _printChalanPdf(),
                    icon: const Icon(Icons.print),
                    label: const Text('Print Delivery Chalan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TableRow _row(String a, String b) => TableRow(
    children: [
      Padding(
        padding: const EdgeInsets.all(6),
        child: Text(a, textAlign: TextAlign.center),
      ),
      Padding(
        padding: const EdgeInsets.all(6),
        child: Text(b, textAlign: TextAlign.center),
      ),
    ],
  );

  Future<void> _printChalanPdf() async {
    final bytes = await buildChalanPdfBytes(
      orderData: orderData,
      chalanNumber: chalanNumber,
      date: date,
      chassis: chassis,
      engine: engine,
      color: color,
    );
    await Printing.layoutPdf(
      onLayout: (f) async => bytes,
      name: 'delivery_chalan_${orderData['name']}.pdf',
    );
  }
}

// ---------------- UI helpers ----------------

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
              _GradientButton(text: 'Check Details', onTap: onViewDetails),
            ],
          ),
        ],
      ),
    );
  }
}

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
                colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x332EA8FF),
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
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    border: Border.all(color: Colors.white.withOpacity(0.10)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x332EA8FF),
                        blurRadius: 30,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // wrap content by default
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [Expanded(child: title)],
                          ),
                        ),
                      ),

                      // Content (scrollable, but only takes space it needs)
                      Flexible(
                        fit: FlexFit.loose, // <- key change vs Expanded
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final bottomInset = MediaQuery.of(
                              context,
                            ).viewInsets.bottom;
                            return SingleChildScrollView(
                              primary: false, // correct for nested scrollables
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                18,
                                0,
                                18,
                                16 +
                                    bottomInset, // keep fields visible above keyboard
                              ),
                              child: ConstrainedBox(
                                // keep width full; don't force height
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: content,
                              ),
                            );
                          },
                        ),
                      ),

                      // Actions
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 10,
                            runSpacing: 8,
                            children: actions,
                          ),
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
      borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.5),
    );

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
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

// ===================
// Center circular UI
// ===================
class _CircleSuccess extends StatelessWidget {
  const _CircleSuccess();

  @override
  Widget build(BuildContext context) {
    const double outerSize = 240;
    const double innerSize = 208;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(), // tap to dismiss
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: outerSize,
              height: outerSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4D2EA8FF),
                    blurRadius: 50,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
            Container(
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F0F23).withOpacity(0.85),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                boxShadow: const [
                  BoxShadow(color: Color(0x332EA8FF), blurRadius: 28),
                ],
              ),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 66,
                        color: Color(0xFF34D399),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Booking Received!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "We'll get back to you soon.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Tap to close',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
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
