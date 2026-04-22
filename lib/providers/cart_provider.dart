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
  final String? sku;
  final int stock;
  final int min_stock;

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
    this.sku,
    this.stock = 0,
    this.min_stock = 10,
  });
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};
  String? _userId;

  Map<String, CartItem> get items => _items;
  String? get userId => _userId;

  Map<String, dynamic>? _deliveryConfig;
  Map<String, dynamic>? get deliveryConfig => _deliveryConfig;

  double calculateDeliveryFee(double subtotal) {
    if (_deliveryConfig == null) return 15000.0; // Default fallback

    final mode = _deliveryConfig!['mode'] ?? 'fixed';
    
    if (mode == 'fixed') {
      return (_deliveryConfig!['fixedPrice'] as num?)?.toDouble() ?? 15000.0;
    } else if (mode == 'tiered') {
      final tiers = _deliveryConfig!['tiers'] as List<dynamic>? ?? [];
      for (var tier in tiers) {
        final Map<String, dynamic> t = tier as Map<String, dynamic>;
        final min = (t['min'] as num?)?.toDouble() ?? 0.0;
        final max = (t['max'] as num?)?.toDouble() ?? double.infinity;
        final price = (t['price'] as num?)?.toDouble() ?? 0.0;
        
        if (subtotal >= min && subtotal <= max) {
          return price;
        }
      }
    }
    
    return 15000.0;
  }

  /// Keyingi dastavka pog'onasi haqida ma'lumot olish
  Map<String, dynamic>? getNextTierInfo(double subtotal) {
    if (_deliveryConfig == null || _deliveryConfig!['mode'] != 'tiered') return null;

    final tiers = _deliveryConfig!['tiers'] as List<dynamic>? ?? [];
    if (tiers.isEmpty) return null;

    // Pog'onalarni min bo'yicha saralaymiz
    final sortedTiers = List<dynamic>.from(tiers);
    sortedTiers.sort((a, b) => ((a['min'] as num?)?.toDouble() ?? 0.0)
        .compareTo((b['min'] as num?)?.toDouble() ?? 0.0));

    for (var tier in sortedTiers) {
      final Map<String, dynamic> t = tier as Map<String, dynamic>;
      final min = (t['min'] as num?)?.toDouble() ?? 0.0;
      
      if (min > subtotal) {
        return {
          'needed': min - subtotal,
          'next_price': (t['price'] as num?)?.toDouble() ?? 0.0,
          'is_free': ((t['price'] as num?)?.toDouble() ?? 0.0) == 0,
        };
      }
    }

    return null; // Keyingi pog'ona yo'q (eng yuqori pog'onada)
  }

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
      
      // Yangi ma'lumotlarni yig'amiz, lekin eskilarini isSelected holatini saqlab qolamiz
      final Map<String, CartItem> newItems = {};
      for (var item in remoteItems) {
        final product = item['product_listings'];
        if (product != null) {
          final String pId = product['id'];
          // Agar bizda bu mahsulot allaqachon bo'lsa, uning tanlanganlik holatini saqlaymiz
          final bool wasSelected = _items.containsKey(pId) ? _items[pId]!.isSelected : true;
          
          // Narxlarni formatlash uchun yordamchi
          String formatPrice(int p) {
            return '${p.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} so\'m';
          }
          
          final String rawPrice = product['price']?.toString() ?? '0';
          final String rawOldPrice = product['original_price']?.toString() ?? '0';
          
          int priceVal = int.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          int oldPriceVal = int.tryParse(rawOldPrice.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

          newItems[pId] = CartItem(
            id: pId,
            title: product['name'] ?? '',
            subtitle: product['category'] ?? '',
            price: formatPrice(priceVal),
            oldPrice: oldPriceVal > priceVal && priceVal > 0 ? formatPrice(oldPriceVal) : null,
            imagePath: product['image_url'] ?? 'assets/images/placeholder.png',
            unit: product['unit'] ?? 'ta',
            quantity: item['quantity'] ?? 1,
            isSelected: wasSelected,
            sku: product['sku']?.toString(),
            stock: int.tryParse(product['stock']?.toString() ?? '0') ?? 0,
            min_stock: int.tryParse(product['min_stock']?.toString() ?? '10') ?? 10,
            discountBadge: (product['discount_percent'] != null && product['discount_percent'].toString() != '0')
                ? '${product['discount_percent']}% CHEGIRMA'
                : (oldPriceVal > priceVal && priceVal > 0)
                    ? '${((oldPriceVal - priceVal) / oldPriceVal * 100).round()}% CHEGIRMA'
                    : null,
          );
        }
      }
      
      _items.clear();
      _items.addAll(newItems);
      
      // Fetch delivery config to stay synced with CRM
      _deliveryConfig = await SupabaseService.getDeliveryConfig();
      
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
          sku: existing.sku,
          stock: existing.stock,
          min_stock: existing.min_stock,
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
    String? sku,
    int stock = 0,
    int min_stock = 10,
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
          sku: existing.sku,
          stock: existing.stock,
          min_stock: existing.min_stock,
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
          sku: sku,
          stock: stock,
          min_stock: min_stock,
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
          sku: existing.sku,
          stock: existing.stock,
          min_stock: existing.min_stock,
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

  Future<void> fetchDeliveryConfig() async {
    try {
      _deliveryConfig = await SupabaseService.getDeliveryConfig();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ CartProvider.fetchDeliveryConfig ERROR: $e');
    }
  }

  Future<void> clearSelectedItems() async {
    // FAQAT Xaridga tanlangan (isSelected = true) narsalarni o'chiramiz
    final selectedIds = _items.values
        .where((item) => item.isSelected)
        .map((item) => item.id)
        .toList();

    for (final id in selectedIds) {
      _items.remove(id);
      if (_userId != null) {
        await SupabaseService.removeFromCart(_userId!, id);
      }
    }
    notifyListeners();
  }

  bool isInCart(String productId) {
    return _items.containsKey(productId);
  }

  CartItem? getItem(String productId) {
    return _items[productId];
  }
}
