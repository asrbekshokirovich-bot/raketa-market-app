import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteItem {
  final String id;
  final String title;
  final String subtitle;
  final String price;
  final String? oldPrice;
  final String imagePath;
  final List<String> images;
  final String? discountBadge;
  final String unit;

  FavoriteItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    this.oldPrice,
    required this.imagePath,
    required this.images,
    this.discountBadge,
    required this.unit,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'price': price,
    'oldPrice': oldPrice,
    'imagePath': imagePath,
    'images': images,
    'discountBadge': discountBadge,
    'unit': unit,
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
    id: json['id'],
    title: json['title'],
    subtitle: json['subtitle'],
    price: json['price'],
    oldPrice: json['oldPrice'],
    imagePath: json['imagePath'],
    images: List<String>.from(json['images'] ?? []),
    discountBadge: json['discountBadge'],
    unit: json['unit'] ?? 'dona',
  );
}

class FavoritesProvider with ChangeNotifier {
  Map<String, FavoriteItem> _items = {};
  SharedPreferences? _prefs;
  static const String _storageKey = 'favorite_items_v1';

  Map<String, FavoriteItem> get items => {..._items};

  int get itemCount => _items.length;

  bool isFavorite(String productId) {
    return _items.containsKey(productId);
  }

  FavoritesProvider() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadFromLocal();
  }

  Future<void> _loadFromLocal() async {
    if (_prefs == null) return;
    
    final storedData = _prefs!.getString(_storageKey);
    if (storedData != null) {
      final decodedData = json.decode(storedData) as Map<String, dynamic>;
      _items = decodedData.map(
        (key, value) => MapEntry(key, FavoriteItem.fromJson(value)),
      );
      notifyListeners();
    }
  }

  Future<void> _saveToLocal() async {
    if (_prefs == null) return;
    
    final encodedData = json.encode(
      _items.map((key, value) => MapEntry(key, value.toJson())),
    );
    await _prefs!.setString(_storageKey, encodedData);
  }

  void toggleFavorite({
    required String productId,
    required String title,
    required String subtitle,
    required String price,
    String? oldPrice,
    required String imagePath,
    List<String> images = const [],
    String? discountBadge,
    String unit = 'dona',
  }) {
    if (_items.containsKey(productId)) {
      _items.remove(productId);
    } else {
      _items.putIfAbsent(
        productId,
        () => FavoriteItem(
          id: productId,
          title: title,
          subtitle: subtitle,
          price: price,
          oldPrice: oldPrice,
          imagePath: imagePath,
          images: images,
          discountBadge: discountBadge,
          unit: unit,
        ),
      );
    }
    _saveToLocal();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _saveToLocal();
    notifyListeners();
  }
}
