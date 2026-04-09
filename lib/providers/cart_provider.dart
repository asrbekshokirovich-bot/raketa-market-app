import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class CartItem {
  final String id;
  final String title;
  final String subtitle;
  final String price;
  final String? oldPrice;
  final String imagePath;
  final List<dynamic>? images;
  final String? discountBadge;
  final String unit;
  int quantity;
  bool isSelected;

  CartItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    this.oldPrice,
    required this.imagePath,
    this.images,
    this.discountBadge,
    this.unit = 'ta',
    this.quantity = 1,
    this.isSelected = true,
  });
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  String? _userId;

  Map<String, CartItem> get items => _items;
  String? get userId => _userId;

  int get itemCount {
    return _items.length;
  }

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      if (cartItem.isSelected) {
        final priceNumStr = cartItem.price.replaceAll(' so\'m', '').replaceAll(' ', '');
        final price = double.tryParse(priceNumStr) ?? 0.0;
        total += price * cartItem.quantity;
      }
    });
    return total;
  }

  // ProxyProvider orqali userId-ni yangilash
  void updateUserId(String? newId) {
    try {
      if (_userId != newId) {
        _userId = newId;
        if (_userId != null) {
          // XATONING YECHIMI: Build vaqtida notifyListeners chaqirilishini oldini olish
          Future.microtask(() => loadFromDatabase());
        } else {
          Future.microtask(() {
            _items.clear();
            notifyListeners();
          });
        }
      }
    } catch (e) {
      debugPrint('❌ CartProvider.updateUserId ERROR: $e');
    }
  }

  // Bazadan yuklash
  Future<void> loadFromDatabase() async {
    try {
      if (_userId == null) return;
      
      final remoteItems = await SupabaseService.getCartItems(_userId!);
      
      _items.clear();
      for (var item in remoteItems) {
        final product = item['product_listings'];
        if (product != null) {
          _items[product['id']] = CartItem(
            id: product['id'],
            title: product['name'] ?? '',
            subtitle: product['category'] ?? '',
            price: "${product['price']} so'm",
            imagePath: product['image_url'] ?? 'assets/images/placeholder.png',
            unit: product['unit'] ?? 'ta',
            quantity: item['quantity'] ?? 1,
          );
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ CartProvider.loadFromDatabase ERROR: $e');
      // Xatolik bo'lsa ham foydalanuvchiga bo'sh savat ko'rsatamiz (oq ekran o'rniga)
      notifyListeners();
    }
  }

  void toggleSelection(String productId) {
    if (_items.containsKey(productId)) {
      _items.update(
        productId,
        (existing) => CartItem(
          id: existing.id,
          title: existing.title,
          subtitle: existing.subtitle,
          price: existing.price,
          oldPrice: existing.oldPrice,
          imagePath: existing.imagePath,
          images: existing.images,
          discountBadge: existing.discountBadge,
          unit: existing.unit,
          quantity: existing.quantity,
          isSelected: !existing.isSelected,
        ),
      );
      notifyListeners();
    }
  }

  Future<void> addItem({
    required String productId,
    required String title,
    required String subtitle,
    required String price,
    String? oldPrice,
    required String imagePath,
    List<dynamic>? images,
    String? discountBadge,
    String? unit,
  }) async {
    debugPrint('--- CART_PROVIDER: ADDING ITEM $productId ---');
    int newQuantity = 1;
    if (_items.containsKey(productId)) {
      newQuantity = _items[productId]!.quantity + 1;
      _items.update(
        productId,
        (existing) => CartItem(
          id: existing.id,
          title: existing.title,
          subtitle: existing.subtitle,
          price: existing.price,
          oldPrice: existing.oldPrice,
          imagePath: existing.imagePath,
          images: existing.images,
          discountBadge: existing.discountBadge,
          unit: existing.unit,
          quantity: newQuantity,
          isSelected: existing.isSelected,
        ),
      );
    } else {
      _items.putIfAbsent(
        productId,
        () => CartItem(
          id: productId,
          title: title,
          subtitle: subtitle,
          price: price,
          oldPrice: oldPrice,
          imagePath: imagePath,
          images: images,
          discountBadge: discountBadge,
          unit: unit ?? 'ta',
          quantity: 1,
          isSelected: true,
        ),
      );
    }
    notifyListeners();
    // Bazaga sinxronizatsiya
    if (_userId != null) {
      await SupabaseService.addToCart(_userId!, productId, newQuantity);
    }
  }

  Future<void> removeItem(String productId) async {
    _items.remove(productId);
    notifyListeners();
    if (_userId != null) {
      await SupabaseService.removeFromCart(_userId!, productId);
    }
  }

  Future<void> removeSingleItem(String productId) async {
    if (!_items.containsKey(productId)) return;
    
    if (_items[productId]!.quantity > 1) {
      int newQuantity = _items[productId]!.quantity - 1;
      _items.update(
        productId,
        (existing) => CartItem(
          id: existing.id,
          title: existing.title,
          subtitle: existing.subtitle,
          price: existing.price,
          oldPrice: existing.oldPrice,
          imagePath: existing.imagePath,
          images: existing.images,
          discountBadge: existing.discountBadge,
          unit: existing.unit,
          quantity: newQuantity,
          isSelected: existing.isSelected,
        ),
      );
      notifyListeners();
      if (_userId != null) {
        await SupabaseService.addToCart(_userId!, productId, newQuantity);
      }
    } else {
      _items.remove(productId);
      notifyListeners();
      if (_userId != null) {
        await SupabaseService.removeFromCart(_userId!, productId);
      }
    }
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    if (_userId != null) {
      await SupabaseService.clearCart(_userId!);
    }
  }

  bool isInCart(String productId) {
    return _items.containsKey(productId);
  }

  CartItem? getItem(String productId) {
    return _items[productId];
  }
}
