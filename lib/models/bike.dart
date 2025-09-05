// lib/models/bike.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Core model for a Bike item shown in the catalog and details page.
class Bike {
  final String id;
  final String name;
  final String price;
  final String imageUrl;
  final List<String> gallery; // up to 3 extra images (optional)
  final String details;

  const Bike({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.gallery,
    required this.details,
  });

  /// Build a [Bike] from a Firestore document.
  ///
  /// Supports multiple legacy keys for images and details to keep backward compatibility.
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

    // Merge possible image arrays and single fields
    final gallery = <String>{}
      ..addAll(_urls(data['gallery']))
      ..addAll(_urls(data['images']))
      ..addAll(_urls(data['extraImages']));

    for (final k in const ['image2', 'image3', 'image4']) {
      final v = (data[k] ?? '').toString();
      if (v.startsWith('http')) gallery.add(v);
    }

    // Remove duplicates / exclude main image, keep max 3
    final cleaned = gallery.where((u) => u != mainUrl).toList();
    final top3 = cleaned.take(3).toList();

    // Details: support several keys
    final details =
        (data['details'] ?? data['detail'] ?? data['description'] ?? '')
            .toString();

    return Bike(
      id: d.id,
      name: (data['name'] ?? '').toString(),
      price: (data['price'] ?? '').toString(),
      imageUrl: mainUrl,
      gallery: top3,
      details: details,
    );
  }

  /// Optional convenience: basic map (e.g., for writes or local caching).
  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'imageUrl': imageUrl,
    'gallery': gallery,
    'details': details,
  };
}
