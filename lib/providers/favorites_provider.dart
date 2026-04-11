import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

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
  String? _userId;

  Map<String, FavoriteItem> get items => {..._items};

  int get itemCount => _items.length;

  bool isFavorite(String productId) {
    return _items.containsKey(productId);
  }

  FavoritesProvider() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('favoritesData')) return;
      
      final String? encodedData = prefs.getString('favoritesData');
      if (encodedData == null) return;
      
      final List<dynamic> decodedData = json.decode(encodedData);
      _items = {};
      for (var item in decodedData) {
        _items[item['key']] = FavoriteItem.fromJson(item['value']);
      }
      Future.microtask(() => notifyListeners());
    } catch (e) {
      debugPrint('Error loading local favorites: $e');
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedData = json.encode(
        _items.entries.map((e) => {"key": e.key, "value": e.value.toJson()}).toList()
      );
      await prefs.setString('favoritesData', encodedData);
    } catch (e) {
      debugPrint('Error saving local favorites: $e');
    }
  }

  void updateUserId(String? newId) {
    if (_userId != newId) {
      _userId = newId;
      if (_userId != null) {
        Future.microtask(() => fetchFavorites());
      } else {
        Future.microtask(() {
          _items.clear();
          _saveFavorites();
          notifyListeners();
        });
      }
    }
  }

  Future<void> fetchFavorites() async {
    if (_userId == null) return;
    
    try {
      final data = await SupabaseService.getFavoriteItems(_userId!);
      
      final Map<String, FavoriteItem> loadedItems = {};
      for (var favoriteRow in data) {
        final product = favoriteRow['product_listings'];
        if(product != null) {
          final productId = favoriteRow['product_id'];
          
          loadedItems[productId] = FavoriteItem(
            id: productId,
            title: product['name'] ?? '',
            subtitle: product['category'] ?? '',
            price: "${product['price']} so'm",
            oldPrice: product['old_price']?.toString(),
            imagePath: product['image_url'] ?? 'assets/images/placeholder.png',
            images: product['images'] != null ? List<String>.from(product['images']) : [],
            discountBadge: product['discount_badge'],
            unit: product['unit'] ?? 'dona',
          );
        }
      }
      _items = loadedItems;
      _saveFavorites();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
    }
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
      if (_userId != null) {
         SupabaseService.removeFavorite(_userId!, productId);
      }
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
      if (_userId != null) {
         SupabaseService.addFavorite(_userId!, productId);
      }
    }
    _saveFavorites();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _saveFavorites();
    notifyListeners();
  }
}
