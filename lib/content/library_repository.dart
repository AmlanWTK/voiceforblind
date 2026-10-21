import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';

/// Loads the generated book catalog from the app bundle.
///
/// Never throws: if the catalog is missing or unreadable the app still opens
/// with an empty library and says so, instead of crashing.
class LibraryRepository {
  LibraryRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const catalogAsset = 'assets/library/catalog.json';

  final AssetBundle _bundle;
  Library? _cache;

  /// Human-readable reason the last load failed, if it did.
  String? loadError;

  Future<Library> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final raw = await _bundle.loadString(catalogAsset);
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('catalog root is not an object');
      }
      final library = Library.fromJson(json);
      _cache = library;
      loadError = null;
      return library;
    } catch (e, st) {
      loadError = '$e';
      debugPrint('Shuni: could not load $catalogAsset: $e\n$st');
      return Library.empty;
    }
  }
}
